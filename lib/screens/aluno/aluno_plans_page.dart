import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../models/plan.dart';
import '../../models/evaluation.dart';
import '../../models/checkin.dart';
import '../../models/prescription.dart';
import '../../models/student.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../utils/adherence.dart';
import '../../utils/diet_pdf.dart';
import '../../utils/training_pdf.dart';
import '../../widgets/adherence_view.dart';
import '../../widgets/plan_result_card.dart';
import '../../widgets/checkin_dialog.dart';
import '../../widgets/labeled_value.dart';
import '../../widgets/prescriptions_section.dart';
import '../../widgets/training_days_view.dart';
import '../../widgets/page_shell.dart';

class AlunoPlansPage extends StatefulWidget {
  const AlunoPlansPage({super.key, required this.service, required this.student, required this.fixedType});

  final FirestoreService service;
  final Student student;

  /// Treino ou dieta — cada aba da navegação do aluno abre esta página
  /// com um tipo fixo.
  final PlanType fixedType;

  @override
  State<AlunoPlansPage> createState() => _AlunoPlansPageState();
}

class _AlunoPlansPageState extends State<AlunoPlansPage> {
  late final Stream<List<Plan>> _plansStream = widget.service.watchPlansForStudent(widget.student.id);
  late final Stream<List<Checkin>> _checkinsStream = widget.service.watchCheckinsForStudent(widget.student.id);
  List<Checkin> _checkins = const [];
  late final Stream<List<Evaluation>> _evaluationsStream =
      widget.service.watchEvaluationsForStudent(widget.student.id);
  List<Evaluation> _evaluations = const [];
  // Atualiza o calendário aberto no diálogo quando chega um registro novo.
  final ValueNotifier<List<Checkin>> _checkinsNotifier = ValueNotifier(const []);

  @override
  void dispose() {
    _checkinsNotifier.dispose();
    super.dispose();
  }
  // Só é criado (lazy) na aba de dietas.
  late final Stream<List<Prescription>> _prescriptionsStream =
      widget.service.watchIssuedPrescriptionsForStudent(widget.student.id);
  List<Prescription> _prescriptions = const [];

