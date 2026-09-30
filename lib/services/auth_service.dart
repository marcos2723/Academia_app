import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<String?> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    }
  }

  Future<void> signOut() => _auth.signOut();

  Future<String?> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    }
  }

  /// Confirma a senha atual antes de permitir uma troca de senha — o
  /// Firebase exige um login "recente" para operações sensíveis como essa.
  Future<String?> reauthenticate(String currentPassword) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return 'Sessão inválida.';
      final credential = EmailAuthProvider.credential(email: user.email!, password: currentPassword);
      await user.reauthenticateWithCredential(credential);
      return null;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
        return 'Senha atual incorreta.';
      }
      return _mapError(e);
    }
  }

  Future<String?> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
      return null;
    } on FirebaseAuthException catch (e) {
      return _mapError(e);
    }
  }

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'Usuário não encontrado.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-mail ou senha inválidos.';
      case 'email-already-in-use':
        return 'Este e-mail já está cadastrado.';
      case 'weak-password':
        return 'A senha precisa ter pelo menos 6 caracteres.';
      case 'invalid-email':
        return 'E-mail inválido.';
      default:
        return 'Erro ao autenticar (${e.code}).';
    }
  }
}
