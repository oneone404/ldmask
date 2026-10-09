package com.topjohnwu.magisk.ui.module

import android.os.Bundle
import android.graphics.Typeface
import android.text.InputType
import android.view.View
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.widget.doAfterTextChanged
import com.google.android.material.card.MaterialCardView
import com.google.android.material.switchmaterial.SwitchMaterial
import com.google.android.material.textfield.TextInputEditText
import com.google.android.material.textfield.TextInputLayout
import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.arch.BaseFragment
import com.topjohnwu.magisk.arch.viewModel
import com.topjohnwu.magisk.databinding.FragmentModuleConfigBinding

class ModuleConfigFragment : BaseFragment<FragmentModuleConfigBinding>() {
    override val layoutRes = R.layout.fragment_module_config
    override val viewModel by viewModel<ModuleConfigViewModel>()
    private fun dp(value: Int) = (value * resources.displayMetrics.density).toInt()
    private val inputs = mutableListOf<View>()
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.configSave.setOnClickListener { viewModel.save() }
        binding.configReload.setOnClickListener { viewModel.reload() }
        viewModel.message.observe(viewLifecycleOwner) { binding.configMessage.text = it }
        viewModel.busy.observe(viewLifecycleOwner) { busy ->
            inputs.forEach { it.isEnabled = !busy }
            binding.configSave.isEnabled = !busy && viewModel.snapshot.value != null
            binding.configReload.isEnabled = !busy
        }
        viewModel.snapshot.observe(viewLifecycleOwner) { data ->
            binding.configFields.removeAllViews(); inputs.clear()
            binding.configSave.isEnabled = data != null && viewModel.busy.value != true
            if (data == null) return@observe
            activity?.title = data.schema.title
            for (field in data.schema.fields) {
                val card = MaterialCardView(requireContext()).apply {
                    radius = dp(12).toFloat()
                    layoutParams = LinearLayout.LayoutParams(-1, -2).apply { bottomMargin = dp(12) }
                }
                val column = LinearLayout(requireContext()).apply {
                    orientation = LinearLayout.VERTICAL; setPadding(dp(16), dp(10), dp(16), dp(10))
                }
                if (field.type == "boolean") column.addView(SwitchMaterial(requireContext()).apply {
                    text = field.label; setTypeface(typeface, Typeface.BOLD)
                    isChecked = viewModel.draft[field.key] == true
                    setOnCheckedChangeListener { _, checked -> viewModel.draft[field.key] = checked }; inputs += this
                }) else column.addView(TextInputLayout(requireContext()).apply {
                    hint = field.label
                    addView(TextInputEditText(context).apply {
                        inputType = InputType.TYPE_CLASS_NUMBER; setText(viewModel.draft[field.key].toString())
                        doAfterTextChanged { viewModel.draft[field.key] = it.toString().toIntOrNull() ?: "invalid" }; inputs += this
                    })
                })
                if (field.description.isNotEmpty()) column.addView(TextView(requireContext()).apply {
                    text = field.description; textSize = 12f
                })
                card.addView(column); binding.configFields.addView(card)
            }
            inputs.forEach { it.isEnabled = viewModel.busy.value != true }
        }
        activity?.title = getString(R.string.ldmask_configuration)
        viewModel.open(requireArguments().getString("moduleId").orEmpty())
    }
}
