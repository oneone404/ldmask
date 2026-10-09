package com.topjohnwu.magisk.ui.settings

import android.view.View
import android.widget.Toast
import androidx.lifecycle.viewModelScope
import com.topjohnwu.magisk.BR
import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.arch.BaseViewModel
import com.topjohnwu.magisk.core.Const
import com.topjohnwu.magisk.core.Info
import com.topjohnwu.magisk.core.di.AppContext
import com.topjohnwu.magisk.core.di.ServiceLocator
import com.topjohnwu.magisk.core.ktx.activity
import com.topjohnwu.magisk.core.ktx.toast
import com.topjohnwu.magisk.core.tasks.HideAPK
import com.topjohnwu.magisk.databinding.bindExtra
import com.topjohnwu.magisk.events.AddHomeIconEvent
import com.topjohnwu.magisk.events.BiometricEvent
import com.topjohnwu.magisk.events.AuthEvent
import com.topjohnwu.magisk.events.SnackbarEvent
import com.topjohnwu.superuser.Shell
import kotlinx.coroutines.launch

class SettingsViewModel : BaseViewModel(), BaseSettingsItem.Handler {

    val items = createItems()
    val extraBindings = bindExtra {
        it.put(BR.handler, this)
    }

    private fun createItems(): List<BaseSettingsItem> {
        // Keep the upstream defaults/values; only expose these root controls.
        return if (Info.env.isActive && Const.Version.atLeast_24_0())
            listOf(Magisk, Zygisk, DenyList, DenyListConfig)
        else emptyList()
    }

    override fun onItemPressed(view: View, item: BaseSettingsItem, andThen: () -> Unit) {
        when (item) {
            DownloadPath -> withExternalRW(andThen)
            UpdateChecker -> withPostNotificationPermission(andThen)
            Authentication -> if (ServiceLocator.biometrics.isEnabled) authenticate(andThen) else AuthEvent(andThen).publish()
            Theme -> SettingsFragmentDirections.actionSettingsFragmentToThemeFragment().navigate()
            DenyListConfig -> SettingsFragmentDirections.actionSettingsFragmentToDenyFragment().navigate()
            SystemlessHosts -> createHosts()
            Hide, Restore -> withInstallPermission(andThen)
            AddShortcut -> AddHomeIconEvent().publish()
            else -> andThen()
        }
    }

    override fun onItemAction(view: View, item: BaseSettingsItem) {
        when (item) {
            UpdateChannel -> openUrlIfNecessary(view)
            is Hide -> viewModelScope.launch { HideAPK.hide(view.activity, item.value) }
            Restore -> viewModelScope.launch { HideAPK.restore(view.activity) }
            Zygisk -> if (Zygisk.mismatch) SnackbarEvent(R.string.reboot_apply_change).publish()
            SuList -> if (SuList.mismatch) SnackbarEvent(R.string.reboot_apply_change).publish()
            else -> Unit
        }
    }

    private fun openUrlIfNecessary(view: View) {
        UpdateChannelUrl.refresh()
        if (UpdateChannelUrl.isEnabled && UpdateChannelUrl.value.isBlank()) {
            UpdateChannelUrl.onPressed(view, this)
        }
    }

private fun authenticate(callback: () -> Unit) {
        BiometricEvent {
            // allow the change on success
            onSuccess { callback() }
        }.publish()
    }

    private fun createHosts() {
        Shell.cmd("add_hosts_module").submit {
            AppContext.toast(R.string.settings_hosts_toast, Toast.LENGTH_SHORT)
        }
    }
}
