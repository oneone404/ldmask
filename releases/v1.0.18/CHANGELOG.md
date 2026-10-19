# LDMask 1.0.18 (27020)

- Sửa lỗi LDMask văng khi chọn LDNPH rồi bấm Cài đặt.
- Màn hình chọn, màn hình cài và bộ cài dùng chung danh sách ID; nhận đúng `zygisk_il2cppdumper`.
- Lựa chọn không hợp lệ bị từ chối mà không ném lỗi làm văng UI.
- Kiểm thử cả 7 tổ hợp chọn LDLogin/LDMenu/LDNPH, chỉ cài đúng các module được chọn.
- Chỉ cần cập nhật APK cho bản vá này. LDLogin 1.25, LDMenu 1.2 và ZIP LDNPH giữ nguyên; không cần root lại hoặc reboot chỉ để sửa lỗi nút cài.

64 JVM tests qua. Không tự cài module hay reboot LD trong quá trình sửa.
