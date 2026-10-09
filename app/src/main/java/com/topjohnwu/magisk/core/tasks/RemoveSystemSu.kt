package com.topjohnwu.magisk.core.tasks

import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.core.Info
import com.topjohnwu.magisk.core.di.AppContext
import com.topjohnwu.superuser.Shell
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext

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
            val command = "( bb=/data/adb/magisk/busybox; " +
                "[ -f \"\$bb\" ] && [ -x \"\$bb\" ] || bb=\"\$(magisk --path)/.magisk/busybox/busybox\"; " +
                "[ -f \"\$bb\" ] && [ -x \"\$bb\" ] || { echo '! BusyBox unavailable'; exit 1; }; " +
                "\"\$bb\" timeout -s TERM -k 5 30 \"\$bb\" sh -c $quoted )"
            // Drain output before the final result so the generic error cannot
            // overtake the actual mount/deletion diagnosis in the UI.
            val result = Shell.cmd(command).exec()
            (result.out + result.err).take(250).forEach { log(it.take(1024)) }
            val success = result.isSuccess
            if (!success) log("! Cleanup incomplete (exit ${result.code}). Check file and mount results above; reboot may be required.")
            success
        } catch (e: Exception) {
            log("! Cleanup error: ${e.message?.take(1024) ?: e.javaClass.simpleName}")
            false
        } finally {
            ModuleInstallGate.release()
        }
    }
}
