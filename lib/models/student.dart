import 'package:cloud_firestore/cloud_firestore.dart';

class Student {
  Student({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
    required this.goal,
    required this.height,
    required this.weight,
    required this.observations,
    required this.sex,
    required this.birthDate,
    this.authUid,
    this.mustChangePassword = false,
    this.createdAt,
    this.active = true,
  });

  final String id;
  final String name;
  final String phone;
  final String email;
  final String goal;
  final double height; // metros
  final double weight; // kg
  final String observations;
  final String sex; // 'M' ou 'F'
  final DateTime birthDate;

  /// uid da conta de login do Firebase Auth deste aluno (null se ele ainda
  /// não tiver acesso próprio ao app).
  final String? authUid;

  /// true enquanto o aluno não trocou a senha temporária do primeiro acesso.
  final bool mustChangePassword;

  /// Quando o cadastro foi criado. Null para alunos antigos, cadastrados
  /// antes deste campo existir.
  final DateTime? createdAt;

  /// false para um aluno desligado/inativo (matrícula trancada etc.) — o
  /// cadastro e o histórico continuam existindo, só fica marcado como
  /// inativo em vez de excluído.
  final bool active;

  double get bmi => height <= 0 ? 0 : weight / (height * height);

  int ageAt(DateTime date) {
    var age = date.year - birthDate.year;
    final beforeBirthdayThisYear = date.month < birthDate.month ||
        (date.month == birthDate.month && date.day < birthDate.day);
    if (beforeBirthdayThisYear) age--;
    return age < 0 ? 0 : age;
  }

  factory Student.fromFirestore(String id, Map<String, dynamic> data) {
    final birth = data['birthDate'] as Timestamp?;
    final created = data['createdAt'] as Timestamp?;
    return Student(
      id: id,
      name: data['name'] as String? ?? '',
      phone: data['phone'] as String? ?? '',
      email: data['email'] as String? ?? '',
      goal: data['goal'] as String? ?? 'Não informado',
      height: (data['height'] as num?)?.toDouble() ?? 0,
      weight: (data['weight'] as num?)?.toDouble() ?? 0,
      observations: data['observations'] as String? ?? '',
      sex: data['sex'] as String? ?? 'M',
      birthDate: birth?.toDate() ?? DateTime(2000, 1, 1),
      authUid: data['authUid'] as String?,
      mustChangePassword: data['mustChangePassword'] as bool? ?? false,
      createdAt: created?.toDate(),
      active: data['active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toMap(String ownerUid) => {
        'ownerUid': ownerUid,
        'name': name,
        'phone': phone,
        'email': email,
        'goal': goal,
        'height': height,
        'weight': weight,
        'observations': observations,
        'sex': sex,
        'birthDate': Timestamp.fromDate(birthDate),
        'authUid': authUid,
        'mustChangePassword': mustChangePassword,
        'createdAt': FieldValue.serverTimestamp(),
        'active': true,
      };

  Map<String, dynamic> toUpdateMap() => {
        'name': name,
        'phone': phone,
        'email': email,
        'goal': goal,
        'height': height,
        'weight': weight,
        'observations': observations,
        'sex': sex,
        'birthDate': Timestamp.fromDate(birthDate),
        'active': active,
      };
}
