# fluttertocflexam

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Build APK Android bằng GitHub Actions

Workflow `.github/workflows/build-android-apk.yml` tự động:

1. Cài đúng dependency từ `pubspec.lock`.
2. Chạy `flutter analyze` và toàn bộ `flutter test`.
3. Kiểm tra catalog TOCFL, một PDF và một audio thật từ R2 công khai.
4. Build một APK universal cho ARM 32-bit, ARM 64-bit và x86-64.
5. Kiểm tra archive, package, launcher, quyền Internet, ABI và chữ ký APK.
6. Đưa APK, SHA-256 và `BUILD-INFO.txt` lên phần Artifacts trong workflow run.

Vào tab **Actions** của repository, chọn **Build installable Android APK**,
chọn **Run workflow**. Khi job thành công, tải artifact
`TOCFL-Full-Exam-Android-...`, giải nén và mở file `.apk` trên Android. Máy cần
Android 7.0 (API 24) trở lên và có thể yêu cầu cho phép cài ứng dụng từ nguồn
không xác định.

Nếu chưa cấu hình signing secrets, workflow vẫn tạo APK ký bằng debug key để
cài và dùng ngay. Để những APK lần sau có thể cập nhật đè mà không phải gỡ app
cũ, thêm đủ bốn repository secrets sau:

- `ANDROID_KEYSTORE_BASE64`: nội dung keystore `.jks` sau khi mã hóa Base64.
- `ANDROID_KEYSTORE_PASSWORD`: mật khẩu keystore.
- `ANDROID_KEY_ALIAS`: alias của khóa.
- `ANDROID_KEY_PASSWORD`: mật khẩu của khóa.

Không đưa file `.jks`, mật khẩu hoặc `android/key.properties` vào Git.
