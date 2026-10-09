package com.topjohnwu.magisk.core.repository

import com.topjohnwu.magisk.core.Config
import com.topjohnwu.magisk.core.Config.Value.CUSTOM_CHANNEL
import com.topjohnwu.magisk.core.Info
import com.topjohnwu.magisk.core.data.GithubPageServices
import com.topjohnwu.magisk.core.data.RawServices
import retrofit2.HttpException
import timber.log.Timber
import java.io.IOException

class NetworkService(
    private val pages: GithubPageServices,
    private val raw: RawServices
) {
    suspend fun fetchUpdate() = safe {
        // LDMask has its own package and native manager identity. Never offer
        // an upstream Kitsune/Magisk APK as an in-place update for this fork.
        when (Config.updateChannel) {
            CUSTOM_CHANNEL -> fetchCustomUpdate(Config.customChannelUrl)
            else -> pages.fetchUpdateJSON("https://github.com/oneone404/ldmask/releases/latest/download/update.json")
        }
    }

    // UpdateInfo
    private suspend fun fetchCustomUpdate(url: String) = pages.fetchUpdateJSON(url)

    private inline fun <T> safe(factory: () -> T): T? {
        return try {
            if (Info.isConnected.value == true)
                factory()
            else
                null
        } catch (e: Exception) {
            Timber.e(e)
            null
        }
    }

    private inline fun <T> wrap(factory: () -> T): T {
        return try {
            factory()
        } catch (e: HttpException) {
            throw IOException(e)
        }
    }

    // Fetch files
    suspend fun fetchFile(url: String) = wrap { raw.fetchFile(url) }
    suspend fun fetchString(url: String) = wrap { raw.fetchString(url) }
    suspend fun fetchModuleJson(url: String) = wrap { raw.fetchModuleJson(url) }
}
