package com.topjohnwu.magisk.core.tasks

import org.json.JSONObject
import java.io.File
import java.security.MessageDigest
import java.util.zip.ZipFile

data class ReleaseAsset(val name: String, val size: Long, val url: String)
data class ModuleRelease(val tag: String, val assets: Map<String, ReleaseAsset>)
data class QuickModule(val id: String, val asset: ReleaseAsset, val versionCode: Int, val sha256: String)

/** Only a release from this repository may supply the two fixed module IDs. */
object QuickModuleCatalog {
    const val REPO = "oneone404/ldmask"
    const val MAX_ZIP = 64L * 1024 * 1024
    private val moduleIds = linkedMapOf("OneOne.zip" to "oneone", "Module.zip" to "ktools_zygisk")

    fun release(text: String): ModuleRelease {
        val json = JSONObject(text)
        require(!json.getBoolean("draft") && !json.getBoolean("prerelease")) { "Not a stable release" }
        val tag = json.getString("tag_name")
        require(tag.matches(Regex("[A-Za-z0-9._-]{1,64}"))) { "Invalid release tag" }
        val assets = linkedMapOf<String, ReleaseAsset>()
        val array = json.getJSONArray("assets")
        require(array.length() <= 100) { "Too many release assets" }
        for (i in 0 until array.length()) {
            val item = array.getJSONObject(i)
            val name = item.getString("name")
            if (name != "modules.json" && name !in moduleIds) continue
            val size = item.getLong("size")
            val url = item.getString("browser_download_url")
            require(size in 1..(if (name == "modules.json") 16384L else MAX_ZIP)) { "Invalid asset size" }
            require(url == "https://github.com/$REPO/releases/download/$tag/$name") { "Unexpected asset URL" }
            require(assets.put(name, ReleaseAsset(name, size, url)) == null) { "Duplicate asset" }
        }
        require(assets.keys == moduleIds.keys + "modules.json") { "Release is missing module assets" }
        return ModuleRelease(tag, assets)
    }

    fun manifest(text: String, release: ModuleRelease): List<QuickModule> {
        val json = JSONObject(text)
        require(json.getInt("schema") == 1 && json.getString("release") == release.tag) { "Manifest version mismatch" }
        val array = json.getJSONArray("modules")
        require(array.length() == 2) { "Expected exactly two modules" }
        val result = linkedMapOf<String, QuickModule>()
        for (i in 0 until array.length()) {
            val item = array.getJSONObject(i)
            val name = item.getString("asset")
            val id = item.getString("id")
            require(moduleIds[name] == id) { "Unexpected module ID" }
            val asset = requireNotNull(release.assets[name])
            require(item.getLong("size") == asset.size) { "Manifest size mismatch" }
            val code = item.getInt("versionCode")
            val hash = item.getString("sha256").lowercase()
            require(code > 0 && hash.matches(Regex("[a-f0-9]{64}"))) { "Invalid module metadata" }
            require(result.put(name, QuickModule(id, asset, code, hash)) == null) { "Duplicate module" }
        }
        return moduleIds.keys.map { requireNotNull(result[it]) }
    }

    fun validate(file: File, module: QuickModule) {
        require(file.length() == module.asset.size) { "ZIP size mismatch: ${module.id}" }
        val digest = MessageDigest.getInstance("SHA-256")
        file.inputStream().use { input ->
            val buffer = ByteArray(8192)
            while (true) {
                val n = input.read(buffer)
                if (n < 0) break
                digest.update(buffer, 0, n)
            }
        }
        val hash = digest.digest().joinToString("") { "%02x".format(it.toInt() and 255) }
        require(hash == module.sha256) { "SHA-256 mismatch: ${module.id}" }
        ZipFile(file).use { zip ->
            val names = hashSetOf<String>()
            val entries = zip.entries()
            var total = 0L
            while (entries.hasMoreElements()) {
                val entry = entries.nextElement()
                val name = entry.name
                require(names.size < 1000 && names.add(name)) { "Duplicate/too many ZIP entries" }
                require(!name.startsWith("/") && '\\' !in name && ':' !in name &&
                    name.split('/').none { it == ".." || it == "." }) { "Unsafe ZIP path" }
                require(entry.size in 0..MAX_ZIP) { "Invalid uncompressed size" }
                total += entry.size
                require(total <= 256L * 1024 * 1024) { "ZIP expands too large" }
            }
            val prop = requireNotNull(zip.getEntry("module.prop")) { "Missing module.prop" }
            require(!prop.isDirectory && prop.size in 1..4096) { "Invalid module.prop" }
            val text = zip.getInputStream(prop).use { input ->
                val bytes = input.readBytesBounded(4096)
                bytes.toString(Charsets.UTF_8)
            }
            val fields = linkedMapOf<String, String>()
            text.lineSequence().map { it.trim() }.filter { it.isNotEmpty() && !it.startsWith("#") }.forEach {
                val parts = it.split('=', limit = 2)
                if (parts.size == 2 && parts[0] in setOf("id", "versionCode")) {
                    require(fields.put(parts[0], parts[1]) == null) { "Duplicate module property" }
                }
            }
            require(fields["id"] == module.id && fields["versionCode"] == module.versionCode.toString()) { "ZIP module identity mismatch" }
        }
    }
}

internal fun java.io.InputStream.readBytesBounded(max: Int): ByteArray {
    val out = java.io.ByteArrayOutputStream()
    val buffer = ByteArray(8192)
    while (true) {
        val n = read(buffer)
        if (n < 0) break
        require(out.size().toLong() + n <= max) { "Response exceeds size limit" }
        out.write(buffer, 0, n)
    }
    return out.toByteArray()
}
