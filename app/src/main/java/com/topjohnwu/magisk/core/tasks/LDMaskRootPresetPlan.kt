package com.topjohnwu.magisk.core.tasks

/** Fixed packages only; no settings-derived shell commands or SQL identifiers. */
internal object LDMaskRootPresetPlan {
    val packages = listOf("com.vng.playtogether", "com.haegin.playtogether")
    const val hook = "/data/adb/post-fs-data.d/ldmask-root-preset.sh"
    const val marker = "ldmask_preset=1"

    fun quote(text: String) = "'" + text.replace("'", "'\\''") + "'"

    fun sql(targets: Collection<Pair<String, String>>): String {
        val unique = targets.distinct().sortedWith(compareBy({ it.first }, { it.second }))
        unique.forEach { (pkg, proc) ->
            require(pkg in packages || pkg == "isolated")
            require(proc.matches(Regex("[A-Za-z0-9_.:]+")))
            if (pkg == "isolated") require(packages.any { proc.startsWith("$it:") })
        }
        return buildString {
            append("BEGIN IMMEDIATE;")
            // SuList is an allowlist, not Hide: never add games to that table.
            append("REPLACE INTO settings (key,value) VALUES('zygisk',1),('magiskhide',1),('sulist',0);")
            unique.forEach { (pkg, proc) ->
                append("INSERT OR IGNORE INTO hidelist (package_name,process) VALUES('$pkg','$proc');")
            }
            append("COMMIT;")
        }
    }

    fun verifySql(targets: Collection<Pair<String, String>>): String = buildString {
        // Validate input even when this function is called independently.
        sql(targets)
        append("SELECT 1 AS ldmask_preset WHERE ")
        append("(SELECT value FROM settings WHERE key='zygisk')=1 AND ")
        append("(SELECT value FROM settings WHERE key='magiskhide')=1 AND ")
        append("(SELECT value FROM settings WHERE key='sulist')=0")
        targets.distinct().forEach { (pkg, proc) ->
            append(" AND EXISTS(SELECT 1 FROM hidelist WHERE package_name='$pkg' AND process='$proc')")
        }
        append(';')
    }

    fun script(targets: Collection<Pair<String, String>>): String = """
        #!/system/bin/sh
        # One-shot: runs before this fork reads Zygisk/Hide settings at post-fs-data.
        [ "${'$'}(id -u)" = 0 ] || exit 1
        magisk --sqlite ${quote(sql(targets))} || exit 1
        CHECK=${'$'}(magisk --sqlite ${quote(verifySql(targets))})
        if [ "${'$'}CHECK" != '$marker' ]; then
          magisk --sqlite 'ROLLBACK;' >/dev/null 2>&1
          echo '! LDMask preset verification failed; retained for next boot'
          exit 1
        fi
        # An immediate attempt must leave the hook for the next daemon startup.
        if [ "${'$'}1" != --persist-only ]; then
          rm -f -- '$hook' || exit 1
        fi
        echo '- LDMask preset saved: Zygisk + MagiskHide; reboot to activate'
    """.trimIndent() + "\n"
}
