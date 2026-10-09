package com.topjohnwu.magisk.core.tasks

import com.squareup.moshi.JsonReader
import okio.Buffer

data class ModuleUiField(val key: String, val type: String, val label: String,
    val description: String, val default: Any, val min: Int = 0, val max: Int = 0)
data class ModuleUiSchema(val title: String, val fields: List<ModuleUiField>) {
    companion object {
        private val keys = setOf("enabled", "boot_wait_seconds", "logging")
        /** Small declarative data only: no paths, commands, script, WebView or arbitrary writer. */
        fun parse(text: String, moduleId: String): ModuleUiSchema {
            require(moduleId == "oneone" && text.toByteArray().size <= 16384) { "Unsupported module UI" }
            val reader = JsonReader.of(Buffer().writeUtf8(text))
            val root = reader.use {
                val value = objectValue(it, 0)
                require(it.peek() == JsonReader.Token.END_DOCUMENT) { "Trailing JSON" }
                value
            }
            require(root.keys == setOf("schema", "settingsId", "title", "fields")) { "Unknown UI property" }
            require(root["schema"] == 1 && root["settingsId"] == "oneone") { "Unsupported UI schema/settingsId" }
            val title = label(root["title"], 64)
            val rows = root["fields"] as? List<*> ?: error("Missing fields")
            require(rows.size == 3)
            val fields = rows.map { row ->
                val map = row as? Map<*, *> ?: error("Invalid field")
                val key = map["key"] as? String ?: error("Invalid key")
                require(key in keys)
                val type = map["type"] as? String ?: error("Invalid type")
                val name = label(map["label"], 64)
                val description = map["description"]?.let { label(it, 200) }.orEmpty()
                val allowed = setOf("key", "type", "label", "description", "default") +
                    if (key == "boot_wait_seconds") setOf("min", "max") else emptySet()
                require(map.keys.all { it in allowed }) { "Unknown field property" }
                if (key == "boot_wait_seconds") {
                    require(type == "integer" && map["default"] == 30 && map["min"] == 0 && map["max"] == 600)
                    ModuleUiField(key, type, name, description, 30, 0, 600)
                } else {
                    require(type == "boolean" && map["default"] == false)
                    ModuleUiField(key, type, name, description, false)
                }
            }
            require(fields.map { it.key }.toSet() == keys) { "Missing/duplicate UI fields" }
            return ModuleUiSchema(title, fields)
        }

        private fun label(value: Any?, max: Int): String {
            val text = value as? String ?: error("Invalid label")
            require(text.length in 1..max && text.none { it < ' ' }) { "Invalid label length/control character" }
            return text
        }

        private fun objectValue(reader: JsonReader, depth: Int): Map<String, Any> {
            require(depth <= 3)
            val map = linkedMapOf<String, Any>()
            reader.beginObject()
            while (reader.hasNext()) {
                require(map.size < 10)
                val key = reader.nextName()
                require(key !in map) { "Duplicate JSON key" }
                map[key] = when (reader.peek()) {
                    JsonReader.Token.STRING -> reader.nextString().also { require(it.length <= 256) }
                    JsonReader.Token.NUMBER -> reader.nextString().toIntOrNull() ?: error("Integer required")
                    JsonReader.Token.BOOLEAN -> reader.nextBoolean()
                    JsonReader.Token.BEGIN_ARRAY -> {
                        reader.beginArray()
                        val rows = mutableListOf<Map<String, Any>>()
                        while (reader.hasNext()) { require(rows.size < 8); rows += objectValue(reader, depth + 1) }
                        reader.endArray()
                        rows
                    }
                    else -> error("Unsupported JSON value")
                }
            }
            reader.endObject()
            return map
        }
    }
}

data class OneOneUiSettings(val enabled: Boolean = false, val bootWait: Int = 30, val logging: Boolean = false) {
    init { require(bootWait in 0..600) }
    fun values(): Map<String, Any> = mapOf("enabled" to enabled, "boot_wait_seconds" to bootWait, "logging" to logging)
    companion object {
        fun from(values: Map<String, Any>): OneOneUiSettings {
            require(values.keys == setOf("enabled", "boot_wait_seconds", "logging"))
            return OneOneUiSettings(values["enabled"] as? Boolean ?: error("Boolean required"),
                values["boot_wait_seconds"] as? Int ?: error("Integer required"),
                values["logging"] as? Boolean ?: error("Boolean required"))
        }
    }
}
