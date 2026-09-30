import 'package:flutter/material.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.label, required this.value, required this.icon, this.color});

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 240,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                CircleAvatar(
                  backgroundColor: (color ?? Theme.of(context).colorScheme.primary).withOpacity(0.18),
                  foregroundColor: color ?? Theme.of(context).colorScheme.primary,
                  child: Icon(icon),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(value, style: Theme.of(context).textTheme.headlineSmall),
                      Text(
                        label,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
