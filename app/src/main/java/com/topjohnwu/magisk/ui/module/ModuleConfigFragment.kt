package com.topjohnwu.magisk.ui.module

import android.os.Bundle
import android.view.View
import android.widget.TextView
import androidx.core.widget.doAfterTextChanged
import com.google.android.material.card.MaterialCardView
import com.google.android.material.switchmaterial.SwitchMaterial
import com.google.android.material.textfield.TextInputEditText
import com.topjohnwu.magisk.R
import com.topjohnwu.magisk.arch.BaseFragment
import com.topjohnwu.magisk.arch.viewModel
import com.topjohnwu.magisk.databinding.FragmentModuleConfigBinding

class ModuleConfigFragment : BaseFragment<FragmentModuleConfigBinding>() {
    override val layoutRes = R.layout.fragment_module_config
    override val viewModel by viewModel<ModuleConfigViewModel>()
    private val inputs = mutableListOf<View>()
    override fun onViewCreated(view: View, savedInstanceState: Bundle?) {
        super.onViewCreated(view, savedInstanceState)
        binding.configSave.setOnClickListener { viewModel.save() }
        binding.configReload.setOnClickListener { viewModel.reload() }
        viewModel.message.observe(viewLifecycleOwner) {
            binding.configMessage.text = it
            binding.configMessage.visibility = if (it.isNullOrBlank()) View.GONE else View.VISIBLE
        }
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
                val card = layoutInflater.inflate(R.layout.item_module_config_field, binding.configFields, false) as MaterialCardView
                card.findViewById<TextView>(R.id.config_field_label).text = field.label
                val description = card.findViewById<TextView>(R.id.config_field_description)
                description.text = field.description
                description.visibility = if (field.description.isEmpty()) View.GONE else View.VISIBLE
                if (field.type == "boolean") card.findViewById<SwitchMaterial>(R.id.config_field_switch).apply {
                    visibility = View.VISIBLE; contentDescription = field.label
                    isChecked = viewModel.draft[field.key] == true
                    setOnCheckedChangeListener { _, checked -> viewModel.draft[field.key] = checked }; inputs += this
                    card.isClickable = true; card.isFocusable = true
                    card.setOnClickListener { if (isEnabled) isChecked = !isChecked }
                } else card.findViewById<TextInputEditText>(R.id.config_field_number).apply {
                    visibility = View.VISIBLE; contentDescription = field.label
                    setText(viewModel.draft[field.key].toString())
                    doAfterTextChanged { viewModel.draft[field.key] = it.toString().toIntOrNull() ?: "invalid" }; inputs += this
                }
                binding.configFields.addView(card)
            }
            inputs.forEach { it.isEnabled = viewModel.busy.value != true }
        }
        activity?.title = getString(R.string.ldmask_configuration)
        viewModel.open(requireArguments().getString("moduleId").orEmpty())
    }
}
