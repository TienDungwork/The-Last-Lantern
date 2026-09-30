# Chọn nhân vật: Daniel hoặc Clara (thiết kế)

Ngày: 2026-09-30. Trạng thái: đang làm. Đã có: menu chọn nhân vật, nâng cấp, chuỗi ghi đè + hoán đổi chân dung,
`RulesClara` (ngưỡng đau theo mảnh chìa, bỏng, virus + hóa quái khóa chiêu, hồi ở vùng mờ, áo không giới hạn sau Boss 2),
bắt sống, Hòa vào bóng tối, Mắt đêm, che đèn khi cầm, chặn flash, không hồi ở op 3/25, Nuốt sáng, thanh virus
(`tests/unit/test_rules_clara.gd`). Còn: sinh vật vây khi hóa quái, Gọi bóng, Bức tường lửa, Đèn đôi, sự kiện riêng
`data_enhanced/clara/levels/` (6 lời giải riêng, câu loại E), đoạn phim kết thật, Daniel NPC ở màn 13. Game chỉ còn một chế độ; chạy trên luật chính `RulesMain`
(máu 100, mất theo độ sáng ô — xem ghi chú đổi hướng ở mục M4 của `docs/plans/2026-09-29-master-plan.md`).

## 1. Mục tiêu

Khi bắt đầu trò chơi mới, người chơi chọn **Daniel Hale** hoặc **Clara Hale**.
Cả hai đi **cùng 19 màn, cùng cốt truyện**, phần lớn câu đố chung; khác lời thoại, chân dung, bộ kỹ năng
và **6 điểm lời giải riêng** kiểu Resident Evil 1 (mục 2.5).

- Nền là luật chính `RulesMain`. Test so sánh với bản gốc gọi `RulesClassic` trực tiếp nên không bị ảnh hưởng.
- Daniel = `RulesMain` + 3 kỹ năng; kỹ năng không bắt buộc để giải màn.
- Clara = `RulesClara extends RulesMain` (ghi đè `_drain`: mất máu theo vùng mờ) + kỹ năng + bắt sống.
- `data/levels/` không sửa. Khác biệt nằm ở file ghi đè chuỗi, `data_enhanced/clara/` và các lớp luật trên.
- Mô hình kiểu **Resident Evil 1**: hai tuyến là hai phiên bản của cùng một đêm, không cần ăn khớp với nhau
  (cả hai đều nhặt đủ 6 mảnh chìa khóa). Hoàn thành một tuyến bất kỳ thì mở khóa **đoạn phim kết thật** (mục 2.6).

## 2. Cốt truyện tuyến Clara

### 2.1 Dựa trên văn bản gốc phần 2

| Câu | Sự thật gốc | Dùng cho tuyến Clara |
|---|---|---|
| 171 | Daniel và Clara sống sót vụ bệnh viện Ashwood 5 năm trước | Clara mang virus từ đó |
| 172, 173 | Tu viện cách ly mọi bệnh nhân; hôm qua tuyên bố tất cả đã chết | Clara là một bệnh nhân; cả thành phố tin cô đã chết |
| 2 | Jack: "Tôi rất tiếc về chuyện của Clara" | NPC sững sờ khi thấy "người chết" trở về |
| 33 | Con trai ông lao công trốn thoát khỏi tu viện | Tiền lệ: bệnh nhân trốn ra được |
| 105 | Tu sĩ muốn đi lại dưới ánh sáng ban ngày | Clara là **vật thí nghiệm thành công nhất**: virus biến đổi trong cô mà cô không chết |
| 119 | Tấm biển "Vật thí nghiệm" trong tu viện | Nơi Clara từng bị giam |
| 120, 121 | Cuối game Clara đã sợ ánh sáng | Ngưỡng ánh sáng gây đau giảm dần theo tiến độ (mục 6) |

### 2.2 Tuyến Clara

- **Mở đầu:** Clara trốn khỏi tu viện, tỉnh dậy trong thành phố đang tin cô đã chết. Mẩu giấy Jack để lại
  cho bố (câu 228) cho biết bố đã tới trung tâm thành phố.
- **Động lực:** cứu những bệnh nhân từng bị giam cùng (cô biết họ còn sống) trước khi bọn tu sĩ bắt cô về.
  Tìm bố là mục tiêu phụ. Không ai cứu ai.
- **Nỗi sợ:** Daniel sợ bóng tối; Clara sợ chính mình — càng đi sâu, cô càng giống thứ quái vật bố cô đang chống lại.
- **NPC:** phản ứng với "người chết trở về". Ví dụ thủ thư (48): "Clara Hale? Lẽ ra cô phải chết rồi mới đúng."
- **Tu sĩ:** thấy Clara thì **bắt sống** (chúng cần cô), không giết (mục 6).
- **Cảnh cuối (màn 13):** Daniel cũng vừa cải trang lẻn vào; hai bố con gặp lại ngang hàng.
  - 120 (Clara, né ánh đèn của bố): "Bố.. hạ đèn xuống giúp con."
  - 121 (Daniel): "Mắt con.. sáng lên trong bóng tối. Chúng đã làm gì con trong này?"
  - 116 (Daniel): "Người dân bị đưa tới ngôi làng của các tu sĩ bóng tối. Bố con mình phải tìm ra họ trước khi quá muộn!"

### 2.3 Hồ sơ Clara

- **Tuổi:** ~16 (5 năm trước ở bệnh viện còn là đứa bé gọi "Bố ơi!").
- **Ngoại hình:** da nhợt, áo bệnh nhân dưới áo khoác cũ quá khổ của bố, vòng cổ tay "Vật thí nghiệm" (câu 119),
  mắt phản sáng trong tối, đèn lồng quấn vải che kín.
- **Tính cách:** ít nói, quan sát kỹ, hài hước khô (lớn lên trong bệnh viện), gan dạ nhưng tự gánh một mình.
- **Khuyết điểm:** nói dối để bảo vệ người khác; tin giữ khoảng cách là thương người.
- **Nỗi sợ:** không phải bóng tối, mà là trở thành quái vật trước mặt bố.
- **Vết thương:** câu 230 — mẹ, bác sĩ Susan Hale, là một người giữ chìa khóa. Ở tuyến Clara, hồ sơ bệnh viện
  trong mộ Susan (vật phẩm 11, màn 4) là **bệnh án của Clara**: mẹ làm việc cho tu sĩ để tìm thuốc chữa cho con.
- **Giọng:** câu ngắn, tả bằng âm thanh/mùi (giác quan ban đêm), hay nói thầm với mẹ. Daniel nói kiểu thám tử.
- **Ý nghĩa tên game:** với Daniel, đèn là che chở; với Clara, đèn là **bố** — cần nhưng không dám đứng gần.
  Vì vậy cô mang đèn che trong áo (luật mục 6).
- **Sinh vật bóng tối:** Clara nghi chúng là bệnh nhân thí nghiệm thất bại — **để ngỏ, không khẳng định**.
  Giải thích Gọi bóng; bảng thống kê tuyến Clara đổi "Quái vật đã giết" thành "Linh hồn đã giải thoát".

