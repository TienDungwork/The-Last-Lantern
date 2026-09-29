# Nghiệm thu M1 (2026-09-29)

Chạy test: `.\tools\test.ps1` → `34 passed, 0 failed`.
Ghi lại trace bản gốc: `.\tools\record_parity.ps1 -level 0` (cần `df2_desktop\qa` và `AutoPlay` có lệnh `R`).

| Hạng mục | Kết quả | Cách kiểm |
|---|---|---|
| Xuất dữ liệu 19 màn, chuỗi en/vi, khung hình, ô | PASS | `tests/unit/test_data_export.gd` |
| Màn 0 dựng 3D, nhân vật ở (6,4), sàn sáng quanh đèn | PASS | `tools/snap.gd`, ảnh `snap/level_0.png` |
| Đi 4 hướng, tường chắn, không lọt biên | PASS | test `test_grid_state`, test so sánh |
| Đọc tờ giấy: nhặt Note 1, câu 228 rồi 7 đúng hình, tiếng Việt | PASS | test `test_script_vm`, ảnh `snap/note.png` |
| Vị trí + hướng mặt 9 bước khớp bản gốc | PASS | `test_parity` |
| Độ sáng từng ô khớp bản gốc (10 trạng thái × 254 ô) | PASS | `test_parity` |
| Mất năng lượng trong tối (2–3 s), về 0 báo chết | PASS (logic) | `test_rules_classic` |
| Chơi tay: mở game, đi, đọc giấy, đứng tối, chết rồi tải lại | CHỜ người dùng | `& (& .\tools\godot.ps1) --path .`, giữ phím là đi liên tục (`tests/integration/test_walk.gd`) |

## Chưa làm ở M1 (chuyển M2)

- Sự kiện `on_action` lúc vào màn (thoại mở đầu), `by_actor`.
- Lệnh kịch bản in `todo op N` khi gặp: 1, 4, 5, 12, 13, 14, 18, 24, 25, 28. Chuyển màn (`change_level`) mới chỉ in log.
- Bảng `ENTER_FLAG` (hướng vào ô ↔ cờ sự kiện) mới được kiểm gián tiếp; tuyến màn 0 chưa đi qua sự kiện một hướng.
  M2 thêm tuyến đi qua event #2 (12,11, chỉ `from_up`).
- Hộp, đèn mang theo, bóng đèn, quái, tu sĩ, menu, lưu game, nhạc.
