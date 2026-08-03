/// Dostop POS design tokens — the single source of colour, type and shape
/// values translated from the Greenleaf/Dostop Claude-Design prototype.
/// See docs/desktop-pos-ui-design.md §2. Screens read from here (and from
/// [DostopTheme]) rather than hard-coding hexes so the palette stays
/// consistent as more screens are ported.
library;

import 'package:flutter/widgets.dart';

/// Flat colour palette. Named for role, not hue, so a re-theme is one edit.
abstract final class DostopColors {
  // Brand green.
  static const brand = Color(0xFF16A34A);
  static const brandDark = Color(0xFF15803D);
  static const brandWash = Color(0xFFECFDF5);

  // Ink / slate ramp.
  static const ink = Color(0xFF0F172A);
  static const inkPanel = Color(0xFF0B1220);
  static const slate600 = Color(0xFF475569);
  static const slate500 = Color(0xFF64748B);
  static const slate400 = Color(0xFF94A3B8);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate50 = Color(0xFFF8FAFC);

  // Surfaces.
  static const canvas = Color(0xFFF3F4F6);
  static const panel = Color(0xFFFFFFFF);
  static const hairline = Color(0xFFEEF1F5);

  // Dark sidebar.
  static const sidebarBg = Color(0xFF111827);
  static const sidebarBorder = Color(0xFF1F2937);
  static const sidebarText = Color(0xFF9CA3AF);
  static const sidebarGroup = Color(0xFF4B5563);
  static const sidebarBrand = Color(0xFFF9FAFB);

  // Semantic stock tones (fg, bg).
  static const stockOkFg = Color(0xFF16A34A);
  static const stockOkBg = Color(0xFFF0FDF4);
  static const stockLowFg = Color(0xFFD97706);
  static const stockLowBg = Color(0xFFFFFBEB);
  static const stockOutFg = Color(0xFFDC2626);
  static const stockOutBg = Color(0xFFFEF2F2);

  // Accents used by pay methods / badges.
  static const blue = Color(0xFF2563EB);
  static const blueWash = Color(0xFFEFF6FF);
  static const violet = Color(0xFF7C3AED);
  static const violetWash = Color(0xFFF5F3FF);
  static const danger = Color(0xFFDC2626);
}

/// A payment method's brand tones (fg + wash bg), matching the prototype.
enum PayMethod {
  cash('Cash', DostopColors.brandDark, DostopColors.stockOkBg),
  lankaQr('LankaQR', DostopColors.blue, DostopColors.blueWash),
  card('Card', DostopColors.violet, DostopColors.violetWash),
  split('Split', DostopColors.slate600, DostopColors.slate100);

  const PayMethod(this.label, this.fg, this.bg);
  final String label;
  final Color fg;
  final Color bg;
}

/// Stock level → tone, per §2.1 (out=0, low=1..8, ok>8).
({Color fg, Color bg, String label}) stockTone(int onHand) {
  if (onHand <= 0) {
    return (fg: DostopColors.stockOutFg, bg: DostopColors.stockOutBg, label: 'Out of stock');
  }
  if (onHand <= 8) {
    return (fg: DostopColors.stockLowFg, bg: DostopColors.stockLowBg, label: 'Low stock');
  }
  return (fg: DostopColors.stockOkFg, bg: DostopColors.stockOkBg, label: 'In stock');
}

/// Font family names (declared in pubspec.yaml).
abstract final class DostopFonts {
  static const sans = 'Manrope';
  static const mono = 'DM Mono';
}

/// Shared radii.
abstract final class DostopRadius {
  static const chip = 7.0;
  static const control = 9.0;
  static const button = 11.0;
  static const card = 14.0;
}
