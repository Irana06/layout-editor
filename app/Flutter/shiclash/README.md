# Shiclash Mobile

Flutter client untuk Base Layout Editor. Website tetap menggunakan Laravel + React/Inertia, sedangkan aplikasi Android/iOS membaca katalog dan layout melalui Laravel API.

## Menjalankan Laravel API untuk emulator Android

Dari root project Laravel:

```powershell
php artisan serve --host=0.0.0.0 --port=8000
```

Lalu dari folder Flutter:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

`10.0.2.2` adalah alamat host Windows dari Android Emulator. Untuk HP fisik, ganti dengan IP LAN komputer, misalnya `http://192.168.1.10:8000/api/v1`. Build produksi harus menggunakan domain HTTPS publik.

## Pemeriksaan proyek

```powershell
flutter analyze
flutter test
```

## APK dari GitHub Actions

Workflow **Flutter Android** berjalan saat perubahan mobile masuk ke branch `main`, atau dapat dijalankan manual dari tab **Actions**. Isi input `api_base_url` saat menjalankan workflow, atau buat repository variable bernama `API_BASE_URL`.

APK hasil build tersedia sebagai artifact `shiclash-android-debug-*` selama 30 hari. Gunakan file `app-arm64-v8a-debug.apk` untuk mayoritas HP Android modern.

Debug APK ditujukan untuk pengujian internal. Distribusi versi release akan memakai signing key permanen dan GitHub Releases.
