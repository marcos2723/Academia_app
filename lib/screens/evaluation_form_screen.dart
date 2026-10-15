import 'package:flutter/material.dart';
import '../models/student.dart';
import '../utils/formatters.dart';
import '../utils/input_formatters.dart';

typedef AddEvaluationCallback = Future<void> Function({
  required Student student,
  required double weight,
  required double height,
  required double neck,
  required double shoulders,
  required double chest,
  required double waist,
  required double hip,
  required double armRight,
  required double armLeft,
  required double forearmRight,
  required double forearmLeft,
  required double thighRight,
  required double thighLeft,
  required double calfRight,
  required double calfLeft,
  required double skinfoldChest,
  required double skinfoldAbdominal,
  required double skinfoldThigh,
  required double skinfoldTriceps,
  required double skinfoldSubscapular,
  required double skinfoldSuprailiac,
  required double skinfoldMidaxillary,
});

/// Tela cheia para lançar uma nova avaliação física, com todas as
/// circunferências e as 7 dobras cutâneas (protocolo de Pollock) usadas
/// para calcular o % de gordura automaticamente.
class EvaluationFormScreen extends StatefulWidget {
  const EvaluationFormScreen({
    super.key,
    required this.student,
    required this.onAddEvaluation,
  });

  final Student student;
  final AddEvaluationCallback onAddEvaluation;

  @override
  State<EvaluationFormScreen> createState() => _EvaluationFormScreenState();
}

class _EvaluationFormScreenState extends State<EvaluationFormScreen> {
  late final weight = TextEditingController(
    text: widget.student.weight > 0 ? widget.student.weight.toStringAsFixed(1) : '',
  );
  late final height = TextEditingController(
    text: widget.student.height > 0 ? widget.student.height.toStringAsFixed(2) : '',
  );

  final neck = TextEditingController();
  final shoulders = TextEditingController();
  final chest = TextEditingController();
  final waist = TextEditingController();
  final hip = TextEditingController();
  final armRight = TextEditingController();
  final armLeft = TextEditingController();
  final forearmRight = TextEditingController();
  final forearmLeft = TextEditingController();
  final thighRight = TextEditingController();
  final thighLeft = TextEditingController();
  final calfRight = TextEditingController();
  final calfLeft = TextEditingController();

  final skinfoldChest = TextEditingController();
  final skinfoldAbdominal = TextEditingController();
  final skinfoldThigh = TextEditingController();
  final skinfoldTriceps = TextEditingController();
  final skinfoldSubscapular = TextEditingController();
  final skinfoldSuprailiac = TextEditingController();
  final skinfoldMidaxillary = TextEditingController();

  bool saving = false;
  String? errorText;

  @override
  void dispose() {
    for (final c in [
      weight, height, neck, shoulders, chest, waist, hip,
      armRight, armLeft, forearmRight, forearmLeft,
      thighRight, thighLeft, calfRight, calfLeft,
      skinfoldChest, skinfoldAbdominal, skinfoldThigh, skinfoldTriceps,
      skinfoldSubscapular, skinfoldSuprailiac, skinfoldMidaxillary,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(TextEditingController controller, String label, {String? hint}) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: decimalInputFormatters,
      decoration: InputDecoration(labelText: label, hintText: hint, isDense: true),
    );
  }

  Widget _pairRow(Widget a, Widget b) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Expanded(child: a),
            const SizedBox(width: 12),
            Expanded(child: b),
          ],
        ),
      );

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Future<void> _save() async {
    final w = parseNumber(weight.text);
    final h = parseNumber(height.text);
    if (w == null || w <= 0 || h == null || h <= 0) {
      setState(() => errorText = 'Preencha peso e altura corretamente.');
      return;
    }
    double v(TextEditingController c) => parseNumber(c.text) ?? 0;

    setState(() {
      saving = true;
      errorText = null;
    });
    await widget.onAddEvaluation(
      student: widget.student,
      weight: w,
      height: h,
      neck: v(neck),
      shoulders: v(shoulders),
      chest: v(chest),
      waist: v(waist),
      hip: v(hip),
      armRight: v(armRight),
      armLeft: v(armLeft),
      forearmRight: v(forearmRight),
      forearmLeft: v(forearmLeft),
      thighRight: v(thighRight),
      thighLeft: v(thighLeft),
      calfRight: v(calfRight),
      calfLeft: v(calfLeft),
      skinfoldChest: v(skinfoldChest),
      skinfoldAbdominal: v(skinfoldAbdominal),
      skinfoldThigh: v(skinfoldThigh),
      skinfoldTriceps: v(skinfoldTriceps),
      skinfoldSubscapular: v(skinfoldSubscapular),
      skinfoldSuprailiac: v(skinfoldSuprailiac),
      skinfoldMidaxillary: v(skinfoldMidaxillary),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Nova avaliação · ${widget.student.name}')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            children: [
              _sectionTitle('Dados gerais'),
              _pairRow(
                _field(weight, 'Peso (kg)', hint: 'Ex: 72.5'),
                _field(height, 'Altura (m)', hint: 'Ex: 1.70'),
              ),
              const Divider(height: 8),
              _sectionTitle('Circunferências (cm)'),
              _pairRow(_field(neck, 'Pescoço'), _field(shoulders, 'Ombros')),
              _pairRow(_field(chest, 'Tórax / peito'), _field(waist, 'Cintura')),
              _pairRow(_field(hip, 'Quadril'), _field(armRight, 'Bíceps direito')),
              _pairRow(_field(armLeft, 'Bíceps esquerdo'), _field(forearmRight, 'Antebraço direito')),
              _pairRow(_field(forearmLeft, 'Antebraço esquerdo'), _field(thighRight, 'Coxa direita')),
              _pairRow(_field(thighLeft, 'Coxa esquerda'), _field(calfRight, 'Panturrilha direita')),
              _pairRow(_field(calfLeft, 'Panturrilha esquerda'), const SizedBox.shrink()),
              const Divider(height: 8),
              _sectionTitle('Dobras cutâneas (mm) — protocolo Pollock 7 dobras'),
              const SizedBox(height: 12),
              _pairRow(_field(skinfoldChest, 'Peitoral'), _field(skinfoldAbdominal, 'Abdominal')),
              _pairRow(_field(skinfoldThigh, 'Coxa'), _field(skinfoldTriceps, 'Tríceps')),
              _pairRow(_field(skinfoldSubscapular, 'Subescapular'), _field(skinfoldSuprailiac, 'Supra-ilíaca')),
              _pairRow(_field(skinfoldMidaxillary, 'Axilar média'), const SizedBox.shrink()),
              if (errorText != null) ...[
                const SizedBox(height: 6),
                Text(errorText!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: saving ? null : _save,
                child: saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Salvar avaliação'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
