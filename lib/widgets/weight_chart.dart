import 'package:flutter/material.dart';

/// Gráfico de linha genérico para qualquer sequência de valores ao longo
/// do tempo (peso, IMC, % de gordura, circunferências, etc.), com o valor
/// de cada ponto exibido acima (ou abaixo, quando não há espaço) do ponto,
/// e a data da avaliação exibida abaixo de cada ponto.
class EvolutionChart extends StatelessWidget {
  const EvolutionChart({super.key, required this.values, required this.dates, this.decimals = 1});
  final List<double> values;
  final List<DateTime> dates;
  final int decimals;

  @override
  Widget build(BuildContext context) => CustomPaint(
        painter: EvolutionChartPainter(
          values,
          dates,
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.onSurface,
          decimals,
        ),
        child: const SizedBox.expand(),
      );
}

class EvolutionChartPainter extends CustomPainter {
  EvolutionChartPainter(this.values, this.dates, this.color, this.textColor, this.decimals);
  final List<double> values;
  final List<DateTime> dates;
  final Color color;
  final Color textColor;
  final int decimals;

  String _shortDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) {
      final p = TextPainter(
        text: const TextSpan(
          text: 'Inclua outra avaliação para visualizar o gráfico.',
          style: TextStyle(color: Colors.grey),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: size.width);
      p.paint(canvas, Offset(12, size.height / 2));
      return;
    }
    final min = values.reduce((a, b) => a < b ? a : b) - 1;
    final max = values.reduce((a, b) => a > b ? a : b) + 1;
    final range = (max - min).abs() < 0.001 ? 1 : (max - min);
    const topMargin = 22.0;
    const bottomMargin = 34.0;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final path = Path();
    final points = <Offset>[];
    for (var i = 0; i < values.length; i++) {
      final x = 18 + (size.width - 36) * i / (values.length - 1);
      final y = topMargin + (size.height - topMargin - bottomMargin) * (1 - (values[i] - min) / range);
      points.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      canvas.drawCircle(point, 4, Paint()..color = color);

      final label = values[i].toStringAsFixed(decimals);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final above = point.dy - tp.height - 6;
      final labelY = above >= 0 ? above : point.dy + 8;
      var labelX = point.dx - tp.width / 2;
      labelX = labelX.clamp(0, size.width - tp.width);
      tp.paint(canvas, Offset(labelX, labelY));

      if (i < dates.length) {
        final dateTp = TextPainter(
          text: TextSpan(
            text: _shortDate(dates[i]),
            style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 9),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        var dateX = point.dx - dateTp.width / 2;
        dateX = dateX.clamp(0, size.width - dateTp.width);
        dateTp.paint(canvas, Offset(dateX, size.height - bottomMargin + 10));
      }
    }
  }

  @override
  bool shouldRepaint(covariant EvolutionChartPainter old) => old.values != values || old.dates != dates;
}
