# The Last Lantern II: bản làm lại 2.5D trên Godot (thiết kế)

Ngày: 2026-09-29. Trạng thái: chờ duyệt.

> **Đổi hướng 2026-09-30:** bỏ hai chế độ Cổ điển/Nâng cao trong menu; game một chế độ, gộp dần cơ chế mục 5 vào
> luật chính, máu 100 thay năng lượng 4 nấc. Chi tiết ở mục M4 của `docs/plans/2026-09-29-master-plan.md`.

## 1. Mục tiêu

Làm lại game trên Godot 4 với hình ảnh 2.5D, **giữ đủ 19 màn, câu đố, kịch bản và cốt truyện gốc**.
Thêm cơ chế ánh sáng mới trong chế độ riêng.

- **Chế độ Cổ điển:** chơi đúng luật gốc. Mọi màn chắc chắn giải được như bản điện thoại.
- **Chế độ Nâng cao:** bật 6 cơ chế ánh sáng mới (mục 5). Màn nào bị kẹt thì được chỉnh bằng file bổ sung riêng.
- Code nằm ở thư mục mới `d:\ntiendung\games\lantern_godot\`. Bản PC hiện tại (`df2_desktop\`) giữ nguyên, dùng làm
  bản tham chiếu để so sánh luật chơi.

Không làm trong đợt này: màn mới, chơi mạng, bản điện thoại hay web.

## 2. Quyết định kỹ thuật

| Vấn đề | Quyết định | Lý do |
|---|---|---|
| Engine | Godot 4 (bản ổn định mới nhất), renderer Forward+ | Miễn phí, nhẹ, có ánh sáng và bóng đổ 3D, xuất .exe dễ |
| Ngôn ngữ | GDScript | Không cần .NET, sửa-chạy nhanh, có chế độ headless để test |
| Dựng màn | Đọc JSON sinh từ `.dat` gốc, dựng cảnh 3D khi chạy | 19 màn đã giải mã đủ, không phải dựng tay |
| Di chuyển | Logic theo ô (1 ô = 1 m), hình ảnh trượt mượt giữa các ô | Câu đố gốc (đẩy hộp, bán kính đèn, công tắc) đều tính theo ô |
| Nhân vật | Mô hình 3D tạo từ ảnh concept (`img\image.png`) bằng Meshy/Tripo, gắn xương và động tác từ Mixamo, xuất glTF | Đi được mọi hướng mà không phải vẽ từng khung |
| Phong cách | Shader tô kiểu tranh vẽ (ánh sáng phân bậc, viền, vân giấy) | Khớp với nét vẽ concept |
| Ánh sáng | Tầng luật tính ô nào sáng; đèn Godot chỉ vẽ cho khớp | Thấy tối là đúng tối, không lệch giữa hình và luật |
| Âm thanh | Chuyển MIDI gốc sang OGG khi xuất dữ liệu | Godot không phát MIDI |
| Test | Script GDScript tự viết, chạy `godot --headless` | Không cần framework test |

## 3. Cấu trúc thư mục

```text
lantern_godot/
  project.godot            cấu hình Godot (main scene: res://src/game.tscn)
  src/                     CODE GAME (chỉ thứ này được đóng gói vào .exe)
    game.gd, game.tscn       nối core ↔ view ↔ ui, bàn phím
    core/                    TẦNG LUẬT CHƠI, logic thuần, không đụng node 3D
      level_data.gd            đọc data/ (màn, thuộc tính ô, chuỗi)
      grid_state.gd            trạng thái màn: vị trí, túi đồ, ô, đèn, cờ sự kiện
      light_field.gd           độ sáng 0..7 từng ô (chuyển từ method_151/152)
      rules_classic.gd         luật gốc (mất năng lượng trong tối...)
      rules_enhanced.gd        (M4) luật Nâng cao, kế thừa luật gốc
      script_vm.gd             bộ chạy kịch bản 31 lệnh gốc (+ lệnh ≥100 cho Nâng cao)
      save_game.gd             (M2) lưu JSON vào user://
    view/                    TẦNG HÌNH ẢNH 3D: level_builder, actor, lighting, camera_rig
    ui/                      hội thoại, HUD, chân dung; (M2) menu, túi đồ, bản đồ
  data/                    SINH TỰ ĐỘNG bởi tools/export_data.py, KHÔNG sửa tay
  data_enhanced/           (M4) file bổ sung cho chế độ Nâng cao, SỬA TAY
  assets/                  original/ (PNG gốc); (M3) model .glb, texture, nhạc .ogg, font
  tests/                   TEST, không đóng gói
    run.gd                   bộ chạy: tìm mọi tests/**/test_*.gd
    lib/test_case.gd         lớp cha (eq, ok, tree)
    unit/                    test core/ và dữ liệu, không cần cảnh 3D
    integration/             chạy game.tscn headless, giả lập phím
    parity/                  so với game gốc; fixtures/ = tuyến đi + trace ghi từ bản gốc
  tools/                   CÔNG CỤ cho người làm, không phải test, không đóng gói
    godot.ps1                tìm file Godot
    test.ps1                 chạy test: .\tools\test.ps1 [unit|integration|parity]
    export_data.py           file gốc → data/ (dùng lại tools/df2_decode.py, df2_lang.py)
    record_parity.ps1        chạy game gốc ẩn theo tuyến, ghi trace vào tests/parity/fixtures/
    snap.gd                  chụp ảnh một màn ra snap/ (bỏ qua git)
  docs/                    specs/ thiết kế, plans/ kế hoạch
```

## 4. Tầng luật chơi (`core/`)

Game chạy theo **lượt**: mỗi lệnh của người chơi (đi, tương tác, dùng vật phẩm) được `core` xử lý trọn vẹn,
rồi phát ra danh sách sự kiện, ví dụ `moved(actor, from, to)`, `light_changed(id)`, `say(string_id, portrait)`,
`damaged(hp)`, `level_changed(n, x, y)`. `view/` và `ui/` chỉ nghe sự kiện để diễn hoạt, không tự đổi trạng thái.

- **Nguồn luật gốc:** `darkest_fear_2_grim_243556\src\class_10.java`, gồm bộ chạy kịch bản `method_209`,
  phần đọc màn `method_116/140/210`, ánh sáng và di chuyển. Bản dịch ngược có chỗ sai (đã biết: `class_7.method_52`),
  nên mọi luật chuyển sang đều phải qua test so sánh (mục 8).
- **Bộ chạy kịch bản:** 31 lệnh gốc, độ dài tham số theo bảng `ARG_LEN` trong `tools\df2_decode.py`.
  Các cờ sự kiện gồm repeat, active, 4 hướng vào, by_actor, on_action. Lệnh mới cho Nâng cao đánh số từ 100.
- **Thuộc tính ô (đã xác nhận ở M1):** `tile_props` trong `dc.dat`, 189 loại ô. bit0 `solid` (chắn đường),
  bit1 `blocks_light` (chắn sáng), bit2 `dim_light` (chắn 40% khi sát ô đích), bit3 `movable` (hộp).
- **Ánh sáng Cổ điển (đã khớp bản gốc ở màn 0):** `core/light_field.gd` chuyển nguyên `method_151/152`, đặt hàng
  trước cột như bản gốc (`field_228[0]` = y). `dir` của đèn trùng mã hướng đi (1 phải, 2 xuống, 3 trái, 4 lên).
  Test so sánh: 10 trạng thái trên tuyến đi màn 0, 254 ô sàn mỗi trạng thái, lệch 0 ô.
- **Mất năng lượng trong tối theo thời gian thực** (không theo lượt, `method_97`): chờ 2000 + ngẫu nhiên 0..999 ms
  rồi −1, quay lại tối sau khi ra sáng thì 800 ms. Năng lượng tối đa mặc định 4 (`field_152`).
- **Cờ `on_action` (128):** sự kiện chạy khi vào màn (ví dụ #11 màn 0: cảnh mở đầu, 3 câu thoại hướng dẫn). M2 cài.
- Còn lại: nến mờ dần sau mỗi 2 bước, đèn tường cần bóng đèn (tính riêng từng màn), công tắc, quái không vào vùng sáng (M2).

## 5. Cơ chế ánh sáng Nâng cao (`rules_enhanced.gd`)

| Cơ chế | Luật |
|---|---|
| Cường độ | Mất máu theo độ sáng ô: 0 mất nhanh, 1–2 mất chậm, từ 3 trở lên không mất |
| Bóng đổ | Tính theo tầm nhìn trên lưới (shadowcasting) từ mỗi nguồn sáng; tường, hộp, đồ cao chắn sáng; ô phía sau bị tối |
| Nhiên liệu | Đèn lồng tốn dầu và đèn pin tốn pin theo số bước; hết thì tắt; bình dầu và pin đặt thêm trong `data_enhanced` |
| Chập chờn | Đèn hỏng tắt/bật ngẫu nhiên có chu kỳ; kịch bản có lệnh làm đèn chập chờn; khi tắt, ô đó tính là tối |
| Gương | Đồ vật mới, đẩy xoay được; tia đèn pin đổi hướng 90°; tia chạm "bộ thu sáng" thì kích hoạt sự kiện |
| Ánh sáng màu | Vật phẩm đèn UV; ô, ký hiệu, lối đi ẩn chỉ hiện và đi được khi có ánh UV chiếu tới |

`data_enhanced/levels/NN.json` chỉ **thêm hoặc ghi đè** đồ vật, sự kiện, nguồn sáng lên dữ liệu gốc.
Không file bổ sung nào được sửa `data/`.

## 6. Tầng hình ảnh (`view/`, `ui/`)

- **Dựng màn:** sàn là mặt phẳng, tường là khối cao 2,5 m, đồ vật là mô hình hoặc khối tạm, đặt theo ô.
  Ban đầu dùng texture phóng to từ ô gạch gốc, sau thay bằng texture vẽ mới.
- **Nhân vật:** giai đoạn đầu là khối tạm (capsule) mang ảnh sprite gốc. Sau đó thay bằng mô hình `.glb`
  với các động tác đứng, đi, đẩy, cầm đèn, chết. Hướng quay theo hướng đi.
- **Ánh sáng:** môi trường gần như tối hẳn, có sương. Mỗi nguồn sáng của `core` tương ứng một đèn Godot, có bán kính
  khớp với số ô sáng. Bóng đổ của Godot bật để hình khớp với luật bóng đổ ở chế độ Nâng cao.
- **UI:**
  - Hội thoại hiển thị chân dung cắt từ ảnh concept.
  - Chữ lấy từ `strings_vi.json` / `strings_en.json`, dùng font hỗ trợ tiếng Việt (Be Vietnam Pro hoặc Noto Serif).
  - Phím theo kiểu PC giống bản hiện tại: WASD/mũi tên, Enter/Space/E/F, Esc, Tab/I, M.

## 7. Dữ liệu và công cụ

`tools/export_data.py` sinh lại toàn bộ `data/` từ file gốc và phải chạy lại được nhiều lần cho cùng kết quả.
Sửa màn bằng `viewer.html` rồi xuất lại là game mới nhận. Mỗi lần xuất có kiểm tra: đủ 19 màn, đủ 258 chuỗi
mỗi ngôn ngữ, mọi file đọc hết đến byte cuối (giống các assert đang có trong `df2_decode.py`).

## 8. Kiểm thử

- **Test luật** (`tests/run.gd`, headless): nạp một màn, đưa chuỗi lệnh, so vị trí, máu, cờ, túi đồ với kết quả mong đợi.
- **Test so sánh với bản gốc (chế độ Cổ điển):** mở rộng `df2_desktop\test\AutoPlay` để ghi lại vị trí, máu, màn,
  cờ sau mỗi phím bằng reflection lên lớp `d`. Chạy cùng chuỗi phím trên `core` rồi so từng bước.
  Màn chỉ được coi là xong khi khớp.
- **Test giải được (chế độ Nâng cao):** mỗi màn có một chuỗi lệnh đi hết màn, chạy tự động mỗi lần sửa luật
  hoặc sửa file bổ sung.

## 9. Mốc thực hiện

| Mốc | Nội dung | Xong khi |
|---|---|---|
| M1 | Xuất dữ liệu; core Cổ điển đủ cho màn 0; dựng 3D bằng hình tạm; hội thoại; chơi được màn 0 | Đi hết màn 0 như bản gốc, test so sánh màn 0 khớp |
| M2 | Đủ 31 lệnh kịch bản, 19 màn Cổ điển, bản đồ thành phố, menu, lưu game, nhạc OGG | Test so sánh khớp cả 19 màn |
| M3 | Hình ảnh: mô hình 3D nhân vật, shader tranh vẽ, texture tường/sàn, chân dung, cảnh cắt | Duyệt bằng mắt |
| M4 | 6 cơ chế Nâng cao và file bổ sung cho từng màn | Test giải được qua cả 19 màn Nâng cao |
| M5 | Xuất .exe Windows, tối ưu, sửa lỗi | Chạy được trên máy khác không cần cài gì |

Kế hoạch chi tiết viết cho từng mốc, bắt đầu từ M1.

## 10. Rủi ro

| Rủi ro | Cách xử lý |
|---|---|
| Luật dịch ngược sai lệch với bản gốc | Test so sánh từng bước với bản gốc đang chạy được |
| Mô hình 3D từ ảnh AI không đồng nhất | Dùng khối tạm đến M3; mỗi nhân vật duyệt riêng trước khi gắn động tác |
| Cơ chế Nâng cao làm màn không giải được | Chế độ Cổ điển luôn còn; màn Nâng cao có test giải được |
| Ý nghĩa bit trong `tile_props` chưa rõ | Đã xác nhận ở M1 (mục 4) |
