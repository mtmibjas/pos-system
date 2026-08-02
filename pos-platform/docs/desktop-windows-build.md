# Desktop POS — Windows Build & Validation (§6 step 9)

> **Status: Runner scaffolded (2026-08-03); build + validation are yours.**
> The `windows/` runner was generated on macOS via
> `flutter create --platforms=windows`. The assistant cannot build or run a
> Windows binary — this doc is the checklist for validating it on a real
> Windows terminal (architecture §5 validation split).

---

## 1. Prerequisites (on the Windows machine)

- Flutter SDK with Windows desktop enabled:
  `flutter config --enable-windows-desktop`.
- **Visual Studio 2022** with the *"Desktop development with C++"* workload
  (the Windows Flutter toolchain needs MSVC + CMake).
- `flutter doctor` should show **no** Windows-toolchain issues.

## 2. Build & run

From `pos-platform/apps/desktop-pos`:

```
flutter pub get
flutter run -d windows      # debug run
flutter build windows       # release build → build/windows/x64/runner/Release/
```

The window title is set to **"pos-platform"** (`windows/runner/main.cpp`).

## 3. Cross-platform gotchas already handled in code

- **SQLite native library** — `sqflite_common_ffi` needs `sqlite3.dll` on
  Windows (no system SQLite). Bundled via **`sqlite3_flutter_libs 0.5.42`**
  (pinned `^0.5.24`; the `0.6.0+eol` version is a no-op tombstone — do NOT
  use it). Confirm it appears in `windows/flutter/generated_plugins.cmake`
  (it does today). If a build regenerates that file, re-run `flutter pub get`.
- **Secure token storage** — `flutter_secure_storage` uses **Windows
  Credential Manager / DPAPI** on Windows (Keychain on macOS). No code change;
  verify below.
- **App-support path** — `path_provider.getApplicationSupportDirectory()`
  resolves to `%APPDATA%\com.mibjas\desktop_pos\` on Windows; the local DB is
  `pos_desktop.db` there.

## 4. Validation checklist (only verifiable on Windows + hardware)

Software spine:
- [ ] App launches to the `AuthGate` (provisioning → login → nav shell).
- [ ] Sign in; relaunch **resumes the session without re-login** (token in
      Credential Manager).
- [ ] Build a cart, **force-quit mid-sale, relaunch** → the cart draft is
      **restored** (SQLite crash recovery, `pos_desktop.db`).
- [ ] Stop the store server → the health chip goes **amber → red**, and
      **Finalize is blocked** with the "store server unreachable" message;
      restart the server → chip greens, finalize re-enables.
- [ ] Simulate a lost-reply finalize (kill the reply) → the **"A sale is
      waiting… Retry now"** banner appears and **auto-completes on reconnect**.

Hardware (the reason for this phase):
- [ ] **Network ESC/POS printer:** set `TerminalConfig.printerTarget` to
      `network:<printer-ip>:9100`, complete a sale, hit **Print receipt** →
      a real receipt prints, cuts, and the **cash drawer kicks**.
- [ ] **File spool fallback:** `printerTarget = file:C:\temp\receipt.escpos`
      → the file is written with the ESC/POS bytes (open/inspect).
- [ ] **Barcode scanner (HID):** plug in, focus the item list (not the search
      box), scan a known SKU → it reserves + adds to the cart.

## 5. Still open (future, needs your hardware)

- Real **USB/serial** ESC/POS drivers (only `network:`/`file:`/`noop`
  implemented). These need platform channels + a device to test.
- Real **CustomerDisplay** secondary-window adapter (Noop today).
- Per-OS hardware adapter selection refinements once real devices are in hand.

*This is the last spine step. After validating here, the spine is done and
P7 (LK VAT+SSCL invoicing + real receipt printing) builds on it.*
