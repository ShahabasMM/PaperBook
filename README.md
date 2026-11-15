<div align="center">
  <img src="web/icons/Icon-512.png" alt="PaperBook Logo" width="120" height="120">
  <h1>PaperBook</h1>
  <p><strong>A quiet, offline-first home for receipts, warranties, invoices and the everyday documents that matter.</strong></p>
  <p>Built with Flutter for iOS, Android, and Web.</p>
  
  <p>
    <a href="#features"><strong>Features</strong></a> •
    <a href="#screenshots"><strong>Screenshots</strong></a> •
    <a href="#getting-started"><strong>Getting Started</strong></a> •
    <a href="#architecture"><strong>Architecture</strong></a> •
    <a href="#testing"><strong>Testing</strong></a> •
    <a href="#tech-stack"><strong>Tech Stack</strong></a>
  </p>
</div>

---

## ✨ Features

### 📱 Core Experience
| Feature | Description |
|---------|-------------|
| **Offline-First** | No accounts, no cloud, no tracking. Your data stays on your device. |
| **Dark & Light Themes** | System-aware themes with a warm paper aesthetic and a single lime accent (`#DFFF00`). |
| **Folder-First Dashboard** | Organize bills into folders (Petrol, Rent, Groceries, etc.) with auto-assigned icons. |
| **Activity Heatmap** | Full-year contribution-style heatmap showing document activity at a glance. |
| **Smart Library** | List/grid layouts, live search, category filters, warranty filter, and multi-sort options. |

### 📄 Document Management
- **Multi-path Add Flow** — Camera scan, photo library, PDF import, or manual entry
- **Unified Review Screen** — Every path flows through the same editable review
- **Rich Metadata** — Title, amount, date, category, folder, notes, warranty/return dates
- **Warranty & Return Countdowns** — Automatic day counters with color-coded urgency
- **Full-Screen Preview** — Zoomable image viewer and paper-style PDF preview
- **Share & Download** — Native share sheet and platform save dialog

### 📸 Document Scanning (Mobile)
| Capability | Details |
|------------|---------|
| **Native Edge Detection** | Live boundary feedback via `doclens` on iOS/Android |
| **Auto-Capture** | Stability-based shutter with haptic feedback |
| **Perspective Correction** | Automatic crop & warp to rectangular scans |
| **Multi-Page Support** | Add, retake, delete, reorder pages |
| **Corner Adjustment** | Draggable handles for precise cropping |
| **Non-Destructive** | Original full-resolution capture preserved alongside enhanced scan |
| **Local PDF Generation** | Multi-page PDF assembled on-device with `pdf` package |

### 🌐 Web Support (Chrome)
- **Browser Scanning** — Live `getUserMedia` preview with lime corner guide
- **Pure-Dart Processing** — `PerspectiveWarp` + `ImageEnhance` from doclens fallback
- **Inline Storage** — Scans stored as `data:` URLs in IndexedDB-backed SQLite
- **Same Review Flow** — Retake, add page, corner adjust, swipe-to-save
- **Manual Entry** — Full document creation without camera access

### ⚙️ Settings & Data
- Theme selection (Light/Dark/System)
- Library layout (List/Grid)
- Storage summary with breakdown
- One-tap data clearing (documents, folders, settings)
- App version & build info

---

## 📸 Screenshots

<div align="center">
  <table>
    <tr>
      <td align="center"><strong>Home Dashboard</strong></td>
      <td align="center"><strong>Scan Review</strong></td>
      <td align="center"><strong>Document Detail</strong></td>
    </tr>
    <tr>
      <td><img src="docs/screenshots/home.png" alt="Home" width="200"></td>
      <td><img src="docs/screenshots/scan_review.png" alt="Scan Review" width="200"></td>
      <td><img src="docs/screenshots/document_detail.png" alt="Document Detail" width="200"></td>
    </tr>
    <tr>
      <td align="center"><strong>Library</strong></td>
      <td align="center"><strong>Folder View</strong></td>
      <td align="center"><strong>Settings</strong></td>
    </tr>
    <tr>
      <td><img src="docs/screenshots/library.png" alt="Library" width="200"></td>
      <td><img src="docs/screenshots/folder.png" alt="Folder" width="200"></td>
      <td><img src="docs/screenshots/settings.png" alt="Settings" width="200"></td>
    </tr>
  </table>
</div>

> **Note**: Add screenshots to `docs/screenshots/` to populate the table above.

---

## 🚀 Getting Started

### Prerequisites
- **Flutter SDK** ≥ 3.24 (stable channel)
- **Dart SDK** ≥ 3.5
- **Android Studio** / **Xcode** for mobile builds
- **Chrome** for web development

### Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/paperbook.git
cd paperbook

# Install dependencies
flutter pub get

# Generate launcher icons (optional, uses assets/logo/paperbook_icon.png)
python3 tool/generate_icons.py

# Run on your preferred platform
flutter run                    # Shows device picker
flutter run -d chrome          # Web (Chrome)
flutter run -d ios             # iOS Simulator/Device
flutter run -d android         # Android Emulator/Device
```

### Web Development Tips

```bash
# Use a fixed port to persist IndexedDB data between runs
flutter run -d chrome --web-port 8080

