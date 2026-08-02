# Desktop POS — Hardware Ports & ESC/POS (§6 step 8)

> **Status: IMPLEMENTED (2026-08-02) — real USB/serial pending user hardware.**
> **8a** four ports (`lib/hardware/ports.dart`) + Noop/sim adapters + selection
> factory (`hardware_providers.dart`, defaults all-Noop) + `printerTarget` on
> `TerminalConfig`. **8b** `ReceiptDocument` + hand-rolled `EscPosEncoder`/
> `encodeReceipt` + `NetworkEscPosTransport` (TCP 9100) + capturing transport +
> `EscPos{ReceiptPrinter,CashDrawer}`; receipt-screen "Print" wired through the
> port. **8c** item picker consumes the `BarcodeScanner` port
> (`WedgeBarcodeScanner`/`SimulatedScanner`). **8d** `FileReceiptPrinter`
> (`file:PATH` spool — the OS-agnostic fallback). Tests: `esc_pos_test.dart`,
> `hardware_ports_test.dart`, `item_picker_scan_test.dart`; full suite 115/115
> green, analyze clean. **REMAINING (user-hardware only):** real USB/serial
> ESC/POS drivers + the real `CustomerDisplay` secondary window — validated on
> actual Windows terminals (§5). Design for migration step 8 of
> `docs/desktop-architecture.md` (§4.4). No code yet. This is the **adoption
> gate into P7** (LK invoicing needs real receipt printing). Elevates
> `apps/desktop-pos` — adds a hardware layer, no rewrite.

---

## 1. Principle (from architecture §4.4)

Hardware is a **first-class layer of swappable ports** (plain Dart
interfaces), each with per-OS adapters. Non-negotiables:

- **No UI or controller talks to a driver directly** — only through a port.
- **Every port ships a `Noop`/simulated adapter** so the whole app runs on
  the dev macOS box and in tests with **no hardware attached**.
- Adapter selection is per-terminal config (§4.1) + OS detection, chosen at a
  single factory — never sprinkled through features.
- **ESC/POS is the first real adapter** and the bridge into P7.

Four ports in scope:

| Port | Dir | Real adapter(s) | Noop/sim |
|---|---|---|---|
| `ReceiptPrinter` | out | ESC/POS (network/USB/serial), OS HTML/PDF fallback | `NoopReceiptPrinter`, `CapturingReceiptPrinter` (tests) |
| `CashDrawer` | out | kick via ESC/POS printer | `NoopCashDrawer` |
| `BarcodeScanner` | in | HID keyboard-wedge (wraps today's `scan_buffer.dart`) | `SimulatedScanner` |
| `CustomerDisplay` | out | secondary window (later) | `NoopCustomerDisplay` |

---

## 2. Current state

- **No printing exists at all** — the receipt is on-screen only
  (`receipt_screen.dart`). ESC/POS is entirely net-new.
- **Scanner logic exists but isn't a port** — `scan_buffer.dart` is a clean
  pure-Dart keyboard-wedge state machine, consumed inline by the item picker.
  We wrap it behind `BarcodeScanner` without rewriting it.
- Cash drawer / customer display: nothing today.

---

## 3. Layering & selection

```
UI / controller  ─depends on→  Port interface (domain/data boundary)
                                      ▲
                         hardwareAdaptersProvider (factory)
                                      │  selects by TerminalConfig + Platform
                 ┌────────────────────┼─────────────────────┐
            Noop/sim adapter     ESC/POS adapter        OS-fallback adapter
```

- A `hardwareProfile` in `TerminalConfig` (added here, defaults to all-Noop)
  names which adapter each port uses + its connection params (e.g. printer
  `network:192.168.1.50:9100`, `usb:...`, `noop`).
- Riverpod providers expose each port; tests override them with sim adapters
  (same pattern as `transportProvider`/`realtimeChannelProvider`).

---

## 4. ReceiptPrinter + ESC/POS (the core of this slice)

- **Structured document, not raw bytes at the call site.** A plain-Dart
  `ReceiptDocument` (store header, line items, subtotal/tax/grand, tender,
  invoice no., footer) is what controllers build. Adapters **render** it —
  ESC/POS to bytes, OS-fallback to HTML/PDF. This keeps the P7 invoice layout
  a *document* concern, testable without a printer.
- **`EscPosEncoder`** — a small, pure, unit-tested encoder: init, codepage,
  align, bold, text, feed, full/partial cut, drawer-kick. Bytes are asserted
  in tests; no printer needed. (Minimal hand-rolled set now; a community
  package can come later if P7 needs logos/QR — see **Q1**.)
- **Adapters:**
  - `CapturingReceiptPrinter` — records the encoded bytes/document (tests + a
    dev "print preview").
  - `NoopReceiptPrinter` — silently succeeds (default on an unconfigured box).
  - `NetworkEscPosPrinter` — TCP to `host:9100`, the most portable real
    transport; assistant can build it, **user validates against a real
    printer** (see **Q2**).
  - USB/serial ESC/POS + OS HTML/PDF fallback — **user-validated**, thin
    wrappers over the same `EscPosEncoder`; stubbed here.
- **Wire it:** the receipt screen gains a **"Print receipt"** action that
  builds a `ReceiptDocument` from the `FinalizeRecord` and sends it through
  the `ReceiptPrinter` port. On the dev box that's Noop/capturing — visible,
  non-failing.

---

## 5. Other ports

- **CashDrawer** — `kick()` emits the ESC/POS drawer pulse through the printer
  transport (real drawers chain off the printer). `NoopCashDrawer` for dev.
- **BarcodeScanner** — a `BarcodeScanner` port exposing a `Stream<String>` of
  completed scans, its default HID adapter wrapping the existing
  `scan_buffer.dart` so scanning works the same regardless of focus. A
  `SimulatedScanner` (push scans programmatically) for tests. The item picker
  consumes the *port*, not the raw buffer.
- **CustomerDisplay** — interface + `NoopCustomerDisplay` only this slice; the
  real secondary-window adapter is deferred (needs multi-window plumbing).

---

## 6. Proposed sub-slices

| Sub | Scope | Assistant-testable? |
|---|---|---|
| **8a** | 4 port interfaces + Noop/sim adapters + `hardwareProfile` config + provider factory. App runs all-Noop. | ✅ fully |
| **8b** | `ReceiptDocument` + `EscPosEncoder` (pure) + `CapturingReceiptPrinter`; wire receipt-screen "Print"; CashDrawer kick. | ✅ (bytes asserted) |
| **8c** | `BarcodeScanner` port over `scan_buffer`; item picker consumes the port; `SimulatedScanner`. | ✅ |
| **8d** | `NetworkEscPosPrinter` (TCP 9100) + USB/serial + OS-fallback stubs. | ⚠️ user-validated on real hardware |

---

## 7. Decisions (resolved 2026-08-02)

- **Q1 — ESC/POS encoding:** **hand-rolled minimal encoder** (no heavy deps,
  fully byte-testable). Revisit a package for P7 if QR/logo compliance needs it.
- **Q2 — first real printer transport:** **Network (TCP 9100)** + a capturing
  simulator now. USB/serial + OS HTML/PDF fallback stubbed for user Windows
  validation.
- **Q3 — receipt layout:** **minimal now** (header, lines, subtotal/tax/grand,
  tender, invoice no., footer). LK-compliant tax invoice is a P7 deliverable on
  the same `ReceiptDocument` model.
- **Q4 — port scope:** **all 4 port interfaces + Noop** now; real impls for
  printer (+ drawer kick) & scanner; `CustomerDisplay` Noop-only.

---

## 8. Test plan (server- and hardware-free)

- `EscPosEncoder`: exact byte sequences for init/align/bold/cut/kick;
  `ReceiptDocument` → encoder → expected bytes for a sample sale.
- `CapturingReceiptPrinter`: receipt-screen "Print" produces the expected
  document; failures surface, never crash the sale.
- `SimulatedScanner`: pushed scans drive the item picker add-line path;
  inter-char timeout / terminator behavior preserved (existing scan_buffer
  tests stay green).
- Port factory: selects Noop by default; selects the named adapter from
  `hardwareProfile`; unknown profile → Noop (never throws).

---

## 9. Scope boundary

- **No LK-compliant invoice layout** — P7, built on `ReceiptDocument`.
- **No real USB/serial drivers verified by the assistant** — user-validated on
  Windows terminals (architecture §5 validation split).
- **No customer-display window** — Noop only this slice.
- **No Windows runner** — step 9.

*After approval: 8a → 8b → 8c (assistant-tested), then 8d stubs for your
hardware validation. This unlocks P7 (LK invoicing + real receipt printing).*