Hành trình: **Trốn chạy** ("mình nguy hiểm, phải tránh xa bố") → **Phát hiện** (bệnh án trong mộ mẹ) →
**Chấp nhận** (màn 11 mặc áo của chúng để trốn, nhưng hương áo làm cô choáng; Boss 2 — thứ quái chúng tạo ra để
đi dưới ánh sáng — cháy rụi trước mắt, cô hiểu mình mới là "mẫu thành công", áo thôi làm cô choáng) → **Lựa chọn** (câu 120: để bố nhìn thấy con người thật).
Các mốc gắn với **số mảnh chìa khóa** chứ không gắn với số màn, vì thứ tự vào màn qua đường phố (màn 14) là tự do.

### 2.4 Hướng dẫn chơi từng màn

Tuyến Clara dùng **đúng cửa vào/ra, đúng vật phẩm và đúng chuỗi điều kiện** của Daniel (lấy từ sự kiện trong
`data/levels/`). Khác ở: cách vượt màn theo luật ánh sáng mờ và kỹ năng, bị bắt thay vì chết, và cảnh truyện.
Đường phố (màn 14) là trung tâm; hầu hết màn có 2 cửa nối ra đường phố.

Ký hiệu: **T** = chỉ ghi đè chuỗi có sẵn; **E** = cần sự kiện/câu mới trong `data_enhanced/levels/NN.json`.

#### Hồi 1 — Trốn chạy (0 → 1 mảnh chìa khóa, ngưỡng đau 5)

