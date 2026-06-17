import 'package:flutter/material.dart';

import '../data/beriya_official_chars.dart';
import '../../../l10n/generated/app_localizations.dart';

class StickerBeriyaKeyboard extends StatelessWidget {
  const StickerBeriyaKeyboard({
    super.key,
    required this.onInsert,
    required this.onBackspace,
    required this.onSpace,
    required this.onClear,
  });

  final ValueChanged<String> onInsert;
  final VoidCallback onBackspace;
  final VoidCallback onSpace;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F3227).withAlpha(230),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFD4AF37).withAlpha(77),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: beriyaOfficialChars.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1.15,
            ),
            itemBuilder: (context, index) {
              final char = beriyaOfficialChars[index];

              return _KeyButton(
                label: char,
                isBeriya: true,
                onTap: () => onInsert(char),
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _KeyButton(
                  label: loc.keyboardSpace,
                  onTap: onSpace,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KeyButton(
                  label: loc.keyboardBackspace,
                  onTap: onBackspace,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KeyButton(
                  label: loc.keyboardClear,
                  onTap: onClear,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.onTap,
    this.isBeriya = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isBeriya;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(20),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: isBeriya ? 26 : 13,
              fontFamily: isBeriya ? 'Kedebideri' : null,
            ),
          ),
        ),
      ),
    );
  }
}