import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// Tela dedicada de "Esqueci minha senha". Funciona tanto para personal
/// quanto para aluno — os dois usam a mesma tela de login.
///
/// Importante: o Firebase (sem um servidor próprio pago) nunca envia uma
/// senha em texto puro por e-mail — isso não existe por segurança. O
/// mecanismo real e gratuito é enviar um link de redefinição: a pessoa
/// clica, define a senha nova ela mesma, e já pode entrar no app com essa
/// senha (sem precisar saber a antiga). O resultado final é o mesmo de
/// "receber uma senha nova e conseguir entrar" — só muda o meio.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _auth = AuthService();
  final _email = TextEditingController();
  bool sending = false;
  String? error;
  bool sent = false;

  Future<void> _submit() async {
    if (!_email.text.contains('@')) {
      setState(() => error = 'Informe um e-mail válido.');
      return;
    }
    setState(() {
      sending = true;
      error = null;
    });
    final result = await _auth.sendPasswordReset(_email.text.trim());
    if (!mounted) return;
    setState(() {
      sending = false;
      error = result;
      sent = result == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Esqueci minha senha')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  sent ? Icons.mark_email_read_outlined : Icons.email_outlined,
                  size: 40,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),
                if (!sent) ...[
                  Text(
                    'Informe seu e-mail para receber o link de nova senha.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'E-mail',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
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
                      onPressed: sending ? null : _submit,
                      child: sending
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Enviar link de redefinição'),
                    ),
                  ),
                ] else ...[
                  Text(
                    'E-mail enviado! Confira também o spam.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Voltar para o login'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
