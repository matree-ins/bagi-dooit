# Siri dan Shortcuts Bagi Dooit

Widget dinonaktifkan: kode Swift dikomentari dan target extension dilepas dari project. Implementasi tetap disimpan di folder BagiDooitWidgets untuk referensi. Instruksi dan hasil pengujian widget di bawah adalah catatan sebelum penonaktifan.

## Cara pakai
- Jalankan aplikasi sekali setelah instalasi. Selesaikan onboarding.
- Tambah widget dari Home Screen → Edit → Tambah Widget → Bagi Dooit. Widget ukuran medium menyediakan Foto Struk dan Catat lewat suara saja.
- Foto Struk membuka scanner yang sudah ada. Pengambilan foto tetap dilakukan di aplikasi.
- Catat lewat suara membuka halaman suara; ketuk rekam untuk mulai. Mikrofon tidak diaktifkan diam-diam.
- Shortcuts menyediakan Foto Struk, Catat lewat Suara, dan Catat Pengeluaran. Untuk pencatatan, isi nominal dalam rupiah dan keterangan. Aplikasi menampilkan draft untuk diperiksa; tekan Simpan ke Riwayat Pengeluaran untuk menyimpan.
- Frasa Siri yang didaftarkan menggunakan bahasa Inggris, misalnya “Record an expense in Bagi Dooit”. Pengguna juga dapat membuat shortcut dengan nama sendiri. Dukungan pengenalan bahasa mengikuti Siri pada perangkat.
- Aksi yang dibuka saat onboarding ditunda hingga onboarding selesai. Pembatalan draft tidak menyimpan transaksi.

## Verifikasi otomatis
- Build aplikasi dan extension iOS Simulator: lulus, extension tertanam dalam PlugIns aplikasi.
- 87 regression checks: lulus. Termasuk rute scan/suara, skema/aksi/path asing, draft tidak lengkap, nominal nol/negatif/nonfinite/terlalu besar, keterangan kosong, dan encoding keterangan.
- Widget menggunakan aset warna yang sama dengan aplikasi, dengan light/dark variants.

## Pengujian perangkat yang masih diperlukan
- Tambahkan widget di Home Screen; uji kedua tombol dalam light/dark mode dan ukuran teks besar.
- Uji Siri dari perangkat terkunci dan terbuka, nominal/keterangan yang belum diisi, pembatalan, serta kembalinya Siri ke draft aplikasi.
- Uji izin kamera/mikrofon ditolak, kamera fisik, dan pengenalan suara offline sesuai kemampuan perangkat.
- Siri suara end-to-end dan kamera fisik belum diverifikasi dengan pengujian otomatis.
