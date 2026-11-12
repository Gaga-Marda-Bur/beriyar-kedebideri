import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'erfe_input_formatter.dart';
import 'transliteration.dart';

Future<void> showTransliterationDialog(
  BuildContext context,
  TextEditingController controller, {
  VoidCallback? onChanged,
}) async {
  final original = controller.value;
  final selected =
      original.selection.isValid && !original.selection.isCollapsed;
  final start = selected ? original.selection.start : 0;
  final end = selected ? original.selection.end : original.text.length;
  final input = TextEditingController(
    text: original.text.substring(start, end),
  );
  var source = WritingScript.erfe;
  var target = WritingScript.latin;
  var latinLowercase = false;
  TransliterationResult? result;
  final output = TextEditingController();
  final applied = await showDialog<String>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Erfe ↔ Latin ↔ Arabe'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Conversion explicite, pas une traduction. La sélection est utilisée lorsqu’elle existe.',
                ),
                TextField(
                  key: const Key('conversion-input'),
                  controller: input,
                  minLines: 2,
                  maxLines: 5,
                  inputFormatters: const [ErfeInputFormatter()],
                  style: const TextStyle(fontFamilyFallback: ['Kedebideri']),
                  decoration: const InputDecoration(labelText: 'Texte source'),
                  onChanged: (_) => setState(() {
                    result = null;
                    output.clear();
                  }),
                ),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButton<WritingScript>(
                        value: source,
                        items: _items(),
                        onChanged: (v) => setState(() {
                          source = v!;
                          result = null;
                          output.clear();
                        }),
                      ),
                    ),
                    const Icon(Icons.arrow_forward),
                    Expanded(
                      child: DropdownButton<WritingScript>(
                        value: target,
                        items: _items(),
                        onChanged: (v) => setState(() {
                          target = v!;
                          result = null;
                          output.clear();
                        }),
                      ),
                    ),
                  ],
                ),
                FilledButton(
                  onPressed: () => setState(() {
                    result = transliterate(
                      input.text,
                      source,
                      target,
                      latinLowercase: latinLowercase,
                    );
                    output.text = result!.text;
                  }),
                  child: const Text('Convertir'),
                ),
                CheckboxListTile(
                  title: const Text('Latin en minuscules'),
                  value: latinLowercase,
                  onChanged: (v) => setState(() {
                    latinLowercase = v!;
                    result = null;
                    output.clear();
                  }),
                ),
                TextField(
                  key: const Key('conversion-output'),
                  controller: output,
                  readOnly: true,
                  minLines: 2,
                  maxLines: 5,
                  textDirection: target == WritingScript.arabic
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  style: const TextStyle(fontFamilyFallback: ['Kedebideri']),
                  decoration: const InputDecoration(labelText: 'Résultat'),
                ),
                if (result != null && result!.unmapped.isNotEmpty)
                  Text(
                    'Conservés sans correspondance : ${result!.unmapped.map((c) => c['codepoint']).join(', ')}',
                  ),
                TextButton.icon(
                  onPressed: result == null
                      ? null
                      : () => Clipboard.setData(
                          ClipboardData(text: result!.text),
                        ),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copier'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          TextButton(
            onPressed: result == null
                ? null
                : () => Navigator.pop(context, result!.text),
            child: const Text('Insérer'),
          ),
        ],
      ),
    ),
  );
  // Dialog controls can still be in the navigator's exit animation; dispose later.
  Future<void>.delayed(const Duration(seconds: 1), () {
    input.dispose();
    output.dispose();
  });
  if (applied == null || !context.mounted || controller.value != original) {
    return;
  }
  controller.value = TextEditingValue(
    text: original.text.replaceRange(start, end, applied),
    selection: TextSelection.collapsed(offset: start + applied.length),
  );
  onChanged?.call();
  final insertedText = controller.text;
  ScaffoldMessenger.maybeOf(context)?.showSnackBar(
    SnackBar(
      content: const Text('Conversion insérée'),
      action: SnackBarAction(
        label: 'Annuler',
        onPressed: () {
          if (!context.mounted || controller.text != insertedText) return;
          controller.value = original;
          onChanged?.call();
        },
      ),
    ),
  );
}

List<DropdownMenuItem<WritingScript>> _items() => const [
  DropdownMenuItem(value: WritingScript.erfe, child: Text('Erfe')),
  DropdownMenuItem(value: WritingScript.latin, child: Text('Latin')),
  DropdownMenuItem(value: WritingScript.arabic, child: Text('Arabe')),
];
