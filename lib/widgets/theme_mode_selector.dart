import 'package:flutter/material.dart';
import '../utils/theme_controller.dart';

/// Seletor "Aparência" (tema claro ou escuro), para ficar dentro do
/// cartão de dados do perfil. Usa chips que quebram de linha em telas
/// estreitas, em vez de espremer o texto.
class ThemeModeSelector extends StatelessWidget {
  const ThemeModeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = ThemeController.instance;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Aparência', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                avatar: const Icon(Icons.light_mode_outlined, size: 18),
                label: const Text('Claro'),
                selected: controller.mode == ThemeMode.light,
                onSelected: (_) => controller.setMode(ThemeMode.light),
              ),
              ChoiceChip(
                avatar: const Icon(Icons.dark_mode_outlined, size: 18),
                label: const Text('Escuro'),
                selected: controller.mode == ThemeMode.dark,
                onSelected: (_) => controller.setMode(ThemeMode.dark),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
