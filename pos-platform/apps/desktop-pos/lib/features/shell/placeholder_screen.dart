/// Placeholder for module slots that the shell anticipates but that ship in
/// a later phase (Parties P8, Purchases P9, Reports, cashier mgmt, settings).
/// The slot exists in the nav now so the shell's structure is settled before
/// the features land. Restyled to the Dostop design so it reads as an
/// intentional "coming soon", not a broken screen.
library;

import 'package:flutter/material.dart';

import '../../ui/tokens.dart';
import '../../ui/widgets.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, required this.phase});

  final String title;

  /// Which phase delivers this, e.g. "P8" — shown so it's clear the slot is
  /// intentional, not unfinished.
  final String phase;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: Column(
        children: [
          DostopScreenHeader(title: title, subtitle: 'Planned · $phase'),
          Expanded(
            child: DostopEmptyState(
              icon: Icons.construction_outlined,
              title: '$title is coming in $phase',
              detail: 'This module is designed and reserved in the shell — '
                  'the feature build lands in its phase.',
            ),
          ),
        ],
      ),
    );
  }
}
