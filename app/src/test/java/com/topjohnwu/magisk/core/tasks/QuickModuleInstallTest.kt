package com.topjohnwu.magisk.core.tasks

import kotlinx.coroutines.runBlocking
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.*
import org.junit.Test
import org.junit.Assume.assumeTrue
import java.io.File
import java.nio.file.Files
import java.security.MessageDigest
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

class QuickModuleInstallTest {
    private fun zip(id: String, unsafe: Boolean = false): ByteArray {
        val out = java.io.ByteArrayOutputStream()
        ZipOutputStream(out).use {
            it.putNextEntry(ZipEntry("module.prop"))
            it.write("id=$id\nversionCode=1\n".toByteArray())
            it.closeEntry()
            if (unsafe) {
                it.putNextEntry(ZipEntry("../escape"))
                it.write(byteArrayOf(1))
                it.closeEntry()
            }
        }
        return out.toByteArray()
    }

    private class Source(private val blobs: List<ByteArray>, private val badHash: Boolean = false) : QuickReleaseSource {
        val modules = listOf("oneone", "ktools_zygisk").mapIndexed { i, id ->
            val hash = MessageDigest.getInstance("SHA-256").digest(blobs[i]).joinToString("") { "%02x".format(it.toInt() and 255) }
            QuickModule(id, ReleaseAsset(if (i == 0) "OneOne.zip" else "Module.zip", blobs[i].size.toLong(), ""), 1,
                if (badHash && i == 1) "0".repeat(64) else hash)
        }
        override fun latest() = ModuleRelease("v1.0.0", emptyMap())
        override fun manifest(release: ModuleRelease) = modules
        override fun download(asset: ReleaseAsset, target: File) { target.writeBytes(blobs[if (asset.name == "OneOne.zip") 0 else 1]) }
    }

    private fun scenario(source: QuickReleaseSource, failAt: Int = -1): Pair<QuickInstallResult, Int> = runBlocking {
        val dir = Files.createTempDirectory("ldmask-test").toFile()
        var calls = 0
        try {
            val result = QuickModuleInstall(dir, source, { _, _ -> calls++; calls != failAt }, {}).exec()
            assertEquals(0, File(dir, "ldmask-downloads").listFiles()?.size ?: 0)
            result to calls
        } finally { dir.deleteRecursively() }
    }

    @Test fun installsBothAndCleansCache() {
        assertEquals(QuickInstallResult(true, 2) to 2, scenario(Source(listOf(zip("oneone"), zip("ktools_zygisk")))))
    }
    @Test fun badSecondHashInstallsNothing() {
        assertEquals(QuickInstallResult(false, 0) to 0, scenario(Source(listOf(zip("oneone"), zip("ktools_zygisk")), true)))
    }
    @Test fun wrongSecondIdInstallsNothing() {
        assertEquals(QuickInstallResult(false, 0) to 0, scenario(Source(listOf(zip("oneone"), zip("wrong")))))
    }
    @Test fun unsafeZipInstallsNothing() {
        assertEquals(QuickInstallResult(false, 0) to 0, scenario(Source(listOf(zip("oneone", true), zip("ktools_zygisk")))))
    }
    @Test fun firstFailureStopsPair() {
        assertEquals(QuickInstallResult(false, 0) to 1, scenario(Source(listOf(zip("oneone"), zip("ktools_zygisk"))), 1))
    }
    @Test fun secondFailureReportsPartial() {
        assertEquals(QuickInstallResult(false, 1) to 2, scenario(Source(listOf(zip("oneone"), zip("ktools_zygisk"))), 2))
    }
    @Test fun networkFailureCleansCache() {
        val source = object : QuickReleaseSource {
            override fun latest(): ModuleRelease = error("HTTP 404")
            override fun manifest(release: ModuleRelease): List<QuickModule> = error("unused")
            override fun download(asset: ReleaseAsset, target: File) = error("unused")
        }
        assertEquals(QuickInstallResult(false, 0) to 0, scenario(source))
    }
    @Test fun rejectsConcurrentInstall() = runBlocking {
        assertTrue(ModuleInstallGate.acquire())
        try {
            val source = Source(listOf(zip("oneone"), zip("ktools_zygisk")))
            assertEquals(QuickInstallResult(false, 0), QuickModuleInstall(File("unused"), source, { _, _ -> error("unused") }, {}).exec())
        } finally { ModuleInstallGate.release() }
    }

    private fun releaseJson(): JSONObject {
        val json = JSONObject().put("draft", false).put("prerelease", false).put("tag_name", "v1.0.0")
        val assets = JSONArray()
        listOf("modules.json", "OneOne.zip", "Module.zip").forEach { name ->
            assets.put(JSONObject().put("name", name).put("size", 100)
                .put("browser_download_url", "https://github.com/oneone404/ldmask/releases/download/v1.0.0/$name"))
        }
        return json.put("assets", assets)
    }
    @Test fun acceptsOwnCompleteRelease() { assertEquals(3, QuickModuleCatalog.release(releaseJson().toString()).assets.size) }
    @Test(expected = IllegalArgumentException::class) fun rejectsWrongRepo() {
        val json = releaseJson()
        json.getJSONArray("assets").getJSONObject(1).put("browser_download_url", "https://github.com/other/repo/releases/download/v1.0.0/OneOne.zip")
        QuickModuleCatalog.release(json.toString())
    }
    @Test(expected = IllegalArgumentException::class) fun rejectsDuplicateAsset() {
        val json = releaseJson()
        json.getJSONArray("assets").put(json.getJSONArray("assets").getJSONObject(1))
        QuickModuleCatalog.release(json.toString())
    }
    @Test(expected = IllegalArgumentException::class) fun rejectsOversizedResponse() {
        byteArrayOf(1, 2, 3).inputStream().readBytesBounded(2)
    }
    @Test(expected = IllegalArgumentException::class) fun rejectsMismatchedManifestTag() {
        QuickModuleCatalog.manifest("{\"schema\":1,\"release\":\"other\",\"modules\":[]}", QuickModuleCatalog.release(releaseJson().toString()))
    }

    @Test fun validatesActualReleaseZipPair() {
        val path = System.getenv("LDMASK_RELEASE_FILES")
        assumeTrue("Set LDMASK_RELEASE_FILES to validate real release assets", path != null)
        val dir = File(requireNotNull(path))
        val json = releaseJson()
        val assets = json.getJSONArray("assets")
        for (i in 0 until assets.length()) {
            val asset = assets.getJSONObject(i)
            asset.put("size", File(dir, asset.getString("name")).length())
        }
        val release = QuickModuleCatalog.release(json.toString())
        val modules = QuickModuleCatalog.manifest(File(dir, "modules.json").readText(), release)
        assertEquals(listOf("oneone", "ktools_zygisk"), modules.map { it.id })
        modules.forEach { QuickModuleCatalog.validate(File(dir, it.asset.name), it) }
    }
}
