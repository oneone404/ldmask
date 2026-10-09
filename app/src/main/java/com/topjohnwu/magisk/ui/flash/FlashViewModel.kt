package com.topjohnwu.magisk.ui.flash

import android.view.MenuItem
import androidx.databinding.Bindable
import androidx.databinding.ObservableArrayList
import androidx.lifecycle.LiveData
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.map
import androidx.lifecycle.viewModelScope
import com.topjohnwu.magisk.BR
import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.arch.BaseViewModel
import com.topjohnwu.magisk.core.Const
import com.topjohnwu.magisk.core.Config
import com.topjohnwu.magisk.core.Info
import com.topjohnwu.magisk.core.ktx.reboot
import com.topjohnwu.magisk.core.ktx.synchronized
import com.topjohnwu.magisk.core.ktx.timeFormatStandard
import com.topjohnwu.magisk.core.ktx.toTime
import com.topjohnwu.magisk.core.tasks.FlashZip
import com.topjohnwu.magisk.core.tasks.LDMaskModuleInstaller
import com.topjohnwu.magisk.core.tasks.RemoveSystemSu
import com.topjohnwu.magisk.core.tasks.RemoveAllModules
import com.topjohnwu.magisk.core.tasks.MagiskInstaller
import com.topjohnwu.magisk.core.tasks.LDMaskRootPreset
import com.topjohnwu.magisk.core.utils.MediaStoreUtils
import com.topjohnwu.magisk.core.utils.MediaStoreUtils.outputStream
import com.topjohnwu.magisk.databinding.set
import com.topjohnwu.magisk.events.SnackbarEvent
import com.topjohnwu.superuser.CallbackList
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import android.os.Handler
import android.os.Looper

class FlashViewModel : BaseViewModel() {

    enum class State {
        FLASHING, SUCCESS, FAILED
    }

    private val _state = MutableLiveData(State.FLASHING)
    val state: LiveData<State> get() = _state
    val flashing = state.map { it == State.FLASHING }

    @get:Bindable
    var showReboot = Info.isRooted
        set(value) = set(value, field, { field = it }, BR.showReboot)

    val items = ObservableArrayList<ConsoleItem>()
    lateinit var args: FlashFragmentArgs

    private val logItems = mutableListOf<String>().synchronized()
    private val outItems = object : CallbackList<String>() {
        override fun onAddElement(e: String?) {
            e ?: return
            items.add(ConsoleItem(e))
            logItems.add(e)
        }
    }

    fun startFlashing() {
        val (action, uri) = args

        viewModelScope.launch {
            val result = when (action) {
                Const.Value.REMOVE_ALL_MODULES -> {
                    showReboot = false
                    val handler = Handler(Looper.getMainLooper())
                    val success = RemoveAllModules.exec { line -> handler.post { outItems.add(line) } }
                    showReboot = success
                    success
                }
                Const.Value.REMOVE_SYSTEM_SU -> {
                    showReboot = false
                    val handler = Handler(Looper.getMainLooper())
                    RemoveSystemSu.exec { line -> handler.post { outItems.add(line) } }
                }
                Const.Value.FLASH_LDMASK_MODULES -> {
                    showReboot = false
                    val ids = uri?.takeIf { it.scheme == "ldmask" && it.host == "modules" }
                        ?.getQueryParameter("ids")?.split(',')?.toSet()
                    if (ids.isNullOrEmpty() || ids.any { it !in setOf("oneone", "ktools_zygisk") }) {
                        outItems.add("! No valid module selection"); onResult(false); return@launch
                    }
                    val handler = Handler(Looper.getMainLooper())
                    val result = LDMaskModuleInstaller.exec({ line ->
                        handler.post { outItems.add(line) }
                    }, ids)
                    showReboot = result.installedCount > 0
                    result.success
                }
                Const.Value.FLASH_ZIP -> {
                    uri ?: return@launch
                    FlashZip(uri, outItems, logItems).exec()
                }
                Const.Value.UNINSTALL -> {
                    showReboot = false
                    MagiskInstaller.Uninstall(outItems, logItems).exec()
                }
                Const.Value.FLASH_MAGISK -> {
                    if (Info.isEmulator)
                        MagiskInstaller.Emulator(outItems, logItems).exec()
                    else
                        MagiskInstaller.Direct(outItems, logItems).exec()
                }
                Const.Value.FLASH_MAGISK_SYSTEM -> {
                    Config.recovery = false
                    val installed = MagiskInstaller.Direct_system(outItems, logItems).exec()
                    val handler = Handler(Looper.getMainLooper())
                    if (installed) LDMaskRootPreset.exec { line -> handler.post { outItems.add(line) } } else false
                }
                Const.Value.FLASH_INACTIVE_SLOT -> {
                    MagiskInstaller.SecondSlot(outItems, logItems).exec()
                }
                Const.Value.PATCH_FILE -> {
                    uri ?: return@launch
                    showReboot = false
                    MagiskInstaller.Patch(uri, outItems, logItems).exec()
                }
                else -> {
                    back()
                    return@launch
                }
            }
            onResult(result)
        }
    }

    private fun onResult(success: Boolean) {
        _state.value = if (success) State.SUCCESS else State.FAILED
    }

    fun onMenuItemClicked(item: MenuItem): Boolean {
        when (item.itemId) {
            R.id.action_save -> savePressed()
        }
        return true
    }

    private fun savePressed() = withExternalRW {
        viewModelScope.launch(Dispatchers.IO) {
            val name = "magisk_install_log_%s.log".format(
                System.currentTimeMillis().toTime(timeFormatStandard)
            )
            val file = MediaStoreUtils.getFile(name, true)
            file.uri.outputStream().bufferedWriter().use { writer ->
                synchronized(logItems) {
                    logItems.forEach {
                        writer.write(it)
                        writer.newLine()
                    }
                }
            }
            SnackbarEvent(file.toString()).publish()
        }
    }

    fun restartPressed() = reboot()
}
