package com.topjohnwu.magisk.core.tasks

import org.junit.Assert.*
import org.junit.Test
import java.io.File

class ModuleUiSchemaTest {
    private fun descriptor(): String = listOf(File("../module-ui/ldlogin.json"), File("module-ui/ldlogin.json"))
        .first { it.isFile }.readText()
    @Test fun actualDescriptorRendersFourNativeFields() {
        val ui = ModuleUiSchema.parse(descriptor(), "ldlogin")
        assertEquals(listOf("enabled", "open_backpack", "boot_wait_seconds", "logging"), ui.fields.map { it.key })
        assertEquals(listOf("boolean", "boolean", "integer", "boolean"), ui.fields.map { it.type })
        assertEquals("Cấu Hình LDLogin", ui.title)
        assertEquals("LDLogin", ui.fields.first().label)
        assertEquals("FramLogin", ui.fields[1].label)
        assertEquals(false, ui.fields[1].default)
    }
    @Test fun rejectsCommandsPathsForeignSettingsAndDuplicateKeys() {
        val json = descriptor()
        for (bad in listOf(json.replace("\"schema\": 1", "\"schema\": 1, \"command\": \"reboot\""),
            json.replace("\"settingsId\": \"ldlogin\"", "\"settingsId\": \"../../system\""),
            json.replace("\"schema\": 1", "\"schema\": 1, \"schema\": 1"),
            json.replace("\"default\": false", "\"default\": true"))) {
            assertTrue(runCatching { ModuleUiSchema.parse(bad, "ldlogin") }.isFailure)
        }
        assertTrue(runCatching { ModuleUiSchema.parse(json, "ldmenu") }.isFailure)
    }
    @Test fun rejectsInvalidRangesFloatsMissingFieldsAndLargeUi() {
        for (bad in listOf(descriptor().replace("\"max\": 600", "\"max\": 601"),
            descriptor().replace("\"default\": 30", "\"default\": 30.0"),
            descriptor().replace("\"key\": \"logging\"", "\"key\": \"enabled\""), " ".repeat(16385)))
            assertTrue(runCatching { ModuleUiSchema.parse(bad, "ldlogin") }.isFailure)
    }
    @Test fun valuesAreTypedBoundedAndOffByDefault() {
        assertEquals(LDLoginUiSettings(false, 30, false), LDLoginUiSettings())
        assertEquals(LDLoginUiSettings(true, 600, true, true), LDLoginUiSettings.from(mapOf("enabled" to true, "boot_wait_seconds" to 600, "logging" to true)))
        for (value in listOf(-1, 601, "30", 30.0, true)) {
            assertTrue(runCatching { LDLoginUiSettings.from(mapOf("enabled" to true, "boot_wait_seconds" to value, "logging" to false)) }.isFailure)
        }
        assertEquals(LDLoginUiSettings(true, 30, false, false), LDLoginUiSettings.from(mapOf(
            "enabled" to true, "boot_wait_seconds" to 30, "logging" to false, "open_backpack" to false)))
        for (bad in listOf("false", 0, 1)) {
            assertTrue(runCatching { LDLoginUiSettings.from(mapOf("enabled" to true,
                "boot_wait_seconds" to 30, "logging" to false, "open_backpack" to bad)) }.isFailure)
        }
    }

    @Test fun legacyThreeFieldDescriptorStillWorks() {
        val old = descriptor().lineSequence().filterNot { it.contains("open_backpack") }.joinToString("\n")
        assertEquals(3, ModuleUiSchema.parse(old, "ldlogin").fields.size)
        assertFalse(LDLoginUiSettings().openBackpack)
        val legacyFour = descriptor().replace("\"label\": \"FramLogin\", \"default\": false", "\"label\": \"Mở Balo\", \"default\": true")
        assertTrue(ModuleUiSchema.parse(legacyFour, "ldlogin").fields[1].default as Boolean)
    }

    @Test fun framLoginRequiresLoginAndDoesNotResumeAfterMasterToggle() {
        val values = LDLoginUiSettings().values().toMutableMap()
        assertFalse(LDLoginSwitchPolicy.canChange("open_backpack", values))
        LDLoginSwitchPolicy.change(values, "open_backpack", true)
        assertEquals(false, values["open_backpack"])
        LDLoginSwitchPolicy.change(values, "enabled", true)
        assertEquals(false, values["open_backpack"])
        assertTrue(LDLoginSwitchPolicy.canChange("open_backpack", values))
        LDLoginSwitchPolicy.change(values, "open_backpack", true)
        assertEquals(true, values["open_backpack"])
        LDLoginSwitchPolicy.change(values, "enabled", false)
        assertEquals(false, values["open_backpack"])
        LDLoginSwitchPolicy.change(values, "enabled", true)
        assertEquals(false, values["open_backpack"])
    }

    @Test fun persistedFarmCannotBypassDisabledLogin() {
        val settings = LDLoginUiSettings.from(mapOf("enabled" to false, "boot_wait_seconds" to 30,
            "logging" to false, "open_backpack" to true))
        assertFalse(settings.enabled)
        assertFalse(settings.openBackpack)
        assertEquals(LDLoginUiSettings(), LDLoginUiSettings(openBackpack = true).normalized())
        assertEquals(LDLoginUiSettings(true, openBackpack = true),
            LDLoginUiSettings(true, openBackpack = true).normalized())
    }
}
