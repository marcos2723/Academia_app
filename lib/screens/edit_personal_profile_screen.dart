import 'package:flutter/material.dart';

/// Tela dedicada para editar nome e telefone do próprio personal.
class EditPersonalProfileScreen extends StatefulWidget {
  const EditPersonalProfileScreen({
    super.key,
    required this.initialName,
    required this.initialPhone,
    required this.onSave,
  });

  final String initialName;
  final String initialPhone;
  final Future<void> Function({required String name, required String phone}) onSave;

  @override
  State<EditPersonalProfileScreen> createState() => _EditPersonalProfileScreenState();
}

class _EditPersonalProfileScreenState extends State<EditPersonalProfileScreen> {
  late final _name = TextEditingController(text: widget.initialName);
  late final _phone = TextEditingController(text: widget.initialPhone);
  bool saving = false;
  String? error;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => error = 'Informe seu nome.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    await widget.onSave(name: _name.text.trim(), phone: _phone.text.trim());
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nome', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Telefone',
                  hintText: 'DDD + número',
                  border: OutlineInputBorder(),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: saving ? null : _save,
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Salvar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
