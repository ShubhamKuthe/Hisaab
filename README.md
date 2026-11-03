# Hisaab

An offline accounts app for small shops in India. Record sales, expenses and credit (udhaar), make bills, and see who owes you money. Runs on Windows and Android. No server — all data stays on the device.

## Features

- Sales, expenses, credit given and payments received
- Cash / UPI on every entry, with cash-in-drawer total
- Customer balances and history
- Bills with item prices, printing, and a UPI QR code
- WhatsApp payment reminders
- Voice entry (Hindi, Marathi, English), e.g. "Ram ko 200 udhaar"
- Reports: last 7 days, this month, last month
- End-of-day summary (share, print, copy)
- Excel backup and restore, plus automatic daily backup on Windows
- 4-digit PIN lock with a recovery code
- 24 languages (22 official Indian languages + English + Tulu)
- Light and dark mode
- Keyboard shortcuts: F1 sale, F2 expense, F3 credit, F4 payment, F5 customers, F6 bill, F7 reports, F8 voice, F9 backup, F10 close day

## Tech

Flutter / Dart. Local JSON storage with atomic writes and daily backups. Custom .xlsx writer and reader. PIN stored as a salted SHA-256 hash.

## Run

Windows: double-click `Run Hisaab.bat` (first time: `Install Flutter.bat`).

Android: double-click `Build Android App.bat` — installs the Android SDK if needed and builds the APK.

Manual:

```
flutter pub get
flutter run -d windows
flutter build apk --release
flutter test
```

## Project layout

```
lib/
  state/      app logic (entries, balances, reports)
  data/       local storage
  screens/    UI screens
  widgets/    shared UI parts
  export/     Excel backup, restore, export
  voice/      voice entry parser
  l10n/       translations (one file per language)
test/         unit tests
```
