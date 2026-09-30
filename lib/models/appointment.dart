import 'package:cloud_firestore/cloud_firestore.dart';

/// Um horário agendado para uma futura avaliação física, com um personal
/// específico.
class Appointment {
  Appointment({
    required this.id,
    required this.studentId,
    required this.personalUid,
    required this.dateTime,
    required this.notes,
  });

  final String id;
  final String studentId;
  final String personalUid;
  final DateTime dateTime;
  final String notes;

  factory Appointment.fromFirestore(String id, Map<String, dynamic> data) {
    final ts = data['dateTime'] as Timestamp?;
    return Appointment(
      id: id,
      studentId: data['studentId'] as String? ?? '',
      personalUid: data['personalUid'] as String? ?? '',
      dateTime: ts?.toDate() ?? DateTime.now(),
      notes: data['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap(String ownerUid) => {
        'ownerUid': ownerUid,
        'studentId': studentId,
        'personalUid': personalUid,
        'dateTime': Timestamp.fromDate(dateTime),
        'notes': notes,
      };
}
