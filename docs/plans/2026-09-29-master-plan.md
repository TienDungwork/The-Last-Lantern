# The Last Lantern II 2.5D: Kế hoạch tổng (M1–M5)

Thiết kế gốc: `docs/specs/2026-09-29-lantern-godot-design.md`. Kế hoạch chi tiết từng bước của mốc 1:
`docs/plans/2026-09-29-m1-vertical-slice.md`. Mỗi mốc sau sẽ có kế hoạch chi tiết riêng khi mốc trước xong.

Người đọc được giả định là lập trình viên giỏi nhưng **chưa biết gì về game này và Godot**.

---

## 0. Bức tranh chung

| Mốc | Kết quả nhìn thấy được | Ước lượng |
|---|---|---|
| M1 | Chơi được màn 0 (Quán rượu) trong Godot với hình tạm: đi, ánh sáng, nhặt Note 1, hội thoại có chân dung | 1–2 tuần |
| M2 | Đủ 19 màn ở chế độ Cổ điển, bản đồ thành phố, menu, lưu game, nhạc, song ngữ | 3–4 tuần |
| M3 | Hình ảnh thật: 11 nhân vật 3D từ concept, shader tranh vẽ, texture tường sàn, cảnh cắt | 3–4 tuần (phụ thuộc tốc độ làm model) |
| M4 | Chế độ Nâng cao với 6 cơ chế ánh sáng, file bổ sung cho từng màn | 2–3 tuần |
| M5 | File `.exe` chạy được trên máy khác, tối ưu, sửa lỗi | 1 tuần |

Nguyên tắc xuyên suốt:

1. `core/` không biết gì về 3D. Mọi thứ trong `core/` test được bằng `godot --headless`.
2. Chế độ Cổ điển được so từng bước với game gốc đang chạy (`df2_desktop`). Không khớp thì chưa xong.
3. Mỗi task nhỏ, có test, commit ngay. Không để một commit chứa nhiều thứ.
4. Không sửa `data/` bằng tay. Muốn đổi nội dung thì sửa file gốc rồi xuất lại.

---

## 1. Kho kiến thức về game gốc (đọc trước khi làm)

### 1.1 Cốt truyện và 19 màn

Nhân vật chính là **Daniel Hale**, thám tử ở thị trấn Ashwood. Vợ Susan đã chết, con gái Clara mắc bệnh lạ từ
bệnh viện. Các tu sĩ áo đỏ nói đang tìm thuốc chữa nhưng thật ra đang biến người bệnh thành sinh vật sợ ánh sáng.
Hale phải tìm **6 mảnh chìa khóa hầm mộ** từ các "người giữ chìa khóa", ghép lại để mở lối vào tu viện bí mật và
cứu dân thị trấn. Kết: Clara còn sống nhưng đã sợ ánh sáng.

| Màn | File `.dat` | Tên (chuỗi số) | Vai trò trong truyện |
|---|---|---|---|
| 0 | ci | Bar (211) | Mở đầu, hướng dẫn: ánh sáng, hộp, đẩy kéo, đèn pin, cửa cơ quan |
| 1 | cj | Library (212) | Lấy bản đồ thành phố, lịch sử Ashwood |
| 2 | ck | Museum (213) | Museum chief giao nhiệm vụ tìm 6 mảnh chìa khóa |
| 3 | cl | Shop (214) | Người bán hàng, mua/đổi đồ |
| 4 | cm | Graveyard (215) | Nghĩa địa |
| 5 | cn | Forbidden graveyard (216) | Chỉ vào được khi có "Combined grave key", cận cuối game |
| 6 | co | Hospital (217) | Nguồn dịch bệnh |
| 7 | cp | Electricity center (218) | Cầu chì, đèn hẻm |
| 8 | cq | Benjamin's house (219) | Ghi chú của Benjamin |
| 9 | cr | School (220) | Principal giao mảnh chìa khóa |
| 10 | cs | Sheriff's office (221) | Tu sĩ, áo choàng cải trang, sàn trơn xà phòng |
| 11 | ct | City cellar (222) | Mảnh chìa khóa giấu trong hầm |
| 12 | cu | Morgue (223) | Cải trang đi cùng tu sĩ tới tu viện |
| 13 | cv | Secret monastery (224) | Gặp Clara, kết |
| 14 | cw | Ashwood streets (225) | Khu trung tâm nối các màn, **game tự lưu ở đây** |
| 15 | cx | Benjamin's front yard (226) | Sân trước nhà Benjamin |
| 16 | cy | (Bar, 211) | Hồi tưởng/cảnh mở đầu trong quán |
| 17 | cz | (Shop, 214) | Phòng nhỏ trong cửa hàng |
| 18 | da | Warp room (227) | Phòng dịch chuyển (bí mật) |
| 19 | db | Bản đồ thành phố | Không phải màn, là màn hình bản đồ (bitmask 1 bit/ô) |

