# Shiclash Mobile

Flutter client untuk Base Layout Editor. Website menggunakan Laravel + React/Inertia. Aplikasi Android/iOS membaca katalog dari Laravel API, menyimpan layout secara lokal, dan dapat mencadangkan data ke ruang privat aplikasi di Google Drive.

## Halaman aplikasi

- **Studio**: beranda, lanjutkan draft, buat base, dan akses koleksi.
- **Buat base**: pilih TH dan scenery. Draft aktif yang berisi objek disimpan sebagai salinan sebelum permintaan canvas baru dikirim ke editor.
- **Katalog**: cari bangunan dan filter berdasarkan TH; ketuk kartu untuk membuka detail level, footprint, dan limit jumlah.
- **Editor**: placement, pilih/pindah/hapus, undo/redo, grid, pan/zoom, autosave, ganti nama layout, dan bagikan. Bangunan yang dipilih menampilkan ring jangkauan serangan bila jangkauannya sudah diisi di Calibrator.
- **Editor landscape**: tombol maximize membuka kanvas satu layar penuh dalam orientasi landscape dengan bilah bangunan di bawah; tombol minimize mengembalikan ke mode potrait. Kartu detail bangunan yang dipilih tampil sama seperti di potrait, di sudut kiri atas.
- **Layouts**: pencarian, urut terbaru/terlama, detail posisi objek, ganti nama, duplikat, bagikan, buka, dan hapus salinan.
- **Akun**: masuk/daftar dengan Google, tetap dapat digunakan secara offline, backup, restore, dan keluar akun.
- **Calibrator · Admin**: kalibrasi grid/origin scenery serta footprint, skala, dan offset building per level. Mendukung zoom/pan, drag langsung, input presisi, undo/redo, reset, salin antar-level, transparansi preview, grid lock, dan proteksi perubahan yang belum disimpan.
- **Lainnya**: akun dan backup, panduan kontrol, tes koneksi server, salin alamat server, dan informasi aplikasi.
- **Update**: cek GitHub Release secara otomatis saat aplikasi dibuka atau secara manual dari Lainnya. Tombol download membuka APK release; Android meminta persetujuan instalasi.

Aplikasi dikunci pada orientasi potrait, kecuali layar editor landscape yang melepas kunci tersebut selama route-nya aktif. Sistem UI disembunyikan sementara di mode landscape supaya scenery terlihat penuh; usap dari tepi layar untuk memunculkannya kembali. Bilah bangunan dapat disembunyikan agar kanvas benar-benar bersih, dan kartu bangunan bisa diketuk untuk memilih atau ditarik langsung ke petak tujuan.

Pratinjau layout adalah diagram posisi, bukan render sprite atau footprint sebenarnya. Statistik tempur belum disajikan jika belum ada di model katalog mobile. Fitur generator sengaja belum dibuat; menunggu instruksi pengguna.

## Perilaku penyimpanan

Perubahan canvas otomatis disimpan ke `shiclash-drafts-v1.json` di direktori dokumen aplikasi. Draft terakhir dipulihkan setelah katalog berhasil dimuat. Autosave menyimpan placement, TH, dan scenery; riwayat undo dimulai ulang saat draft dibuka.

Beri nama layout lewat judul di Editor untuk menyimpannya ke koleksi; setelah bernama, setiap perubahan langsung tersimpan ke entri yang sama tanpa langkah simpan terpisah. Tab **Layouts** menyediakan draft yang belum diberi nama beserta seluruh layout tersimpan, lengkap dengan duplikat, bagikan, buka, dan hapus. Perhatikan status penyimpanan sebelum menutup aplikasi; jika penyimpanan gagal, gunakan tombol coba lagi.

## Berbagi layout

Tombol bagikan mengunggah **salinan beku** ke Laravel dan menghasilkan tautan `/l/<kode>` berisi enam karakter. Layout di perangkat tetap milikmu dan tetap bisa diedit; perubahan itu tidak ikut ke tautan yang sudah dibagikan. Untuk membagikan versi terbaru, bagikan lagi dan tautan baru akan dibuat. Hanya layout yang kamu bagikan yang naik ke server; sisanya tetap lokal dan Google Drive.

Penerima yang membuka tautan akan masuk ke halaman hanya-baca dan dapat menekan **Salin layout ini** untuk menyimpannya ke koleksi mereka sendiri.

Tautan dikenali dalam dua bentuk: `https://<host>/l/<kode>` untuk Android App Links, dan `shiclash://layout/<kode>` sebagai cadangan yang langsung bekerja tanpa verifikasi domain. Host `https` ditentukan saat build lewat `-PshareHost=domain.com`, dengan Railway sebagai bawaan.

