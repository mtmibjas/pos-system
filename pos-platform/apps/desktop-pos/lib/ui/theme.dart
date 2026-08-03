/// Dostop POS Material theme — assembles the tokens in [DostopColors] into a
/// [ThemeData] and a small set of shared text styles. Wired in main.dart.
/// See docs/desktop-pos-ui-design.md §2.
library;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// Reusable text styles. `mono*` use DM Mono with tabular figures so money
/// and quantities align in columns.
abstract final class DostopText {
  static const _tabular = [FontFeature.tabularFigures()];

  static const h1 = TextStyle(
    fontFamily: DostopFonts.sans,
    fontSize: 17,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.3,
    color: DostopColors.ink,
  );

  static const kicker = TextStyle(
    fontFamily: DostopFonts.sans,
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: DostopColors.slate400,
  );

  /// Uppercase column header (SKU / ITEM / STOCK …).
  static const columnHead = TextStyle(
    fontFamily: DostopFonts.sans,
    fontSize: 10,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.5,
    color: DostopColors.slate400,
  );

  static const itemName = TextStyle(
    fontFamily: DostopFonts.sans,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    color: DostopColors.ink,
  );

  static const label = TextStyle(
    fontFamily: DostopFonts.sans,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: DostopColors.slate500,
  );

  /// Money / numerics.
  static const money = TextStyle(
    fontFamily: DostopFonts.sans,
    fontSize: 13.5,
    fontWeight: FontWeight.w800,
    color: DostopColors.ink,
    fontFeatures: _tabular,
  );

  static const mono = TextStyle(
    fontFamily: DostopFonts.mono,
    fontSize: 11.5,
    color: DostopColors.slate500,
    fontFeatures: _tabular,
  );

  /// Small keycap / chip mono (F2, Enter).
  static const keycap = TextStyle(
    fontFamily: DostopFonts.mono,
    fontSize: 10,
    color: DostopColors.slate500,
    fontFeatures: _tabular,
  );
}

ThemeData buildDostopTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: DostopColors.brand,
    primary: DostopColors.brand,
    surface: DostopColors.panel,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: DostopColors.canvas,
    fontFamily: DostopFonts.sans,
    splashFactory: InkSparkle.splashFactory,
    dividerColor: DostopColors.slate200,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: DostopColors.brand,
        foregroundColor: Colors.white,
        textStyle: const TextStyle(
          fontFamily: DostopFonts.sans,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DostopRadius.button),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DostopColors.slate50,
      hintStyle: const TextStyle(color: DostopColors.slate400),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DostopRadius.control),
        borderSide: const BorderSide(color: DostopColors.slate300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DostopRadius.control),
        borderSide: const BorderSide(color: DostopColors.slate300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(DostopRadius.control),
        borderSide: const BorderSide(color: DostopColors.blue, width: 1.5),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
  );
}