Toàn bộ lời thoại nằm ở `darkest_fear_2_grim_243556\text_English.txt` và `text_TiengViet.txt` (258 chuỗi).

### 1.2 Cơ chế gốc (danh sách đầy đủ để không bỏ sót)

- Di chuyển theo ô, 4 hướng: 1 phải, 2 xuống, 3 trái, 4 lên.
- **Ánh sáng là cơ chế trung tâm:** mỗi ô có độ sáng 0..7. Ở ô tối thì mất năng lượng. Quái không vào vùng sáng.
- Nguồn sáng (trường `type` trong dữ liệu): 0 đèn lồng (mang được), 1 đèn pin (mang được, chiếu một hướng, dài),
  4 đèn tường (cần bóng đèn), 5 và 6 đèn chiếu hướng cố định. Còn `on`, `radius` 0..15, `dir`.
  Ý nghĩa chính xác của từng loại phải xác nhận bằng test so sánh (M1, Task 13).
- Nến: mờ dần sau mỗi 2 bước. Đèn pin: dùng pin (`field_275`, 99 = vô hạn khi nhập mã thưởng).
- Bóng đèn: nhặt từ đèn tường sáng, lắp vào đèn tường tối. Số bóng tính riêng theo màn.
- Công tắc đèn: đi vào để bật/tắt.
- Hộp: đẩy; đẩy vào vật cố định thì kéo. Cửa cơ quan mở khi có hộp, nguồn sáng hoặc người đứng lên ô kích hoạt.
- Cửa khóa: cần chìa (Pub key, School key, Cellar key…). Cửa "phải giết quái trước".
- 34 vật phẩm (`ITEM_NAME` trong `tools\df2_decode.py`), túi đồ, trang bị một món.
- Quái, đạn (op 14), tu sĩ đuổi theo, cải trang bằng áo choàng, 2 boss (SPECIAL 2/8/10/12).
- Kịch bản sự kiện: 31 lệnh (`disasm` trong `df2_decode.py`). Cờ sự kiện: repeat, active, 4 hướng vào, by_actor, on_action.
- Bộ đếm (op 18), hẹn giờ (op 24), bộ đếm hộp trên vùng (op 28).
- Bản đồ thành phố: điểm đánh dấu (op 4/5), mở ô bản đồ (op 15), đi tới màn.
- Kết chương với nhạc và các đoạn chữ (op 13). Một mini game (op 12).
- 18 bánh muffin ẩn, phần thưởng khi đủ: mã áo choàng 7825537. Thời gian chơi (`field_188`).
- Lưu game (định dạng ở `class_10.method_112/114`), chọn ngôn ngữ, bật tắt nhạc.

### 1.3 Dữ liệu và công cụ đã có

