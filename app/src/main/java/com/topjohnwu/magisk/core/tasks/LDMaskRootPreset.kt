package com.topjohnwu.magisk.core.tasks

import android.content.pm.PackageManager
import com.topjohnwu.magisk.core.Config
import com.topjohnwu.magisk.core.di.AppContext
import com.topjohnwu.magisk.ui.deny.AppProcessInfo
import com.topjohnwu.superuser.Shell
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext

/** Called only after successful direct-system root installation, never on ordinary app open. */
object LDMaskRootPreset {
    suspend fun exec(log: (String) -> Unit): Boolean = withContext(Dispatchers.IO + NonCancellable) {
        try {
            val pm = AppContext.packageManager
            val targets = mutableSetOf<Pair<String, String>>()
            for (pkg in LDMaskRootPresetPlan.packages) {
                val info = try {
                    pm.getApplicationInfo(pkg, 0)
                } catch (_: PackageManager.NameNotFoundException) {
                    log("- Skip Hide: $pkg is not installed")
                    continue
                }
                targets += pkg to pkg
                // Use the same manifest/process reader as the MagiskHide screen,
                // including secondary processes such as :adnw. Do not guess suffixes.
                AppProcessInfo(info, pm, emptyList()).processes.forEach {
                    targets += it.packageName to it.name
                }
                log("- Preset Hide: $pkg")
            }
            val script = LDMaskRootPresetPlan.script(targets)
            val hook = LDMaskRootPresetPlan.hook
            val dir = "/data/adb/post-fs-data.d"
            val stage = "( umask 077; " +
                "[ ! -L '$dir' ] && [ ! -L '$hook' ] && [ ! -L '$hook.tmp' ] || exit 1; " +
                "mkdir -p '$dir' && " +
                "printf '%s' ${LDMaskRootPresetPlan.quote(script)} > '$hook.tmp' && " +
                "chmod 700 '$hook.tmp' && chown 0:0 '$hook.tmp' && mv -f '$hook.tmp' '$hook' )"
            if (!Shell.cmd(stage).exec().isSuccess) {
                log("! Root installed, but could not save the startup preset. Configure manually.")
                return@withContext false
            }
            // Initial LD root has no Magisk daemon yet. Do not start or restart a
            // daemon here; the staged hook applies at the first normal Magisk boot.
            val immediate = Shell.cmd(
                "/data/adb/magisk/busybox timeout -s TERM -k 2 10 /system/bin/sh '$hook' --persist-only"
            ).exec()
            if (immediate.isSuccess) {
                Config.zygisk = true
                Config.denyList = true
                Config.sulist = false
                log("- Zygisk/MagiskHide configuration saved. Reboot LD to activate it.")
            } else {
                log("- Startup preset saved; it will apply on the next LD reboot before Zygisk starts.")
            }
            log("- No automatic reboot. The preset removes itself after successful startup application.")
            true
        } catch (e: Exception) {
            log("! Root installed; preset error: ${e.message?.take(512)}. Configure manually.")
            false
        }
    }
}
