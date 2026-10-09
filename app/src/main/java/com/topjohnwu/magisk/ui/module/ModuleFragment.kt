package com.topjohnwu.magisk.ui.module

import android.os.Bundle
import android.view.View
import android.view.Menu
import android.view.MenuInflater
import android.view.MenuItem
import android.view.ContextThemeWrapper
import android.widget.PopupMenu
import androidx.core.view.MenuProvider
import com.topjohnwu.magisk.core.Info
import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.arch.BaseFragment
import com.topjohnwu.magisk.arch.viewModel
import com.topjohnwu.magisk.core.utils.MediaStoreUtils.displayName
import com.topjohnwu.magisk.databinding.FragmentModuleMd2Binding
import rikka.recyclerview.addEdgeSpacing
import rikka.recyclerview.addInvalidateItemDecorationsObserver
import rikka.recyclerview.addItemSpacing
import rikka.recyclerview.fixEdgeEffect

class ModuleFragment : BaseFragment<FragmentModuleMd2Binding>(), MenuProvider {

    override val layoutRes = R.layout.fragment_module_md2
    override val viewModel by viewModel<ModuleViewModel>()

    override fun onStart() {
        super.onStart()
        activity?.title = resources.getString(R.string.ldmask_tools)
        viewModel.data.observe(this) {
            it ?: return@observe
            val displayName = runCatching { it.displayName }.getOrNull() ?: return@observe
            viewModel.requestInstallLocalModule(it, displayName)
            viewModel.data.value = null
        }
    }

    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)

        binding.moduleList.apply {
            addEdgeSpacing(top = R.dimen.l_50, bottom = R.dimen.l1)
            addItemSpacing(R.dimen.l1, R.dimen.l_50, R.dimen.l1)
            fixEdgeEffect()
            post { addInvalidateItemDecorationsObserver() }
        }
    }

    override fun onPreBind(binding: FragmentModuleMd2Binding) = Unit

    override fun onCreateMenu(menu: Menu, inflater: MenuInflater) {
        inflater.inflate(R.menu.menu_module_ldmask, menu)
    }

    override fun onPrepareMenu(menu: Menu) {
        menu.findItem(R.id.action_tools_cleanup)?.isEnabled = Info.env.isActive
    }

    override fun onMenuItemSelected(item: MenuItem): Boolean {
        if (item.itemId != R.id.action_tools_cleanup) return false
        val host = activity ?: return false
        val anchor = host.findViewById<View>(R.id.action_tools_cleanup) ?: return false
        PopupMenu(ContextThemeWrapper(host, R.style.Foundation_PopupMenu), anchor).apply {
            host.menuInflater.inflate(R.menu.menu_tools_cleanup, menu)
            setOnMenuItemClickListener {
                when (it.itemId) {
                    R.id.action_remove_all_modules -> viewModel.removeAllModulesPressed()
                    R.id.action_remove_system_su -> viewModel.removeSystemSuPressed()
                    else -> return@setOnMenuItemClickListener false
                }
                true
            }
            show()
        }
        return true
    }

}
