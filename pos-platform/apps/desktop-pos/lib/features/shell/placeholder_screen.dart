/// Placeholder for module slots that the shell anticipates but that ship in
/// a later phase (Parties P8, Purchases P9, Reports, cashier mgmt, settings).
/// The slot exists in the nav now so the shell's structure is settled before
/// the features land.
library;

import 'package:flutter/material.dart';

class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, required this.phase});

  final String title;

  /// Which phase delivers this, e.g. "P8" — shown so it's clear the slot is
  /// intentional, not unfinished.
  final String phase;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.construction,
                size: 48, color: Theme.of(context).disabledColor),
            const SizedBox(height: 12),
            Text('$title — coming in $phase',
                style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