# If web SQLite binaries are missing:
dart run sqflite_common_ffi_web:setup
```

### Platform Requirements

| Platform | Minimum Version | Notes |
|----------|----------------|-------|
| iOS | 15.0 | Requires Xcode + CocoaPods |
| Android | API 24 (Android 7.0) | Camera permission in manifest |
| Web | Chrome 90+ | HTTPS or localhost required for camera |

---

## 🏗 Architecture

### Project Structure
```
paperbook/
├── lib/
│   ├── core/                    # Design system & utilities
│   │   ├── theme/               # Colors, spacing, typography, theme data
│   │   ├── utils/               # Formatters, attachment handling
│   │   └── widgets/             # Reusable UI components (buttons, sheets, etc.)
│   ├── data/                    # Data layer
│   │   ├── database/            # SQLite (sqflite) + migrations
│   │   ├── models/              # Document, Folder, Page, ScanBundle
│   │   └── repositories/        # DocumentRepository (single source of truth)
│   └── features/                # Feature modules (MVVM-ish)
│       ├── add/                 # Document creation flows
│       ├── documents/           # Library, detail, viewer, actions
│       ├── folders/             # Folder CRUD & folder-scoped library
│       ├── home/                # Dashboard, heatmap, folder grid
│       ├── scan/                # Scanner, review, PDF, web scanner
│       ├── settings/            # Preferences, storage, about
│       ├── shell/               # Bottom navigation, app scaffold
│       └── startup/             # Boot, onboarding, error screens
├── test/                        # Unit, widget & integration tests
├── tool/                        # Icon generation script
└── assets/                      # Logo, fonts, icons
```

### Key Patterns
- **Repository Pattern** — `DocumentRepository` wraps SQLite, exposes reactive streams via `ChangeNotifier`
- **Provider DI** — Repository & settings provided at app root
- **Route-based Navigation** — `MaterialPageRoute` with typed arguments
- **Platform Channels** — Native scanner via `doclens` (iOS/Android), pure Dart on web
- **Inline Attachments** — Web scans stored as `data:` URLs; mobile uses file bundles

### Data Model Highlights
```
Document
├── id, title, amount, category, folderId
├── documentDate, warrantyExpiry, returnExpiry
├── filePath, pdfPath, fileType, fileSize, pageCount
├── createdAt, updatedAt
└── DocumentPage[] (originalPath, scanPath, pageIndex)

ScanBundle (transient, pre-persistence)
├── ScanPageDraft[] (originalPath, cropPath)
└── pdfPath?
```

---

## 🧪 Testing

```bash
# Run all tests
flutter test

# Run with coverage
flutter test --coverage

# Run specific test file
flutter test test/repository_test.dart

# Run integration tests (requires device)
flutter test integration_test/
```

### Test Coverage Areas
- **Database Migrations** — Schema v1→v2→v3 with data preservation
- **Repository** — CRUD, scan bundles, folder operations, cleanup
- **PDF Generation** — Multi-page assembly, inline bytes (web), file paths (mobile)
- **Scanner Review Flow** — Retake, adjust corners, add/delete pages, swipe-to-save
- **UI Rendering** — Heatmap responsiveness, folder grid, form validation

---

## 🛠 Tech Stack

| Category | Technology |
|----------|------------|
| **Framework** | Flutter 3.24+, Dart 3.5+ |
| **Database** | SQLite via `sqflite` + `sqflite_common_ffi_web` |
| **State Management** | `provider` (ChangeNotifier) |
| **Navigation** | Flutter Navigator 1.0 |
| **Scanner (Mobile)** | `doclens` 0.0.12 (native edge detection + warp) |
| **Scanner (Web)** | `camera` 0.12.2 (`camera_web`) + doclens Dart fallbacks |
| **PDF** | `pdf` 3.13.1 |
| **Image Processing** | `image` (mobile), `dart:ui` (web) |
| **File Handling** | `path_provider`, `file_picker`, `image_picker`, `file_saver` |
| **Sharing** | `share_plus` |
| **Icons/Fonts** | Space Grotesk + Inter, Material Icons |

---

## 📦 Build & Release

### Debug Builds
```bash
# Android
flutter build apk --debug

# iOS (requires Xcode)
flutter build ios --debug

# Web
flutter build web --debug
```

### Release Builds
```bash
# Android (App Bundle for Play Store)
flutter build appbundle --release

# iOS (Archive for App Store)
flutter build ipa --release

# Web (Production)
flutter build web --release --wasm
```

### Versioning
Update `version` in `pubspec.yaml`:
```yaml
version: 1.0.0+1   # version+build_number
```

---

## 🔧 Configuration

### Environment-Specific
- **Android**: Camera permission in `android/app/src/main/AndroidManifest.xml`
- **iOS**: `NSCameraUsageDescription` in `ios/Runner/Info.plist`
- **Web**: HTTPS required for `getUserMedia` (works on `localhost`)

### Theme Customization
Edit `lib/core/theme/app_colors.dart` and `app_typography.dart` to adjust:
- Color palette (light/dark)
- Spacing & radius scales
- Font families & text styles

---

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style
```bash
# Format
dart format lib test

# Analyze
flutter analyze

# Test
flutter test
```

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- [`doclens`](https://pub.dev/packages/doclens) — Native document scanning pipeline
- [`pdf`](https://pub.dev/packages/pdf) — PDF generation
- [`sqflite`](https://pub.dev/packages/sqflite) — SQLite bindings
- [`camera`](https://pub.dev/packages/camera) — Camera access (mobile + web)
- Space Grotesk & Inter — Typography
- Flutter team — The framework

---

<div align="center">
  <sub>Built with ❤️ using Flutter. <br>
  PaperBook — Your documents, your device, your privacy.</sub>
</div>