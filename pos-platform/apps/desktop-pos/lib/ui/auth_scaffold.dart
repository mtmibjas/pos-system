/// Shared Dostop auth layout — a split screen with a green brand panel on the
/// left and a centered white card on the right (collapses to just the card on
/// narrow windows). Used by the login and provisioning screens so the two
/// entry points feel like one product. See docs/desktop-pos-ui-design.md.
library;

import 'package:flutter/material.dart';

import 'theme.dart';
import 'tokens.dart';

class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.child});

  /// The form content rendered inside the card.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final card = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: DostopColors.panel,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: DostopColors.slate200),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x14000000),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _BrandMark(),
                const SizedBox(height: 22),
                child,
              ],
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      backgroundColor: DostopColors.canvas,
      body: LayoutBuilder(
        builder: (context, c) {
          if (c.maxWidth < 860) return card;
          return Row(
            children: [
              const Expanded(child: _BrandPanel()),
              Expanded(child: card),
            ],
          );
        },
      ),
    );
  }
}

/// Compact brand lockup shown at the top of the card.
class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: DostopColors.brand,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.eco, size: 19, color: Colors.white),
        ),
        const SizedBox(width: 11),
        const Text('Dostop POS',
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: DostopColors.ink,
            )),
      ],
    );
  }
}

/// The left green brand/marketing panel (wide screens only).
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: DostopColors.brand,
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.eco, size: 28, color: Colors.white),
          ),
          const SizedBox(height: 26),
          const Text('Point of sale\nfor modern retail',
              style: TextStyle(
                fontFamily: DostopFonts.sans,
                fontSize: 30,
                height: 1.15,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: Colors.white,
              )),
          const SizedBox(height: 14),
          Text(
            'Offline-first billing, inventory, invoicing and books — '
            'built for Sri Lankan shops.',
            style: TextStyle(
              fontFamily: DostopFonts.sans,
              fontSize: 14.5,
              height: 1.5,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 30),
          for (final f in const [
            'Works without internet at the counter',
            'VAT & SSCL invoicing, LankaQR payments',
            'Live stock across every till',
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, size: 18, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(f,
                      style: TextStyle(
                        fontFamily: DostopFonts.sans,
                        fontSize: 13.5,
                        color: Colors.white.withValues(alpha: 0.92),
                      )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A labelled field used by the auth forms.
class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.obscure = false,
    this.autofocus = false,
    this.textInputAction,
    this.onSubmitted,
    this.validator,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool obscure;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(label,
              style: const TextStyle(
                fontFamily: DostopFonts.sans,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: DostopColors.slate600,
              )),
        ),
        TextFormField(
          controller: controller,
          obscureText: obscure,
          autofocus: autofocus,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          validator: validator,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

/// Inline error banner for the auth forms.
class AuthError extends StatelessWidget {
  const AuthError({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: DostopColors.stockOutBg,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 17, color: DostopColors.danger),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message,
                style: DostopText.label.copyWith(color: DostopColors.danger)),
          ),
        ],
      ),
    );
  }
}
