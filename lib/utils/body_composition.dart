/// Cálculo de composição corporal pelo protocolo de 7 dobras cutâneas
/// de Jackson & Pollock (1978), amplamente usado em avaliações físicas
/// de academia. Dobras em milímetros (mm), idade em anos completos.
class SkinfoldMeasurements {
  const SkinfoldMeasurements({
    required this.chest,
    required this.abdominal,
    required this.thigh,
    required this.triceps,
    required this.subscapular,
    required this.suprailiac,
    required this.midaxillary,
  });

  final double chest; // peitoral
  final double abdominal;
  final double thigh; // coxa
  final double triceps;
  final double subscapular; // subescapular
  final double suprailiac; // supra-ilíaca
  final double midaxillary; // axilar média

  double get sum =>
      chest + abdominal + thigh + triceps + subscapular + suprailiac + midaxillary;
}

/// Densidade corporal pela equação de Jackson & Pollock (7 dobras).
double bodyDensityPollock7({
  required String sex,
  required int age,
  required double sumSkinfoldsMm,
}) {
  final s = sumSkinfoldsMm;
  if (sex == 'F') {
    return 1.097 - 0.00046971 * s + 0.00000056 * s * s - 0.00012828 * age;
  }
  return 1.112 - 0.00043499 * s + 0.00000055 * s * s - 0.00028826 * age;
}

/// Converte densidade corporal em % de gordura pela equação de Siri (1961).
double bodyFatFromDensity(double density) => density <= 0 ? 0 : (495 / density) - 450;

double calculateBodyFatPercent({
  required String sex,
  required int age,
  required SkinfoldMeasurements skinfolds,
}) {
  final density = bodyDensityPollock7(sex: sex, age: age, sumSkinfoldsMm: skinfolds.sum);
  final percent = bodyFatFromDensity(density);
  return percent.clamp(2, 60);
}
