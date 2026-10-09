package com.topjohnwu.magisk.core.tasks

import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.core.Info
import com.topjohnwu.magisk.core.di.AppContext
import com.topjohnwu.superuser.Shell
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.util.concurrent.atomic.AtomicBoolean

/** Bounded user-requested recovery only; failure is intentionally silent. */
object LDMaskGameLauncher {
    private val running = AtomicBoolean(false)
    suspend fun exec(): Boolean = withContext(Dispatchers.IO) {
        if (!Info.env.isActive || !running.compareAndSet(false, true)) return@withContext false
        try {
            val script = AppContext.resources.openRawResource(R.raw.ldmask_open_game)
                .bufferedReader().use { it.readText() }
            val command = "/data/adb/magisk/busybox timeout -s TERM -k 2 120 " +
                "/system/bin/sh -c ${LDMaskRootPresetPlan.quote(script)}"
            val result = Shell.cmd(command).exec()
            result.isSuccess && "LDLOGIN_GAME_READY" in result.out
        } finally {
            running.set(false)
        }
    }
}