  Future<void> _register(Plan p, {DateTime? date}) async {
    final draft = await showCheckinDialog(context, plan: p, existing: _checkins, date: date);
    if (draft == null) return;
    try {
      await widget.service.saveCheckins([
        for (final e in draft.entries)
          Checkin(
            id: Checkin.docId(p.id, e.date),
            studentId: widget.student.id,
            planId: p.id,
            type: p.type,
            date: e.date,
            status: draft.status,
            dayLabel: e.dayLabel,
            note: draft.note,
          ),
      ]);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não consegui salvar o registro.')),
        );
      }
    }
  }

  bool get _isTraining => widget.fixedType == PlanType.training;
  Color get _accent => Theme.of(context).colorScheme.primary;

  Future<void> _downloadDietPdf(Plan p) async {
    final bytes = await buildDietPdf(
      studentName: widget.student.name,
      planTitle: p.title,
      validity: '${formatDate(p.startDate)} a ${formatDate(p.endDate)}',
      objective: widget.student.goal,
      dietContent: p.dietContent,
    );
    final safeName = p.title.trim().isEmpty
        ? 'dieta'
        : p.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final ok = await Printing.sharePdf(bytes: bytes, filename: 'dieta_$safeName.pdf')
        .catchError((_) => false);
    if (context.mounted && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui salvar/compartilhar o PDF.')),
      );
    }
  }

  Future<void> _downloadTrainingPdf(Plan p) async {
    final bytes = await buildTrainingPdf(
      studentName: widget.student.name,
      planTitle: p.title,
      validity: '${formatDate(p.startDate)} a ${formatDate(p.endDate)}',
      objective: widget.student.goal,
      days: p.days,
    );
    final safeName = p.title.trim().isEmpty
        ? 'treino'
        : p.title.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    final ok = await Printing.sharePdf(bytes: bytes, filename: 'treino_$safeName.pdf')
        .catchError((_) => false);
    if (context.mounted && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui salvar/compartilhar o PDF.')),
      );
    }
  }

  void _showDetails(Plan p, List<Plan> allPlans) {
    String? linkedTitle;
    if (p.linkedPlanId != null) {
      final match = allPlans.where((other) => other.id == p.linkedPlanId);
      linkedTitle = match.isEmpty ? null : match.first.title;
    }
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(p.title),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LabeledValue(
                  label: 'Vigência',
                  value: '${formatDate(p.startDate)} até ${formatDate(p.endDate)}'
                      '${p.isActive ? ' (em andamento)' : ''}',
                ),
                if (linkedTitle != null)
                  LabeledValue(
                    label: p.type == PlanType.training ? 'Integrado à dieta' : 'Integrado ao treino',
                    value: linkedTitle,
                  ),
                const Divider(height: 24),
                ValueListenableBuilder<List<Checkin>>(
                  valueListenable: _checkinsNotifier,
                  builder: (_, list, __) => PlanResultCard(plan: p, evaluations: _evaluations, checkins: list),
                ),
                const Divider(height: 24),
                ValueListenableBuilder<List<Checkin>>(
                  valueListenable: _checkinsNotifier,
                  builder: (_, list, __) => AdherenceView(
                    plan: p,
                    checkins: list,
                    showCalendar: true,
                    onRegisterDay: (d) => _register(p, date: d),
                  ),
                ),
                const Divider(height: 24),
                if (p.type == PlanType.training)
                  TrainingDaysView(days: p.days)
                else
                  Text(p.dietContent.isEmpty ? 'Nenhum conteúdo cadastrado.' : p.dietContent),
              ],
            ),
          ),
        ),
        actions: [
          if (p.type == PlanType.training)
            TextButton.icon(
              onPressed: () => _downloadTrainingPdf(p),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Baixar PDF'),
            ),
          if (p.type == PlanType.diet)
            TextButton.icon(
              onPressed: () => _downloadDietPdf(p),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('Baixar PDF'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Fechar')),
        ],
      ),
    );
  }

  Widget _buildList(List<Plan> myPlans) {
    final filtered = myPlans.where((p) => p.type == widget.fixedType).toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    final extra = _isTraining ? 0 : 1;
    if (filtered.isEmpty && _isTraining) {
      return const Center(child: Text('Nenhuma ficha de treino no momento.'));
    }
    return ListView.separated(
      itemCount: filtered.length + extra + (filtered.isEmpty && !_isTraining ? 1 : 0),
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (!_isTraining && filtered.isEmpty && i == 0) {
          return const Card(child: Padding(padding: EdgeInsets.all(18), child: Text('Nenhuma dieta no momento.')));
        }
        final dietsShown = filtered.isEmpty ? 1 : filtered.length;
        if (!_isTraining && i == dietsShown) {
          return Padding(
            padding: const EdgeInsets.only(top: 20, bottom: 12),
            child: PrescriptionsSection(
              service: widget.service,
              student: widget.student,
              prescriptions: _prescriptions,
              isPersonal: false,
            ),
          );
        }
        final p = filtered[i];
        final todayKey = Checkin.dateKeyOf(DateTime.now());
        final todays = _checkins.where((c) => c.planId == p.id && c.dateKey == todayKey);
        return Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(_isTraining ? Icons.fitness_center : Icons.restaurant, color: _accent),
                title: Text(p.title),
                subtitle: Text(
                  '${_isTraining ? 'Treinos: ${p.days.length} · Exercícios: ${p.exerciseCount}' : 'Tipo: Dieta'}'
                  '\nAdesão: ${adherenceLabel(p, _checkins)}',
                ),
                isThreeLine: true,
                trailing: Text(
                  'Vigência: ${formatDate(p.startDate)} - ${formatDate(p.endDate)}',
                  style: p.isActive
                      ? TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)
                      : null,
                ),
                onTap: () => _showDetails(p, myPlans),
              ),
              if (p.isActive)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          todays.isEmpty
                              ? 'Hoje: sem registro'
                              : 'Hoje: ${todays.first.status.resultLabel(p.type)}',
                        ),
                      ),
                      FilledButton.tonal(
                        onPressed: () => _register(p),
                        child: Text(todays.isEmpty ? 'Registrar' : 'Alterar'),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Plan>>(
      stream: _plansStream,
      initialData: const [],
      builder: (context, snapshot) {
        final myPlans = snapshot.data ?? const <Plan>[];
        return StreamBuilder<List<Evaluation>>(
          stream: _evaluationsStream,
          initialData: const [],
          builder: (context, evalSnapshot) {
            _evaluations = evalSnapshot.data ?? const <Evaluation>[];
            return StreamBuilder<List<Checkin>>(
          stream: _checkinsStream,
          initialData: const [],
          builder: (context, checkinSnapshot) {
            _checkins = checkinSnapshot.data ?? const <Checkin>[];
            final latest = _checkins;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _checkinsNotifier.value = latest;
            });
            Widget shell() => PageShell(
                  title: _isTraining ? 'Treinos' : 'Dietas',
                  subtitle: _isTraining ? 'Suas fichas de treino.' : 'Suas dietas.',
                  child: _buildList(myPlans),
                );
            if (_isTraining) return shell();
            return StreamBuilder<List<Prescription>>(
              stream: _prescriptionsStream,
              initialData: const [],
              builder: (context, rxSnapshot) {
                _prescriptions = rxSnapshot.data ?? const <Prescription>[];
                return shell();
              },
            );
          },
        );
          },
        );
      },
    );
  }
}
