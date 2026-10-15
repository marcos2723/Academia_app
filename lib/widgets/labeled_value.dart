import 'package:flutter/material.dart';

/// Linha de dado no formato "Rótulo: Valor" (ex.: "Nome: Marcos Paulo").
/// O rótulo fica em destaque e o valor em texto normal. Se o valor estiver
/// vazio, mostra "—" em vez de deixar o rótulo solto.
class LabeledValue extends StatelessWidget {
  const LabeledValue({
    super.key,
    required this.label,
    required this.value,
    this.padding = const EdgeInsets.only(bottom: 4),
  });

  final String label;
  final String value;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.bodyMedium;
    final shown = value.trim().isEmpty ? '—' : value;
    return Padding(
      padding: padding,
      child: Text.rich(
        TextSpan(
          style: base,
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.w600)),
            TextSpan(text: shown),
          ],
        ),
      ),
    );
  }
}
