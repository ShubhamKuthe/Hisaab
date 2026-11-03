# Hisaab (हिसाब)

**Bolo, aur hisaab ho gaya.** Simple shop accounts for Indian shopkeepers who keep no records today,
or only a paper notebook. Works fully offline, in **all 22 official languages of India, plus English and Tulu** (24 in all), with each script's own digits and right-to-left layout for Urdu, Kashmiri and Sindhi.

## Phase 1 (this version) – Windows
- **Simple mode** (default): just Sale and Expense, today's money in / out / net — no names, no udhaar.
  **Advanced mode**: udhaar, payments, customers, and the **bill maker**.
- **Bill maker** (advanced, F6): item × qty × price → total, remembers item prices, live receipt preview,
  **print** (80 mm receipt or any printer) or save a **WhatsApp image**; old bills can be reopened and reprinted.
  Receipts are rendered by Flutter and printed as an image so Marathi/Hindi letters stay correct.
- **Look**: clean Revolut-style cards in tiranga colours (saffron, white, India green), **light and dark mode**.
- First run: choose मराठी / हिंदी / English (change any time; optional Devanagari digits १२३)
- Big colour-coded buttons: **Sale** (green), **Expense** (red), **Udhaar given** (orange), **Payment received**
- Keyboard shortcuts for a busy counter: F1 Sale, F2 Expense, F3 Udhaar, F4 Payment, F5 Who owes me; Enter saves, Esc cancels
- On-screen number pad for mouse / touch-screen counters
- Today's money in, money out, net, and total udhaar due
- **Who owes me**: every customer's balance, biggest first, with full history
- Indian number format (₹1,00,000)
- Offline storage: atomic saves, 7 daily backups, damaged-file recovery
- **Backup now** (button or F9): saves the whole book as an Excel file to a pen drive or Google Drive folder
  (chosen once, remembered). Shows *last backup: N days ago* and turns red after 7 days. Keeps the newest 30 backups.
- **Restore from backup**: pick a backup .xlsx on a new PC and every entry comes back (safe to run twice, never duplicates).
  Works even if the file was opened and re-saved in Excel.
- **Excel file for your CA**: same Excel (all entries, customer dues, daily summary) saved to `Documents\Hisaab\`
- **4-digit PIN** set on first use; asked every time the app opens (🔒 button locks it).
  Stored only as a salted, iterated SHA-256 hash. 5 wrong tries → 30 s wait (growing).
  **Forgot PIN?** An 8-digit recovery code is shown once at setup to write in the shop's notebook; it lets you set a new PIN without losing data.
- No server: all data stays on the device

## Run it
Double-click **Setup and Run.bat**. On the first run it adds the Windows/Android platform folders
(`flutter create .`), then starts the app. Or manually:

```
flutter create --platforms=windows,android --project-name hisaab --org com.shubhamkuthe .
flutter pub get
flutter run -d windows
flutter test
```

Data is saved in `%APPDATA%\com.shubhamkuthe\hisaab\hisaab_data.json` (backups in `backups\`).

## Code
```
lib/
  main.dart, app.dart          app start, theme, AppScope (state access)
  l10n/strings.dart            language list, lookup with fallback (Tulu → Kannada → English)
  l10n/lang/*.dart             one file per language (24 files)
  models/entry.dart            Entry + EntryType
  data/store.dart              offline JSON store (swappable: SQLite / cloud later)
  state/app_state.dart         book logic: summaries, balances, add/delete
  screens/                     language, home, add entry, customers
  utils/format.dart            ₹ Indian grouping, Devanagari digits
  export/                      .xlsx writer + reader, backup / restore / CA export
  security/pin.dart            PIN hashing, recovery code
  theme/app_theme.dart         tiranga light + dark themes
  bills/receipt_output.dart    receipt capture, print, image
test/widget_test.dart          unit tests (formatting, balances, storage)
```

## Roadmap
1. **Voice entry** in Marathi/Hindi ("रमेशला २०० रुपये उधार दिले") with read-back
2. Bills with UPI QR, WhatsApp reminders, receipt printing
3. Android app (same Flutter code, phone layout)
4. Spring Boot + PostgreSQL backend on AWS for PC ↔ phone sync and cloud backup

## Languages
| Status | Languages |
|---|---|
| Checked | Marathi, Hindi, English |
| Full draft (beta) | Bengali, Telugu, Tamil, Gujarati, Kannada, Malayalam, Odia, Punjabi, Urdu, Assamese, Konkani, Nepali |
| Partial (beta) | Maithili, Dogri, Sanskrit, Sindhi, Kashmiri, Bodo, Manipuri (Meetei Mayek), Santali (Ol Chiki), Tulu |

Partial languages show the lines we're sure of; every other line falls back to the closest language their readers know
(Konkani→Marathi, Assamese→Bengali, Kashmiri/Sindhi→Urdu, Tulu→Kannada, Maithili/Dogri/Bodo/Sanskrit/Nepali/Santali→Hindi,
Manipuri→English). Native speakers can improve any language by editing `lib/l10n/lang/<code>.dart`.

## Newer features

- **Speak an entry** (F8): say "Ram ko 200 udhaar", "500 ki sale" or "chai 50 kharcha" and the type, amount and name fill in. You always see what was understood before saving. Works best in Hindi, Marathi and English.
- **Cash / UPI** on every sale, payment and expense, with "Cash in drawer" on the home screen.
- **UPI QR on bills**: add the shop's UPI ID once (Make a bill → Edit shop) and every bill gets a scan-to-pay QR with the amount filled in.
- **WhatsApp udhaar reminder** on each customer's page (save their phone number once).
- **Fix mistakes**: tap any entry to edit it; delete has an Undo.
- **Reports** (F7): last 7 days / this month / last month, daily chart, best day, biggest expenses, top dues.
- **Close the day** (F10): the day's totals to send on WhatsApp, print or copy. Also saves a backup.
- **Automatic daily backup** into the chosen backup folder (turn off in the backup ⋮ menu).

## Phone app (Android)

Double-click **Build Android App.bat**. The first time it installs Java 17 and the Android SDK by itself (about 1 GB), then builds **Hisaab.apk** into this folder. Send that file to the phone (WhatsApp to yourself, Google Drive or USB), tap it and press Install.

On the phone: Backup, Excel export and bill pictures open the share sheet (Google Drive, WhatsApp, Gmail), because phones have no folders a shopkeeper can pick. The top bar's extra buttons move into the ⋮ menu.