| Có sẵn | Ở đâu |
|---|---|
| Bộ giải mã `.dat`, `l`, `r`, `dc.dat`, `db.dat` | `tools\df2_decode.py` |
| 19 màn dạng JSON + text dễ đọc | `darkest_fear_2_grim_243556\decoded\` |
| Bảng 435 khung hình → file PNG | `decode_frames` trong `df2_decode.py` |
| Code Java dịch ngược (tham khảo luật) | `darkest_fear_2_grim_243556\src\class_10.java` (lõi), tên gốc ghi ở comment `$VF: renamed from` |
| Game gốc chạy được trên PC + công cụ bấm phím tự động | `df2_desktop\` và `df2_desktop\test\AutoPlay.java` |
| Ảnh concept 11 nhân vật | `img\image.png` |

Thuộc tính ô (từ `dc.dat`, bảng `tile_props`, đã xác nhận trên màn 0):

| Bit | Tên trong dự án | Ý nghĩa | Chỗ dùng trong code gốc |
|---|---|---|---|
| bit0 | `solid` | Không đi qua được | `field_200`, va chạm khi đi |
| bit1 | `blocks_light` | Chắn sáng hoàn toàn | `field_201`, hàm `method_152/153` |
| bit2 | `dim_light` | Chắn sáng một phần (40%) khi ở ngay cạnh | `field_202` |
| bit3 | `movable` | Hộp, đẩy được | `movable_object` |

Ô có giá trị `< 8` là sàn; giá trị `>= 8` là vật thể, khung hình = giá trị − 8.

---

## 2. M1: Bản thử màn 0

Kế hoạch chi tiết từng bước với code và test: `docs/plans/2026-09-29-m1-vertical-slice.md`.

Tóm tắt các task:

| # | Task | Kết quả |
|---|---|---|
| 0 | Cài Godot 4 bằng winget, tạo `project.godot`, bộ chạy test headless | `godot --headless -s tests/run.gd` in `0 failed` |
| 1 | `tools/export_data.py` sinh `data/` | 19 file màn, `tiles.json`, 2 file chuỗi, `citymap.json`, `frames.json`, copy PNG |
| 2 | `core/level_data.gd` đọc JSON | test: màn 0 là 19×22, 19 đèn, 78 sự kiện, start (6,4) |
| 3 | `core/grid_state.gd`: trạng thái, va chạm | test: sàn đi được, tường (0x38) không |
| 4 | Di chuyển + kích hoạt sự kiện theo hướng vào | test: đi phải từ (6,4) tới (7,4); vào ô sự kiện thì sự kiện chạy |
| 5 | `core/light_field.gd`: độ sáng từng ô (chuyển từ `method_152/153`) | test: cạnh đèn sáng, xa đèn tối, sau tường tối |
| 6 | `core/script_vm.gd`: các lệnh màn 0 cần | test: đi vào (5,3) nhặt Note 1, hiện chuỗi 228 rồi 7, tắt sự kiện 21–23 |
| 7 | `core/rules_classic.gd`: mất năng lượng trong tối, nhặt/đặt đèn | test: đứng ô tối N lượt thì năng lượng giảm |
| 8 | `view/level_builder.gd`: sàn + tường 3D từ grid | ảnh chụp cảnh màn 0 |
| 9 | `view/actor.gd` + `view/camera_rig.gd`: nhân vật tạm trượt giữa ô, camera bám | ảnh chụp |
| 10 | `view/lighting.gd`: đèn Godot bám `light_field` | ảnh chụp: vùng sáng khớp ô sáng |
| 11 | `ui/dialog.gd`: hộp thoại có chân dung, chữ tiếng Việt | ảnh chụp câu thoại 228 |
| 12 | `game.gd`: nối core ↔ view ↔ ui, InputMap phím PC | chơi được màn 0 bằng tay |
| 13 | Bộ so sánh với bản gốc: mở rộng `AutoPlay` ghi trạng thái từng bước, script so | tuyến đi cố định trong màn 0 khớp vị trí và năng lượng |
| 14 | Nghiệm thu M1, cập nhật docs | checklist đủ |

---

## 3. M2: Đủ 19 màn Cổ điển

### 3.1 Công việc

1. **Bộ chạy kịch bản đầy đủ 31 lệnh.** Làm theo thứ tự tần suất dùng trong 19 màn: 21, 2, 27, 7, 20, 8, 26, 11, 29, 22,
   9, 10, 30, 16, 23, 6, 4, 15, 18, 19, 24, 14, 12, 28, 25, 3, 13, 17, 5, 1. Mỗi lệnh: đọc `method_209` trong
   `class_10.java`, viết test từ một sự kiện thật trong dữ liệu, rồi cài.
2. **Diễn viên (ACTOR_CONFIG, op 27):** tu sĩ, quái, NPC, boss. Đọc `field_228`/`field_229` trong `class_10`.
   Quái đuổi theo khi ở ngoài vùng sáng; tu sĩ đuổi khi không cải trang.
3. **Đạn (op 14) và va chạm.**
4. **Hộp:** đẩy, kéo, đếm hộp trên vùng (op 28), kích hoạt cửa cơ quan.
5. **Chìa khóa, cửa khóa, các chuỗi 239–243, 250–252.**
6. **Bóng đèn theo màn, nến mờ dần, pin.**
7. **Bản đồ thành phố:** đọc `citymap.json`, điểm đánh dấu, đi tới màn (đọc `method_171` và phần xử lý bản đồ).
8. **Chuyển màn:** TELEPORT, exit_door, giữ trạng thái đã đổi của màn (cờ `persist` trong SET_TILE/ENABLE/DISABLE).
9. **Lưu game** JSON vào `user://save.json`. Tự lưu khi vào màn 14 và ở các điểm gốc gọi `method_112`.
10. **Menu:** Trò chơi mới, Chơi tiếp, Cài đặt (âm thanh, ngôn ngữ, chế độ Cổ điển/Nâng cao), Trợ giúp, Giới thiệu, Thoát
    (có hỏi lại). Logo, màn tiêu đề, chọn ngôn ngữ lần đầu.
