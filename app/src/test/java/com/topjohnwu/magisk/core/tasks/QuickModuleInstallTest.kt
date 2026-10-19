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
        val modules = listOf("ldlogin", "ldmenu", "zygisk_il2cppdumper").take(blobs.size).mapIndexed { i, id ->
            val hash = MessageDigest.getInstance("SHA-256").digest(blobs[i]).joinToString("") { "%02x".format(it.toInt() and 255) }
            QuickModule(id, ReleaseAsset(listOf("LDLogin.zip", "LDMenu.zip", "LDNPH.zip")[i], blobs[i].size.toLong(), ""), 1,
                if (badHash && i == 1) "0".repeat(64) else hash)
        }
        override fun latest() = ModuleRelease("v1.0.0", emptyMap())
        override fun manifest(release: ModuleRelease) = modules
        override fun download(asset: ReleaseAsset, target: File) {
            target.writeBytes(blobs[modules.indexOfFirst { it.asset.name == asset.name }])
        }
    }

    private fun scenario(source: QuickReleaseSource, failAt: Int = -1, selected: Set<String>? = null): Pair<QuickInstallResult, Int> = runBlocking {
        val dir = Files.createTempDirectory("ldmask-test").toFile()
        var calls = 0
        try {
            val result = QuickModuleInstall(dir, source, { _, _ -> calls++; calls != failAt }, {}, selected).exec()
            assertEquals(0, File(dir, "ldmask-downloads").listFiles()?.size ?: 0)
            result to calls
        } finally { dir.deleteRecursively() }
    }

    @Test fun installsBothAndCleansCache() {
        assertEquals(QuickInstallResult(true, 2) to 2, scenario(Source(listOf(zip("ldlogin"), zip("ldmenu")))))
    }

    @Test fun everyPickerCombinationPassesNavigationAndInstallsOnlyRequestedModules() = runBlocking {
        val all = listOf("ldlogin", "ldmenu", "zygisk_il2cppdumper")
        for (mask in 1..7) {
            val selected = all.filterIndexed { index, _ -> mask and (1 shl index) != 0 }.toSet()
            val payload = requireNotNull(QuickModuleCatalog.encodeSelection(selected))
            val decoded = requireNotNull(QuickModuleCatalog.decodeSelection(payload))
            assertEquals(selected, decoded)
            val source = Source(all.map { zip(it) })
            val dir = Files.createTempDirectory("ldmask-selection-path").toFile()
            val installed = mutableListOf<String>()
            var kept = emptySet<String>()
            try {
                val result = QuickModuleInstall(dir, source, { _, module -> installed += module.id; true }, {},
                    decoded, { allowed -> kept = allowed; true }).exec()
                assertEquals(QuickInstallResult(true, selected.size), result)
                assertEquals(selected, installed.toSet())
                assertEquals(all.toSet(), kept)
                assertEquals(0, File(dir, "ldmask-downloads").listFiles()?.size ?: 0)
            } finally { dir.deleteRecursively() }
        }
    }

    @Test fun selectionRejectsInvalidPayloadsWithoutThrowing() {
        assertNull(QuickModuleCatalog.encodeSelection(emptySet()))
        assertNull(QuickModuleCatalog.encodeSelection(setOf("foreign")))
        for (value in listOf(null, "", "foreign", "ldnph", "ldlogin,", ",ldmenu", "ldmenu,ldmenu",
            "ldlogin,foreign", "../zygisk_il2cppdumper", "zygisk_il2cppdumper ", "x".repeat(129))) {
            assertNull("Rejected: $value", QuickModuleCatalog.decodeSelection(value))
        }
        assertEquals(setOf("zygisk_il2cppdumper"), QuickModuleCatalog.decodeSelection("zygisk_il2cppdumper"))
        assertFalse(QuickModuleCatalog.isValidSelection(null))
    }

    @Test fun cleanupKeepsAllPublishedModulesNotOnlySelected() = runBlocking {
        val source = Source(listOf(zip("ldlogin"), zip("ldmenu")))
        val dir = Files.createTempDirectory("ldmask-cleanup-test").toFile()
        val installed = mutableListOf<String>()
        var kept = emptySet<String>()
        try {
            val result = QuickModuleInstall(dir, source, { _, module -> installed += module.id; true }, {},
                setOf("ldlogin"), { allowed -> kept = allowed; assertEquals(listOf("ldlogin"), installed); true }).exec()
            assertEquals(QuickInstallResult(true, 1), result)
            assertEquals(setOf("ldlogin", "ldmenu"), kept)
        } finally { dir.deleteRecursively() }
    }

    @Test fun cleanupNeverRunsOnDownloadValidationOrInstallFailure() = runBlocking {
        for (badHash in listOf(false, true)) {
            val dir = Files.createTempDirectory("ldmask-cleanup-failure").toFile()
            var cleaned = false
            try {
                val result = QuickModuleInstall(dir, Source(listOf(zip("ldlogin"), zip("ldmenu")), badHash),
                    { _, _ -> false }, {}, setOf("ldlogin", "ldmenu"), { cleaned = true; true }).exec()
                assertFalse(result.success); assertFalse(cleaned)
            } finally { dir.deleteRecursively() }
        }
    }

    @Test fun cleanupFailureReportsInstalledModulesWithoutSuccess() = runBlocking {
        val dir = Files.createTempDirectory("ldmask-cleanup-result").toFile()
        try {
            val result = QuickModuleInstall(dir, Source(listOf(zip("ldlogin"), zip("ldmenu"))),
                { _, _ -> true }, {}, setOf("ldlogin", "ldmenu"), { false }).exec()
            assertEquals(QuickInstallResult(false, 2), result)
        } finally { dir.deleteRecursively() }
    }
    @Test fun badSecondHashInstallsNothing() {
        assertEquals(QuickInstallResult(false, 0) to 0, scenario(Source(listOf(zip("ldlogin"), zip("ldmenu")), true)))
    }
    @Test fun installsOnlySelectedModuleAndDoesNotDownloadBadUnselectedZip() {
        assertEquals(QuickInstallResult(true, 1) to 1, scenario(Source(listOf(zip("ldlogin"), zip("ldmenu")), true), selected=setOf("ldlogin")))
    }
    @Test fun hiddenOrEmptySelectionInstallsNothing() {
        val source = Source(listOf(zip("ldlogin"), zip("ldmenu")))
        assertEquals(QuickInstallResult(false, 0) to 0, scenario(source, selected=emptySet()))
        assertEquals(QuickInstallResult(false, 0) to 0, scenario(source, selected=setOf("foreign")))
    }
    @Test fun publicationIsServerControlledAndFailsClosed() {
        val json = """{"schema":1,"modules":[{"id":"ldlogin","name":"LDLogin","published":true},{"id":"ldmenu","name":"LDMenu","published":false}]}"""
        assertEquals(mapOf("ldlogin" to "LDLogin"), QuickModuleCatalog.publication(json))
        assertTrue(QuickModuleCatalog.publication("""{"schema":1,"modules":[]}""").isEmpty())
        assertTrue(runCatching { QuickModuleCatalog.publication(json.replace("true", "\"true\"")) }.isFailure)
        assertTrue(runCatching { QuickModuleCatalog.publication(json.replace("ldmenu", "ldlogin")) }.isFailure)
    }

    @Test fun thirdModuleUsesOriginalIdentityAndCanBeHidden() {
        val json = """{"schema":1,"modules":[{"id":"ldlogin","name":"LDLogin","published":true},{"id":"ldmenu","name":"LDMenu","published":true},{"id":"zygisk_il2cppdumper","name":"LDNPH","published":true}]}"""
        assertEquals(mapOf("ldlogin" to "LDLogin", "ldmenu" to "LDMenu", "zygisk_il2cppdumper" to "LDNPH"),
            QuickModuleCatalog.publication(json))
        assertFalse(QuickModuleCatalog.publication(json.replace("\"name\":\"LDNPH\",\"published\":true",
            "\"name\":\"LDNPH\",\"published\":false")).containsKey("zygisk_il2cppdumper"))
        assertTrue(runCatching { QuickModuleCatalog.publication(json.replace("zygisk_il2cppdumper", "ldnph")) }.isFailure)
    }

    @Test fun optionalCatalogRowsAreBackwardCompatibleAndRejectDuplicates() {
        val main = """{"id":"ldlogin","name":"LDLogin","published":true}"""
        val optional = """{"id":"zygisk_il2cppdumper","name":"LDNPH","published":true}"""
        val json = """{"schema":1,"modules":[$main],"optionalModules":[$optional]}"""
        assertEquals(1, JSONObject(json).getJSONArray("modules").length()) // Older app sees only the base rows.
        assertEquals(setOf("ldlogin", "zygisk_il2cppdumper"), QuickModuleCatalog.publication(json).keys)
        assertTrue(runCatching { QuickModuleCatalog.publication(json.replace(optional, main)) }.isFailure)
        assertTrue(runCatching { QuickModuleCatalog.publication(json.replace("[$optional]", "true")) }.isFailure)
    }
    @Test fun wrongSecondIdInstallsNothing() {
        assertEquals(QuickInstallResult(false, 0) to 0, scenario(Source(listOf(zip("ldlogin"), zip("wrong")))))
    }
    @Test fun unsafeZipInstallsNothing() {
        assertEquals(QuickInstallResult(false, 0) to 0, scenario(Source(listOf(zip("ldlogin", true), zip("ldmenu")))))
    }
    @Test fun firstFailureStopsPair() {
        assertEquals(QuickInstallResult(false, 0) to 1, scenario(Source(listOf(zip("ldlogin"), zip("ldmenu"))), 1))
    }
    @Test fun secondFailureReportsPartial() {
        assertEquals(QuickInstallResult(false, 1) to 2, scenario(Source(listOf(zip("ldlogin"), zip("ldmenu"))), 2))
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
            val source = Source(listOf(zip("ldlogin"), zip("ldmenu")))
            assertEquals(QuickInstallResult(false, 0), QuickModuleInstall(File("unused"), source, { _, _ -> error("unused") }, {}).exec())
        } finally { ModuleInstallGate.release() }
    }

    private fun releaseJson(tag: String = "v1.0.0"): JSONObject {
        val json = JSONObject().put("draft", false).put("prerelease", false).put("tag_name", tag)
        val assets = JSONArray()
        listOf("modules.json", "LDLogin.zip", "LDMenu.zip").forEach { name ->
            assets.put(JSONObject().put("name", name).put("size", 100)
                .put("browser_download_url", "https://github.com/oneone404/ldmask/releases/download/$tag/$name"))
        }
        return json.put("assets", assets)
    }
    @Test fun acceptsOwnCompleteRelease() { assertEquals(3, QuickModuleCatalog.release(releaseJson().toString()).assets.size) }
    @Test(expected = IllegalArgumentException::class) fun rejectsWrongRepo() {
        val json = releaseJson()
        json.getJSONArray("assets").getJSONObject(1).put("browser_download_url", "https://github.com/other/repo/releases/download/v1.0.0/LDLogin.zip")
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

    @Test fun validatesActualReleaseZips() {
        val path = System.getenv("LDMASK_RELEASE_FILES")
        assumeTrue("Set LDMASK_RELEASE_FILES to validate real release assets", path != null)
        val dir = File(requireNotNull(path))
        val text = File(dir, "modules.json").readText()
        val json = releaseJson(JSONObject(text).getString("release"))
        val assets = json.getJSONArray("assets")
        if (File(dir, "LDNPH.zip").isFile) {
            val tag = JSONObject(text).getString("release")
            assets.put(JSONObject().put("name", "LDNPH.zip").put("size", 1)
                .put("browser_download_url", "https://github.com/oneone404/ldmask/releases/download/$tag/LDNPH.zip"))
        }
        for (i in 0 until assets.length()) {
            val asset = assets.getJSONObject(i)
            asset.put("size", File(dir, asset.getString("name")).length())
        }
        val release = QuickModuleCatalog.release(json.toString())
        val modules = QuickModuleCatalog.manifest(text, release)
        val expected = if (File(dir, "LDNPH.zip").isFile) listOf("ldlogin", "ldmenu", "zygisk_il2cppdumper")
            else listOf("ldlogin", "ldmenu")
        assertEquals(expected, modules.map { it.id })
        assertEquals(modules, QuickModuleCatalog.select(modules, expected.toSet()))
        assertEquals(listOf("ldlogin", "ldmenu"), QuickModuleCatalog.select(modules, null).map { it.id })
        modules.forEach { QuickModuleCatalog.validate(File(dir, it.asset.name), it) }
    }
}
