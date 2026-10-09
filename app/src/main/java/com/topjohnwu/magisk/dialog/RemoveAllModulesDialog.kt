package com.topjohnwu.magisk.dialog

import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.events.DialogBuilder
import com.topjohnwu.magisk.ui.module.ModuleViewModel
import com.topjohnwu.magisk.view.MagiskDialog

class RemoveAllModulesDialog(private val viewModel: ModuleViewModel) : DialogBuilder {
    override fun build(dialog: MagiskDialog) {
        dialog.apply {
            setTitle(R.string.ldmask_remove_all_modules)
            setMessage(context.getString(R.string.ldmask_remove_all_modules_confirm))
            setButton(MagiskDialog.ButtonType.POSITIVE) {
                text = R.string.ldmask_delete
                onClick { viewModel.confirmRemoveAllModules() }
            }
            setButton(MagiskDialog.ButtonType.NEGATIVE) { text = android.R.string.cancel }
        }
    }
}
