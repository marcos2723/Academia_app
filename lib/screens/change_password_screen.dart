import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Tela de troca de senha obrigatória no primeiro acesso — usada tanto
/// para o aluno (senha provisória enviada por WhatsApp) quanto para um
/// personal recém-cadastrado por um colega.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, required this.onChanged});

  /// Chamado depois que a senha no Firebase Auth já foi trocada com
  /// sucesso — aqui quem chama grava, no Firestore, que a pessoa não
  /// precisa mais trocar a senha (aluno ou personal).
  final Future<void> Function() onChanged;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _auth = AuthService();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool showPassword = false;
  bool saving = false;
  String? error;

  Future<void> _submit() async {
    if (_password.text.length < 6) {
      setState(() => error = 'A senha precisa ter pelo menos 6 caracteres.');
      return;
    }
    if (_password.text != _confirm.text) {
      setState(() => error = 'As senhas não coincidem.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    final result = await _auth.updatePassword(_password.text);
    if (result != null) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = result;
      });
      return;
    }
    await widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_reset, size: 40),
                const SizedBox(height: 12),
                Text('Crie sua senha', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'Defina uma senha nova para continuar.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 22),
                TextField(
                  controller: _password,
                  obscureText: !showPassword,
                  decoration: InputDecoration(
                    labelText: 'Nova senha',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => showPassword = !showPassword),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _confirm,
                  obscureText: !showPassword,
                  decoration: const InputDecoration(labelText: 'Confirmar nova senha', border: OutlineInputBorder()),
                ),
                if (error != null) ...[
                  const SizedBox(height: 10),
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: saving ? null : _submit,
                    child: saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Salvar e continuar'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
