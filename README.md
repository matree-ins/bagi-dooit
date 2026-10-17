# Bagi Dooit (JustDooit)

Aplikasi iOS untuk mencatat pengeluaran dan membagi tagihan (split bill). Fokus lokal Indonesia: rupiah utuh, nama peserta manual, dan pencatatan lewat Siri tanpa menebak kontak.

- **Platform:** iOS 27+
- **UI:** SwiftUI
- **Intents:** App Intents (Siri / Shortcuts)
- **Bundle display name:** Bagi Dooit

---

## Fitur utama

| Fitur | Ringkas |
| --- | --- |
| Beranda & riwayat | Catat pengeluaran, grafik, dan saran hemat |
| Split bill | Item, peserta, pajak/ongkir/biaya lain, bagikan ke WhatsApp |
| Foto struk | Buka scanner struk di app |
| Input suara | Buka layar rekam pengeluaran |
| **Siri Split Bill** | Sebut item, jumlah, harga, tambahan, nama teman, pembagian → konfirmasi → langsung tersimpan |
| Widget Quick Entry | Pintasan cepat ke scan / voice (target widget) |

---

## Siri: Buat Split Bill

Shortcut utama untuk mencatat split bill tanpa membuka form manual.

### Cara memicu

**Wajib:** install/run app sekali di device supaya Siri mendaftarkan shortcut. Kalau Siri “ngarang” jawaban tanpa menanyakan item/teman, berarti intent app **belum** terpicu.

Ucapkan **persis** salah satu (sebut nama app):

- “Hey Siri, **buat split bill di Bagi Dooit**”
- “Hey Siri, **catat split bill ke Bagi Dooit**”
- “Hey Siri, **bagi tagihan di Bagi Dooit**”
- “Hey Siri, **Bagi Dooit buat split bill**”
- English: “Create a split bill in Bagi Dooit”

Nama lain yang dikenali: **JustDooit**, **BagiDooit**, **Bagi Doit**.

**Kalau masih halu:**
1. Buka app Bagi Dooit sekali (shortcut di-donate ulang saat launch).
2. Buka app **Shortcuts** → cari **Buat Split Bill** / Bagi Dooit → jalankan manual, atau Add to Siri.
3. Settings → Siri → pastikan bahasa cocok; coba frasa English di atas.
4. Jangan bilang hanya “catat split bill” tanpa nama app — Siri akan jawab generatif, bukan masuk ke Bagi Dooit.

### Alur yang diminta Siri

Siri menanyakan lima hal secara berurutan:

1. **Nama tagihan** — contoh: `Makan Siang`
2. **Item, jumlah, harga satuan** — setiap item wajib punya jumlah dan harga satuan
3. **Pajak, ongkir, tambahan, atau diskon** — atau bilang `tidak ada`
4. **Nama teman** — kamu otomatis masuk sebagai **Saya**
5. **Pembagian item** — sebut tiap item untuk siapa (dan berapa porsi, jika perlu)

Setelah itu Siri membacakan ringkasan (item, tambahan, bagian per orang) dan minta konfirmasi. Baru setelah kamu setuju, tagihan disimpan ke store yang sama dengan UI Beranda.

### Contoh percakapan lengkap

> **Kamu:** Hey Siri, buat split bill di Bagi Dooit  
> **Siri:** Apa nama tagihannya?  
> **Kamu:** Makan Siang  
> **Siri:** Sebutkan item, jumlah, harga satuan…  
> **Kamu:** nasi goreng jumlah dua harga satuan dua puluh lima ribu lalu es teh jumlah tiga harga satuan lima ribu  
> **Siri:** Ada tambahan atau diskon?  
> **Kamu:** pajak sepuluh persen lalu ongkir dua belas ribu lalu biaya admin tiga ribu lalu diskon lima ribu  
> **Siri:** Siapa saja teman yang ikut?  
> **Kamu:** Budi dan Siti  
> **Siri:** Sebutkan setiap item untuk siapa…  
> **Kamu:** nasi goreng untuk Budi satu dan Siti satu lalu es teh untuk Saya satu dan Budi satu dan Siti satu  
> **Siri:** *(ringkasan + total + bagian masing-masing)* Simpan?  
> **Kamu:** Ya  