Agar Android membuka tautan `https` langsung di aplikasi, Laravel harus menyajikan `/.well-known/assetlinks.json`. Isi `ANDROID_SHA256_FINGERPRINT` di server dengan sidik jari keystore rilis:

```powershell
keytool -list -v -keystore android/app/shiclash-release.jks -alias <alias>
```

Selama variabel itu kosong, endpoint tersebut membalas 404 dan tautan cukup membuka halaman web biasa.

Penulisan dilakukan berurutan melalui file sementara, lalu mengganti file utama. File rusak atau versi yang tidak didukung tidak ditimpa. Draft yang tidak sesuai katalog ditolak sebelum mengganti canvas. Data lokal dapat hilang jika data aplikasi dibersihkan atau aplikasi dihapus, sehingga gunakan menu **Backup** setelah masuk dengan Google.

Backup Google Drive memakai scope `drive.appdata` dan file `shiclash-backup-v1.json` di `appDataFolder`. Shiclash hanya dapat membaca file privat yang dibuatnya sendiri dan tidak mendapat akses ke file Drive pengguna lainnya. Restore selalu meminta konfirmasi karena mengganti draft dan koleksi lokal.

Editor masih memerlukan koneksi ke Laravel untuk katalog dan gambar. Penyimpanan lokal belum berarti editor sepenuhnya offline.

Calibrator mengirim Google ID token ke Laravel melalui HTTPS. Laravel memverifikasi tanda tangan, issuer, audience, masa berlaku, dan email terverifikasi sebelum mengecek `ADMIN_EMAILS`. Nilai yang berhasil disimpan langsung membuat Katalog dan Editor memuat ulang data positioning terbaru.

## Menjalankan Laravel API untuk emulator Android

Dari root project Laravel:

```powershell
php artisan serve --host=0.0.0.0 --port=8000
```

Lalu dari folder Flutter:

```powershell
flutter run `
  --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1 `
  --dart-define=GOOGLE_WEB_CLIENT_ID=YOUR_WEB_CLIENT_ID `
  --dart-define=GOOGLE_IOS_CLIENT_ID=YOUR_IOS_CLIENT_ID
```

`10.0.2.2` adalah alamat host Windows dari Android Emulator. Untuk HP fisik, ganti dengan IP LAN komputer, misalnya `http://192.168.1.10:8000/api/v1`. Build produksi harus menggunakan domain HTTPS publik.

## Pemeriksaan proyek

```powershell
flutter analyze
flutter test
```

## APK dari GitHub Actions

Workflow **Flutter Android** berjalan saat perubahan mobile masuk ke branch `master` atau `flutter`, atau dapat dijalankan manual dari tab **Actions**. Isi input `api_base_url` saat menjalankan workflow, atau gunakan repository variable `API_BASE_URL`.

APK hasil build tersedia sebagai artifact `shiclash-android-debug-*` selama 30 hari. Gunakan file `app-arm64-v8a-debug.apk` untuk mayoritas HP Android modern.

Debug APK ditujukan untuk pengujian internal. Distribusi versi release akan memakai signing key permanen dan GitHub Releases.

## Update melalui GitHub Releases

Setiap rilis wajib menaikkan `version` di `pubspec.yaml`, misalnya `0.1.1+2`, lalu menggunakan tag yang sama tanpa build number: `v0.1.1`. Workflow menolak tag yang tidak cocok agar aplikasi tidak membandingkan versi yang salah.

Signed release membutuhkan empat repository secrets:

- `ANDROID_KEYSTORE_BASE64`: isi file JKS dalam format base64.
- `ANDROID_KEYSTORE_PASSWORD`: password keystore.
- `ANDROID_KEY_ALIAS`: alias key.
- `ANDROID_KEY_PASSWORD`: password key.

Repository variables berikut digunakan oleh build:

- `API_BASE_URL`: URL HTTPS Laravel dengan akhiran `/api/v1`.
- `GOOGLE_WEB_CLIENT_ID`: OAuth client tipe Web application, dipakai sebagai server client Google Sign-In.
- `GOOGLE_IOS_CLIENT_ID`: OAuth client tipe iOS untuk build iPhone.

Setelah secrets dan variables tersedia, naikkan versi lalu push tag yang cocok, misalnya `v0.2.0` untuk `version: 0.2.0+2`. Workflow akan menguji aplikasi, membuat APK universal bertanda tangan, lalu membuat GitHub Release beserta APK-nya.

Jangan mengganti atau kehilangan keystore. Semua update Android untuk package `com.shiclash.editor` harus ditandatangani dengan key yang sama. APK lama yang masih memakai package ID contoh harus dihapus satu kali sebelum memasang release pertama.
