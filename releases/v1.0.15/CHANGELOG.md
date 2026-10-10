# LDMask 1.0.15 (27017)

- Đổi thông báo phát hiện SU ngoài Magisk thành **Thông Báo Trạng Thái**.
- Nội dung: **Lệnh SU Không Thuộc Về Magisk Đã Được Tìm Thấy**.
- **OK** đóng thông báo; **DELETE** chạy cùng luồng Xoá Su Bin/Xbin trong Tools.
- Giữ nguyên kiểm tra bảo vệ root Magisk, xác minh kết quả xoá và không tự reboot.
- Không thay đổi LDLogin v1.24 (25) hoặc LDMenu v1.2 (3).

Chỉ cần cập nhật APK để áp dụng thay đổi giao diện này. Không cần cài lại core hoặc module riêng cho thay đổi popup.

Build release thành công; 56 JVM tests qua. Chưa kiểm thử xoá SU trực tiếp trên LD trong lần build này.