Tagihan langsung muncul di daftar split bill aplikasi.

### Format item

Pisahkan beberapa item dengan kata **lalu** (atau `kemudian` / `then`), titik koma, atau baris baru.

| Gaya | Contoh |
| --- | --- |
| Bahasa Indonesia | `nasi goreng jumlah dua harga satuan dua puluh lima ribu` |
| English | `fried rice quantity two unit price twenty five thousand` |
| Ringkas angka | `kopi 2 x 25.000` |

Aturan:

- 1–20 item per tagihan
- Jumlah 1–99
- Harga satuan > 0, total item ≤ Rp 1.000.000.000
- Nama item harus unik (case/diacritic insensitive)
- Angka bisa diucapkan (`dua puluh lima ribu`) atau ditulis (`25.000` / `25,000` / `Rp 25.000`)

### Format pajak, ongkir, dan tambahan

Pisahkan beberapa biaya dengan **lalu**. Bilang **tidak ada** jika tanpa tambahan.

| Contoh | Arti |
| --- | --- |
| `pajak sepuluh persen` | Persentase dari subtotal setelah diskon |
| `ongkir dua belas ribu` | Biaya tetap |
| `biaya admin tiga ribu` | Biaya tetap bernama bebas |
| `diskon lima ribu` | Potongan nominal (atau `diskon sepuluh persen`) |
| `tidak ada` | Tidak menambah pajak/ongkir/diskon |

Catatan penting:

- Pajak/service default UI (11% / 5%) **tidak** ditambahkan otomatis lewat Siri, supaya tidak dobel dengan biaya yang kamu sebut.
- Biaya persen dihitung dari subtotal setelah diskon, lalu dibulatkan.
- Ongkir dan biaya tetap dibagi **proporsional** menurut nilai pesanan tiap orang.
- Diskon tidak boleh melebihi subtotal.

### Format nama peserta

- Sebut 1–9 teman, dipisah koma atau kata **dan** / **and**
- **Saya** selalu ikut sekali (alias: `aku`, `me`, `myself`, `i`)
- Nama harus huruf (boleh spasi, `-`, `'`); jangan campur angka di nama
- Tidak menebak dari Contacts

Contoh: `Budi dan Siti` → peserta: Saya, Budi, Siti

### Format pembagian item

Harus ada **satu baris per item** (jumlah baris = jumlah item). Pisahkan baris dengan **lalu**.

| Gaya | Contoh | Arti |
| --- | --- | --- |
| Porsi eksplisit | `nasi goreng untuk Budi satu dan Siti satu` | Jumlah porsi harus pas dengan quantity item |
| Patungan satu item | `nasi goreng untuk Saya dan Budi` | Item utuh dibagi rata ke nama yang disebut |

Aturan:

- Nama orang harus sudah disebut di daftar peserta
- Jika ada jumlah di salah satu nama, semua penerima item itu harus punya jumlah, dan jumlahnya harus = quantity item
- Alias pemilik: `Saya` / `aku` / `me`

### Shortcut Siri lain

| Shortcut | Frasa contoh | Hasil |
| --- | --- | --- |
| Catat Pengeluaran | “Catat pengeluaran di Bagi Dooit” | Nominal + keterangan → konfirmasi → simpan ke Riwayat |
| Foto Struk | “Foto struk di Bagi Dooit” | Buka `bagidooit://scan` |
| Buka Input Suara | “Buka input suara di Bagi Dooit” | Buka `bagidooit://voice` |

---

## Arsitektur Siri Split Bill

Alur data:

```
Siri / Shortcuts
  → CreateSplitBillIntent
  → SiriEntryValidator + SiriBillParser (+ SiriSpokenNumber)
  → SiriSplitBillDraft (hitung total & bagian)
  → requestConfirmation (ringkasan)
  → SiriRecordingService.recordSplitBill
  → ExpenseStore.shared.addSplitSession
  → UserDefaults (persist) + UI Beranda
```

