package com.topjohnwu.magisk.core.tasks

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.withContext
import java.io.File
import java.util.UUID

interface QuickReleaseSource {
    fun latest(): ModuleRelease
    fun manifest(release: ModuleRelease): List<QuickModule>
    fun download(asset: ReleaseAsset, target: File)
}

data class QuickInstallResult(val success: Boolean, val installedCount: Int)

/** Validate the complete pair before invoking root. No silent rollback or reboot. */
class QuickModuleInstall(
    private val cache: File,
    private val source: QuickReleaseSource,
    private val install: (File, QuickModule) -> Boolean,
    private val log: (String) -> Unit
) {
    suspend fun exec(): QuickInstallResult = withContext(Dispatchers.IO) {
        if (!ModuleInstallGate.acquire()) {
            log("! Another module installation is running")
            return@withContext QuickInstallResult(false, 0)
        }
        val work = File(cache, "ldmask-downloads/install-${UUID.randomUUID()}")
        var count = 0
        try {
            check(work.mkdirs()) { "Cannot create private download directory" }
            log("- Reading latest LDMask release")
            val release = source.latest()
            val modules = source.manifest(release)
            log("- Release ${release.tag}")
            for (module in modules) {
                currentCoroutineContext().ensureActive()
                log("- Downloading ${module.asset.name}")
                val file = File(work, module.asset.name)
                source.download(module.asset, file)
                QuickModuleCatalog.validate(file, module)
                log("- Verified ${module.id} / ${module.versionCode}")
            }
            currentCoroutineContext().ensureActive()
            // Do not abandon a running root installer if the UI scope is cancelled.
            withContext(NonCancellable) {
                for (module in modules) {
                    log("- Installing ${module.id}")
                    check(install(File(work, module.asset.name), module)) { "Installation failed: ${module.id}" }
                    count++
                    log("- Installed $count/2")
                }
            }
            log("- Complete 2/2. Reboot LD manually to activate modules.")
            QuickInstallResult(true, count)
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            log("! ${e.message ?: e.javaClass.simpleName}")
            log("! Installed $count/2. No automatic rollback or reboot.")
            QuickInstallResult(false, count)
        } finally {
            try {
                if (work.exists() && !work.deleteRecursively()) log("! Cannot remove temporary ZIPs")
                else log("- Temporary ZIPs removed")
            } finally {
                ModuleInstallGate.release()
            }
        }
    }
}
