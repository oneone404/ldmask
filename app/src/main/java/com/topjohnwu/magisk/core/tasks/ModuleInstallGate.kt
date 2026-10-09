package com.topjohnwu.magisk.core.tasks

import java.util.concurrent.atomic.AtomicBoolean

/** Shared by manual and quick module installs: Magisk staging is not reentrant. */
object ModuleInstallGate {
    private val busy = AtomicBoolean(false)
    fun acquire() = busy.compareAndSet(false, true)
    fun release() { busy.set(false) }
}
