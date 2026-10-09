package com.topjohnwu.magisk.core.tasks

import org.junit.Assert.*
import org.junit.Test
import java.io.File

class ModuleUiSchemaTest {
    private fun descriptor(): String = listOf(File("../module-ui/oneone.json"), File("module-ui/oneone.json"))
        .first { it.isFile }.readText()
    @Test fun actualDescriptorRendersThreeNativeFields() {
        val ui = ModuleUiSchema.parse(descriptor(), "oneone")
        assertEquals(listOf("enabled", "boot_wait_seconds", "logging"), ui.fields.map { it.key })
        assertEquals(listOf("boolean", "integer", "boolean"), ui.fields.map { it.type })
    }
    @Test fun rejectsCommandsPathsForeignSettingsAndDuplicateKeys() {
        val json = descriptor()
        for (bad in listOf(json.replace("\"schema\": 1", "\"schema\": 1, \"command\": \"reboot\""),
            json.replace("\"settingsId\": \"oneone\"", "\"settingsId\": \"../../system\""),
            json.replace("\"schema\": 1", "\"schema\": 1, \"schema\": 1"),
            json.replace("\"default\": false", "\"default\": true"))) {
            assertTrue(runCatching { ModuleUiSchema.parse(bad, "oneone") }.isFailure)
        }
        assertTrue(runCatching { ModuleUiSchema.parse(json, "ktools_zygisk") }.isFailure)
    }
    @Test fun rejectsInvalidRangesFloatsMissingFieldsAndLargeUi() {
        for (bad in listOf(descriptor().replace("\"max\": 600", "\"max\": 601"),
            descriptor().replace("\"default\": 30", "\"default\": 30.0"),
            descriptor().replace("\"key\": \"logging\"", "\"key\": \"enabled\""), " ".repeat(16385)))
            assertTrue(runCatching { ModuleUiSchema.parse(bad, "oneone") }.isFailure)
    }
    @Test fun valuesAreTypedBoundedAndOffByDefault() {
        assertEquals(OneOneUiSettings(false, 30, false), OneOneUiSettings())
        assertEquals(OneOneUiSettings(true, 600, true), OneOneUiSettings.from(mapOf("enabled" to true, "boot_wait_seconds" to 600, "logging" to true)))
        for (value in listOf(-1, 601, "30", 30.0, true)) {
            assertTrue(runCatching { OneOneUiSettings.from(mapOf("enabled" to true, "boot_wait_seconds" to value, "logging" to false)) }.isFailure)
        }
    }
}
