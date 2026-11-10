# Gia Phả Việt

Ứng dụng gia phả đa nền tảng (web, Android, iOS) viết bằng Flutter. Ghi chép cây gia phả nhiều đời, nhắc ngày giỗ theo âm lịch, tra cứu cách xưng hô, lưu phả ký và tộc ước của dòng họ.

Các tính năng được chọn lọc từ những ứng dụng gia phả phổ biến ở Việt Nam (Phả Tuệ, Gia Phả Đại Việt, Gia Phả Việt Nam). Bản này giữ lại phần thiết thực nhất mà gia đình nào cũng dùng tới.

## Tính năng

| Nhóm | Chi tiết |
|---|---|
| **Phả đồ tương tác** | Cây từ thủy tổ xuống; kéo, phóng to/thu nhỏ, vừa khung hình; thu gọn/mở từng nhánh; giới hạn số đời hiển thị; tìm một người và nhảy tới vị trí của họ; vợ/chồng hiển thị cạnh nhau, nhiều vợ theo thứ tự (vợ cả, vợ hai…) |
| **Hồ sơ thành viên** | Họ tên, tên húy/tên thường gọi, giới tính, con thứ, ngày sinh/ngày mất (chấp nhận chỉ năm hoặc tháng/năm), ngày giỗ âm lịch, nơi an táng, chức danh, nghề nghiệp, địa chỉ, điện thoại, tiểu sử; dâu/rể được đánh dấu riêng |
| **Quan hệ** | Thêm con (chọn đúng mẹ khi bố có nhiều vợ), thêm vợ/chồng, thêm bố/mẹ (thêm đời trên thủy tổ, cây tự dịch đời); đời được tính tự động |
| **Danh sách thành viên** | Tìm kiếm không dấu, lọc theo giới tính, còn sống/đã mất, đời, ẩn dâu/rể |
| **Ngày giỗ âm lịch** | Tự quy đổi ngày mất dương lịch sang ngày giỗ âm lịch; lịch giỗ 30 ngày / 3 tháng / cả năm kèm ngày dương lịch tương ứng, số ngày còn lại, số năm đã mất; tháng thiếu thì ngày 30 làm vào 29; giỗ sắp tới hiện ngay ở trang chủ |
| **Lịch âm** | Hôm nay âm lịch, can chi ngày/tháng/năm; công cụ đổi ngày âm ↔ dương (có tháng nhuận) |
| **Xưng hô** | Chọn hai người để biết A gọi B là gì và ngược lại: bố mẹ, ông bà nội/ngoại, bác/chú/cô/cậu/dì, anh chị em họ theo vai vế nhánh (con chú con bác), con dâu, chị dâu, thím, mợ, bố chồng/bố vợ… |
| **Dòng họ** | Quê gốc, nhà thờ họ, phả ký, tộc ước; thống kê theo đời, nam/nữ, còn sống/đã mất |
| **Sao lưu** | Sao chép bản sao lưu JSON để cất giữ và khôi phục trên máy khác; xuất bảng thành viên sang Excel/Google Sheets (CSV) |
| **Gia phả mẫu** | Một gia phả hư cấu 6 đời để xem thử ngay |

Dữ liệu được lưu ngay trên thiết bị (localStorage trên web, SharedPreferences trên điện thoại), không cần tài khoản hay máy chủ.

## Chạy thử

Yêu cầu Flutter 3.35 trở lên (Dart 3.9+).

```bash
# Lần đầu: sinh các thư mục nền tảng android/ ios/ và icon web
flutter create . --platforms=web,android,ios --project-name giaphavietnam --org vn.giaphaviet

flutter pub get
flutter run -d chrome        # web
flutter run                  # điện thoại / máy ảo đang kết nối
flutter test                 # chạy kiểm thử
```

Build bản phát hành:

```bash
flutter build web --release
flutter build apk --release
flutter build ipa            # cần máy Mac + Xcode
```

## Triển khai tự động

Workflow `.github/workflows/ci.yml` chạy ở mỗi lần đẩy code lên `main`:

1. `flutter analyze` và `flutter test`
2. Build web rồi đăng lên **GitHub Pages**: `https://<username>.github.io/giaphavietnam/`
3. Build file APK Android, tải về trong mục *Actions → Artifacts*

Muốn bật GitHub Pages, vào **Settings → Pages → Build and deployment → Source** và chọn **GitHub Actions** (chỉ cần làm một lần).

## Cấu trúc mã nguồn

```
lib/
  core/lunar/       Lịch âm Việt Nam (thuật toán Hồ Ngọc Đức, UTC+7), can chi
  core/kinship/     Tính xưng hô giữa hai người
  data/             Mô hình dữ liệu, chỉ mục quan hệ (FamilyGraph), lưu trữ, xuất CSV, dữ liệu mẫu
  state/            Riverpod: nơi duy nhất thay đổi và lưu dữ liệu
  features/         home, tree (phả đồ), members, anniversary (ngày giỗ), kinship, clan
  widgets/          Thành phần dùng chung
test/               Kiểm thử lịch âm, xưng hô, bố cục phả đồ, sao lưu, giao diện
```

## Hướng phát triển tiếp

- Đồng bộ đám mây và phân quyền biên tập theo chi/nhánh (Firebase hoặc Supabase)
- Thông báo nhắc giỗ trên điện thoại (`flutter_local_notifications`)
- Ảnh chân dung thành viên
- Xuất phả đồ ra PNG/PDF khổ lớn để in
- Nhập danh sách thành viên từ Excel
