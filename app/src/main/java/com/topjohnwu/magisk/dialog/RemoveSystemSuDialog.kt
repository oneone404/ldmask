package com.topjohnwu.magisk.dialog

import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.events.DialogBuilder
import com.topjohnwu.magisk.ui.module.ModuleViewModel
import com.topjohnwu.magisk.view.MagiskDialog

class RemoveSystemSuDialog(private val viewModel: ModuleViewModel) : DialogBuilder {
    override fun build(dialog: MagiskDialog) {
        dialog.apply {
            setTitle(R.string.ldmask_remove_system_su)
            setMessage(context.getString(R.string.ldmask_remove_system_su_confirm))
            setButton(MagiskDialog.ButtonType.POSITIVE) {
                text = R.string.ldmask_delete
                onClick { viewModel.confirmRemoveSystemSu() }
            }
            setButton(MagiskDialog.ButtonType.NEGATIVE) { text = android.R.string.cancel }
        }
    }
}
