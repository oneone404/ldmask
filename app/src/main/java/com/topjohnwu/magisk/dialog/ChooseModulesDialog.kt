package com.topjohnwu.magisk.dialog

import android.widget.CheckBox
import android.widget.LinearLayout
import android.widget.TextView
import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.events.DialogBuilder
import com.topjohnwu.magisk.ui.module.ModuleViewModel
import com.topjohnwu.magisk.view.MagiskDialog

class ChooseModulesDialog(private val vm: ModuleViewModel, private val modules: List<Pair<String, String>>) : DialogBuilder {
    override fun build(dialog: MagiskDialog) {
        val selected = linkedSetOf<String>()
        dialog.setTitle(R.string.ldmask_choose_modules)
        val layout = LinearLayout(dialog.context).apply { orientation = LinearLayout.VERTICAL }
        modules.forEach { (id, name) ->
            layout.addView(CheckBox(dialog.context).apply {
                text = name
                setOnCheckedChangeListener { _, checked ->
                    if (checked) selected.add(id) else selected.remove(id)
                }
            })
        }
        layout.addView(TextView(dialog.context).apply {
            setText(R.string.ldmask_cleanup_unlisted_hint)
            setTextAppearance(R.style.AppearanceFoundation_Tiny_Variant)
        })
        dialog.setView(layout)
        dialog.setButton(MagiskDialog.ButtonType.POSITIVE) {
            text = R.string.install; doNotDismiss = true
            onClick { if (selected.isNotEmpty()) { vm.confirmQuickInstall(selected.toSet()); it.dismiss() } }
        }
        dialog.setButton(MagiskDialog.ButtonType.NEGATIVE) { text = android.R.string.cancel }
    }
}
