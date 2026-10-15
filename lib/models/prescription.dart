import 'package:cloud_firestore/cloud_firestore.dart';

/// Situação da receita. Só as emitidas (e canceladas) aparecem ao aluno.
/// A assinatura é feita à mão pela personal, na receita impressa.
enum PrescriptionStatus { draft, signed, revoked }

extension PrescriptionStatusInfo on PrescriptionStatus {
  String get label => switch (this) {
        PrescriptionStatus.draft => 'Rascunho',
        PrescriptionStatus.signed => 'Emitida',
        PrescriptionStatus.revoked => 'Cancelada',
      };
}

PrescriptionStatus prescriptionStatusFromString(String? value) =>
    PrescriptionStatus.values.firstWhere((s) => s.name == value, orElse: () => PrescriptionStatus.draft);

/// Formas farmacêuticas mais comuns em manipulados.
const List<String> kPharmaceuticalForms = [
  'Cápsula',
  'Sachê',
  'Pó',
  'Solução oral',
  'Gotas',
  'Creme',
  'Gel',
  'Goma',
  'Outra',
];

/// Um componente da fórmula (ex.: "Cafeína anidra" — "200 mg").
class PrescriptionComponent {
  PrescriptionComponent({required this.name, required this.amount});

  final String name;
  final String amount;

  factory PrescriptionComponent.fromMap(Map<String, dynamic> m) => PrescriptionComponent(
        name: m['name'] as String? ?? '',
        amount: m['amount'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {'name': name, 'amount': amount};
}

/// Um manipulado da receita.
class PrescriptionItem {
  PrescriptionItem({
    required this.name,
    required this.form,
    required this.quantity,
    required this.components,
    required this.posology,
  });

  final String name;
  final String form;

  /// Quantidade a manipular (ex.: "60 cápsulas").
  final String quantity;
  final List<PrescriptionComponent> components;

  /// Como usar (ex.: "1 cápsula pela manhã, 30 min antes do treino").
  final String posology;

  factory PrescriptionItem.fromMap(Map<String, dynamic> m) => PrescriptionItem(
        name: m['name'] as String? ?? '',
        form: m['form'] as String? ?? kPharmaceuticalForms.first,
        quantity: m['quantity'] as String? ?? '',
        components: ((m['components'] as List?) ?? const [])
            .map((e) => PrescriptionComponent.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        posology: m['posology'] as String? ?? '',
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'form': form,
        'quantity': quantity,
        'components': components.map((c) => c.toMap()).toList(),
        'posology': posology,
      };
}

/// Receita de manipulados montada pela personal para um aluno.
class Prescription {
  Prescription({
    required this.id,
    required this.studentId,
    required this.personalUid,
    required this.personalName,
    required this.title,
    required this.items,
    required this.createdAt,
    this.notes = '',
    this.validityDays = 30,
    this.status = PrescriptionStatus.draft,
    this.signedAt,
    this.councilType,
    this.councilNumber,
    this.councilState,
    this.code,
  });

  final String id;
  final String studentId;
  final String personalUid;
  final String personalName;
  final String title;
  final List<PrescriptionItem> items;
  final DateTime createdAt;

  /// Orientações gerais ao aluno e à farmácia.
  final String notes;
  final int validityDays;
  final PrescriptionStatus status;

  final DateTime? signedAt;

  /// Registro profissional de quem assinou (ex.: CRN, 12345, MG).
  final String? councilType;
  final String? councilNumber;
  final String? councilState;

  /// Código de validação gerado na emissão.
  final String? code;

  bool get isSigned => status == PrescriptionStatus.signed;
  bool get isDraft => status == PrescriptionStatus.draft;

  DateTime? get validUntil => signedAt == null ? null : signedAt!.add(Duration(days: validityDays));

  bool get isExpired => isSigned && validUntil != null && DateTime.now().isAfter(validUntil!);

  /// Ex.: "CRN 12345/MG".
  String? get registration {
    if (councilType == null || councilNumber == null) return null;
    final uf = (councilState ?? '').isEmpty ? '' : '/$councilState';
    return '$councilType $councilNumber$uf';
  }

  factory Prescription.fromFirestore(String id, Map<String, dynamic> d) {
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    return Prescription(
      id: id,
      studentId: d['studentId'] as String? ?? '',
      personalUid: d['personalUid'] as String? ?? '',
      personalName: d['personalName'] as String? ?? '',
      title: d['title'] as String? ?? 'Receita de manipulados',
      items: ((d['items'] as List?) ?? const [])
          .map((e) => PrescriptionItem.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      createdAt: ts(d['createdAt']) ?? DateTime.now(),
      notes: d['notes'] as String? ?? '',
      validityDays: (d['validityDays'] as num?)?.toInt() ?? 30,
      status: prescriptionStatusFromString(d['status'] as String?),
      signedAt: ts(d['signedAt']),
      councilType: d['councilType'] as String?,
      councilNumber: d['councilNumber'] as String?,
      councilState: d['councilState'] as String?,
      code: d['code'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'personalUid': personalUid,
        'personalName': personalName,
        'title': title,
        'items': items.map((i) => i.toMap()).toList(),
        'createdAt': Timestamp.fromDate(createdAt),
        'notes': notes,
        'validityDays': validityDays,
        'status': status.name,
        'signedAt': signedAt == null ? null : Timestamp.fromDate(signedAt!),
        'councilType': councilType,
        'councilNumber': councilNumber,
        'councilState': councilState,
        'code': code,
      };

  Prescription copyWith({
    String? title,
    List<PrescriptionItem>? items,
    String? notes,
    int? validityDays,
    PrescriptionStatus? status,
    DateTime? signedAt,
    String? councilType,
    String? councilNumber,
    String? councilState,
    String? code,
  }) =>
      Prescription(
        id: id,
        studentId: studentId,
        personalUid: personalUid,
        personalName: personalName,
        title: title ?? this.title,
        items: items ?? this.items,
        createdAt: createdAt,
        notes: notes ?? this.notes,
        validityDays: validityDays ?? this.validityDays,
        status: status ?? this.status,
        signedAt: signedAt ?? this.signedAt,
        councilType: councilType ?? this.councilType,
        councilNumber: councilNumber ?? this.councilNumber,
        councilState: councilState ?? this.councilState,
        code: code ?? this.code,
      );
}
