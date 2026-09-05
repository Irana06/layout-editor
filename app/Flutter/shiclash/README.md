# Shiclash Mobile

Flutter client untuk Base Layout Editor. Website menggunakan Laravel + React/Inertia. Aplikasi Android/iOS membaca katalog dari Laravel API dan menyimpan layout secara lokal; sinkronisasi layout ke akun belum tersedia.

## Halaman aplikasi

- **Studio**: beranda, lanjutkan draft, buat base, dan akses koleksi.
- **Buat base**: pilih TH dan scenery. Draft aktif yang berisi objek disimpan sebagai salinan sebelum permintaan canvas baru dikirim ke editor.
- **Katalog**: cari bangunan dan filter berdasarkan TH; ketuk kartu untuk membuka detail level, footprint, dan limit jumlah.
- **Editor**: placement, pilih/pindah/hapus, undo/redo, grid, pan/zoom, autosave, dan simpan salinan.
- **Layouts**: pencarian, urut terbaru/terlama, detail posisi objek, ganti nama, buka, dan hapus salinan.
- **Lainnya**: panduan kontrol, penjelasan penyimpanan, tes koneksi server, salin alamat server, dan informasi aplikasi.
- **Update**: cek GitHub Release secara otomatis saat aplikasi dibuka atau secara manual dari Lainnya. Tombol download membuka APK release; Android meminta persetujuan instalasi.

Pratinjau layout adalah diagram posisi, bukan render sprite atau footprint sebenarnya. Statistik tempur belum disajikan jika belum ada di model katalog mobile. Fitur generator sengaja belum dibuat; menunggu instruksi pengguna.

## Perilaku penyimpanan

Perubahan canvas otomatis disimpan ke `shiclash-drafts-v1.json` di direktori dokumen aplikasi. Draft terakhir dipulihkan setelah katalog berhasil dimuat. Autosave menyimpan placement, TH, dan scenery; riwayat undo dimulai ulang saat draft dibuka.

Gunakan **Simpan salinan** di Editor untuk menyimpan layout bernama. Tab **Layouts** menyediakan draft terakhir serta salinan yang dapat dibuka atau dihapus. Mengedit canvas tidak mengubah salinan yang telah disimpan. Perhatikan status penyimpanan sebelum menutup aplikasi; jika penyimpanan gagal, gunakan tombol coba lagi.

Penulisan dilakukan berurutan melalui file sementara, lalu mengganti file utama. File rusak atau versi yang tidak didukung tidak ditimpa. Draft yang tidak sesuai katalog ditolak sebelum mengganti canvas. Data lokal dapat hilang jika data aplikasi dibersihkan atau aplikasi dihapus; belum ada backup akun.

Editor masih memerlukan koneksi ke Laravel untuk katalog dan gambar. Penyimpanan lokal belum berarti editor sepenuhnya offline.

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

## Update melalui GitHub Releases

Setiap rilis wajib menaikkan `version` di `pubspec.yaml`, misalnya `0.1.1+2`, lalu menggunakan tag yang sama tanpa build number: `v0.1.1`. Workflow menolak tag yang tidak cocok agar aplikasi tidak membandingkan versi yang salah.

Signed release membutuhkan empat repository secrets:

- `ANDROID_KEYSTORE_BASE64`: isi file JKS dalam format base64.
- `ANDROID_KEYSTORE_PASSWORD`: password keystore.
- `ANDROID_KEY_ALIAS`: alias key.
- `ANDROID_KEY_PASSWORD`: password key.

Repository variable `API_BASE_URL` juga wajib berisi URL HTTPS Laravel dengan akhiran `/api/v1`. Setelah secrets dan variable tersedia, push tag `v0.1.0`. Workflow akan menguji aplikasi, membuat APK universal bertanda tangan, lalu membuat GitHub Release beserta APK-nya.

Jangan mengganti atau kehilangan keystore. Semua update Android untuk package `com.shiclash.editor` harus ditandatangani dengan key yang sama. APK lama yang masih memakai package ID contoh harus dihapus satu kali sebelum memasang release pertama.
