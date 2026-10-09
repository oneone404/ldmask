package com.topjohnwu.magisk.core.tasks

import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.core.Info
import com.topjohnwu.magisk.core.di.AppContext
import com.topjohnwu.superuser.Shell
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext

object RemoveAllModules {
    suspend fun exec(log: (String) -> Unit): Boolean = withContext(Dispatchers.IO + NonCancellable) {
        if (!Info.env.isActive || !ModuleInstallGate.acquire()) {
            log("! Root unavailable or another module/root action is running")
            return@withContext false
        }
        try {
            val script = AppContext.resources.openRawResource(R.raw.ldmask_remove_all_modules)
                .bufferedReader().use { it.readText() }
            val quoted = "'" + script.replace("'", "'\\''") + "'"
            val result = Shell.cmd("( bb=/data/adb/magisk/busybox; " +
                "[ -f \"\$bb\" ] && [ -x \"\$bb\" ] || bb=\"\$(magisk --path)/.magisk/busybox/busybox\"; " +
                "[ -f \"\$bb\" ] && [ -x \"\$bb\" ] || { echo '! BusyBox unavailable'; exit 1; }; " +
                "\"\$bb\" timeout -s TERM -k 5 30 \"\$bb\" sh -c $quoted )").exec()
            (result.out + result.err).take(500).forEach { log(it.take(1024)) }
            if (result.isSuccess) {
                Shell.cmd("copy_preinit_files").exec()
            } else {
                log("! Removal marking failed; some modules may already be marked. Review output.")
            }
            result.isSuccess
        } catch (e: Exception) {
            log("! Removal error: ${e.message?.take(1024)}")
            false
        } finally {
            ModuleInstallGate.release()
        }
    }
}
