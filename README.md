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

### Penting: Siri harus bahasa Inggris

Siri belum mendukung Bahasa Indonesia. Siri hanya mencocokkan frasa dalam bahasa Siri di perangkat, dan juga mentranskrip jawabanmu dalam bahasa itu. Jadi:

- **Settings → Siri → Language → English** (US/UK/Australia, bebas).
- Ucapkan frasa pemicu **dan** jawaban dalam format English di bawah.
- Kalau Siri menjawab sendiri tanpa menanyakan item/teman, berarti intent app **tidak** terpicu (biasanya karena bahasa Siri atau frasa salah).

Install/run app sekali dari Xcode di iPhone supaya shortcut terdaftar.

### Cara memicu

Sebut nama app **Bagi Dooit** (ucapkan “bagi du-it”). Alias yang juga dikenali: `BagiDooit`, `Bagi Doit`.

- “Hey Siri, **create a split bill in Bagi Dooit**”
- “Hey Siri, **split a bill with Bagi Dooit**”
- “Hey Siri, **new split bill in Bagi Dooit**”

Alternatif tanpa suara: buka app **Shortcuts** → cari **Buat Split Bill** → jalankan dan ketik jawabannya (format Indonesia maupun English sama-sama diterima kalau diketik).

### Alur yang diminta Siri

Siri menanyakan lima hal secara berurutan:

1. **Nama tagihan** — contoh: `lunch`
2. **Item, jumlah, harga satuan** — setiap item wajib punya jumlah dan harga satuan
3. **Pajak, ongkir, tambahan, atau diskon** — atau bilang `none`
4. **Nama teman** — kamu otomatis masuk sebagai **Saya**
5. **Pembagian item** — sebut tiap item untuk siapa (dan berapa porsi, jika perlu)

Setelah itu Siri membacakan ringkasan (item, tambahan, bagian per orang) dan minta konfirmasi. Baru setelah kamu setuju, tagihan disimpan ke store yang sama dengan UI Beranda.

### Contoh percakapan lengkap (Siri English)

> **Kamu:** Hey Siri, create a split bill in Bagi Dooit  
> **Siri:** What is the bill name?  
> **Kamu:** Lunch  
> **Siri:** Say each item with quantity and unit price…  
> **Kamu:** fried rice quantity two unit price twenty five thousand, then iced tea quantity three unit price five thousand  
> **Siri:** Any tax, delivery, extra fee, or discount?  
> **Kamu:** tax ten percent, then delivery twelve thousand  
> **Siri:** Who joined?  
> **Kamu:** Budi and Siti  
> **Siri:** Say who each item is for…  
> **Kamu:** fried rice for Budi one and Siti one, then iced tea for me one and Budi one and Siti one  
> **Siri:** *(ringkasan + total + bagian masing-masing)*  
> **Kamu:** Yes  

Tagihan langsung muncul di daftar split bill aplikasi.

Kata kunci English yang dikenali parser: `quantity`, `unit price`, `then`, `for`, `and`, `me`, `percent`, `discount`, `none`.

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
