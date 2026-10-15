import 'package:flutter/material.dart';
import '../models/personal.dart';
import '../models/availability.dart';
import '../models/callbacks.dart';
import '../widgets/labeled_value.dart';
import '../widgets/page_shell.dart';
import '../widgets/theme_mode_selector.dart';
import 'edit_personal_profile_screen.dart';

class PersonalProfilePage extends StatelessWidget {
  const PersonalProfilePage({
    super.key,
    required this.myProfile,
    required this.myAvailabilityStream,
    required this.onSaveAvailability,
    required this.onSaveProfile,
    this.onOpenAgenda,
    this.onOpenEquipe,
  });

  final Personal? myProfile;
  final Stream<PersonalAvailability> myAvailabilityStream;
  final SaveAvailabilityCallback onSaveAvailability;
  final Future<void> Function({required String name, required String phone}) onSaveProfile;

  /// Atalhos pra Agenda e Equipe, mostrados aqui só na navegação compacta
  /// (celular), onde essas seções saíram da barra de baixo pra caber
  /// dentro de Perfil. No layout largo (com menu lateral), ambas já têm
  /// ícone próprio, então esses callbacks vêm nulos e nada é mostrado.
  final VoidCallback? onOpenAgenda;
  final VoidCallback? onOpenEquipe;

  Future<void> _openEditProfile(BuildContext context, List<AvailabilityRange> ranges) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditPersonalProfileScreen(
          initialName: myProfile?.name ?? '',
          initialPhone: myProfile?.phone ?? '',
          onSave: onSaveProfile,
          initialRanges: ranges,
          onSaveAvailability: onSaveAvailability,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = myProfile;
    return StreamBuilder<PersonalAvailability>(
      stream: myAvailabilityStream,
      builder: (context, snapshot) {
        final ranges = snapshot.data?.ranges ?? const <AvailabilityRange>[];
        return PageShell(
      title: 'Meu perfil',
      subtitle: 'Seus dados e horários.',
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(child: Text(me?.name.isNotEmpty == true ? me!.name[0].toUpperCase() : '?')),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dados pessoais', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 10),
                        LabeledValue(label: 'Nome', value: me?.name ?? ''),
                        LabeledValue(label: 'E-mail', value: me?.email ?? ''),
                        LabeledValue(label: 'Telefone', value: me?.phone ?? ''),
                        const SizedBox(height: 14),
                        const ThemeModeSelector(),
                        const SizedBox(height: 14),
                        Text('Horários de atendimento', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 6),
                        if (ranges.isEmpty)
                          const LabeledValue(label: 'Horários', value: '')
                        else
                          for (var wd = 1; wd <= 7; wd++)
                            if (ranges.any((r) => r.weekday == wd))
                              LabeledValue(
                                label: weekdayNames[wd],
                                value: (ranges.where((r) => r.weekday == wd).toList()
                                      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes)))
                                    .map((r) => '${r.startLabel} - ${r.endLabel}')
                                    .join(' · '),
                              ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _openEditProfile(context, ranges),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Editar'),
                  ),
                ],
              ),
            ),
          ),
          if (onOpenAgenda != null || onOpenEquipe != null) ...[
            const SizedBox(height: 24),
            Text('Outras seções', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (onOpenAgenda != null)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(Icons.calendar_month_outlined),
                  ),
                  title: const Text('Agenda'),
                  subtitle: const Text('Avaliações marcadas com os alunos'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenAgenda,
                ),
              ),
            if (onOpenEquipe != null) ...[
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.15),
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    child: Icon(Icons.groups_outlined),
                  ),
                  title: const Text('Equipe'),
                  subtitle: const Text('Outros personais cadastrados'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: onOpenEquipe,
                ),
              ),
            ],
          ],
        ],
      ),
    );
      },
    );
  }
}
