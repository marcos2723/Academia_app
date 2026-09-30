import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/personal.dart';
import '../models/callbacks.dart';
import '../services/app_exceptions.dart';
import '../widgets/page_shell.dart';

class PersonalsPage extends StatelessWidget {
  const PersonalsPage({
    super.key,
    required this.currentUid,
    required this.personals,
    required this.onAddPersonal,
  });

  final String currentUid;
  final List<Personal> personals;
  final AddPersonalCallback onAddPersonal;

  Future<void> _openNewPersonalForm(BuildContext context) async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    bool saving = false;
    String? errorText;
    String? createdPassword;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Novo personal'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (createdPassword == null) ...[
                  TextField(controller: name, decoration: const InputDecoration(labelText: 'Nome')),
                  const SizedBox(height: 10),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'E-mail'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'Telefone', hintText: 'DDD + número'),
                  ),
                  if (errorText != null) ...[
                    const SizedBox(height: 10),
                    Text(errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                ] else ...[
                  Text('Conta criada para ${name.text.trim()}!', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Text('E-mail: ${email.text.trim()}'),
                  Text('Senha temporária: $createdPassword'),
                  const SizedBox(height: 10),
                  Text(
                    'Passe esses dados para a pessoa entrar; ela pode trocar a senha depois em '
                    '"Esqueci minha senha" na tela de login, ou na aba Perfil já logada.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (createdPassword == null) ...[
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (name.text.trim().isEmpty || !email.text.contains('@')) {
                          setDialogState(() => errorText = 'Informe nome e e-mail válidos.');
                          return;
                        }
                        if (phone.text.trim().isEmpty) {
                          setDialogState(() => errorText = 'Informe o telefone.');
                          return;
                        }
                        setDialogState(() {
                          saving = true;
                          errorText = null;
                        });
                        try {
                          final password = await onAddPersonal(
                            name: name.text.trim(),
                            email: email.text.trim(),
                            phone: phone.text.trim(),
                          );
                          setDialogState(() {
                            saving = false;
                            createdPassword = password;
                          });
                        } on AppException catch (e) {
                          setDialogState(() {
                            saving = false;
                            errorText = e.message;
                          });
                        } on FirebaseAuthException catch (e) {
                          setDialogState(() {
                            saving = false;
                            errorText = e.code == 'email-already-in-use'
                                ? 'Este e-mail já está em uso.'
                                : 'Erro ao criar conta (${e.code}).';
                          });
                        }
                      },
                child: saving
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Criar conta'),
              ),
            ] else
              FilledButton(onPressed: () => Navigator.pop(context), child: const Text('Concluído')),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'Equipe',
      subtitle: 'Personais da academia.',
      action: FilledButton.icon(
        onPressed: () => _openNewPersonalForm(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Novo personal'),
      ),
      child: personals.isEmpty
          ? const Center(child: Text('Nenhum personal cadastrado ainda.'))
          : ListView.separated(
              itemCount: personals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final p = personals[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(child: Text(p.name.isEmpty ? '?' : p.name[0].toUpperCase())),
                    title: Text(p.name.isEmpty ? p.email : p.name),
                    subtitle: Text(p.phone.isEmpty ? p.email : '${p.email}\n${p.phone}'),
                    isThreeLine: p.phone.isNotEmpty,
                    trailing: p.uid == currentUid ? const Chip(label: Text('Você')) : null,
                  ),
                );
              },
            ),
    );
  }
}