11. **Kết chương (op 13), cảnh cắt (SPECIAL 15/16), mini game (op 12):** đọc `class_4`/`class_11` để biết nội dung.
12. **Nhạc:** chuyển 7 file `.mid` sang `.ogg` bằng FluidSynth + SoundFont miễn phí (GeneralUser GS), lệnh:
    `fluidsynth -ni GeneralUser.sf2 input.mid -F out.wav -r 44100` rồi `ffmpeg -i out.wav out.ogg`. Op 1 PLAY_MUSIC
    đổi nhạc theo số.
13. **Muffin, mã thưởng, thời gian chơi.**
14. **Test so sánh cả 19 màn:** mỗi màn một tuyến đi ghi từ bản gốc bằng `AutoPlay` (dùng cách vào thẳng màn qua
    file save như `df2_desktop\test\levels.ps1`), chạy lại trên `core`, so vị trí, năng lượng, túi đồ, cờ sự kiện.

### 3.2 Xong khi

- 19 màn đi hết được bằng tay ở chế độ Cổ điển.
- Test so sánh khớp cho 19 tuyến đi.
- Lưu rồi mở lại đúng chỗ.

---

## 4. M3: Hình ảnh thật

### 4.1 Quy trình làm nhân vật 3D từ ảnh concept (làm cho từng nhân vật)

Cần cài: **Blender** (`winget install BlenderFoundation.Blender`), tài khoản **Meshy** hoặc **Tripo** (tạo mô hình từ ảnh),
tài khoản **Mixamo** (miễn phí, gắn xương và động tác).

