import 'package:flutter/material.dart';
import '../../models/student.dart';
import '../../utils/formatters.dart';
import '../../widgets/page_shell.dart';

class AlunoProfilePage extends StatelessWidget {
  const AlunoProfilePage({super.key, required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    return PageShell(
      title: 'Meu perfil',
      subtitle: 'Seus dados cadastrados na academia.',
      child: ListView(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student.name, style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(student.email),
                  Text(student.phone),
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
                  Text('Altura: ${student.height.toStringAsFixed(2)} m'),
                  Text('Peso cadastrado: ${student.weight.toStringAsFixed(1)} kg'),
                  Text('IMC de referência: ${student.bmi.toStringAsFixed(1)}'),
                  Text('Data de nascimento: ${formatDate(student.birthDate)}'),
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
                  Text('Objetivo', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(student.goal),
                  if (student.observations.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Text('Observações', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 6),
                    Text(student.observations),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(18),
              child: Text(
                'Precisa corrigir algum dado? Fale com seu personal — só ele pode editar essas informações.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
