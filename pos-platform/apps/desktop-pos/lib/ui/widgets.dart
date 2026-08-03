/// Small shared Dostop UI widgets used across feature screens so the chrome
/// stays consistent as more screens are ported (docs/desktop-pos-ui-design.md).
library;

import 'package:flutter/material.dart';

import 'theme.dart';
import 'tokens.dart';

/// The 56px panel header a nav-module screen puts at its top (in place of a
/// Material AppBar — the sidebar is the app chrome). Title + optional
/// subtitle on the left, optional actions on the right.
class DostopScreenHeader extends StatelessWidget {
  const DostopScreenHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });

  final String title;
  final String? subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: const BoxDecoration(
        color: DostopColors.panel,
        border: Border(bottom: BorderSide(color: DostopColors.hairline)),
      ),
      child: Row(
        children: [
          Text(title, style: DostopText.h1),
          if (subtitle != null) ...[
            const SizedBox(width: 10),
            Expanded(child: Text(subtitle!, style: DostopText.kicker)),
          ] else
            const Spacer(),
          ...actions,
        ],
      ),
    );
  }
}

/// A rounded status pill (e.g. "In stock", payment method, sale status).
class DostopPill extends StatelessWidget {
  const DostopPill({
    super.key,
    required this.label,
    required this.fg,
    required this.bg,
  });

  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(DostopRadius.chip),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: DostopFonts.sans,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }
}

/// Centered empty / hint state used by list screens.
class DostopEmptyState extends StatelessWidget {
  const DostopEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.detail,
  });

  final IconData icon;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: DostopColors.brandWash,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: DostopColors.brand),
          ),
          const SizedBox(height: 14),
          Text(title,
              style: DostopText.h1.copyWith(fontSize: 15),
              textAlign: TextAlign.center),
          if (detail != null) ...[
            const SizedBox(height: 6),
            Text(detail!, style: DostopText.label, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
