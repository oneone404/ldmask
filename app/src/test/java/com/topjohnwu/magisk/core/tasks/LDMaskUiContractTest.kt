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
        assertFalse(xml.contains("home_support"))
        assertFalse(xml.contains("home_follow"))
        assertFalse(xml.contains("DeveloperItem"))
        assertTrue(xml.contains("include_home_magisk"))
        assertTrue(xml.contains("include_home_manager"))
    }

    @Test fun cleanupIsAnAlwaysVisibleToolbarAction() {
        val xml = source("res/menu/menu_module_ldmask.xml")
        assertTrue(xml.contains("action_tools_cleanup"))
        assertTrue(xml.contains("@drawable/ic_delete_md2"))
        assertTrue(xml.contains("showAsAction=\"always\""))
        val popup = source("res/menu/menu_tools_cleanup.xml")
        assertTrue(popup.contains("action_remove_system_su"))
        assertTrue(popup.contains("action_remove_all_modules"))
        assertEquals(2, Regex("<item ").findAll(popup).count())
    }

    @Test fun cleanupHasFixedFileTargetsAndPreservesIndependentRoot() {
        val script = source("res/raw/ldmask_remove_system_su.sh")
        assertEquals(3, Regex("for TARGET in /system/bin/su /system/xbin/su; do").findAll(script).count())
        assertTrue(script.contains("rm -f -- \"\$TARGET\""))
        assertFalse(script.contains("rm -r"))
        assertTrue(script.contains("Refusing directory"))
        assertTrue(script.contains("Root depends on a target file"))
        assertTrue(script.contains("ORIGINAL_APP_PATH"))
        assertTrue(script.contains("Independent Magisk su is not usable"))
        assertTrue(script.contains("trap finish EXIT"))
        assertTrue(script.contains("mount -o ro,remount"))
        assertTrue(script.indexOf("printf '%s\\n' \"\$MOUNT_POINT\"") < script.indexOf("mount -o rw,remount"))
        assertTrue(script.contains("Recovering pending mount"))
        assertTrue(script.contains("system mount is not verified read-only"))
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

    @Test fun settingsOnlyExposeRequestedMagiskControls() {
        val vm = source("java/com/topjohnwu/magisk/ui/settings/SettingsViewModel.kt")
        val factory = vm.substringAfter("private fun createItems()").substringBefore("override fun onItemPressed")
        assertTrue(factory.contains("listOf(Magisk, Zygisk, DenyList, DenyListConfig)"))
        for (hidden in listOf("Theme", "Language", "SuList", "SystemlessHosts", "UpdateChannel", "Superuser"))
            assertFalse(factory.contains(hidden))
        assertTrue(source("res/values-vi/strings.xml").contains(">Cấu Hình MagiskHide<"))
    }

    @Test fun compactToolsAndEnglishNavigation() {
        val nav = source("res/menu/menu_bottom_nav.xml")
        for (title in listOf("ldmask_home", "ldmask_log", "ldmask_tools"))
            assertTrue(nav.contains("@string/$title"))
        val install = source("res/layout/item_module_download.xml")
        assertFalse(install.contains("installPressed()"))
        assertFalse(install.contains("module_action_install_external"))
        assertTrue(install.contains("quickInstallPressed()"))
        val card = source("res/layout/item_module_md2.xml")
        assertFalse(card.contains("module_state_icon"))
        assertTrue(card.contains("ldmask_pending_removal"))
        assertTrue(card.contains("@={item.enabled}"))
    }

    @Test fun defaultThemeIsMigratedBeforeActivitySelectsStyle() {
        val config = source("java/com/topjohnwu/magisk/core/Config.kt")
        assertTrue(config.contains("Theme.Fraxure.ordinal"))
        assertTrue(config.contains("AppCompatDelegate.MODE_NIGHT_NO"))
        val theme = source("java/com/topjohnwu/magisk/ui/theme/Theme.kt")
        assertTrue(theme.contains("if (!Config.ldmaskUiDefaultsApplied) Fraxure"))
        val activity = source("java/com/topjohnwu/magisk/arch/UIActivity.kt")
        assertTrue(activity.contains("Config.darkTheme else AppCompatDelegate.MODE_NIGHT_NO"))
        val splash = source("java/com/topjohnwu/magisk/ui/SplashActivity.kt")
        assertFalse(splash.contains("Config.applyLDMaskUiDefaults()"))
    }

    @Test fun removalMarksActiveAndStagedModulesWithoutDeletingRoot() {
        val script = source("res/raw/ldmask_remove_all_modules.sh")
        assertTrue(script.contains("for BASE in /data/adb/modules /data/adb/modules_update"))
        assertTrue(script.contains("touch \"\$DIR/remove\""))
        assertTrue(script.contains("Refusing symlink"))
        assertFalse(script.contains("rm -"))
        assertFalse(script.contains("magisk --remove-modules"))
        val task = source("java/com/topjohnwu/magisk/core/tasks/RemoveAllModules.kt")
        assertTrue(task.contains("ModuleInstallGate.acquire()"))
        assertTrue(task.contains("ModuleInstallGate.release()"))
        assertTrue(task.contains("timeout -s TERM -k 5 30"))
        val dialog = source("java/com/topjohnwu/magisk/dialog/RemoveAllModulesDialog.kt")
        assertTrue(dialog.contains("ButtonType.POSITIVE"))
        assertTrue(dialog.contains("ButtonType.NEGATIVE"))
    }
}
