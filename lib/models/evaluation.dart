import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/body_composition.dart';

class Evaluation {
  Evaluation({
    required this.id,
    required this.studentId,
    required this.date,
    required this.weight,
    required this.height,
    // Circunferências (cm)
    required this.neck,
    required this.shoulders,
    required this.chest,
    required this.waist,
    required this.hip,
    required this.armRight,
    required this.armLeft,
    required this.forearmRight,
    required this.forearmLeft,
    required this.thighRight,
    required this.thighLeft,
    required this.calfRight,
    required this.calfLeft,
    // Dobras cutâneas (mm)
    required this.skinfoldChest,
    required this.skinfoldAbdominal,
    required this.skinfoldThigh,
    required this.skinfoldTriceps,
    required this.skinfoldSubscapular,
    required this.skinfoldSuprailiac,
    required this.skinfoldMidaxillary,
    // Resultado calculado no momento do lançamento
    required this.bodyFat,
  });

  final String id;
  final String studentId;
  final DateTime date;
  final double weight; // kg
  final double height; // m

  final double neck;
  final double shoulders;
  final double chest;
  final double waist;
  final double hip;
  final double armRight;
  final double armLeft;
  final double forearmRight;
  final double forearmLeft;
  final double thighRight;
  final double thighLeft;
  final double calfRight;
  final double calfLeft;

  final double skinfoldChest;
  final double skinfoldAbdominal;
  final double skinfoldThigh;
  final double skinfoldTriceps;
  final double skinfoldSubscapular;
  final double skinfoldSuprailiac;
  final double skinfoldMidaxillary;

  /// % de gordura corporal já calculado (Pollock 7 dobras + Siri) no
  /// momento em que a avaliação foi lançada.
  final double bodyFat;

  double get bmi => height <= 0 ? 0 : weight / (height * height);
  double get leanMassPercent => (100 - bodyFat).clamp(0, 100);
  double get leanMassKg => weight * (leanMassPercent / 100);
  double get skinfoldSum => SkinfoldMeasurements(
        chest: skinfoldChest,
        abdominal: skinfoldAbdominal,
        thigh: skinfoldThigh,
        triceps: skinfoldTriceps,
        subscapular: skinfoldSubscapular,
        suprailiac: skinfoldSuprailiac,
        midaxillary: skinfoldMidaxillary,
      ).sum;

  factory Evaluation.fromFirestore(String id, Map<String, dynamic> data) {
    final timestamp = data['date'] as Timestamp?;
    double d(String key) => (data[key] as num?)?.toDouble() ?? 0;
    return Evaluation(
      id: id,
      studentId: data['studentId'] as String? ?? '',
      date: timestamp?.toDate() ?? DateTime.now(),
      weight: d('weight'),
      height: d('height'),
      neck: d('neck'),
      shoulders: d('shoulders'),
      chest: d('chest'),
      waist: d('waist'),
      hip: d('hip'),
      armRight: d('armRight'),
      armLeft: d('armLeft'),
      forearmRight: d('forearmRight'),
      forearmLeft: d('forearmLeft'),
      thighRight: d('thighRight'),
      thighLeft: d('thighLeft'),
      calfRight: d('calfRight'),
      calfLeft: d('calfLeft'),
      skinfoldChest: d('skinfoldChest'),
      skinfoldAbdominal: d('skinfoldAbdominal'),
      skinfoldThigh: d('skinfoldThigh'),
      skinfoldTriceps: d('skinfoldTriceps'),
      skinfoldSubscapular: d('skinfoldSubscapular'),
      skinfoldSuprailiac: d('skinfoldSuprailiac'),
      skinfoldMidaxillary: d('skinfoldMidaxillary'),
      bodyFat: d('bodyFat'),
    );
  }

  Map<String, dynamic> toMap(String ownerUid) => {
        'ownerUid': ownerUid,
        'studentId': studentId,
        'date': Timestamp.fromDate(date),
        'weight': weight,
        'height': height,
        'neck': neck,
        'shoulders': shoulders,
        'chest': chest,
        'waist': waist,
        'hip': hip,
        'armRight': armRight,
        'armLeft': armLeft,
        'forearmRight': forearmRight,
        'forearmLeft': forearmLeft,
        'thighRight': thighRight,
        'thighLeft': thighLeft,
        'calfRight': calfRight,
        'calfLeft': calfLeft,
        'skinfoldChest': skinfoldChest,
        'skinfoldAbdominal': skinfoldAbdominal,
        'skinfoldThigh': skinfoldThigh,
        'skinfoldTriceps': skinfoldTriceps,
        'skinfoldSubscapular': skinfoldSubscapular,
        'skinfoldSuprailiac': skinfoldSuprailiac,
        'skinfoldMidaxillary': skinfoldMidaxillary,
        'bodyFat': bodyFat,
      };
}