| Màn (vào → ra) | Việc phải làm (chung hai tuyến) | Clara chơi khác thế nào | Cảnh truyện Clara |
|---|---|---|---|
| 16 Quán, mở đầu (Trò chơi mới → màn 0) | Không điều khiển; cảnh mở đầu 171–174, tự đi rồi ngất | — | Clara trùm mũ ngồi góc quán, **nghe lén** dân bàn về bố: 0 "Lão Hale lại la rằng tu sĩ nói dối", 1 "Con bé nhà lão chết rồi, tội nghiệp", 2 Jack: "Tôi để giấy cho Hale, bảo sáng lên trung tâm." 3: "Clara ngất trong kho quán." **T** |
| 0 Quán (→ đường phố, 2 lối) | Đọc giấy Jack; học đèn, đẩy/kéo hộp, bàn đạp, bóng đèn tường; nam châm đào chìa khóa quán dưới song sắt; mở cửa khóa | Hướng dẫn nói theo luật Clara: giữ ở rìa vùng sáng; mang đèn che trong áo, đặt xuống mới sáng. Câu đố "để đèn chiếu xuống" (#65) giải bằng đặt đèn | 175 "Clara tỉnh dậy một mình". 228 giấy gửi bố → cô biết bố còn sống, đã đi. 9: "Sáng quá thì đau mắt. Tối quá thì… có gì đó trong mình thức dậy." 170 "vài ngụm rượu" → "vài ngụm nước lạnh". **T** |
| 14 Đường phố, lần đầu | Hỏi con trai lao công (33–34); ăn mày đòi xu (36–37); thấy huy hiệu cảnh sát trưởng dưới cống (44); hẻm tối (35) | Hẻm tối (sáng 0) an toàn trước tu sĩ nhưng làm virus tăng: phải đi nhanh giữa các ô mờ | Con trai lao công là **bạn cùng xà lim**: "Clara! Cậu cũng ra được à? Bọn chúng đang lùng cậu đấy." Nhắc lời hứa quay lại cứu người. **T** |
| 1 Thư viện (↔ đường phố) | Nói với thủ thư; nhặt bản đồ, chổi, xu, ghi chú 2; công tắc đèn. Mảnh chìa khóa sau ống thông gió cần **kìm** (có ở màn 3) | Thủ thư tắt đèn: với Daniel là làm khó, với Clara là **giúp** — nhưng phòng tối hẳn làm virus tăng, phải bật lại một phần bằng công tắc | 48: "Clara Hale? Lẽ ra cô phải chết rồi mới đúng." 51: "Cô ta tắt đèn… cho mình?" Mầm nghi: thủ thư biết cô. **T** |
| 2 Bảo tàng, lần đầu (↔ đường phố) | Giám đốc giao nhiệm vụ + danh sách 6 người giữ chìa khóa; lấy mảnh của giám đốc (**mảnh 1**); chổi làm cần gạt mở cửa sau (nhớ lấy lại chổi) | Như Daniel | Giám đốc từng thấy Clara trong phòng thí nghiệm, trao nhiệm vụ như chuộc lỗi. 63: "Mẹ tôi? Mẹ mất trước khi tôi vào tu viện cơ mà…" **T** |

#### Hồi 2 — Phát hiện và Chấp nhận (mảnh 2 → 6, ngưỡng đau 5 → 4 → 3; thứ tự tự do, dưới đây là một thứ tự hợp lý)

| Màn (vào → ra) | Việc phải làm (chung hai tuyến) | Clara chơi khác thế nào | Cảnh truyện Clara |
|---|---|---|---|
| 3 Cửa hàng — **Boss 1** (↔ đường phố) | Nhặt máy ảnh, xu, **kìm**; boss xuất hiện, cửa khóa tới khi boss chết | Boss mất máu ở ô sáng ≥ 4 và không vào ô ≥ 5. Khi ngưỡng đau của Clara còn là 5, **cô đứng được ở ô sáng 4 còn boss thì không** — đặt đèn tạo vùng 4 rồi dụ boss vào (boss cần ~6,4 s liên tục ở ô >= 4, về tối thì hồi). Mẹo bẫy: Nuốt sáng làm vùng sáng 5 tụt xuống 4 → dụ boss vào → Clara chạy ra trước 8 s → đèn sáng lại, boss không bước vào ô >= 5 và không có ô < 4 để lùi, đứng cháy. Tới muộn (ngưỡng 4) thì chỉ còn mẹo bẫy: thứ tự vào màn có ý nghĩa | Boss giống một bệnh nhân khổng lồ biến dạng. Khi nó chết: "Xin lỗi… Mình sẽ quay lại vì những người còn lại." **E** |
| 17 Phòng cửa hàng (↔ đường phố) | Đổi xu lấy khúc xương / muffin | Như Daniel | 125 đổi xưng hô ("Giá rẻ đây, cô bé!"). **T** |
| 1 Thư viện (lần đầu hoặc quay lại) | Kìm mở ống thông gió → **mảnh 2** | **Riêng Clara:** chui lọt ống thông gió, không cần kìm (vẫn cần kìm cho hàng rào ra nghĩa địa) | 55: "Ống thông gió… vừa người mình. Ở xà lim mình chui mấy cái hẹp hơn thế này." **E** |
| 14 Đường phố — ăn mày | Cho xu → chổi quét rác → **mảnh 3** | Như Daniel | Ăn mày là người duy nhất đối xử với cô như mọi người: 37 "Muốn thì đưa một xu. Ai cũng thế." **T** |
| 4 Nghĩa địa (↔ đường phố; cổng lưới thép cần kìm) | Xẻng → đào mộ Susan → **mảnh 4** + hồ sơ bệnh viện; khúc xương | Nghĩa địa tối: Mắt đêm nhặt xẻng và xương không cần đèn. Ở lâu trong tối là virus tăng, nên vẫn phải mang đèn làm vùng mờ | **Mốc Phát hiện.** Hồ sơ đọc được: "Bệnh nhân: Clara Hale, 11 tuổi. Nếu tu viện có thuốc, tôi sẽ lấy được — bằng mọi giá. — S.H." 68: "Mộ mẹ. Mẹ chôn cùng bí mật… về con." **T + E** |
| 15 Sân Benjamin (đường phố ↔ nhà Benjamin) | Chó dữ chắn sân: cho khúc xương hoặc thức ăn tẩm thuốc mê | **Riêng Clara:** chó cụp đuôi lùi lại, cô đi qua không cần xương | 90: "Con chó rên lên và lùi vào góc." 91: "Nó sợ mình. Mình cũng thấy sợ mình." **E** |
| 8 Nhà Benjamin (↔ sân) | Bơm cầu hút nước bồn tắm → **xà phòng**; nói với Benjamin; ghi chú 4 | Nhà nhiều hốc đèn tường: tháo bớt bóng để tạo vùng mờ | Benjamin nhìn mắt cô trong tối và hiểu. 95: "Mắt cháu sáng lên kìa. Phải tới tu viện trước khi nó nuốt mất cháu." **T** |
| 6 Bệnh viện (↔ đường phố) | Nến; lấy ống tiêm thuốc mê, cầu chì, dao mổ; gây mê người gác nhà xác, rạch áo lấy **chìa khóa nhà xác** | Nến mờ dần sau mỗi 2 bước — với Daniel là mối lo, với Clara nến mờ là **ánh sáng lý tưởng**. **Riêng Clara:** người gác hoảng chạy, đánh rơi áo khoác có chìa khóa — không cần ống tiêm, dao mổ (dao vẫn cần ở trường học) | Nơi cô nhiễm bệnh: hồi tưởng khi vào màn: "Hành lang này… bố bế con chạy qua đây." Nhận ra ống tiêm — loại tiêm mỗi đêm trong xà lim. 83: "Xác chết biết đi! Tránh xa tôi ra!" **T + E** |
| 7 Trạm điện (↔ đường phố) | Lắp cầu chì → đèn hẻm ở đường phố bật | Bật đèn hẻm làm đường phố **sáng hơn — khó hơn cho chính Clara**; từ đây cô phải đi mép hẻm | 128 thêm: "Đèn hẻm đã bật. Không phải cho mình." **T** |
| 9 Trường học (↔ đường phố) | Dao mổ đẩy chìa khóa rơi, nam châm lấy **chìa khóa trường**; dao cắt dây → **dây thừng**; hiệu trưởng → **mảnh 5** | Như Daniel | Hiệu trưởng là **thầy của Clara**. 103: "Clara… Thầy đã biết. Thầy đã im lặng." **T** |
| 14 Đường phố — huy hiệu | Dây thừng + nam châm câu huy hiệu bẩn; xà phòng lau sạch → mã 4 số → mở bàn phím cửa | Như Daniel | 44: "Mình nhớ gương mặt này, ông từng tới tu viện." **T** |
| 10 VP cảnh sát trưởng (↔ đường phố) | Chổi hoặc dây nam châm lấy **chìa khóa hầm** sau song sắt; ghi chú 5 | Như Daniel | Thư cảnh sát trưởng có thêm dòng: "…đứa bé nhà Hale trong lồng kính. Tôi không thể tiếp tục." Clara nhận ra đó là mình. **T + E** |
| 11 Hầm ngầm (↔ đường phố, cần chìa khóa hầm) | Xô nước + xà phòng → nước xà phòng; tu sĩ xuất hiện; hắt nước → tu sĩ trượt ngã → **áo choàng tu sĩ** + **mảnh 6** | Tu sĩ thấy Clara thì **bắt về cửa vào màn**, đèn rơi tại chỗ, túi đồ còn nguyên. Hòa vào bóng tối: đứng ô sáng 0 để tu sĩ đi qua | **Mở đầu Chấp nhận.** 107: "Giọng đó… hắn trực xà lim mỗi đêm." 109 (viết lại): mặc lại đồ của chúng để trốn, nhưng hương tu viện làm cô choáng — chỉ mặc được một lúc (luật 30 s). Lần đầu áo tự cởi: 306. **T + E** |

#### Hồi 3 — Lựa chọn (đủ 6 mảnh, ngưỡng đau 3)

| Màn (vào → ra) | Việc phải làm (chung hai tuyến) | Clara chơi khác thế nào | Cảnh truyện Clara |
|---|---|---|---|
| 2 Bảo tàng, quay lại | Đặt mảnh vào khe; huy hiệu sáng làm "con mắt" tượng; câu đố 2 tia nắng; ghép → **chìa khóa hầm mộ hoàn chỉnh** | Tia nắng là ánh sáng mạnh: với ngưỡng 3, Clara phải chỉnh tượng rồi **lùi ra khỏi tia** trước khi bị đau | 58 thêm: "Nắng… mẹ ơi, con không đứng gần được nữa." 59: "Các mảnh đã ghép. Có cả mảnh của mẹ." **T** |
| 14 Đường phố — **Boss 2** | Bị boss đuổi dọc đường phố: đặt đèn đang sáng vào làn trước mặt nó, tránh cục lửa; boss chết thì đi tiếp | Cầm đèn không bỏng (che trong áo), đặt vào làn trước mặt boss thì đèn sáng. Ngưỡng đau lúc này là 3 nên đứng cạnh đèn là bỏng: **mặc áo choàng** (30 s chặn bỏng, không có tu sĩ nên đồng hồ chạy) cho lúc đặt đèn; hết áo thì đi mép ô mờ 20 s chờ mặc lại. Nuốt sáng tắt bớt đèn tường dọc phố. Gọi bóng vô dụng (màn 14 không có sinh vật) | **Mốc Chấp nhận** (khi SPECIAL 12, boss chết): 307 boss là thứ chúng tạo ra để đi dưới ánh sáng và bị ánh sáng thiêu; 308 Clara hiểu mình mới là mẫu thành công; 309 khoác áo lại, hương không còn làm cô choáng → **mở áo không giới hạn**. **E** |
| 12 Nhà xác (đường phố → nghĩa địa cấm, cần chìa khóa nhà xác) | Mặc áo choàng; tu sĩ tới và dẫn đi | Không mặc áo choàng = bị bắt, về cửa vào | 112: "Nơi chúng mang xác đi… mình từng bị đưa qua cửa này." 113: "Chúng đang nói về 'mẫu thành công đã trốn'. Là mình. Cúi đầu." **T + E** |
| 5 Nghĩa địa cấm (nhà xác → tu viện) | Tu sĩ dẫn tới lối vào (114); dùng chìa khóa hoàn chỉnh → lối vào mở (115) | Như Daniel | 114: "Clara đi giữa đoàn tu sĩ về lại nơi cô vừa trốn khỏi." 118 thêm: "Mẹ ơi, con mang mảnh của mẹ về rồi." **T** |
| 13 Tu viện (lối vào → hết game) | Giữ áo choàng (117), tránh tu sĩ tuần tra; tới gặp nhân vật còn lại → cảnh kết | Ngưỡng đau 3 cả màn. Bị bắt thì về chỗ tự lưu. **Riêng Clara:** lối tắt từ xà lim cũ (cạnh biển "Vật thí nghiệm") né đoạn tuần tra; lối chính vẫn còn. Nhân vật đứng tại ô gặp mặt (7,6) là **Daniel** | Đi qua tấm biển "Vật thí nghiệm" (119) — xà lim cũ: "Chỗ của mình. Số 7." Gặp bố: 120, 121, 116 (mục 2.2), rồi 176. **T + E** |
| 18 Phòng dịch chuyển (tùy chọn, từ góc đường phố) | Lối tắt tới các màn 5–11; tu sĩ xuất hiện khi bước vào giữa phòng | Bị bắt thay vì chết | 124: "Chào mừng về nhà, vật thí nghiệm của ta." **T** |

Nguyên tắc cho câu mới (loại E): chạy **một lần** khi vào màn hoặc khi nhặt vật phẩm có sẵn; không chặn đường,
không đổi điều kiện giải câu đố, để tuyến giải được của Daniel dùng lại được cho Clara.

### 2.5 Lời giải riêng (kiểu Resident Evil 1)

Đã dò chuỗi phụ thuộc vật phẩm trong `data/levels/`: món bị bỏ qua hoặc vẫn cần ở chỗ khác, hoặc không ai cần nữa.

| # | Chỗ | Daniel | Clara | Vì sao không kẹt |
|---|---|---|---|---|
| 1 | Ống thông gió thư viện (màn 1, #15–17) | Kìm | Chui lọt | Kìm vẫn cần cho hàng rào lưới thép (màn 14, #24/#55) |
| 2 | Người gác nhà xác (màn 6, #21–22) | Ống tiêm rồi dao mổ | Người gác hoảng chạy, rơi áo khoác có chìa khóa | Dao mổ vẫn cần ở trường (màn 9, #16) |
| 3 | Chó nhà Benjamin (màn 15, #13/#17) | Khúc xương hoặc thuốc mê | Chó lùi lại, đi qua | Khúc xương không dùng ở đâu khác |
| 4 | Máy ảnh flash | Dùng được | **Không dùng được** (flash làm lóa, đau); dùng Mắt đêm thay | Flash chỉ là lời giải phụ |
| 5 | Tu viện (màn 13) | Đường chính | Thêm lối tắt từ xà lim cũ | Thêm lối, không bỏ lối cũ |
| 6 | Đồ sưu tầm (món 21) | 18 bánh muffin ôi thiu | 18 **vòng tay bệnh nhân**, mỗi vòng một tên người từng bị giam | Chỉ đổi tên/mô tả (203, 244), phần thưởng giữ nguyên |

Chiều ngược lại, Daniel đứng được ở vùng sáng mạnh nên đánh boss dễ hơn; Clara phải dụ boss vào vùng sáng.

Cài đặt: lời giải riêng nằm ở `data_enhanced/clara/levels/NN.json` (cùng định dạng file bổ sung, chỉ nạp khi
`hero == "clara"`), ghi đè hoặc thêm sự kiện; không đụng `data/`.

### 2.6 Đoạn phim kết thật

- Mở sau khi hoàn thành một tuyến bất kỳ; cờ lưu ở `user://progress.json` (`{"done": ["daniel"]}`), không bị xóa khi
  "Trò chơi mới".
- Chiếu sau bảng thống kê (SPECIAL 17): hai bố con cùng lên đường tới ngôi làng tu sĩ; Daniel cầm đèn, Clara đi
  trong vùng mờ sau lưng bố — nối sang phần 3. Dùng lại cảnh cắt op 13 (tranh 181..188), 3–4 câu mới
  (chỉ số mới từ 300 trong file ghi đè).

## 3. Lời thoại và chân dung

- File ghi đè `data_enhanced/strings_vi_clara.json` / `strings_en_clara.json`: object `{ "chỉ_số": "câu mới" }`,
  chỉ chứa câu cần đổi; câu không có trong file thì dùng bản gốc.
- Danh sách câu cần viết lại (tiếng Việt, 59 câu):
  - Nhắc tên/người nói: 0, 1, 2, 3, 7, 8, 9, 31, 32, 34, 35, 36, 39, 44, 45, 48, 49, 50, 51, 56, 58, 62, 63, 78, 80,
    82, 91, 93, 94, 101, 104, 107, 109, 112, 113, 114, 116, 117, 120, 121, 160, 162, 168, 169, 170, 171, 175, 228, 230.
    Tiền tố "Hale:" đổi thành "Clara:"; câu có nội dung gia đình/giới tính (2, 3, 34, 48, 63, 113, 114, 116, 120,
    121, 160, 162, 169, 171, 228) viết lại nội dung.
  - NPC xưng "anh" → "cô"/"cháu": 37, 40, 42, 60, 61, 83, 95, 96, 124, 125.
  - Tiếng Anh: đổi đại từ he/him/his, wife → mother, daughter → father (thêm 42, 75, 84, 87 theo quét tự động).
  - **Đã viết** (2026-09-30): `data_enhanced/strings_vi_clara.json`, `strings_en_clara.json`, kiểm bằng
    `tests/unit/test_clara_strings.gd`. Giữ nguyên bản gốc: 171, 230 (đúng cho cả hai tuyến), 64, 75, 84, 87.
    Thêm ngoài danh sách: 15, 33, 55, 59, 68, 90, 103, 105, 106, 115, 119, 128, 174, 203, 231, 244, 246.
  - Câu mới: 300 hồ sơ bệnh viện (đọc từ túi đồ), 301 người gác nhà xác bỏ chạy, 302 Boss 1 chết, 303 hồi tưởng
    bệnh viện, 304 chặn flash, 305 chui ống thông gió, 306 áo tự cởi lần đầu, 307–309 Boss 2 chết (mở áo không
    giới hạn), 310–314 đoạn phim kết thật (dùng chung hai tuyến).
- Chân dung: kịch bản dùng khung **171 = Daniel**, **179 = Clara**. Tuyến Clara hoán đổi 171 ↔ 179 ngay trong
  `dialog.show_line`, không sửa kịch bản.
  Ngoại lệ: câu 120 (màn 13, op 2, khung 179) vẫn do Clara nói nên phải giữ khung 179 — file ghi đè cho phép kèm
  chân dung (`{"120": {"text": "...", "portrait": 179}}`). Câu 121 → 116 → 176 nằm trong cảnh cắt op 13 của màn 13
  (tranh khung 187, không chân dung), thứ tự này khớp hướng viết ở mục 2; tranh 187 cần vẽ lại cho tuyến Clara ở M3.
- Sprite/model: M3 cần thêm model Clara; trước đó dùng capsule tạm đổi màu.

## 4. Luật chung cho kỹ năng

- Daniel **4 chiêu** (phím `1`–`4`), Clara **3 chiêu** (phím `1`–`3`). Mở dần theo mốc boss, mỗi mốc gắn với một
  món nhặt được hoặc một đoạn truyện (bảng mục 6b): Daniel có chiêu 1–2 từ đầu, chiêu 3 (Bức tường lửa) sau Boss 1,
  chiêu 4 (Đèn đôi) sau Boss 2; Clara có chiêu 1 từ đầu, chiêu 2 sau Boss 1, chiêu 3 sau Boss 2. Hồi chiêu và thời gian hiệu lực tính theo **giây** (thời gian game, dừng khi tạm
  dừng/hội thoại).
- Điều khiển giữ như cũ: W A S D / mũi tên để đi; E, Space, Enter, F để nhặt/tương tác.
- Trước Boss 1 (màn 0, 14, 1, 2, 3) không câu đố nào cần kỹ năng; 1 chiêu là đủ. Chỗ phối hợp đầu tiên là Boss 1:
  Daniel dùng Mồi lửa thắp lại đèn để tạo ô sáng >= 4 làm boss mất máu.
- Mọi hiệu ứng làm tắt/đổi đèn đều **tạm thời**, hết hạn thì trả nguyên trạng, để không bao giờ kẹt màn.
- Tu sĩ, sinh vật bóng tối, boss giữ nguyên luật hiện có; kỹ năng chỉ tác động qua trạng thái có sẵn
  (độ sáng ô, vị trí, bàn đạp).

## 5. Daniel: người mang đèn (an toàn khi sáng)

Điểm yếu: mất máu theo độ sáng ô (`RulesMain`: tối hẳn 10 máu/s, mờ 4 máu/s, đủ sáng không mất).

**Áo choàng tu sĩ có giới hạn (đã làm trong `RulesMain`, 2026-09-30):** bản gốc cho áo vừa che mắt tu sĩ vừa chặn
mất máu, mặc được mọi nơi → từ màn 11 Daniel gần như bất tử (chỉ Boss 2 giết được). Luật mới: mặc tối đa **30 s**,
hết thì tự cởi và phải chờ **20 s** mới mặc lại; cởi sớm thì thời gian mặc hồi dần (đầy sau 20 s). Đồng hồ **dừng khi
có tu sĩ trong 6 ô** — cải trang theo kịch bản ở màn 12 (`IF_HOLDING` áo), 5 (tu sĩ dẫn đường), 13, 18 không hỏng.
Truyện: áo tẩm hương tu viện, người thường mặc lâu thì choáng. Còn thiếu: thanh thời gian áo trên HUD (làm cùng HUD kỹ năng).

| Phím | Kỹ năng | Luật | Hồi chiêu |
|---|---|---|---|
| 1 | Mồi lửa | Thắp lại nến đã tàn hoặc đèn cầm tay đã tắt ở ô kề (nến nạp đầy lại). **Không** thắp đèn cố định đang chờ công tắc/kịch bản (tránh lách câu đố) | 8 s |
| 2 | Băng bó | Đứng yên 3 s, hồi 10 máu. **Chỉ dùng được ở ô đủ sáng (>= 3, chỗ không mất máu)**: trong tối/mờ quái cào xé, không băng được — bấm thì báo "Quá tối, không băng bó được", không tốn hồi chiêu. Đang băng mà di chuyển hoặc ô tụt dưới sáng 3 (nến tàn, đèn bị tắt) thì hủy, không tốn hồi chiêu | 20 s |
| 3 | Bức tường lửa (mở sau Boss 1: chai dầu đèn lấy trong cửa hàng màn 3, cửa khóa tới khi boss chết) | Ném chai dầu đèn xa tối đa 4 ô: vệt lửa 3 ô trong 8 s, sáng mức 6; tu sĩ và sinh vật bóng tối không đi qua, tu sĩ **đổi hướng** khi gặp lửa. Gây sát thương cho Boss 2 bằng 1 cây đèn (6400) | 50 s |
| 4 | Đèn đôi (mở sau Boss 2: móc sắt tháo từ cột một trong 4 cây đèn lồng dùng đánh Boss 2) | Mang được **2 đèn cầm tay** cùng lúc (một cầm tay, một đeo lưng), cả hai cùng sáng. Phím 4 đổi đèn cầm tay ↔ đèn đeo lưng; nhặt/đặt (E) chỉ tác động đèn cầm tay | 1 s |

## 6. Clara: đứa trẻ của bóng tối (an toàn khi mờ)

**Vùng an toàn = ánh sáng mờ**, từ 1 tới dưới ngưỡng đau. Ngưỡng đau **giảm theo tiến độ truyện** (virus tiến triển):

| Mảnh chìa khóa đã có (món 29) | Ngưỡng đau | Vùng an toàn |
|---|---|---|
| 0–2 | 5 | 1–4 |
| 3–5 | 4 | 1–3 |
| 6, hoặc đang ở màn 13 | 3 | 1–2 |

- Sáng >= ngưỡng: ánh sáng làm đau, mất 7 máu/s.
- Sáng 0: **không mất máu**, nhưng **thanh virus** (0–100, trên HUD) tăng 20/s, tức đầy sau 5 s. Ở vùng mờ hoặc
  chỗ sáng thanh giảm 20/s (đầy về 0 mất 5 s).
- **Thanh đầy → Hóa quái** (tạm thời, tới khi thanh về 0):
  - Màn hình méo, viền đỏ; kỹ năng chủ động bị khóa.
  - Sinh vật bóng tối trong 5 ô coi Clara là đồng loại, kéo tới đứng ở các ô kề cô, chặn đường (không gây sát thương).
  - Không bao giờ chặn cả 4 phía: luôn chừa ít nhất 1 ô kề trống, ưu tiên ô hướng về vùng mờ gần nhất, để không kẹt.
  - Về vùng mờ thì thanh giảm; về 0 là tỉnh lại, sinh vật tản đi.
  - Màn không có sinh vật bóng tối (14, 15): chỉ còn méo màn hình và khóa kỹ năng.
- **Hồi máu trong vùng an toàn** (khác Daniel): đứng ở vùng mờ, không bị mất máu liên tục 2000 ms thì hồi 2 máu/s
  tới tối đa. Lý do: câu đố của Clara buộc cô lao vào chỗ sáng để tắt đèn, cần chỗ lùi về lấy lại sức.
- **Không có 12 điểm hồi đầy** (op 3, op 25 bỏ phần hồi máu khi `hero == "clara"`; op 25 vẫn mở cửa sau và cho
  pin). Nguồn hồi duy nhất là vùng an toàn. Câu 170 (uống nước ở màn 0) đã viết lại cho khớp.
- Tu sĩ phát hiện (luật tầm nhìn 2 ô hiện có, áo choàng vẫn che được, xem luật áo của Clara bên dưới): **bắt sống** thay vì câu 169 —
  đưa về điểm vào màn, đèn đang cầm rơi lại chỗ bị bắt, túi đồ giữ nguyên (tránh kẹt màn). Câu mới:
  "Clara bị bắt lại.. nhưng cô lại trốn thoát."
- **Áo choàng tu sĩ (chốt 2026-09-30):** áo **chặn bỏng ánh sáng** + che mắt tu sĩ; **không** chặn thanh virus
  (tối hẳn vẫn tăng). Từ màn 11 tới Boss 2: giới hạn **30 s mặc / 20 s chờ** như Daniel (đồng hồ dừng khi có tu sĩ
  trong 6 ô). Sau Boss 2 (**Một trong số họ**): mặc không giới hạn. Truyện: tu sĩ là sinh vật bóng đêm đi được trong
  sáng nhờ áo tẩm hương; hương làm người thường choáng. Boss 2 là thứ chúng tạo ra để đi dưới ánh sáng và bị ánh sáng
  thiêu — Clara hiểu virus trong mình đã biến cô thành đúng thứ chúng muốn (lúc này đã đủ 6 mảnh, ngưỡng đau 3),
  nên hương áo thôi làm cô choáng. `RulesClara`: bỏ bỏng khi `equipped == CLOAK`; tắt đồng hồ áo của `RulesMain`
  khi cờ `boss2_dead`. Câu dẫn: 109, 306 (màn 11), 307–309 (Boss 2 chết).
- Cầm đèn: Clara nhặt/đặt đèn như Daniel nhưng **che đèn trong áo** — đèn tắt khi cầm, bật lại khi đặt
  (đèn pin chiếu theo hướng cô đang nhìn). Nhờ vậy câu đố di chuyển đèn vẫn giải được.

| Phím | Kỹ năng | Luật | Hồi chiêu |
|---|---|---|---|
| — | Mắt đêm (bị động) | Nhặt đồ ở ô tối (op 10 bỏ điều kiện ô sáng) | — |
| — | Hòa vào bóng tối (bị động) | Đứng ở ô sáng 0: tu sĩ không phát hiện, sinh vật bóng tối không chạy trốn | — |
| 1 | Nuốt sáng | Tắt một nguồn sáng bất kỳ trong 3 ô (cả đèn tường) trong 8 s. Kích được cảm biến sáng ngưỡng 0 | 10 s |
| 2 | Gọi bóng (mở sau Boss 1) | Sinh vật bóng tối trong 3 ô đi tới ô tối chỉ định và đứng đó 10 s (đè được bàn đạp). Sinh vật tự sinh mỗi giây ở ô tối (mọi màn trừ 14, 15) | 12 s |
| — | Một trong số họ (mở sau Boss 2, thay Thức tỉnh đã bỏ) | Áo choàng tu sĩ hết giới hạn thời gian (xem luật áo ở trên). Clara chỉ có 2 chiêu chủ động; phím 3 để trống | — |

Căng thẳng thiết kế: ánh sáng mạnh làm Clara mất máu, tối hẳn làm cô hóa quái. Hòa vào bóng tối cần ô sáng 0,
nhưng ở đó lâu thì thanh virus đầy, nên phải lẩn nhanh qua rồi về vùng mờ.

## 6b. Nâng cấp (chốt 2026-09-30)

Không có kinh nghiệm hay farm. Nâng cấp đến từ vật sưu tầm đặt sẵn và mốc truyện, tổng số có giới hạn nên cân bằng
được trước. Không nhặt gì vẫn phá đảo được.

**Nguồn:**

| Nguồn | Daniel | Clara |
|---|---|---|
| Vật sưu tầm | 18 muffin (món 21, có sẵn: màn 1–18, màn 14 và 15 mỗi màn 2, màn 16 không có) | 18 vòng tay bệnh nhân, đặt đúng ô muffin cũ |
| Mỗi món nhặt được | +1 điểm nâng cấp (tổng 18) | +1 điểm nâng cấp (tổng 18) |
| Đủ 18 | Giữ thưởng gốc "Pin vô hạn" (câu 244) | Manh mối về kết thật (câu 244 ghi đè) |
| Hạ Boss 1 | Nhặt chai dầu đèn trong cửa hàng → mở khóa **Bức tường lửa** (3) | Mở khóa **Gọi bóng** (2) |
| Hạ Boss 2 (màn 14, hồi 3, ~15 điểm) | Nhặt móc sắt từ cột đèn lồng → mở khóa **Đèn đôi** (4) (đã bỏ Không khuất phục) | Mở **Một trong số họ**: áo choàng hết giới hạn thời gian (mốc truyện: câu 307–309) |

Kỹ năng mở từ đầu: Daniel có Mồi lửa (1) và Băng bó (2), **không có bị động nào** — mọi bị động của Daniel ở cấp 0, chỉ nâng bằng điểm; Clara có Nuốt sáng (1) và 2 bị động. Các kỹ năng còn lại mở theo
mốc boss như bảng trên. Bức tường lửa, Đèn đôi và Một trong số họ **mạnh sẵn, không có cấp nâng**: sau Boss 2 chỉ còn ~3 điểm và
3 màn (12 Nhà xác, 5 Nghĩa địa cấm, 13 Tu viện), nhiều tu sĩ và ánh sáng mạnh: áo không giới hạn cho Clara đi qua vùng sáng.
Trước đây Daniel ở 3 màn này gần như không bị đe dọa vì áo choàng chặn mất máu vô hạn; nay áo có giới hạn thời gian
(mục 5) nên bóng tối lại nguy hiểm tới cuối game, kể cả khi quay lại màn cũ nhặt muffin.

**Giá:** mỗi bảng tổng đúng **18 điểm** = nhặt đủ 18 món thì nâng hết (giá từng dòng ghi trong bảng).
Người chơi chỉ chọn **thứ tự** nâng; bỏ sót món thì thiếu cấp.
Kỹ năng chưa mở khóa thì chưa nâng được.

**Nhịp điểm theo tiến độ** (mỗi màn ~1 món; món ở phòng cửa hàng mua bằng xu):

| Mốc | Điểm cộng dồn |
|---|---|
| Hạ Boss 1 (màn 3) | ~5 |
| Mảnh chìa thứ 6 (hầm ngầm, màn 11) | ~15 |
| Hạ Boss 2 (màn 14) — Daniel mở Đèn đôi (4), Clara mở chiêu 3 | ~15 |
| Tu viện (màn 13, màn cuối) | 18 |

Dữ liệu màn có 19 lệnh nhặt món 21 (màn 14, 15 mỗi màn 2), có thể 1 lệnh trùng; cần xác nhận khi làm.

**Bảng Daniel:**

| Nâng cấp | Loại | Mỗi cấp | Số cấp | Tổng điểm |
|---|---|---|---|---|
| Mồi lửa | Chủ động | Cấp 1: đèn vừa thắp sáng rộng thêm 1 ô trong 10 s; cấp 2: hồi chiêu 8 → 6 s | 2 | 4 |
| Băng bó | Chủ động | Hồi 10 → 15 → 25 máu | 2 | 4 |
| Người giữ đèn | Bị động | Nến cầm theo cháy lâu gấp rưỡi → gấp đôi (bản gốc mất 1 `life` mỗi bước; cấp 1: 2 mỗi 3 bước, cấp 2: 1 mỗi 2 bước). Có ích ở 5 màn có nến (6–10) | 2 | 2 |
| Máu tối đa | Bị động | 100 → 110 → 125 (tăng bao nhiêu hồi bấy nhiêu) | 2 | 2 |
| Tay quen | Bị động | Chiêu 1, 2, 3 (Mồi lửa, Băng bó, Bức tường lửa) hồi nhanh hơn 10% → 25%; Đèn đôi không ảnh hưởng | 2 | 2 |
| Da dày | Bị động | Giảm máu mất theo bóng tối, áp dụng cả tối hẳn lẫn vùng mờ: −1 → −2 máu/s (tối hẳn 10 → 9 → 8, mờ 4 → 3 → 2) | 2 | 2 |
| Thợ săn bóng | Bị động | Sinh vật bóng tối chết nhanh hơn trong sáng: 2 → 1,75 → 1,5 s (`CREATURE_HP_MS`; bản gốc 1 s, remake nâng lên 2 s cho cả hai nhân vật). Giết nhiều hơn → xếp hạng cuối game tốt hơn (`GRADE_KILLS`), không làm Daniel trâu hơn | 2 | 2 |
| Bức tường lửa (3, sau Boss 1) + Đèn đôi (4, sau Boss 2) | Chủ động | Mạnh sẵn, không nâng | — | 0 |
| | | **Tổng** | **14 cấp** | **18** |

**Bảng Clara:**

| Nâng cấp | Loại | Mỗi cấp | Số cấp | Tổng điểm |
|---|---|---|---|---|
| Nuốt sáng | Chủ động | Cấp 1: hiệu lực 8 → 12 s; cấp 2: tầm 3 → 5 ô | 2 | 4 |
| Gọi bóng (sau Boss 1) | Chủ động | Cấp 1: phạm vi 3 → 5 ô, đứng 10 → 15 s; cấp 2: gọi **2 sinh vật** cùng lúc (2 ô chỉ định, đè được 2 bàn đạp) | 2 | 4 |
| Một trong số họ (sau Boss 2) | Mở khóa | Áo choàng hết giới hạn thời gian, không nâng | — | 0 |
| Máu tối đa | Bị động | 100 → 110 → 125, giống Daniel (tăng bao nhiêu hồi bấy nhiêu) | 2 | 2 |
| Hồi phục | Bị động | Hồi trong vùng an toàn 2 → 3 → 4 máu/s | 2 | 2 |
| Mũ trùm | Bị động | Kéo mũ trùm che mặt: bỏng ánh sáng 7 → 6 → 5 máu/s (đối xứng Da dày của Daniel); ngưỡng đau vẫn giảm theo mảnh chìa như truyện | 2 | 2 |
| Tỉnh nhanh | Bị động | Thanh virus giảm khi không ở tối hẳn 20 → 25 → 30/s (đầy về 0: 5 → 4 → 3,3 s) | 2 | 2 |
| Mắt đêm+ | Bị động | Vật phẩm phát sáng mờ trong 4 ô → 7 ô (dễ tìm đồ, vòng tay trong tối) | 2 | 2 |
| | | **Tổng** | **14 cấp** | **18** |

Đã bỏ Bóng sâu (Hòa vào bóng tối ở ô sáng 1–2): ở tu viện vùng an toàn chỉ còn sáng 1–2 nên tu sĩ gần như vô dụng.

Giá chung: bị động **1 điểm/cấp**, chủ động **2 điểm/cấp**. Daniel: bị động 5 dòng × 2 cấp = 10, chủ động 8.
Clara: bị động 5 dòng × 2 cấp = 10, chủ động 8. Cả hai tổng đúng 18. Daniel tiêu được cả 18 điểm từ đầu (không
chiêu có cấp nào bị khóa); Clara bị khóa 4 điểm (Gọi bóng) tới Boss 1. Tay quen (giảm hồi chiêu) chỉ Daniel có.

Ghi chú:

- Không có nâng cấp tốc độ đi (đã bỏ Chạy nhanh): tốc độ đổi thời gian của câu đố hẹn giờ (op 24) và tu sĩ tuần.
- "Pin vô hạn" đã có trong code (`World.infinite_battery`); chỉ cần bật khi nhặt đủ 18 muffin.
- Chọn nâng cấp: không bật popup giữa lúc chơi. Nhặt món thì hiện "+1 điểm nâng cấp (Tab)" và ô túi đồ trên HUD
  nháy. Người chơi mở túi đồ (Tab) → nút **Kỹ năng** → trang nâng cấp: hiện số điểm còn lại; mỗi dòng một nâng cấp,
  cấp hiện tại / tối đa và giá; bấm để mua; không đủ điểm hoặc chưa mở khóa thì xám (kèm "Hạ Boss 1" / "Hạ Boss 2").
  Điểm chưa dùng được giữ. Không hoàn điểm (chọn là chốt).

## 7. Thay đổi code

- `World`: thêm `hero` (`"daniel"` | `"clara"`), ghi vào `save.json`; bản lưu cũ không có trường này thì là Daniel.
- `menu.gd`: "Trò chơi mới" → xác nhận → màn chọn nhân vật.
- `game.gd` (chỗ tạo `RulesMain`, dòng ~185): chọn `RulesMain` + kỹ năng Daniel hoặc `RulesClara` theo `hero`.
- `LevelData`: nạp chuỗi gốc rồi áp file ghi đè theo `hero`.
- `dialog.gd`: hoán đổi chân dung 171 ↔ 179 khi `hero == "clara"`.
- `rules_clara.gd` (`RulesClara extends RulesMain`): máu theo vùng mờ (ngưỡng đau theo số mảnh chìa khóa), hồi máu
  trong vùng an toàn (cùng chỗ ghi đè `_drain`), bắt sống. `ScriptVM` op 3 / op 25: bỏ hồi máu khi `hero == "clara"`.
- Kỹ năng (mỗi nhân vật 3 chủ động; Daniel +1 bị động mở theo boss, Clara +2 bị động có sẵn) và hồi chiêu: một file `skills.gd`, không đụng `RulesClassic`.
- `hud.gd`: 3 ô kỹ năng 1/2/3 + hồi chiêu (giây); Clara thêm thanh virus.
- `game.gd` bảng phím: thêm `skill_1..4` (KEY_1..KEY_4; Clara không dùng phím 4), giữ nguyên phím di chuyển và tương tác.
- `game.gd`: sau SPECIAL 17 chiếu đoạn phim kết thật nếu `progress.json` có tuyến đã xong.
- Túi đồ: tuyến Clara cho vật phẩm 11 (hồ sơ bệnh viện) "đọc được" như các ghi chú 0/22..25.
- Bảng thống kê (câu 246): tuyến Clara đổi nhãn "Quái vật đã giết" qua file ghi đè.
- Màn 13 tuyến Clara: vẽ Daniel (NPC đứng yên) tại ô gặp mặt (7,6) thay cho Clara.
- `LevelData`: sau `data_enhanced/levels/NN.json` nạp thêm `data_enhanced/clara/levels/NN.json` khi `hero == "clara"`.
- Nâng cấp: `World.upgrade_points`, `World.upgrades` (`{tên: cấp}`) và `World.skills_unlocked`, ghi vào `save.json`. `skills.gd` đọc
  hai trường này khi tính hồi chiêu, tầm, bán kính. Boss 1 / Boss 2 chết (sự kiện đã có) thì mở khóa kỹ năng theo bảng mục 6b.
  Trang nâng cấp là một trang mới trong `menu.gd`, mở từ túi đồ (cùng kiểu với trang bản đồ `open_map`), không thêm file UI.
- Flash máy ảnh: tuyến Clara chặn dùng (câu mới: "Ánh flash… không, mắt mình không chịu nổi.").

## 8. Kiểm thử

- Unit: luật máu Clara ở cả 3 mức ngưỡng (sáng >= ngưỡng → mất, vùng mờ → hồi sau 2000 ms, không vượt tối đa,
  sáng 0 → không mất máu, thanh virus tăng); thanh đầy → hóa quái, sinh vật chặn nhưng luôn chừa 1 ô trống,
  về 0 thì tỉnh; tu sĩ bắt sống
  đưa về điểm vào màn, túi đồ còn nguyên; mỗi kỹ năng một test; hiệu ứng hết hạn trả nguyên trạng;
  nhặt món thì +1 điểm; mua trừ đúng giá (bị động 1, chủ động 2); thiếu điểm, vượt cấp tối đa hoặc kỹ năng chưa
  mở khóa thì bị từ chối; hạ Boss 1 / Boss 2 thì mở đúng kỹ năng; tổng giá mỗi bảng = 18;
  áo Clara giới hạn 30 s trước Boss 2, không giới hạn sau Boss 2; hồi chiêu đếm theo giây và dừng khi tạm dừng.
- Giải được với **không nâng cấp nào** và với **mọi nâng cấp tối đa** (bắt lỗi lách câu đố).
- Dữ liệu: file ghi đè chỉ chứa chỉ số hợp lệ; đủ mọi chỉ số trong danh sách mục 3 cho cả vi và en.
- Giải được: mỗi màn một tuyến đi hết cho **cả Daniel và Clara**.
  `tools/story_bot.gd` hiện kẹt ở 2/6 mảnh (tìm kiếm tham lam), phải sửa trước khi dùng làm tuyến chuẩn.
- Cổ điển: test so sánh với bản gốc giữ nguyên, phải xanh.

## 9. Rủi ro

| Rủi ro | Cách xử lý |
|---|---|
| Màn thiết kế cho ánh sáng mạnh, Clara không qua được | Tuyến giải được cho Clara; kẹt thì thêm nguồn sáng/ô mờ qua `data_enhanced` |
| Boss 1 quá khó nếu Clara tới muộn (ngưỡng 4) | Chấp nhận là độ khó theo lựa chọn; nếu tuyến giải được kẹt thì thêm một ô sáng 3 cạnh chỗ boss |
| Lời giải riêng của Clara làm kẹt màn sau (thiếu món) | Mỗi điểm ở mục 2.5 đã kiểm chuỗi phụ thuộc; tuyến giải được của Clara chạy lại mỗi lần sửa |
| Clara hồi máu làm ánh sáng hết đáng sợ | Chỉ hồi sau 2000 ms không mất máu, tối đa 4 máu/s < 7 máu/s mất khi đau; nhàm thì tăng thời gian chờ |
| Chiêu 3 làm 3 màn cuối quá dễ | Cố ý: đó là phần thưởng hồi 3. Bức tường lửa mở từ Boss 1 nên để hồi 50 s, lửa 8 s, gây sát thương cho Boss 2 bằng 1 cây đèn (chơi thử màn tu sĩ 5, 11 xem có quá dễ). Chơi thử thấy dễ quá thì tăng hồi chiêu |
| Nuốt sáng (tầm 3 ô, cả đèn tường) làm cảm biến sáng (op 28) đổi trạng thái, lách câu đố | Hết 8 s trả nguyên trạng; chạy tuyến giải được của Clara qua các màn có op 28 |
| Sau Boss 2 Clara mặc áo không giới hạn và chặn bỏng → ánh sáng hết nguy hiểm ở 3 màn cuối; Mũ trùm / Hồi phục ít tác dụng | Người dùng chấp nhận (2026-09-30). Từ màn 11 tới Boss 2 áo vẫn giới hạn 30 s như Daniel. Nguy hiểm còn lại cuối game: thanh virus ở chỗ tối hẳn |
| Đèn đôi làm dễ câu đố cố ý bắt chọn 1 trong 2 đèn | Đã rà (2026-09-30): 11 màn có >= 2 đèn cầm tay (0, 1, 3, 4, 6, 7, 8, 9, 10, 13, 14). Đèn đôi mở sau Boss 2 nên chỉ ảnh hưởng màn 13 (2 đèn lồng) và lúc quay lại màn cũ khi câu đố thường đã giải. Bàn đạp/cảm biến vẫn cần **đặt** đèn xuống, Đèn đôi chỉ bớt chạy đi chạy lại. Kiểm lại màn 13 khi chơi thử; chỗ nào hỏng thì màn đó chỉ cho đeo lưng đèn đã tắt |
| Bức tường lửa cần tu sĩ biết đổi hướng khi bị chặn (hiện chưa có) | Tu sĩ đi thẳng tới đích kịch bản (`tick_guards`). Thêm: ô kế tiếp là lửa thì quay đầu về ô vừa đi, hết lửa đi tiếp tới đích cũ — không làm hỏng sự kiện cờ 64 ở đích; test riêng. Tu sĩ chỉ có ở màn 5, 11, 12, 13, 18 |
| Gọi bóng vô dụng ở màn 14, 15 (không sinh quái) | Màn đó không có câu đố dựa vào kỹ năng này |
| Viết lại 59 câu × 2 ngôn ngữ lệch giọng | Viết cả lô một lần, đọc lại theo thứ tự màn |
