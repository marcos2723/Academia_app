import 'package:flutter/material.dart';

class PageShell extends StatelessWidget {
  const PageShell({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: Theme.of(context).textTheme.headlineMedium),
                        const SizedBox(height: 4),
                        Text(subtitle, style: Theme.of(context).textTheme.bodyLarge),
                      ],
                    ),
                  ),
                  if (action != null) action!,
                ],
              ),
              const SizedBox(height: 24),
              Expanded(child: child),
            ],
          ),
        ),
      );
}
