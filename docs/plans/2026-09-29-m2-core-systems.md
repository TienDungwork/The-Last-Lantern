# M2 — Hệ thống lõi Classic (đủ 19 màn chơi được)

Nhánh: `m2`. Nguyên tắc như M1: logic trong `src/core` (không node), test headless, parity với bản gốc khi có thể.

## Phát hiện từ `class_10.java` (đã kiểm chứng bằng test)

| Chủ đề | Sự thật |
|---|---|
| Cờ sự kiện | 1 repeat, 2 active, 4/8/16/32 = đang đi xuống/trái/lên/phải (`field_425`), 64 by_actor, 128 chạy khi vào màn |
| Kích hoạt (`method_216`) | Bỏ qua sự kiện tắt và loại 16/24/28. Bước lên ô = dir 0 (không lọc hướng). Đâm tường = lọc theo hướng. PICKUP (op 10) cần ô sáng |
| Tắt sự kiện (`method_208`) | Chỉ khi chạy hết và không repeat. Hủy giữa chừng (IF_HOLDING sai, COUNTER chưa đủ, PICKUP tối) giữ nguyên active |
| Op 16 | **Bàn đạp**, không phải cửa ra (`method_215`): vùng bị đè (vật, người, actor, đèn) → ô cửa = 0, nhả → trả ô cũ |
| Chuyển màn | TELEPORT (op 6) với màn khác. Rời màn 14 → autosave (`method_112`) |
| Thế giới (`method_205/206`) | Mỗi lần vào màn nạp lại .dat + áp sổ thay đổi. Chỉ lệnh có bit 0x80 ở byte màn mới được ghi. Loại: 0 bật, 1 tắt (triệt nhau), 2 đặt ô (ghi đè cùng x,y), 3 bán kính đèn |
| COUNTER (op 18) | Tự giảm arg; chạy tiếp khi arg = 1 |

## Phần A — xong

- `World`: túi đồ, năng lượng, bản đồ, sổ thay đổi sống qua các màn.
- `GridState.enter()`: sự kiện on-enter + bàn đạp; `step()` đúng luật hướng; `update_plates()`.
- `ScriptVM`: trả về hoàn tất/hủy, WeakRef về state (hết rò RefCounted), COUNTER, marker bản đồ, TELEPORT khác màn.
- `game.gd`: dùng `World`, chạy on-enter khi nạp màn, chuyển màn sau khi đóng hết thoại.
- Test: unit grid_state/script_vm/world, integration change_level.

## Phần B — còn lại (thứ tự làm)

1. Hộp: đẩy/kéo, op 28 (đếm hộp), bàn đạp bị hộp đè.
2. Mang đèn/bóng (op 23), nến/đèn pin.
3. Actor: quái/tu sĩ (op 27), đạn (op 14), hẹn giờ (op 24).
4. Nhạc (op 1, MIDI→OGG), kết chương (op 13), minigame (op 12), special (op 30).
5. Bản đồ thành phố, menu, lưu game (autosave rời màn 14).
6. Parity route cho mỗi màn (`tools/record_parity.ps1`), kèm một route qua bàn đạp.
