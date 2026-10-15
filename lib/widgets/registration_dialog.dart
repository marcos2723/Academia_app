import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Registro profissional informado ao emitir uma receita.
class RegistrationResult {
  RegistrationResult({
    required this.councilType,
    required this.councilNumber,
    required this.councilState,
  });

  final String councilType;
  final String councilNumber;
  final String councilState;
}

const List<String> kCouncils = ['CRN', 'CRM', 'CRF', 'CREF', 'Outro'];

const List<String> kStates = [
  'AC', 'AL', 'AP', 'AM', 'BA', 'CE', 'DF', 'ES', 'GO', 'MA', 'MT', 'MS', 'MG', 'PA',
  'PB', 'PR', 'PE', 'PI', 'RJ', 'RN', 'RS', 'RO', 'RR', 'SC', 'SP', 'SE', 'TO',
];

/// Pede o registro profissional de quem emite a receita. Devolve null se
/// a personal cancelar.
Future<RegistrationResult?> showRegistrationDialog(BuildContext context, {required String personalName}) {
  return showDialog<RegistrationResult>(
    context: context,
    builder: (_) => _RegistrationDialog(personalName: personalName),
  );
}

class _RegistrationDialog extends StatefulWidget {
  const _RegistrationDialog({required this.personalName});
  final String personalName;

  @override
  State<_RegistrationDialog> createState() => _RegistrationDialogState();
}

class _RegistrationDialogState extends State<_RegistrationDialog> {
  final _number = TextEditingController();
  String _council = kCouncils.first;
  String _state = 'MG';
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  void _confirm() {
    if (_number.text.trim().isEmpty) {
      setState(() => _error = 'Informe o número do registro.');
      return;
    }
    Navigator.pop(
      context,
      RegistrationResult(councilType: _council, councilNumber: _number.text.trim(), councilState: _state),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Emitir receita'),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Profissional: ${widget.personalName}'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _council,
                    decoration: const InputDecoration(labelText: 'Conselho'),
                    items: [for (final c in kCouncils) DropdownMenuItem(value: c, child: Text(c))],
                    onChanged: (v) => setState(() => _council = v ?? _council),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    value: _state,
                    decoration: const InputDecoration(labelText: 'UF'),
                    items: [for (final s in kStates) DropdownMenuItem(value: s, child: Text(s))],
                    onChanged: (v) => setState(() => _state = v ?? _state),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _number,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9A-Za-z.\-]'))],
              decoration: const InputDecoration(labelText: 'Registro'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ],
        ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: _confirm, child: const Text('Emitir')),
      ],
    );
  }
}
