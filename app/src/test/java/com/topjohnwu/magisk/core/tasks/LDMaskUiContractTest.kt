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
        assertTrue(task.contains("boundedCommand(script, 30)"))
        assertTrue(task.contains("timeout -s TERM -k 5 \$seconds"))
        assertFalse(task.contains("reboot("))
    }

    @Test fun foreignSuStatusHasOkAndDeleteUsingExistingCleanup() {
        val activity = source("java/com/topjohnwu/magisk/ui/MainActivity.kt")
        val warning = activity.substringAfter("if (!Info.isEmulator && Info.env.isActive")
            .substringBefore("if (applicationInfo.flags")
        assertTrue(warning.contains("File(\"\$it/su\").exists()"))
        assertTrue(warning.contains("setTitle(R.string.ldmask_other_su_title)"))
        assertTrue(warning.contains("setMessage(R.string.ldmask_other_su_message)"))
        assertTrue(warning.contains("ButtonType.POSITIVE) { text = android.R.string.ok }"))
        assertTrue(warning.contains("ButtonType.NEGATIVE"))
        assertTrue(warning.contains("text = R.string.ldmask_delete_action"))
        assertEquals(2, Regex("setButton\\(").findAll(warning).count())
        assertTrue(warning.contains("MainDirections.actionFlashFragment(Const.Value.REMOVE_SYSTEM_SU, null).navigate()"))
        assertFalse(warning.contains("FLASH_MAGISK"))
        assertFalse(warning.contains("FixEnv"))
        assertFalse(warning.contains("rm -"))
    }

    @Test fun foreignSuStatusUsesExactVietnameseTextWithoutChangingOtherWarnings() {
        val vi = source("res/values-vi/ldmask.xml")
        assertTrue(vi.contains(">Thông Báo Trạng Thái<"))
        assertTrue(vi.contains(">Lệnh SU Không Thuộc Về Magisk Đã Được Tìm Thấy<"))
        assertTrue(source("res/values/ldmask.xml").contains(">DELETE<"))
        val activity = source("java/com/topjohnwu/magisk/ui/MainActivity.kt")
        val otherWarnings = activity.substringAfter("if (applicationInfo.flags")
        assertTrue(otherWarnings.contains("R.string.unsupport_general_title"))
        assertTrue(otherWarnings.contains("R.string.unsupport_system_app_msg"))
        assertTrue(otherWarnings.contains("R.string.unsupport_external_storage_msg"))
    }

    @Test fun suRemovalSuccessRequiresVerifiedAbsenceNotSuccessfulRemount() {
        val task = source("java/com/topjohnwu/magisk/core/tasks/RemoveSystemSu.kt")
        assertTrue(task.contains("boundedCommand(verifier, 10)"))
        assertTrue(task.contains("verified.isSuccess && \"LDMASK_SYSTEM_SU_REMOVED\" in verified.out"))
        assertFalse(task.contains("val success = result.isSuccess"))
        val script = source("res/raw/ldmask_verify_system_su.sh")
        assertTrue(script.contains("for TARGET in /system/bin/su /system/xbin/su; do"))
        assertTrue(script.contains("[ ! -e \"\$TARGET\" ] && [ ! -L \"\$TARGET\" ]"))
        assertTrue(script.contains("\"\$ROOT_TMP/su\" -c id"))
        assertTrue(script.contains("LDMASK_SYSTEM_SU_REMOVED"))
        assertFalse(script.contains("rm -"))
        assertFalse(script.contains("mount -"))
    }

    @Test fun toolsHasNoEmptyModulesMessage() {
        val xml = source("res/layout/fragment_module_md2.xml")
        assertFalse(xml.contains("@string/module_empty"))
        assertTrue(xml.contains("@+id/module_list"))
        assertTrue(xml.contains("@{viewModel.loading}"))
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
        assertFalse(card.contains("ldmask_pending_removal"))
        assertFalse(card.contains("module_version_author"))
        assertFalse(card.contains("module_description"))
        assertEquals(1, Regex("<TextView").findAll(card).count())
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

    @Test fun homeUsesInstallIconsAndAppOnlyShowsWhenOutdated() {
        val manager = source("res/layout/include_home_manager.xml")
        val magisk = source("res/layout/include_home_magisk.xml")
        for (xml in listOf(manager, magisk)) {
            assertTrue(xml.contains("AppCompatImageButton"))
            assertTrue(xml.contains("@drawable/ic_install"))
            assertFalse(xml.contains("@drawable/ic_update_md2"))
            assertFalse(xml.contains("android:text=\"@string/install\""))
            assertFalse(xml.contains("android:text=\"@string/update\""))
        }
        assertTrue(manager.contains("viewModel.appState != State.OUTDATED"))
        assertFalse(manager.contains("State.UP_TO_DATE"))
        assertEquals(1, Regex("<androidx.appcompat.widget.AppCompatImageButton").findAll(manager).count())
        val vm = source("java/com/topjohnwu/magisk/ui/home/HomeViewModel.kt")
        val load = vm.substringAfter("override suspend fun doLoadWork()").substringBefore("override fun onNetworkChanged")
        assertTrue(load.contains("svc.fetchUpdate()"))
        assertFalse(load.contains("Info.getRemote(svc)"))
        assertTrue(vm.contains("latest.magisk.versionCode > BuildConfig.VERSION_CODE"))
    }

    @Test fun moduleActionsAreIconOnlyAndNewVersionGated() {
        val xml = source("res/layout/item_module_md2.xml")
        assertFalse(xml.contains("android:text=\"@string/update\""))
        assertFalse(xml.contains("@drawable/ic_update_md2"))
        assertTrue(xml.contains("@drawable/ic_install"))
        assertTrue(xml.contains("android:contentDescription="))
        Regex("<androidx.appcompat.widget.AppCompatImageButton[\\s\\S]*?/>").findAll(xml).forEach {
            assertFalse(it.value.contains("android:text="))
        }
        val item = source("java/com/topjohnwu/magisk/ui/module/ModuleRvItem.kt")
        assertTrue(item.contains("item.updateInfo != null && item.outdated && !isRemoved && !isUpdated"))
        val install = source("res/layout/item_module_download.xml")
        assertFalse(install.contains("ldmask_quick_install_hint"))
        assertTrue(source("res/values-vi/ldmask.xml").contains(">Cài Nhanh Module<"))
    }

    @Test fun rebootAfterFlashIsAnAccessibleIconOnlyFab() {
        val xml = source("res/layout/fragment_flash_md2.xml")
        assertFalse(xml.contains("ExtendedFloatingActionButton"))
        assertFalse(xml.contains("android:text=\"@string/reboot\""))
        assertTrue(xml.contains("FloatingActionButton"))
        assertTrue(xml.contains("android:contentDescription=\"@string/reboot\""))
        assertTrue(xml.contains("@drawable/ic_restart"))
        assertTrue(xml.contains("viewModel.flashing || !viewModel.showReboot"))
    }

    @Test fun magiskInstallIsDirectSystemWithoutRecoveryOrChooser() {
        val vm = source("java/com/topjohnwu/magisk/ui/home/HomeViewModel.kt")
        val action = vm.substringAfter("fun onMagiskPressed()").substringBefore("private suspend fun ensureEnv")
        assertTrue(action.contains("!Info.isRooted || Info.isBootPatched"))
        assertTrue(action.contains("Config.recovery = false"))
        assertTrue(action.contains("Const.Value.FLASH_MAGISK_SYSTEM"))
        assertFalse(action.contains("withExternalRW"))
        assertFalse(source("res/navigation/main.xml").contains("installFragment"))
        val flash = source("java/com/topjohnwu/magisk/ui/flash/FlashViewModel.kt")
            .substringAfter("Const.Value.FLASH_MAGISK_SYSTEM ->").substringBefore("Const.Value.FLASH_INACTIVE_SLOT")
        assertTrue(flash.contains("Config.recovery = false"))
        assertTrue(flash.contains("MagiskInstaller.Direct_system"))
        assertTrue(source("res/layout/include_home_manager.xml").contains("android:text=\"@string/ldmask_app_label\""))
    }

    @Test fun homeDetailsAreBoldAndUnlabelledWithStatusIcons() {
        val manager = source("res/layout/include_home_manager.xml")
        val magisk = source("res/layout/include_home_magisk.xml")
        for (xml in listOf(manager, magisk)) {
            assertFalse(xml.contains("@string/home_installed_version"))
            assertFalse(xml.contains("@string/home_latest_version"))
            assertFalse(xml.contains("@string/home_package"))
            assertTrue(xml.contains("@style/Widget.LDMask.HomeInfo"))
        }
        assertEquals(3, Regex("<TextView").findAll(manager).count()-1)
        assertTrue(manager.contains("viewModel.managerRemoteVersion"))
        assertTrue(manager.contains("viewModel.managerInstalledVersion"))
        assertTrue(manager.contains("context.packageName"))
        assertEquals(2, Regex("viewModel.appState != State.OUTDATED").findAll(manager).count())
        assertEquals(2, Regex("R.drawable.ic_check_md2").findAll(magisk).count())
        assertEquals(2, Regex("R.drawable.ic_close_md2").findAll(magisk).count())
        val style = source("res/values/styles_ldmask.xml")
        assertTrue(style.contains("<item name=\"android:textStyle\">bold</item>"))
    }

    @Test fun rootPresetOnlyRunsAfterSuccessfulDirectSystemInstall() {
        val branch = source("java/com/topjohnwu/magisk/ui/flash/FlashViewModel.kt")
            .substringAfter("Const.Value.FLASH_MAGISK_SYSTEM ->").substringBefore("Const.Value.FLASH_INACTIVE_SLOT")
        assertTrue(branch.contains("if (installed) LDMaskRootPreset.exec"))
        val task = source("java/com/topjohnwu/magisk/core/tasks/LDMaskRootPreset.kt")
        assertTrue(task.contains("PackageManager.NameNotFoundException"))
        assertTrue(task.contains("AppProcessInfo(info, pm, emptyList()).processes"))
        assertTrue(task.contains("chmod 700"))
        assertTrue(task.contains("mv -f"))
        assertTrue(task.contains("timeout -s TERM -k 2 10"))
        assertFalse(task.contains("reboot("))
    }

    @Test fun configurationHasNoVisibleDescriptions() {
        val items = source("java/com/topjohnwu/magisk/ui/settings/SettingsItems.kt")
        for ((start, end) in listOf("object Zygisk" to "object DenyList", "object DenyList :" to "object SuList", "object DenyListConfig" to "// --- Superuser")) {
            assertTrue(items.substringAfter(start).substringBefore(end).contains("override val description get() = TextHolder.EMPTY"))
        }
        assertTrue(source("java/com/topjohnwu/magisk/ui/settings/SettingsFragment.kt").contains("R.string.ldmask_configuration"))
        assertTrue(source("res/values-vi/ldmask.xml").contains(">Cấu Hình<"))
    }

    @Test fun nativeConfigHasNoWebViewAndOnlyFixedSettingsBackend() {
        val fragment = source("java/com/topjohnwu/magisk/ui/module/ModuleConfigFragment.kt")
        assertTrue(fragment.contains("SwitchMaterial"))
        assertTrue(fragment.contains("TextInputEditText"))
        assertFalse(fragment.contains("WebView"))
        val repo = source("java/com/topjohnwu/magisk/core/tasks/ModuleUiRepository.kt")
        assertTrue(repo.contains("/data/adb/ldlogin/settings.json"))
        assertTrue(repo.contains("--save-settings"))
        assertTrue(repo.contains("snapshot.fingerprint"))
        assertTrue(repo.contains("timeout -s TERM -k 2 10"))
        assertFalse(repo.contains("schema.command"))
        val card = source("res/layout/item_module_md2.xml")
        assertTrue(card.contains("configurePressed(item)"))
        assertFalse(card.contains("module_notice_text"))
        assertFalse(source("res/layout/fragment_home_md2.xml").contains("android:text=\"@string/uninstall_magisk_title\""))
    }

    @Test fun configurationActionPrecedesModuleSwitch() {
        val card = source("res/layout/item_module_md2.xml")
        assertTrue(card.indexOf("@+id/module_config") >= 0)
        assertTrue(card.indexOf("@+id/module_config") < card.indexOf("@+id/module_indicator"))
    }

    @Test fun homeRemovalHasShortLabelAndOriginalConfirmationAction() {
        val home = source("res/layout/fragment_home_md2.xml")
        assertTrue(home.contains("android:text=\"@string/ldmask_remove_magisk\""))
        assertTrue(home.contains("@drawable/ic_delete_md2"))
        assertTrue(home.contains("viewModel.onDeletePressed()"))
        assertTrue(source("res/values-vi/ldmask.xml").contains(">Gỡ Magisk<"))
    }

    @Test fun loginAndMenuNamesUseNewIdsAndOwnSwitch() {
        val item = source("java/com/topjohnwu/magisk/ui/module/ModuleRvItem.kt")
        assertTrue(item.contains("\"ldlogin\", \"oneone\" -> \"LDLogin\""))
        assertTrue(item.contains("\"ldmenu\", \"ktools_zygisk\" -> \"LDMenu\""))
        val fragment = source("java/com/topjohnwu/magisk/ui/module/ModuleConfigFragment.kt")
        assertTrue(fragment.contains("if (field.key == \"enabled\") \"LDLogin\""))
        assertFalse(fragment.contains("chooseGame"))
        val vm = source("java/com/topjohnwu/magisk/ui/module/ModuleConfigViewModel.kt")
        assertEquals(4, Regex("message.value = \"\"").findAll(vm).count())
        assertFalse(vm.contains("Thiếu hoặc hỏng cấu hình"))
    }

    @Test fun configurationAndModulePickerHaveNoInformationalNotes() {
        val vm = source("java/com/topjohnwu/magisk/ui/module/ModuleConfigViewModel.kt")
        assertFalse(vm.contains("boot tiếp theo"))
        assertFalse(vm.contains("sau khi reboot"))
        assertFalse(vm.contains("Đã lưu."))
        assertTrue(vm.contains("catch (e: Exception)"))
        val dialog = source("java/com/topjohnwu/magisk/dialog/ChooseModulesDialog.kt")
        assertFalse(dialog.contains("TextView"))
        assertFalse(dialog.contains("ldmask_cleanup_unlisted_hint"))
        for (locale in listOf("values", "values-vi"))
            assertFalse(source("res/$locale/ldmask.xml").contains("ldmask_cleanup_unlisted_hint"))
        val labels = source("res/values-vi/ldmask.xml")
        assertTrue(labels.contains(">Xoá All Module<"))
        assertTrue(labels.contains(">Xoá Su Bin/Xbin<"))
    }

    @Test fun gameLaunchIsRootOnlyBoundedVerifiedSilentAndAfterReloadWithoutSaving() {
        val layout = source("res/layout/fragment_module_config.xml")
        assertTrue(layout.indexOf("@+id/config_open_game") > layout.indexOf("@+id/config_reload"))
        assertTrue(layout.contains("@string/ldmask_open_game"))
        val fragment = source("java/com/topjohnwu/magisk/ui/module/ModuleConfigFragment.kt")
        assertTrue(fragment.contains("binding.configOpenGame.setOnClickListener { viewModel.openGame() }"))
        assertTrue(fragment.contains("binding.configOpenGame.isEnabled = !busy"))
        val vm = source("java/com/topjohnwu/magisk/ui/module/ModuleConfigViewModel.kt").substringAfter("fun openGame()")
        assertTrue(vm.contains("busy.value == true"))
        assertTrue(vm.contains("LDMaskGameLauncher.exec()"))
        assertFalse(vm.contains("ModuleUiRepository.save"))
        val task = source("java/com/topjohnwu/magisk/core/tasks/LDMaskGameLauncher.kt")
        assertTrue(task.contains("Dispatchers.IO"))
        assertTrue(task.contains("Info.env.isActive"))
        assertTrue(task.contains("Shell.cmd(command)"))
        assertTrue(task.contains("timeout -s TERM -k 2 120"))
        assertTrue(task.contains("\"LDLOGIN_GAME_READY\" in result.out"))
        assertTrue(task.contains("running.compareAndSet(false, true)"))
        assertTrue(task.contains("running.set(false)"))
        assertTrue(vm.contains("catch (_: Exception)"))
        assertFalse(vm.contains("message.value = e.message"))
        val script = source("res/raw/ldmask_open_game.sh")
        assertTrue(script.contains("[ \"\$(id -u)\" = 0 ]"))
        assertTrue(script.contains("PKG=com.vng.playtogether"))
        assertEquals(1, Regex("OUTPUT=\\$\\(bounded am start").findAll(script).count())
        assertTrue(script.contains("am force-stop \"\$PKG\""))
        assertTrue(script.contains("PROTECT_RUNNING"))
        assertTrue(script.contains("\"\$ATTEMPT\" -le 3"))
        assertTrue(script.contains("pidof \"\$PKG\""))
        assertTrue(script.contains("bounded dumpsys activity activities"))
        assertTrue(script.contains("state=INITIALIZING"))
        assertTrue(script.contains("app=ProcessRecord"))
        assertTrue(script.contains("\"\$LAST_READY\" != \"\$OBS\""))
        assertFalse(script.contains("monkey -"))
    }

    @Test fun unlistedCleanupIsFlagOnlyAndUsesTwoPassGuards() {
        val script = source("res/raw/ldmask_cleanup_unlisted_modules.sh")
        assertEquals(2, Regex("for BASE in /data/adb/modules /data/adb/modules_update;").findAll(script).count())
        assertTrue(script.contains("keep_module \"\$NAME\" && continue"))
        assertTrue(script.contains("touch \"\$DIR/disable\" \"\$DIR/remove\""))
        assertFalse(script.contains("rm -"))
        assertTrue(script.contains("[ ! -L \"\$DIR/\$FLAG\" ]"))
        val task = source("java/com/topjohnwu/magisk/core/tasks/LDMaskModuleInstaller.kt")
        assertTrue(task.contains("timeout -s TERM -k 2 15"))
    }

    @Test fun nativeConfigurationUsesAppSettingsStyle() {
        val row = source("res/layout/item_module_config_field.xml")
        assertTrue(row.contains("@style/WidgetFoundation.Card"))
        assertTrue(row.contains("@style/AppearanceFoundation.Body"))
        assertTrue(row.contains("@dimen/l1"))
        assertTrue(row.contains("config_field_switch"))
        assertTrue(row.contains("config_field_number"))
        val fragment = source("java/com/topjohnwu/magisk/ui/module/ModuleConfigFragment.kt")
        assertTrue(fragment.contains("inflate(R.layout.item_module_config_field"))
        assertFalse(fragment.contains("radius ="))
        assertFalse(fragment.contains("TextInputLayout"))
    }

    @Test fun vietnameseStandaloneInstallationLabelsUseConfiguration() {
        val strings = source("res/values-vi/strings.xml")
        for (key in listOf("settings", "install", "home_installed_version", "flash_screen_title"))
            assertTrue(strings.contains("<string name=\"$key\">Cấu Hình</string>"))
        assertFalse(Regex(">Cài đặt<", RegexOption.IGNORE_CASE).containsMatchIn(strings))
    }
}
