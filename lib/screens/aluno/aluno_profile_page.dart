import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../utils/formatters.dart';
import '../../widgets/labeled_value.dart';
import '../../widgets/page_shell.dart';
import '../../widgets/theme_mode_selector.dart';

class AlunoProfilePage extends StatelessWidget {
  const AlunoProfilePage({super.key, required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'Meu perfil',
      subtitle: 'Seus dados cadastrados.',
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dados pessoais', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  LabeledValue(label: 'Nome', value: student.name),
                  LabeledValue(label: 'E-mail', value: student.email),
                  LabeledValue(label: 'Telefone', value: student.phone),
                  LabeledValue(label: 'Sexo', value: student.sex == 'F' ? 'Feminino' : 'Masculino'),
                  LabeledValue(label: 'Data de nascimento', value: formatDate(student.birthDate)),
                  LabeledValue(label: 'Idade', value: '${student.ageAt(DateTime.now())} anos'),
                  const SizedBox(height: 14),
                  const ThemeModeSelector(),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dados físicos', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  LabeledValue(label: 'Altura', value: '${student.height.toStringAsFixed(2)} m'),
                  LabeledValue(label: 'Peso cadastrado', value: '${student.weight.toStringAsFixed(1)} kg'),
                  LabeledValue(label: 'IMC de referência', value: student.bmi.toStringAsFixed(1)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Acompanhamento', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  LabeledValue(label: 'Objetivo', value: student.goal),
                  if (student.observations.isNotEmpty)
                    LabeledValue(label: 'Observações', value: student.observations),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Para corrigir seus dados, fale com seu personal.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
