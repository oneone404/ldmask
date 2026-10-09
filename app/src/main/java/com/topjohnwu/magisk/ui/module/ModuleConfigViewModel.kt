package com.topjohnwu.magisk.ui.module

import androidx.lifecycle.MutableLiveData
import androidx.lifecycle.viewModelScope
import com.topjohnwu.magisk.arch.BaseViewModel
import com.topjohnwu.magisk.core.tasks.ModuleUiRepository
import com.topjohnwu.magisk.core.tasks.ModuleUiSnapshot
import com.topjohnwu.magisk.core.tasks.OneOneUiSettings
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

class ModuleConfigViewModel : BaseViewModel() {
    val snapshot = MutableLiveData<ModuleUiSnapshot?>()
    val busy = MutableLiveData(false)
    val message = MutableLiveData("")
    val draft = linkedMapOf<String, Any>()
    private var moduleId = ""
    fun open(id: String) {
        if (moduleId == id && snapshot.value != null) return
        moduleId = id; reload()
    }
    fun reload() {
        if (busy.value == true) return
        busy.value = true
        viewModelScope.launch {
            try {
                val next = ModuleUiRepository.load(moduleId)
                draft.clear(); draft.putAll(next.settings.values()); snapshot.value = next
                message.value = when {
                    !next.valid -> "Thiếu hoặc hỏng cấu hình: bot đang TẮT. Bấm Lưu để tạo cấu hình mới."
                    next.pending -> "Module đang chờ áp dụng sau khi reboot; cấu hình vẫn được lưu riêng."
                    else -> "Bật/tắt và log áp dụng qua inotify. Thời gian chờ áp dụng ở lần boot tiếp theo."
                }
            } catch (e: CancellationException) { throw e }
            catch (e: Exception) { snapshot.value = null; message.value = e.message.orEmpty() }
            finally { busy.value = false }
        }
    }
    fun save() {
        if (busy.value == true) return
        val old = snapshot.value ?: return
        val values = try { OneOneUiSettings.from(draft) } catch (_: Exception) {
            message.value = "Thời gian chờ phải là số nguyên từ 0 đến 600 giây."; return
        }
        busy.value = true
        viewModelScope.launch {
            try {
                snapshot.value = ModuleUiRepository.save(moduleId, old, values)
                message.value = "Đã lưu. Bật/tắt và log áp dụng ngay; thời gian chờ áp dụng ở lần boot tiếp theo."
            } catch (e: CancellationException) { throw e }
            catch (e: Exception) { message.value = "${e.message}. Nếu dữ liệu đã đổi, bấm Tải Lại trước khi lưu." }
            finally { busy.value = false }
        }
    }
}
