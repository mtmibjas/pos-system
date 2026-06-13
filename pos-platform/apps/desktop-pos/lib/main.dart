/// Desktop POS — macOS Flutter client entrypoint.
///
/// Phase 2 Slice 2.8 scope: ProviderScope + MaterialApp + ItemPicker,
/// which lists items from the local-store-server on 127.0.0.1:8081
/// via ItemService.ListItems. Cart + finalize land in Slices 2.9–2.10.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/items/item_picker_screen.dart';

void main() {
  runApp(const ProviderScope(child: PosApp()));
}

class PosApp extends StatelessWidget {
  const PosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'pos-platform',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const ItemPickerScreen(),
    );
  }
}
