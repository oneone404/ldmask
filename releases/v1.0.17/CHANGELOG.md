# LDMask 1.0.17 / LDLogin 1.25

- Thêm công tắc **Mở Balo** trong cấu hình LDLogin, mặc định bật để giữ hành vi cũ.
- Tắt Mở Balo: không quét/bấm balo, không lấy vợt hay bấm dự phòng, không quét/bấm X đóng menu. Giữ nguyên login, Xác nhận, OK và giám sát game.
- Lưu cấu hình áp dụng qua inotify/FIFO, không thêm polling JSON. Tắt trong lúc chờ hoặc tìm vợt dừng các thao tác tiếp theo; bật lại có thể chạy luồng balo mà không force-stop game chỉ vì đổi công tắc.
- Cần cập nhật APK và LDLogin; reboot LD một lần để kích hoạt module mới. Sau đó thay đổi công tắc chỉ cần lưu, không cần reboot.
- Thêm **LDNPH** vào danh sách cài nhanh; cho chọn và điều khiển published riêng. Giữ nguyên ZIP người dùng cung cấp, ID `zygisk_il2cppdumper`, versionCode 1. Đây là Il2CppDumper Zygisk, không phải module ẩn root; không có source đi kèm để xác nhận toàn bộ hành vi.
- Hai module cũ vẫn nằm trong danh sách dành cho app cũ. LDNPH dùng hàng optional, cần APK 1.0.17 để chọn cài. App cũ có thể đánh dấu LDNPH là module ngoài danh sách khi chạy cleanup; cập nhật APK trước khi dùng LDNPH.
- LDMenu giữ nguyên ZIP v1.2. Không lấy core mới từ fork Kitsune; xem báo cáo upstream trong source.

Không tự cài module, sửa setting hoặc reboot LD trong quá trình build này.
