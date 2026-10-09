package com.topjohnwu.magisk.core.tasks

import com.topjohnwu.magisk.core.Info
import com.topjohnwu.superuser.Shell
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.withContext

data class ModuleUiSnapshot(val schema: ModuleUiSchema, val settings: OneOneUiSettings,
    val valid: Boolean, val pending: Boolean, val fingerprint: String)

object ModuleUiRepository {
    private const val file = "/data/adb/oneone/settings.json"
    // Paths/reader/writer never come from the module JSON.
    private val guard = """
        [ "${'$'}(id -u)" = 0 ] || exit 10
        BASE=/data/adb/modules/oneone
        PENDING=0
        if [ -d /data/adb/modules_update/oneone ]; then BASE=/data/adb/modules_update/oneone; PENDING=1; fi
        [ ! -L "${'$'}BASE" ] && [ ! -f "${'$'}BASE/remove" ] || exit 11
        [ ! -L "${'$'}BASE/ui.json" ] && [ -f "${'$'}BASE/ui.json" ] || exit 12
        FINDER="${'$'}BASE/system/bin/oneone_finder_v2"
        [ ! -L "${'$'}BASE/system" ] && [ ! -L "${'$'}BASE/system/bin" ] && [ ! -L "${'$'}FINDER" ] && [ -x "${'$'}FINDER" ] || exit 13
        [ ! -L /data/adb/oneone ] && [ ! -L '$file' ] || exit 14
        fingerprint() {
          if [ -e '$file' ]; then
            [ -f '$file' ] || return 1
            [ "${'$'}(wc -c < '$file')" -le 65536 ] || return 1
            sha256sum '$file' | cut -d ' ' -f 1
          else echo missing; fi
        }
    """.trimIndent()

    private fun run(script: String): List<String> {
        check(Info.env.isActive) { "Root chưa hoạt động" }
        val quoted = LDMaskRootPresetPlan.quote(guard + "\n" + script)
        val result = Shell.cmd("/data/adb/magisk/busybox timeout -s TERM -k 2 10 /data/adb/magisk/busybox sh -c $quoted").exec()
        check(result.isSuccess) { "Không đọc/lưu được cấu hình (root, module, đường dẫn hoặc dữ liệu đã đổi; mã ${result.code})" }
        return result.out
    }

    suspend fun load(moduleId: String): ModuleUiSnapshot = withContext(Dispatchers.IO) {
        require(moduleId == "oneone")
        val schema = ModuleUiSchema.parse(run("head -c 16385 \"\${BASE}/ui.json\"").joinToString("\n"), moduleId)
        val lines = run("""
            BEFORE=${'$'}(fingerprint) || exit 15
            RESULT=${'$'}("${'$'}FINDER" --settings '$file' 2>/dev/null); VALID=${'$'}?
            AFTER=${'$'}(fingerprint) || exit 15
            [ "${'$'}BEFORE" = "${'$'}AFTER" ] || exit 16
            printf '%s\nMETA %s %s %s\n' "${'$'}RESULT" "${'$'}VALID" "${'$'}PENDING" "${'$'}AFTER"
        """.trimIndent())
        require(lines.size == 2)
        val fields = lines[0].split(' ')
        val meta = lines[1].split(' ')
        require(fields.size == 4 && fields[0] == "SETTINGS" && meta.size == 4 && meta[0] == "META")
        require(fields[1] in setOf("0", "1") && fields[3] in setOf("0", "1"))
        require(meta[3] == "missing" || meta[3].matches(Regex("[a-f0-9]{64}")))
        val valid = meta[1] == "0"
        ModuleUiSnapshot(schema, if (valid) OneOneUiSettings(fields[1] == "1", fields[2].toInt(), fields[3] == "1") else OneOneUiSettings(),
            valid, meta[2] == "1", meta[3])
    }

    suspend fun save(moduleId: String, snapshot: ModuleUiSnapshot, settings: OneOneUiSettings): ModuleUiSnapshot =
        withContext(Dispatchers.IO + NonCancellable) {
            require(moduleId == "oneone")
            require(snapshot.fingerprint == "missing" || snapshot.fingerprint.matches(Regex("[a-f0-9]{64}")))
            // Revalidate the descriptor and reload if any external writer changed the file.
            ModuleUiSchema.parse(run("head -c 16385 \"\${BASE}/ui.json\"").joinToString("\n"), moduleId)
            run("""
                [ "${'$'}(fingerprint)" = '${snapshot.fingerprint}' ] || exit 20
                mkdir -p /data/adb/oneone && chmod 700 /data/adb/oneone || exit 21
                "${'$'}FINDER" --save-settings '$file' ${if (settings.enabled) 1 else 0} ${settings.bootWait} ${if (settings.logging) 1 else 0} || exit 22
            """.trimIndent())
            load(moduleId).also { check(it.valid && it.settings == settings) { "Đã ghi nhưng kiểm tra lại không khớp; tải lại cấu hình" } }
        }
}
