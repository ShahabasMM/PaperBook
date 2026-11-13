# PaperBook

A quiet, offline-first home for receipts, warranties, invoices and the everyday
documents that matter. Built with Flutter for iOS and Android.

## Design

- **Palette** — warm paper background `#F7F8F5`, ink `#171717`, quiet grey
  `#777777`, and a single lime accent `#DFFF00` reserved for primary actions and
  active states. Full dark mode uses `#101010` / `#1A1A1A`.
- **Type** — Space Grotesk for brand and headings, Inter for body and detail.
- **Motion** — short fades, a 10px reveal, 0.98 press scale. Nothing bounces.
- **Layout** — one 4pt spacing scale, a shared radius scale, and content capped
  at 760pt on tablets.

### Brand assets

The source mark is `assets/logo/paperbook.png`. Every launcher icon (Android,
iOS, macOS, Windows, web) plus the in-app logo asset and the web splash mark are
generated from it:

```bash
python3 tool/generate_icons.py
```

The script crops the white canvas, extracts the book mark and re-renders it at
the exact size each platform expects, so new icons always match the source art.

## Features

- Dark, textured welcome experience.
- Folder-first dashboard with a live activity heatmap and a grid of folders.
- Folders for repeated bills such as petrol, rent or groceries. Folders get an
  icon automatically from their name, and their documents can be sorted by date
  or title.
- Library with list/grid layouts, live search, category filters, warranty filter
  and sorting.
- Add via camera, photo library, PDF import or manual entry — every path flows
  through the same editable review screen.
- **Document scanning** on iOS and Android: native edge detection with live
  boundary feedback, auto-capture, and automatic crop/perspective correction.
  Multi-page scans can have pages added, retaken, deleted and corner-adjusted
  before saving.
- **Nothing is destructive.** Each scan keeps the untouched full-resolution
  original alongside the enhanced, perspective-corrected copy. A multi-page
  scan also gets a locally generated PDF. Originals are never overwritten or
  deleted by enhancement.
- Document details with preview, metadata, warranty/return countdowns, notes,
  share, download and delete. Scanned documents preview their first processed
  page and show their page count.
- Full-screen zoomable image preview and a paper-style PDF preview.
- Settings for appearance, library layout, storage summary and data clearing.
- Everything is stored locally: SQLite for metadata, app-private storage for
  attachments. There is no account, backend or upload — cloud sync for scans is
  intentionally deferred.
- Runs on iOS and Android, with a Chrome preview that keeps documents in
  IndexedDB. File attachments and camera scanning are mobile-only; manual entry
  and browsing work on the web.

## Project structure

```
lib/
  core/        design tokens, theme, formatters and reusable widgets
  data/        models, SQLite database, repository, settings controller
  features/    onboarding, shell, home, documents, folders, add, scan, settings
test/          model, repository, migration, PDF and end-to-end widget tests
```

## Scanning

Scanning uses [`doclens`](https://pub.dev/packages/doclens) for the native
camera pipeline — edge detection, auto-capture and perspective warp — with a
custom PaperBook interface built on top. PDFs are assembled locally with
[`pdf`](https://pub.dev/packages/pdf).

Each scan is persisted as one self-contained, app-private bundle:

```
<app storage>/scans/<timestamp>_<suffix>/
  original_1.jpg   # untouched full-resolution capture
  scan_1.jpg       # enhanced, perspective-corrected copy
  original_2.jpg
  scan_2.jpg
  document.pdf     # multi-page PDF of the processed scans
```

The document's `file_path` points at the PDF, `pdf_path` mirrors it, and
`page_count` records the number of pages. `document_pages` stores each page's
original and processed paths. Deleting a document removes the whole bundle;
files imported before scanning (stored directly in media storage) are left on
the existing per-file cleanup path.

Temporary scanner and PDF files are caller-owned and deleted once a scan is
saved or discarded.

## Run

```bash
flutter pub get
flutter run            # pick an iOS/Android device, or Chrome
```

On first run in a browser, the web SQLite binaries must be present. They are
already committed, and can be regenerated with:

```bash
dart run sqflite_common_ffi_web:setup
```

Browser storage is scoped to the origin, port included, so use a fixed port to
keep web preview data between runs:

```bash
flutter run -d chrome --web-port 8080
```

If you launch on an unsupported target, startup now shows a readable error
screen instead of a blank window.

## Verify

```bash
flutter analyze
flutter test
flutter build web --release
flutter build apk --debug
```

The test suite uses `sqflite_common_ffi`, so no simulator or device is needed.
It covers the database migrations, scan bundle persistence and cleanup, local
PDF generation and the scanner review flow.

### Browser scanning (Chrome)

On the web the Add Document sheet shows **Scan your bill** and **Enter details
manually**. The scanner opens a live `getUserMedia` preview with a lime corner
guide. Captured frames are decoded, perspective-warped and contrast-enhanced
using doclens' pure-Dart `PerspectiveWarp` and `ImageEnhance` fallbacks.
Multi-page scans are supported with the same review screen: retake, add page,
and corner adjustment via a draggable overlay.

Pages and the generated PDF are stored as inline `data:` URLs inside the
IndexedDB-backed SQLite database — no filesystem access is required. The same
`DocumentRepository.addScanned` path is used, so the rest of the app (preview,
viewer, share, download) works unchanged. Share uses the native web share
target; download streams the bytes via `file_saver`.

> **Caveats:** Camera access requires HTTPS (or `localhost`). The browser
> permission prompt appears on first use. Inline storage inflates the
> IndexedDB size — acceptable for testing, but the mobile file-bundle model
> remains the primary design.

Real camera behaviour (edge detection, auto-capture, warping) needs a physical
iOS or Android device. iOS builds additionally require a complete Xcode
installation with CocoaPods.
