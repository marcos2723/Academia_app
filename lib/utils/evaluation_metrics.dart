import 'package:flutter/material.dart';
import '../models/evaluation.dart';

class Metric {
  const Metric(this.label, this.unit, this.extract);
  final String label;
  final String unit;
  final double Function(Evaluation e) extract;
}

class MetricCategory {
  const MetricCategory(this.label, this.icon, this.metrics);
  final String label;
  final IconData icon;
  final List<Metric> metrics;
}

final List<MetricCategory> evaluationMetricCategories = [
  MetricCategory('Peso', Icons.monitor_weight_outlined, [
    Metric('Peso', 'kg', (e) => e.weight),
    Metric('IMC', '', (e) => e.bmi),
    Metric('% Gordura', '%', (e) => e.bodyFat),
    Metric('% Massa magra', '%', (e) => e.leanMassPercent),
    Metric('Massa magra', 'kg', (e) => e.leanMassKg),
  ]),
  MetricCategory('Tórax', Icons.accessibility_new_outlined, [
    Metric('Tórax', 'cm', (e) => e.chest),
    Metric('Ombros', 'cm', (e) => e.shoulders),
    Metric('Cintura', 'cm', (e) => e.waist),
    Metric('Quadril', 'cm', (e) => e.hip),
    Metric('Pescoço', 'cm', (e) => e.neck),
  ]),
  MetricCategory('Braços', Icons.fitness_center, [
    Metric('Bíceps direito', 'cm', (e) => e.armRight),
    Metric('Bíceps esquerdo', 'cm', (e) => e.armLeft),
    Metric('Antebraço direito', 'cm', (e) => e.forearmRight),
    Metric('Antebraço esquerdo', 'cm', (e) => e.forearmLeft),
  ]),
  MetricCategory('Pernas', Icons.directions_walk, [
    Metric('Coxa direita', 'cm', (e) => e.thighRight),
    Metric('Coxa esquerda', 'cm', (e) => e.thighLeft),
    Metric('Panturrilha direita', 'cm', (e) => e.calfRight),
    Metric('Panturrilha esquerda', 'cm', (e) => e.calfLeft),
  ]),
];
