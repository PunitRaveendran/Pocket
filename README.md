# Pocket

> An offline-first, private daily allowance and expense tracking application tailored for students on a monthly budget (₹2,000 – ₹3,000/month).

Built with Flutter, Pocket translates a modest monthly stipend into a daily spending allowance (~₹65 – ₹100/day), tracks expenses in real time, and separates one-off social outings so they never penalize your daily meal budget.

---

## ✨ Key Features

- **Daily Allowance Pacing**:
  - Live daily allowance meter showing exactly what is left to spend today.
  - Safe daily pace calculator adapts dynamically based on remaining days and days ahead/behind pace.
  - Quick amount presets (`+₹10`, `+₹20`, `+₹50`, `+₹100`) for one-tap logging of chai, snacks, and xerox runs.
- **Categorized Spends**:
  - Standard student categories: **Food**, **Snacks**, **Study**, and **Misc**.
  - Custom categories with tailored iconography (Commute, Gym, Shopping, Health, Tech, and more).
  - Live daily spend totals per category on the Today screen.
- **Separate Outings Ledger**:
  - Social outings, college fests, and group road trips have their own dedicated ledger.
  - Outing expenses are tracked item-by-item without reducing your daily food allowance.
- **7-Day Visual Insights**:
  - Clean bar chart comparing daily spends against your allowance threshold.
  - Category percentage breakdown with safe pace projections.
- **Privacy by Default & Calm Editorial Design**:
  - **100% offline**: All data lives solely on your device in a local SQLite database. No accounts, no cloud sync, no tracking.
  - **Integer Paise Arithmetic**: Zero floating-point drift (`100 paise = ₹1.00`).
  - **Dry, Respectful Tone**: Warm paper palette (`#F7F4EC`), hairline dividers, and typography powered by Source Serif 4 and IBM Plex Sans.
- **Export & Backup**:
  - Export complete transaction histories and outing details to RFC 4180-compliant CSV at any time.

---

## 🛠️ Tech Stack & Architecture

- **Framework**: Flutter 3.47 (Dart 3.13)
- **Local Database**: SQLite via `sqflite` (with in-memory mock fallback for web previews)
- **State Management**: Reactive `ChangeNotifier` and scoped listeners (`Ledger`)
- **Typography**: Source Serif 4 & IBM Plex Sans
- **Platforms**: Android (API 21 – 36), Web Preview

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://flutter.dev) (v3.24+ recommended)
- Android SDK (API 34/35/36)

### Run Locally

1. **Clone the repository**:
   ```bash
   git clone https://github.com/PunitRaveendran/Pocket.git
   cd Pocket
   ```

2. **Install dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run automated checks & test suite**:
   ```bash
   ./run_checks.sh
   # Or individually:
   # flutter analyze
   # flutter test
   ```

4. **Launch on a connected device**:
   ```bash
   flutter run
   ```

### Build Android APK

- **Release APK** (Optimized, AOT compiled, ~50 MB universal / ~18 MB split):
  ```bash
  flutter build apk --release
  ```
  Output: `build/app/outputs/flutter-apk/app-release.apk`

- **Debug APK**:
  ```bash
  flutter build apk --debug
  ```
  Output: `build/app/outputs/flutter-apk/app-debug.apk`

---

## 📄 License

This project is personal and open-source under the MIT License.