Bước 1. **Tách ảnh concept.** Cắt từng nhân vật trong `img\image.png` ra file riêng `assets/concepts/<ten>.png`,
nền trong suốt hoặc trắng phẳng, cả người, không bị cắt chân. Đặt tên theo vai: `hale`, `clara`, `bartender_jack`,
`daniel_boy`, `susan`, `museum_chief`, `librarian`, `principal`, `sheriff`, `beggar`, `hermit`.
Nếu công cụ tạo 3D cho phép nhiều góc nhìn, tạo thêm ảnh nhìn nghiêng và sau lưng bằng AI với cùng mô tả nhân vật,
sẽ cho mô hình đúng hơn.

Bước 2. **Ảnh → mô hình 3D** (Meshy "Image to 3D" hoặc Tripo). Cài đặt khuyên dùng: số mặt 15.000–30.000,
texture 1024 hoặc 2048, bật "PBR" nếu có, dáng đứng thẳng, hai tay hơi dang (A-pose) để gắn xương dễ.
Tải về **FBX** (cho Mixamo) và **GLB** (để xem nhanh). Kiểm tra: không thủng lưới ở tay chân, texture không lem.
Mô hình xấu thì tạo lại, đừng sửa tay.

Bước 3. **Gắn xương ở Mixamo.** Upload FBX → Auto-Rigger → đặt 6 điểm (cằm, hai cổ tay, hai khuỷu, hai đầu gối, háng)
→ chọn "Standard skeleton" → Next. Tải về nhân vật ở T-pose: định dạng FBX Binary, "With Skin".

Bước 4. **Tải động tác từ Mixamo** cho đúng nhân vật đó (giữ nhân vật đang chọn, tìm động tác, tải FBX
"Without Skin", 30 fps, không giảm keyframe). Danh sách tối thiểu:

| Tên trong game | Động tác Mixamo | Lặp |
|---|---|---|
| `idle` | Idle | có |
| `walk` | Walking (bật "In Place") | có |
| `push` | Pushing (In Place) | có |
| `pickup` | Picking Up | không |
| `carry_idle`, `carry_walk` | Carrying Idle / Carry Walk (In Place) | có |
| `hurt` | Hit Reaction | không |
| `death` | Dying | không |

Quái vật và tu sĩ: thêm `attack`, `chase` (Zombie Walk / Running).

Bước 5. **Ghép trong Blender thành một file GLB.**
1. File → Import → FBX nhân vật T-pose, Scale 0.01 (Mixamo dùng cm), bật "Automatic Bone Orientation".
2. Với mỗi FBX động tác: Import với cùng cài đặt, chọn Armature của động tác, vào Dope Sheet → Action Editor,
   đổi tên Action theo bảng trên, rồi trong Action Editor gán action đó cho Armature nhân vật (dùng nút "Push Down"
   để đưa vào NLA của nhân vật). Xóa Armature động tác thừa.
3. Chọn Armature nhân vật + mesh → File → Export → glTF 2.0: định dạng `.glb`, Include "Selected Objects",
   Animation: bật "Group by NLA Track" hoặc export tất cả actions, "Apply Modifiers" bật, "+Y Up" bật.
4. Lưu vào `assets/actors/<ten>/<ten>.glb`.

Bước 6. **Import vào Godot.** Bấm đúp file `.glb` trong FileSystem → Advanced Import Settings:
- Root Type: `Node3D`. Scale: chỉnh sao cho Hale cao ~1,8 đơn vị (1 đơn vị = 1 m = 1 ô).
- Tab Animations: `idle`, `walk`, `push`, `carry_idle`, `carry_walk` đặt Loop Mode = Linear.
- Tab Materials: "Extract Materials" ra `assets/actors/<ten>/materials/` để thay bằng shader tranh vẽ.
- Bấm Reimport. Kéo `.glb` vào scene `view/actor.tscn`, nút `AnimationPlayer` phải liệt kê đủ tên động tác.

Bước 7. **Kiểm tra trong game:** chạy màn 0, đi 4 hướng, nhặt đèn, đứng trong tối, chết. Ghi lại video ngắn hoặc ảnh.

