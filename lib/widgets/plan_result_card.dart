import 'package:flutter/material.dart';
import '../models/checkin.dart';
import '../models/evaluation.dart';
import '../models/plan.dart';
import '../utils/adherence.dart';
import '../utils/formatters.dart';

/// Avaliações de referência de um plano: a do início e a mais recente
/// dentro da vigência (ou a gravada no encerramento do ciclo).
({Evaluation? initial, Evaluation? last}) planReferenceEvaluations(Plan plan, List<Evaluation> all) {
  if (all.isEmpty) return (initial: null, last: null);
  final sorted = all.toList()..sort((a, b) => a.date.compareTo(b.date));
  Evaluation? byId(String? id) {
    if (id == null) return null;
    final m = sorted.where((e) => e.id == id);
    return m.isEmpty ? null : m.first;
  }

  var initial = byId(plan.initialEvaluationId);
  if (initial == null) {
    final start = dateOnly(plan.startDate);
    initial = sorted.reduce(
      (a, b) => a.date.difference(start).abs() <= b.date.difference(start).abs() ? a : b,
    );
  }

  var last = byId(plan.finalEvaluationId);
  if (last == null) {
    final limit = dateOnly(plan.endDate).add(const Duration(days: 1));
    final inside = sorted.where((e) => e.date.isBefore(limit) && e.date.isAfter(initial!.date)).toList();
    last = inside.isEmpty ? null : inside.last;
  }
  if (last != null && last.id == initial.id) last = null;
  return (initial: initial, last: last);
}

/// "Resultado do plano": avaliação inicial x final + adesão.
class PlanResultCard extends StatelessWidget {
  const PlanResultCard({super.key, required this.plan, required this.evaluations, required this.checkins});

  final Plan plan;
  final List<Evaluation> evaluations;
  final List<Checkin> checkins;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ref = planReferenceEvaluations(plan, evaluations);
    final initial = ref.initial;
    final last = ref.last;
    final adherence = computeAdherence(plan, checkins).percent;
    final muted = theme.colorScheme.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resultado do plano', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        if (adherence != null) Text('Adesão: ${adherence.round()}%', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 6),
        if (initial == null)
          Text('Sem avaliações.', style: theme.textTheme.bodySmall?.copyWith(color: muted))
        else if (last == null)
          Text(
            'Inicial: ${formatDate(initial.date)} · aguardando nova avaliação.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          )
        else ...[
          Text(
            '${formatDate(initial.date)} → ${formatDate(last.date)}'
            '${plan.isActive ? ' (parcial)' : ''}',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          const SizedBox(height: 8),
          _Row(label: 'Peso', unit: 'kg', from: initial.weight, to: last.weight, betterWhen: _Better.neutral),
          _Row(label: '% gordura', unit: '%', from: initial.bodyFat, to: last.bodyFat, betterWhen: _Better.lower),
          _Row(label: 'Massa magra', unit: 'kg', from: initial.leanMassKg, to: last.leanMassKg, betterWhen: _Better.higher),
          _Row(label: 'Cintura', unit: 'cm', from: initial.waist, to: last.waist, betterWhen: _Better.lower),
        ],
      ],
    );
  }
}

enum _Better { lower, higher, neutral }

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.unit, required this.from, required this.to, required this.betterWhen});

  final String label;
  final String unit;
  final double from;
  final double to;
  final _Better betterWhen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final diff = to - from;
    final flat = diff.abs() < 0.05;
    Color color = theme.colorScheme.onSurfaceVariant;
    if (!flat && betterWhen != _Better.neutral) {
      final good = betterWhen == _Better.lower ? diff < 0 : diff > 0;
      color = good
          ? (dark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A))
          : (dark ? const Color(0xFFF87171) : const Color(0xFFDC2626));
    }
    final sign = diff > 0 ? '+' : '';
    final icon = flat ? Icons.trending_flat : (diff > 0 ? Icons.trending_up : Icons.trending_down);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(label, style: theme.textTheme.bodyMedium)),
          Expanded(
            flex: 4,
            child: Text(
              '${from.toStringAsFixed(1)} → ${to.toStringAsFixed(1)} $unit',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          SizedBox(
            width: 52,
            child: Text(
              '$sign${diff.toStringAsFixed(1)}',
              textAlign: TextAlign.end,
              style: TextStyle(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