| File | Peran |
| --- | --- |
| `JustDooit/Intents/CreateSplitBillIntent.swift` | App Intent: parameter, dialog, konfirmasi, simpan |
| `JustDooit/Intents/BagiDooitShortcuts.swift` | Daftar frasa App Shortcut |
| `JustDooit/Intents/RecordExpenseIntent.swift` | Catat pengeluaran pribadi lewat Siri |
| `JustDooit/Services/SiriBillParser.swift` | Parse item, biaya, dan pembagian |
| `JustDooit/Services/SiriSpokenNumber.swift` | Angka lisan / format rupiah terkontrol |
| `JustDooit/Services/SiriEntryValidator.swift` | Validasi judul, nominal, daftar nama |
| `JustDooit/Services/SiriRecordingService.swift` | Konfirmasi dulu, baru tulis ke store |
| `JustDooit/Models/SiriSplitBillDraft.swift` | Draft session + teks konfirmasi |
| `JustDooit/Models/SiriReceiptItem.swift` | Item + qty + harga satuan |
| `JustDooit/Models/SiriBillCharges.swift` | Biaya tambahan + diskon |
| `JustDooit/Models/SplitBillCharge.swift` | Model biaya (fixed / percentage) |
| `JustDooit/Models/SplitBillChargeKind.swift` | Enum jenis biaya |
| `JustDooit/Models/SiriEntryError.swift` | Pesan error yang dibacakan Siri |
| `JustDooit/Models/SplitBillSession.swift` | Session, total, pembulatan rupiah, WhatsApp |
| `JustDooit/Services/ExpenseStore.swift` | `@Observable` shared store untuk UI + Siri |
| `Tests/SiriRegressionChecks.swift` | Regresi parser, konfirmasi, persistensi |

Keamanan & integritas:

- Intent memakai `requiresAuthentication` dan mode background
- Tidak ada kontak yang di-import otomatis
- Penolakan konfirmasi / pembatalan task **tidak** menyimpan data
- Draft yang sama (id session sama) tidak digandakan saat diulang
- Tagihan lama tanpa `additionalCharges` tetap bisa di-decode

---

## Struktur project

```
JustDooit/
├── JustDooit/                 # App target (folder sync Xcode)
│   ├── App/
│   ├── DesignSystem/
│   ├── Docs/
│   ├── Intents/               # App Intents + Shortcuts
│   ├── Models/
│   ├── Resources/
│   ├── Services/
│   └── Views/
├── BagiDooitWidgets/          # Widget extension
├── Tests/                     # Regresi Swift (script lokal)
├── workflow/                  # CI / TestFlight helpers
└── JustDooit.xcodeproj
```

---

## Menjalankan di Xcode

1. Buka `JustDooit.xcodeproj`
2. Pilih target **JustDooit** / skema app
3. Pilih device atau simulator iOS 27+
4. Run (⌘R)
5. Di device: Settings → Siri → pastikan shortcut Bagi Dooit muncul setelah install/run sekali

URL scheme app: `bagidooit://` (`scan`, `voice`, dan rute quick entry lain).

---

## Tes regresi

Parser dan alur simpan Siri diuji lewat script lokal (tanpa XCTest runner):

```bash
./Tests/run-regressions.sh
```

Script mengompilasi model/service terkait + `SiriRegressionChecks` lalu menjalankan assertion (angka lisan, item, biaya, pembagian, konfirmasi, persistensi, reload).

---

## Catatan pembagian & pembulatan

- Subtotal = Σ (quantity × harga satuan yang dialokasikan)
- Total = subtotal − diskon + biaya tambahan (persen & tetap)
- Bagian tiap orang proporsional terhadap subtotal pesanan mereka
- Dengan `roundsToWholeRupiah`, bagian dibulatkan ke rupiah utuh (largest remainder) sehingga jumlah bagian = total tagihan

---

## Kontribusi singkat

- Pertahankan satu tipe publik per file Swift (konvensi project)
- Jangan menambah dependency pihak ketiga tanpa diskusi
- Perubahan parser Siri wajib diikuti tes di `Tests/SiriRegressionChecks.swift`
- Commit message mengikuti Conventional Commits (`feat:`, `fix:`, …)
