package com.topjohnwu.magisk.core.tasks

import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.core.Info
import com.topjohnwu.magisk.core.di.AppContext
import com.topjohnwu.superuser.Shell
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/** Explicit one-shot root launch. Fixed VNG target; no restart, config writes or polling. */
object LDMaskGameLauncher {
    suspend fun exec() = withContext(Dispatchers.IO) {
        check(Info.env.isActive) { AppContext.getString(R.string.ldmask_game_root_required) }
        val script = AppContext.resources.openRawResource(R.raw.ldmask_open_game)
            .bufferedReader().use { it.readText() }
        val command = "/data/adb/magisk/busybox timeout -s TERM -k 2 15 " +
            "/system/bin/sh -c ${LDMaskRootPresetPlan.quote(script)}"
        val result = Shell.cmd(command).exec()
        if (!result.isSuccess || "LDLOGIN_LAUNCH_SENT" !in result.out) {
            val message = when (result.code) {
                10 -> R.string.ldmask_game_root_required
                11 -> R.string.ldmask_game_not_found
                124, 137 -> R.string.ldmask_game_launch_timeout
                else -> R.string.ldmask_game_launch_failed
            }
            error(AppContext.getString(message))
        }
    }
}
