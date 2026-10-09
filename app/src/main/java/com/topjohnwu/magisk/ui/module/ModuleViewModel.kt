package com.topjohnwu.magisk.ui.module

import android.net.Uri
import androidx.databinding.Bindable
import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.viewModelScope
import com.topjohnwu.magisk.core.tasks.LDMaskModuleInstaller
import com.topjohnwu.magisk.dialog.ChooseModulesDialog
import kotlinx.coroutines.launch
import kotlinx.coroutines.CancellationException
import com.topjohnwu.magisk.BR
import com.topjohnwu.magisk.MainDirections
import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.arch.AsyncLoadViewModel
import com.topjohnwu.magisk.core.Info
import com.topjohnwu.magisk.core.Const
import com.topjohnwu.magisk.core.base.ContentResultCallback
import com.topjohnwu.magisk.core.model.module.LocalModule
import com.topjohnwu.magisk.core.model.module.OnlineModule
import com.topjohnwu.magisk.databinding.MergeObservableList
import com.topjohnwu.magisk.databinding.RvItem
import com.topjohnwu.magisk.databinding.bindExtra
import com.topjohnwu.magisk.databinding.diffList
import com.topjohnwu.magisk.databinding.set
import com.topjohnwu.magisk.dialog.LocalModuleInstallDialog
import com.topjohnwu.magisk.dialog.RemoveSystemSuDialog
import com.topjohnwu.magisk.dialog.RemoveAllModulesDialog
import com.topjohnwu.magisk.dialog.OnlineModuleInstallDialog
import com.topjohnwu.magisk.events.GetContentEvent
import com.topjohnwu.magisk.events.SnackbarEvent
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.parcelize.Parcelize

class ModuleViewModel : AsyncLoadViewModel() {

    private val itemsInstalled = diffList<LocalModuleRvItem>()

    val items = MergeObservableList<RvItem>()
    val extraBindings = bindExtra {
        it.put(BR.viewModel, this)
    }

    val data get() = uri

    @get:Bindable
    var loading = true
        private set(value) = set(value, field, { field = it }, BR.loading)

    override suspend fun doLoadWork() {
        loading = true
        val moduleLoaded = Info.env.isActive &&
                withContext(Dispatchers.IO) { LocalModule.loaded() }
        if (moduleLoaded) {
            loadInstalled()
            if (items.isEmpty()) {
                items.insertItem(InstallModule)
                    .insertList(itemsInstalled)
            }
        }
        loading = false
        loadUpdateInfo()
    }

    override fun onNetworkChanged(network: Boolean) = startLoading()

    private suspend fun loadInstalled() {
        withContext(Dispatchers.Default) {
            val installed = LocalModule.installed().map { LocalModuleRvItem(it) }
            itemsInstalled.update(installed)
        }
    }

    private suspend fun loadUpdateInfo() {
        withContext(Dispatchers.IO) {
            itemsInstalled.forEach {
                if (it.item.fetch())
                    it.fetchedUpdateInfo()
            }
        }
    }

    fun downloadPressed(item: OnlineModule?) =
        if (item != null && Info.isConnected.value == true) {
            withExternalRW { OnlineModuleInstallDialog(item).show() }
        } else {
            SnackbarEvent(R.string.no_connection).publish()
        }

    fun installPressed() = withExternalRW {
        GetContentEvent("application/zip", UriCallback()).publish()
    }

    private var choosing = false
    fun quickInstallPressed() {
        if (!Info.env.isActive || choosing) return
        choosing = true
        viewModelScope.launch {
            try {
                val modules = LDMaskModuleInstaller.available()
                if (modules.isEmpty()) SnackbarEvent("Không có module được phát hành").publish()
                else ChooseModulesDialog(this@ModuleViewModel, modules).show()
            } catch (e: CancellationException) { throw e }
            catch (e: Exception) { SnackbarEvent("Không lấy được danh sách module: ${e.message}").publish() }
            finally { choosing = false }
        }
    }

    fun confirmQuickInstall(ids: Set<String>) {
        require(ids.isNotEmpty() && ids.all { it in setOf("ldlogin", "ldmenu") })
        MainDirections.actionFlashFragment(Const.Value.FLASH_LDMASK_MODULES,
            Uri.parse("ldmask://modules?ids=${ids.joinToString(",")}")).navigate()
    }

    fun removeSystemSuPressed() {
        if (Info.env.isActive) RemoveSystemSuDialog(this).show()
    }

    fun configurePressed(item: LocalModuleRvItem) {
        if (Info.env.isActive && item.hasConfiguration && !item.isRemoved)
            MainDirections.actionModuleConfigFragment(item.item.id).navigate()
    }

    fun confirmRemoveSystemSu() {
        MainDirections.actionFlashFragment(Const.Value.REMOVE_SYSTEM_SU, null).navigate()
    }

    fun removeAllModulesPressed() {
        if (Info.env.isActive) RemoveAllModulesDialog(this).show()
    }

    fun confirmRemoveAllModules() {
        MainDirections.actionFlashFragment(Const.Value.REMOVE_ALL_MODULES, null).navigate()
    }

    fun requestInstallLocalModule(uri: Uri, displayName: String) {
        LocalModuleInstallDialog(this, uri, displayName).show()
    }

    @Parcelize
    class UriCallback : ContentResultCallback {
        override fun onActivityResult(result: Uri) {
            uri.value = result
        }
    }

    companion object {
        private val uri = MutableLiveData<Uri?>()
    }
}
