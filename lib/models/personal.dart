/// Um usuário do tipo "personal" (profissional) — o único tipo de usuário
/// além do aluno. Todos os personais compartilham acesso a todos os alunos.
class Personal {
  Personal({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.mustChangePassword = false,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;

  /// true enquanto a pessoa não trocou a senha temporária do primeiro
  /// acesso (só se aplica a contas criadas por outro personal; a conta
  /// "chefe", criada manualmente no Console, não passa por isso).
  final bool mustChangePassword;

  factory Personal.fromFirestore(String uid, Map<String, dynamic> data) {
    return Personal(
      uid: uid,
      name: data['name'] as String? ?? '',
      email: data['email'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      mustChangePassword: data['mustChangePassword'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'phone': phone,
        'mustChangePassword': mustChangePassword,
      };
}