### 4.2 Shader tranh vẽ

Một `ShaderMaterial` dùng chung cho nhân vật và môi trường, tham số: màu albedo, số bậc sáng (3), độ dày viền,
texture vân giấy. Cấu trúc:
- Ánh sáng phân bậc: lấy `NdotL`, lượng tử hóa thành 3 mức.
- Viền: mesh thứ hai lật mặt (inverted hull) phóng theo normal, màu sẫm.
- Vân giấy: nhân albedo với texture nhiễu ở tọa độ màn hình, cường độ 10–15%.
- Bóng đổ vẫn dùng bóng thật của Godot.

### 4.3 Môi trường

- Texture tường và sàn cho 5 bộ gạch (bj, bg, bk, bh, bi tương ứng quán rượu, thư viện, cửa hàng…): vẽ tay
  hoặc tạo bằng AI theo cùng phong cách, 512×512, liền mạch (tileable).
- Đồ vật: dựng mô hình thấp đa giác cho ~40 loại vật thể xuất hiện nhiều nhất (bàn, ghế, quầy, hộp, đèn tường,
  công tắc, cửa, bia mộ…). Các vật còn lại giữ billboard sprite gốc phóng to.
- Chân dung hội thoại: cắt từ concept, 256×256. Cảnh cắt: giữ ảnh gốc `aw`…`bd` phóng to bằng AI hoặc vẽ lại.
- Hiệu ứng: hạt bụi trong luồng đèn pin, sương thấp, lửa nến.

### 4.4 Xong khi

- 11 nhân vật + tu sĩ + quái có mô hình, chạy đủ động tác trong game.
- Mọi màn nhìn được, không còn khối hộp trắng.
- Ảnh chụp từng màn được duyệt.

---

## 5. M4: Chế độ Nâng cao

### 5.1 Định dạng file bổ sung `data_enhanced/levels/NN.json`

```json
{
  "level": 0,
  "add_lights":   [{"x": 8, "y": 13, "type": 0, "on": 0, "radius": 2, "dir": 0, "fuel": 120}],
  "set_lights":   [{"id": 3, "flicker": {"period_turns": 6, "off_turns": 2}}],
  "add_objects":  [{"x": 9, "y": 12, "kind": "mirror", "facing": 1},
                   {"x": 9, "y": 6,  "kind": "light_receiver", "event": 90}],
  "add_items":    [{"x": 7, "y": 9, "item": "oil_flask", "amount": 60}],
  "hidden_tiles": [{"x": 4, "y": 6, "tile": 0, "reveal_with": "uv"}],
  "add_events":   [{"id": 90, "x": 9, "y": 6, "w": 1, "h": 1, "flags": 3,
                    "commands": [{"op": 101, "args": [1, 0]}]}]
}
```

Lệnh kịch bản mới (op ≥ 100): 100 `FLICKER light on/off`, 101 `OPEN_TRIGGER_DOOR id`, 102 `SET_FUEL light value`,
103 `UV_REVEAL x y`.

### 5.2 Luật từng cơ chế (trong `rules_enhanced.gd`, kế thừa `rules_classic.gd`)

| Cơ chế | Luật cụ thể | Test |
|---|---|---|
| Cường độ | Mỗi lượt: độ sáng 0 → −3 năng lượng; 1–2 → −1; ≥3 → 0 | 3 test theo 3 mức |
| Bóng đổ | `light_field` dùng shadowcasting đối xứng từ mỗi nguồn; ô `solid` hoặc `movable` chắn; ô sau đó độ sáng 0 | Đèn – hộp – ô sau hộp tối; bỏ hộp thì sáng |
| Nhiên liệu | Đèn lồng −1 dầu/lượt khi đang cầm và bật, đèn pin −1 pin/lượt; về 0 thì `on=0`; bình dầu +60, pin +40 | Đếm lượt tới khi tắt |
| Chập chờn | Đèn có `flicker`: tắt `off_turns` lượt sau mỗi `period_turns`; op 100 ép tắt/bật | Chuỗi trạng thái theo lượt |
| Gương | Vật `mirror` có `facing` 1–4; tia đèn pin tới gương đổi hướng 90° theo `facing`; đẩy gương xoay `facing`; tia tới `light_receiver` thì chạy `event` | Tia qua 2 gương tới bộ thu |
| Ánh sáng màu | Vật phẩm `uv_lamp` (type 7); ô trong `hidden_tiles` chỉ đi được và hiện khi có UV chiếu tới | Không UV: solid; có UV: đi được |

