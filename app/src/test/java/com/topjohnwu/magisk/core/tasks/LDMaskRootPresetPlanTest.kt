package com.topjohnwu.magisk.core.tasks

import org.junit.Assert.*
import org.junit.Test

class LDMaskRootPresetPlanTest {
    @Test fun emptyGamesStillEnableZygiskAndHideWithoutAddingTargets() {
        val sql = LDMaskRootPresetPlan.sql(emptyList())
        assertTrue(sql.contains("('zygisk',1),('magiskhide',1),('sulist',0)"))
        assertFalse(sql.contains("INSERT OR IGNORE INTO hidelist"))
        assertTrue(sql.startsWith("BEGIN IMMEDIATE;"))
        assertTrue(sql.endsWith("COMMIT;"))
    }

    @Test fun secondaryProcessesAreIncludedAndRepeatedTargetsAreIdempotent() {
        val targets = listOf("com.vng.playtogether" to "com.vng.playtogether",
            "com.vng.playtogether" to "com.vng.playtogether:adnw",
            "com.haegin.playtogether" to "com.haegin.playtogether",
            "com.vng.playtogether" to "com.vng.playtogether")
        val sql = LDMaskRootPresetPlan.sql(targets)
        assertEquals(3, Regex("INSERT OR IGNORE INTO hidelist").findAll(sql).count())
        assertTrue(sql.contains("com.vng.playtogether:adnw"))
        assertFalse(sql.contains("INTO sulist"))
        assertFalse(sql.contains("DELETE"))
        val verify = LDMaskRootPresetPlan.verifySql(targets)
        assertEquals(3, Regex("EXISTS\\(SELECT 1 FROM hidelist").findAll(verify).count())
    }

    @Test fun foreignPackagesAndInjectedProcessNamesAreRejected() {
        for (target in listOf("com.oneone.launcher" to "com.oneone.launcher",
            "io.github.oneone404.ldmask" to "io.github.oneone404.ldmask",
            "com.vng.playtogether" to "bad';DROP TABLE settings;--",
            "isolated" to "com.other.game:service")) {
            assertThrows(IllegalArgumentException::class.java) { LDMaskRootPresetPlan.sql(listOf(target)) }
        }
    }

    @Test fun bootHookSelfRemovesOnlyAfterVerifiedApplicationAndHasNoResidentLoop() {
        val script = LDMaskRootPresetPlan.script(emptyList())
        assertTrue(script.indexOf("CHECK=") < script.indexOf("rm -f --"))
        assertTrue(script.contains("--persist-only"))
        assertTrue(script.contains("ldmask_preset=1"))
        assertTrue(script.contains("ROLLBACK;"))
        assertFalse(script.contains("sleep"))
        assertFalse(script.contains("while "))
        assertFalse(script.contains("reboot\n"))
        assertFalse(script.contains("pm clear"))
    }
}
