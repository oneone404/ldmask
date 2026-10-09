package com.topjohnwu.magisk.core.tasks

import org.junit.Assert.*
import org.junit.Test
import java.io.File

/** Source/packaging contracts, not a substitute for live Android/root tests. */
class LDMaskUiContractTest {
    private fun source(path: String): String {
        val files = listOf(File("src/main/$path"), File("app/src/main/$path"))
        return requireNotNull(files.firstOrNull { it.isFile }).readText()
    }

    @Test fun noHomeWarningViewOrHideButton() {
        val xml = source("res/layout/fragment_home_md2.xml")
        assertFalse(xml.contains("home_notice"))
        assertFalse(xml.contains("noticeVisible"))
        assertFalse(xml.contains("hideNotice"))
        assertTrue(xml.contains("include_home_magisk"))
        assertTrue(xml.contains("include_home_manager"))
    }

    @Test fun cleanupIsAnAlwaysVisibleToolbarAction() {
        val xml = source("res/menu/menu_module_ldmask.xml")
        assertTrue(xml.contains("action_remove_system_su"))
        assertTrue(xml.contains("@drawable/ic_delete_md2"))
        assertTrue(xml.contains("showAsAction=\"always\""))
    }

    @Test fun cleanupHasFixedFileTargetsAndPreservesIndependentRoot() {
        val script = source("res/raw/ldmask_remove_system_su.sh")
        assertEquals(2, Regex("for TARGET in /system/bin/su /system/xbin/su; do").findAll(script).count())
        assertTrue(script.contains("rm -f -- \"\$TARGET\""))
        assertFalse(script.contains("rm -r"))
        assertTrue(script.contains("Refusing directory"))
        assertTrue(script.contains("Root depends on a target file"))
        assertTrue(script.contains("ORIGINAL_APP_PATH"))
        assertTrue(script.contains("Independent Magisk su is not usable"))
        assertTrue(script.contains("trap finish EXIT"))
        assertTrue(script.contains("mount -o ro,remount"))
    }

    @Test fun cleanupRequiresConfirmationAndHasNoReboot() {
        val dialog = source("java/com/topjohnwu/magisk/dialog/RemoveSystemSuDialog.kt")
        val task = source("java/com/topjohnwu/magisk/core/tasks/RemoveSystemSu.kt")
        assertTrue(dialog.contains("ButtonType.POSITIVE"))
        assertTrue(dialog.contains("ButtonType.NEGATIVE"))
        assertTrue(task.contains("ModuleInstallGate.acquire()"))
        assertTrue(task.contains("ModuleInstallGate.release()"))
        assertTrue(task.contains("timeout -s TERM -k 5 30"))
        assertFalse(task.contains("reboot("))
    }
}
