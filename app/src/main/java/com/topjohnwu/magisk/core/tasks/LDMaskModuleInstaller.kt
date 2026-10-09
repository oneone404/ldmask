package com.topjohnwu.magisk.core.tasks

import com.topjohnwu.magisk.core.Info
import com.topjohnwu.magisk.core.di.AppContext
import com.topjohnwu.magisk.core.di.ServiceLocator
import com.topjohnwu.superuser.CallbackList
import com.topjohnwu.superuser.Shell
import okhttp3.HttpUrl
import okhttp3.HttpUrl.Companion.toHttpUrl
import okhttp3.Request
import okhttp3.Response
import okhttp3.logging.HttpLoggingInterceptor
import java.io.File
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import kotlinx.coroutines.CancellationException

private class GitHubModuleSource : QuickReleaseSource {
    private val client = ServiceLocator.okhttp.newBuilder().apply {
        cache(null)
        interceptors().removeAll { it is HttpLoggingInterceptor }
        followRedirects(false)
        followSslRedirects(false)
        retryOnConnectionFailure(false)
        connectTimeout(15, TimeUnit.SECONDS)
        readTimeout(30, TimeUnit.SECONDS)
        callTimeout(120, TimeUnit.SECONDS)
    }.build()

    private fun response(initial: String): Response {
        var url = initial.toHttpUrl()
        repeat(6) { attempt ->
            checkUrl(url)
            val request = Request.Builder().url(url)
                .header("Accept", "application/vnd.github+json")
                .header("X-GitHub-Api-Version", "2022-11-28").build()
            val result = client.newCall(request).execute()
            if (result.code in setOf(301, 302, 303, 307, 308)) {
                val location = result.header("Location")
                result.close()
                check(attempt < 5 && location != null) { "Too many/invalid redirects" }
                url = requireNotNull(url.resolve(location)) { "Invalid redirect" }
            } else {
                if (!result.isSuccessful) {
                    val code = result.code
                    result.close()
                    error("GitHub HTTP $code (network, rate limit or release unavailable)")
                }
                return result
            }
        }
        error("Too many redirects")
    }

    private fun checkUrl(url: HttpUrl) {
        require(url.isHttps && url.port == 443 && url.username.isEmpty() && url.password.isEmpty()) { "Unsafe download URL" }
        require(url.host in setOf("api.github.com", "github.com", "release-assets.githubusercontent.com", "objects.githubusercontent.com")) { "Unexpected download host" }
    }

    override fun latest(): ModuleRelease = response(
        "https://api.github.com/repos/${QuickModuleCatalog.REPO}/releases/latest"
    ).use { res ->
        val body = requireNotNull(res.body)
        QuickModuleCatalog.release(body.byteStream().readBytesBounded(512 * 1024).toString(Charsets.UTF_8))
    }

    override fun manifest(release: ModuleRelease): List<QuickModule> {
        val asset = requireNotNull(release.assets["modules.json"])
        return response(asset.url).use { res ->
            val bytes = requireNotNull(res.body).byteStream().readBytesBounded(16384)
            require(bytes.size.toLong() == asset.size) { "Manifest download incomplete" }
            QuickModuleCatalog.manifest(bytes.toString(Charsets.UTF_8), release)
        }
    }

    override fun download(asset: ReleaseAsset, target: File) {
        response(asset.url).use { res ->
            val body = requireNotNull(res.body)
            val length = body.contentLength()
            require(length == -1L || length == asset.size) { "HTTP size mismatch" }
            body.byteStream().use { input ->
                target.outputStream().use { output ->
                    val buffer = ByteArray(8192)
                    var total = 0L
                    while (true) {
                        val n = input.read(buffer)
                        if (n < 0) break
                        total += n
                        require(total <= asset.size) { "Download exceeds expected size" }
                        output.write(buffer, 0, n)
                    }
                    require(total == asset.size) { "ZIP download incomplete" }
                }
            }
        }
    }
}

object LDMaskModuleInstaller {
    private fun quote(value: String) = "'" + value.replace("'", "'\\''") + "'"

    suspend fun exec(log: (String) -> Unit): QuickInstallResult {
        if (!Info.env.isActive) {
            log("! Root is not active. Install LDMask root first.")
            return QuickInstallResult(false, 0)
        }
        val lines = AtomicInteger()
        val boundedLog: (String) -> Unit = {
            val line = lines.incrementAndGet()
            if (line <= 2000) log(it.take(1024))
            else if (line == 2001) log("! Additional installer output suppressed")
        }
        return try {
        QuickModuleInstall(AppContext.cacheDir, GitHubModuleSource(), { file, module ->
            val output = object : CallbackList<String>() {
                override fun onAddElement(e: String?) { if (e != null) boundedLog(e) }
            }
            // BusyBox shipped with LDMask contains timeout. Never fall back to an unbounded install.
            val command = "bb=/data/adb/magisk/busybox; " +
                "[ -x \"\$bb\" ] || bb=\"\$(magisk --path)/.magisk/busybox\"; " +
                "[ -x \"\$bb\" ] || exit 1; " +
                "\"\$bb\" timeout -s TERM -k 5 180 magisk --install-module ${quote(file.absolutePath)}"
            val success = Shell.cmd(command).to(output).exec().isSuccess
            val prop = quote("/data/adb/modules_update/${module.id}/module.prop")
            success && Shell.cmd(
                "grep -qxF ${quote("id=${module.id}")} $prop && " +
                    "grep -qxF ${quote("versionCode=${module.versionCode}")} $prop"
            ).exec().isSuccess
        }, boundedLog).exec()
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            boundedLog("! Cannot start installation: ${e.message ?: e.javaClass.simpleName}")
            QuickInstallResult(false, 0)
        }
    }
}
