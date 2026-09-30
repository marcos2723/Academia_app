import 'package:flutter/material.dart';
import '../models/personal.dart';
import '../models/availability.dart';
import '../models/callbacks.dart';
import '../utils/app_colors.dart';
import '../widgets/page_shell.dart';
import 'availability_form_screen.dart';
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

  Future<void> _openMyAvailability(BuildContext context) async {
    final current = await myAvailabilityStream.first;
    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AvailabilityFormScreen(initialRanges: current.ranges, onSave: onSaveAvailability),
      ),
    );
  }

  Future<void> _openEditProfile(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditPersonalProfileScreen(
          initialName: myProfile?.name ?? '',
          initialPhone: myProfile?.phone ?? '',
          onSave: onSaveProfile,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = myProfile;
    return PageShell(
      title: 'Meu perfil',
      subtitle: 'Seus dados e horários de atendimento.',
      child: ListView(
        children: [
          Card(
            child: ListTile(
              leading: CircleAvatar(child: Text(me?.name.isNotEmpty == true ? me!.name[0].toUpperCase() : '?')),
              title: Text(me?.name.isNotEmpty == true ? me!.name : 'Sem nome cadastrado'),
              subtitle: Text([
                if (me?.email.isNotEmpty == true) me!.email,
                if (me?.phone.isNotEmpty == true) me!.phone,
              ].join('\n')),
              isThreeLine: (me?.phone.isNotEmpty ?? false) && (me?.email.isNotEmpty ?? false),
              trailing: TextButton.icon(
                onPressed: () => _openEditProfile(context),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Editar'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.schedule)),
              title: const Text('Meus horários de atendimento'),
              subtitle: const Text('Defina quando você aceita marcar avaliações'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openMyAvailability(context),
            ),
          ),
          if (onOpenAgenda != null || onOpenEquipe != null) ...[
            const SizedBox(height: 24),
            Text('Outras seções', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            if (onOpenAgenda != null)
              Card(
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x33FFC15C),
                    foregroundColor: kAgendaAccent,
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
                  leading: const CircleAvatar(
                    backgroundColor: Color(0x33FF7FA8),
                    foregroundColor: kEquipeAccent,
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
  }
}
