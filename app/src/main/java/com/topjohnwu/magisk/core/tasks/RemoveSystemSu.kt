package com.topjohnwu.magisk.core.tasks

import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.core.Info
import com.topjohnwu.magisk.core.di.AppContext
import com.topjohnwu.superuser.CallbackList
import com.topjohnwu.superuser.Shell
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicInteger

object RemoveSystemSu {
    private fun quote(value: String) = "'" + value.replace("'", "'\\''") + "'"
    suspend fun exec(log: (String) -> Unit): Boolean = withContext(Dispatchers.IO + NonCancellable) {
        if (!Info.env.isActive) {
            log("! Root is not active")
            return@withContext false
        }
        if (!ModuleInstallGate.acquire()) {
            log("! Another module/root action is running")
            return@withContext false
        }
        try {
            val rawScript = AppContext.resources.openRawResource(R.raw.ldmask_remove_system_su)
                .bufferedReader().use { it.readText() }
            // libsu starts bare 'su' on app restart. Require the independent
            // root executable to remain discoverable via the app's original PATH.
            val script = "ORIGINAL_APP_PATH=${quote(System.getenv("PATH").orEmpty())}\n$rawScript"
            val quoted = quote(script)
            val lines = AtomicInteger()
            val output = object : CallbackList<String>() {
                override fun onAddElement(e: String?) {
                    if (e != null && lines.incrementAndGet() <= 250) log(e.take(1024))
                }
            }
            val command = "( bb=/data/adb/magisk/busybox; " +
                "[ -f \"\$bb\" ] && [ -x \"\$bb\" ] || bb=\"\$(magisk --path)/.magisk/busybox/busybox\"; " +
                "[ -f \"\$bb\" ] && [ -x \"\$bb\" ] || { echo '! BusyBox unavailable'; exit 1; }; " +
                "\"\$bb\" timeout -s TERM -k 5 30 \"\$bb\" sh -c $quoted )"
            val success = Shell.cmd(command).to(output).exec().isSuccess
            if (!success) log("! Cleanup failed or timed out. Review output; one file may already have been removed.")
            success
        } catch (e: Exception) {
            log("! Cleanup error: ${e.message?.take(1024) ?: e.javaClass.simpleName}")
            false
        } finally {
            ModuleInstallGate.release()
        }
    }
}
