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
| Hộp | Ô có bit movable tách thành danh sách riêng lúc nạp (ô lưới = 0). Đẩy; phía sau bị chặn thì **kéo** (lùi 1 ô, hộp vào chỗ cũ); hai đầu chặn thì đứng yên. Hộp chặn sáng, đè bàn đạp, chặn cửa bàn đạp |
| Cầm đèn (method_149/143/92) | Phím bắn nhặt đèn loại 0/1/2 ở ô đang đứng (bật nó), bấm lại để đặt. Đèn pin (1): đổi hướng chỉ xoay. Nến (2): life = r*2+1, mỗi bước -1, r = life>>1 |
| Op 28 | **Cảm biến sáng** (method_214), không phải đếm hộp: ô (x,y) sáng >= ngưỡng (0 = tối hẳn) thì chạy và tắt hẳn |
| Op 24 | Hẹn giờ (method_213): 4 byte đối số = ms 32 bit, đếm lùi, về <= 0 thì chạy |
| Op 25 | Hồi đầy năng lượng + câu 234 |
| Op 10 | Kèm câu 238 "Bạn tìm thấy: %1" (tên món, chân dung = biểu tượng món) |
| Cờ 128 | Chạy khi vào màn **và** khi đóng menu trong game (phím 6 -> ield_434), cần làm khi có menu |

## Phần A — xong

- `World`: túi đồ, năng lượng, bản đồ, sổ thay đổi sống qua các màn.
- `GridState.enter()`: sự kiện on-enter + bàn đạp; `step()` đúng luật hướng; `update_plates()`.
- `ScriptVM`: trả về hoàn tất/hủy, WeakRef về state (hết rò RefCounted), COUNTER, marker bản đồ, TELEPORT khác màn.
- `game.gd`: dùng `World`, chạy on-enter khi nạp màn, chuyển màn sau khi đóng hết thoại.
- Test: unit grid_state/script_vm/world, integration change_level.

## Phần B — xong

- Hộp đẩy/kéo; cầm đèn lồng/đèn pin/nến; cảm biến sáng (28); hẹn giờ (24); hồi năng lượng (25); thông báo nhặt đồ.
- `GridState.light_level` = port đúng `method_132` (bỏ xấp xỉ cũ ở is_lit).
- Parity: `level00_box`, `level00_flashlight`, `level06_candle` (so cả số câu thoại mỗi bước với số lần phải đóng thoại ở bản gốc).

## Phần C — còn lại (thứ tự làm)

1. ~~Bóng đèn/đui (op 23), công tắc tường~~ — xong: đâm hốc sáng lấy bóng, hốc tối lắp bóng (`GridState.bulbs`,
   reset mỗi màn như `field_278`). Công tắc khung 63/52 bật-tắt đèn loại 5 ở hai bên rồi thành 62/53, chỉ gạt một lần.
2. "Actor" — đọc code thì op 27 **không phải quái** mà là mũi tên hướng dẫn / khung nhấp nháy quanh HUD (`method_219`).
   Có 4 loại thực thể động:
   - ~~Tu sĩ (op 14 có bit 0x80, `method_231/232`)~~ — xong: tối đa 8, đi thẳng 400 ms/ô không va chạm, tới đích chạy
     sự kiện cờ 64 với chính tu sĩ đó (op 8 = đi tiếp, op 6 = dịch chuyển / rời màn, op 22 chỉ truyền tu sĩ vào sự kiện
     cờ 64). Thấy người chơi trong 2 ô (`method_153`, bị vật chắn sáng che) mà không mặc Áo choàng tu sĩ (món 20)
     → năng lượng 0, câu 169. Áo choàng cũng chặn mất máu trong tối (`method_97`). `World.equipped` chờ UI túi đồ.
   - ~~Sinh vật bóng tối~~, ~~Boss 1~~, ~~Boss 2~~ — xong (test `test_creatures.gd`, `test_boss.gd`). Vị trí chạm của boss so với
     ô người chơi (bản gốc so pixel khi người đang trượt giữa hai ô).
   - Sinh vật bóng tối (op 14 không bit 0x80, `method_233/236/237`): tối đa 16, tự sinh mỗi giây ở ô tối ngẫu nhiên
     (trừ màn 14, 15), chạy về ô tối nhất cạnh nó khi bị chiếu, ở trong sáng đủ 1000 ms thì chết (đếm `field_474`),
     hộp đè lên thì mất. Không gây sát thương.
   - Boss 1 (SPECIAL 2/8, `method_196`): máu 25600, đuổi khi thấy người chơi trong 5 ô, không vào ô sáng >= 5,
     mất máu khi đứng ô sáng >= 4, chạm người chơi -1 năng lượng mỗi 2 s, chết -> 5 s -> chạy SPECIAL 8. Chặn đường.
   - Boss 2 (SPECIAL 10/11/12, `method_199/200`, màn 14): trôi sang phải, đèn trước mặt làm nó mất 1/4 máu và tắt,
     ai ở bên trái nó hoặc chạm cục lửa (SPECIAL 11) thì chết ngay; hết máu -> SPECIAL 12.
4. Nhạc (op 1, MIDI→OGG), kết chương (op 13), minigame (op 12), special (op 30).
5. Bản đồ thành phố, menu, ~~lưu game~~. Lưu xong: JSON `user://save.json` (`World.save_game/load_game`), tự lưu
   khi vào màn 14, khi TELEPORT lúc đang ở màn 14 và SPECIAL 18; `game.continue_from_save()` chờ menu "Chơi tiếp".
   Trang bị tạm bằng phím Tab (xoay vòng túi đồ) cho tới khi có màn hình túi đồ. Op 27 (mũi tên/nháy HUD) xong.
6. Parity route cho mỗi màn (`tools/record_parity.ps1`), kèm một route qua bàn đạp.
