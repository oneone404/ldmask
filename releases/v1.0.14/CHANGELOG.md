# LDMask 1.0.14 + LDMenu 1.2

- Sửa deadlock khi tạo namespace sạch của MagiskHide, nguyên nhân khiến game bị kẹt khởi động sau root. Giữ nguyên lựa chọn Hide và Zygisk.
- Tích hợp loader đã test cùng ARM wrapper mới của LDMenu. Giảm các đường dẫn/tên thư viện và hai SONAME cụ thể trong bản sao riêng; không sửa xác thực key hay file ELF gốc.
- LDMenu v1.2 / 3; LDLogin v1.24 / 25 giữ nguyên chức năng. APK LDMask-1.0.14 / 27016.
- Build Release/R8/strip, bỏ hook ptrace thử nghiệm và log audit ARM wrapper. 54 JVM tests qua, gồm kiểm tra hai ZIP phát hành thật.

## Cài / cập nhật

1. Cập nhật LDMask APK. APK dùng cùng chứng chỉ với các bản LDMask trước.
2. Trong Home, bấm icon cài của Magisk để cập nhật lõi system trực tiếp trên LD đã root system.
3. Trong Tools, cập nhật LDMenu hoặc chọn LDMenu từ Cài Nhanh Module. LDLogin đã v1.24 thì không cần nâng riêng.
4. Reboot LD một lần sau khi cả lõi và module cài thành công, rồi test mở game, menu và key trước khi clone nhiều LD.

Chỉ cập nhật APK không thay lõi Magisk đang cài hay LDMenu. Đây là bộ release để thử nghiệm; các lần test tiền nhiệm không thay thế test chạy lâu của bộ build này. Không bảo đảm ẩn root 100%, game/server không phát hiện, hoặc tốt hơn mọi detector so với MagiskHide gốc.

Wrapper mới chuyển cache `ktools_loader` sang `.runtime`, giữ nguyên dữ liệu. Khi rollback cần phục hồi đường dẫn cache tương ứng; không xoá cache chỉ để hạ bản. Project giữ binary gốc làm dependency, chưa phục hồi source project LDMenu gốc.