### 5.3 Chỉnh 19 màn

Với mỗi màn: chơi ở Nâng cao, ghi lại chỗ kẹt, thêm dầu/pin/gương/UV vào file bổ sung, viết tuyến đi hết màn thành
test `tests/enhanced/level_NN.gd`. Không sửa `data/`.

### 5.4 Xong khi

- 6 cơ chế có test riêng.
- 19 tuyến đi Nâng cao chạy xanh.
- Chuyển chế độ trong Cài đặt không làm hỏng save (save ghi kèm chế độ).

---

## 6. M5: Đóng gói

1. Godot → Project → Export → Windows Desktop, tải export templates cùng phiên bản.
2. Bật "Embed PCK", icon từ `df2_desktop\icon.png`, tên `TheLastLantern2-2.5D.exe`.
3. Tắt console, đặt renderer Forward+ với fallback Mobile cho máy yếu (Project Settings → Rendering → Renderer).
4. Kiểm tra trên máy khác không có Godot: chạy, lưu, mở lại, toàn màn hình, độ phân giải 1366×768 và 1920×1080.
5. Kích cỡ mục tiêu < 300 MB. Nén texture VRAM Compressed.
6. Ghi `CHANGELOG.md` và cập nhật `HUONG_DAN_SUA_GAME.md` ở thư mục gốc: thêm mục về bản Godot.

---

## 7. Kiểm thử xuyên suốt

| Loại | Cách chạy | Khi nào |
|---|---|---|
| Test luật (`tests/test_*.gd`) | `godot --headless -s tests/run.gd` | Mỗi commit |
| So sánh với bản gốc | `df2_desktop\test\parity.ps1 <màn>` sinh trace, `godot --headless -s tests/parity.gd` so | Mỗi khi đụng `core/` |
| Tuyến đi hết màn (Nâng cao) | `tests/enhanced/*.gd` | Mỗi khi đụng `rules_enhanced.gd` hoặc `data_enhanced/` |
| Ảnh chụp cảnh | `godot --path . tools/snap.gd --level N` xuất `snap/level_N.png` | Sau mỗi task hình ảnh |
| Chơi tay | Chạy `game.tscn` | Cuối mỗi mốc |

---

## 8. Rủi ro và cách né

| Rủi ro | Cách né |
|---|---|
| Godot không chạy được trong môi trường tự động (không có GPU) | Test luật chỉ dùng `--headless`; ảnh chụp dùng `--rendering-driver opengl3`, nếu vẫn không được thì người dùng chạy tay và gửi ảnh |
| Luật dịch ngược sai | Test so sánh từng bước với bản gốc; tuyệt đối không tin `src\` khi chưa so |
| Mô hình AI xấu hoặc không nhất quán | Tạo nhiều lần, chọn; duyệt từng nhân vật trước khi gắn xương; giữ khối tạm để game luôn chạy |
| Mixamo đổi chính sách hoặc ngừng | Thay bằng Meshy Animate hoặc rig bằng Rigify trong Blender |
| Nâng cao làm màn kẹt | File bổ sung + test tuyến đi; Cổ điển luôn còn |
| Dự án kéo dài | Mỗi mốc cho ra bản chơi được; M1 và M2 là bản có giá trị ngay cả khi dừng ở đó |
