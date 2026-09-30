import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Cria contas de login (Firebase Auth) para novos alunos ou novos personais
/// SEM deslogar quem está usando o app no momento.
///
/// O SDK do Firebase Auth, se você chamar createUserWithEmailAndPassword
/// no app principal enquanto já há alguém logado, troca a sessão atual
/// para o usuário recém-criado — o que expulsaria a personal que está
/// cadastrando o aluno. Para evitar isso, a conta é criada numa instância
/// secundária e independente do Firebase, e a sessão principal nunca é
/// tocada.
class AccountProvisioningService {
  static const _secondaryAppName = 'secondary_provisioning';
  static int _counter = 0;

  /// Cria a conta e devolve o uid gerado. Lança [FirebaseAuthException] se
  /// o e-mail já estiver em uso ou a senha for inválida.
  static Future<String> createAccount({
    required String email,
    required String password,
  }) async {
    _counter++;
    final secondaryApp = await Firebase.initializeApp(
      name: '$_secondaryAppName$_counter',
      options: Firebase.app().options,
    );
    try {
      final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
      final credential = await secondaryAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = credential.user!.uid;
      await secondaryAuth.signOut();
      return uid;
    } finally {
      await secondaryApp.delete();
    }
  }

  /// Gera uma senha temporária aleatória e razoavelmente forte.
  static String generateTemporaryPassword({int length = 10}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789';
    final rand = Random.secure();
    return List.generate(length, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
