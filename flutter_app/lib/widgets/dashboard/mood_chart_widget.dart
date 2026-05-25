/// SKILL: mensaena-features + mensaena-design
/// 7-Tage-Mood-Chart als CustomPainter (kein zusaetzliches Package).
library;

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/mood_repository.dart';
import '../effects/glass_card.dart';
import '../shared/mood_check_in_dialog.dart';

final _mood7dProvider = FutureProvider<List<double?>>((ref) async {
  return MoodRepository.last7Days();
});

class MoodChartWidget extends ConsumerWidget {
  const MoodChartWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_mood7dProvider);
    return GlassCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.heart,
                  size: 16, color: AppColors.bronze),
              const SizedBox(width: 8),
              Text('mood.chartTitle'.tr(),
                  style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                      weight: FontWeight.w700)),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final ok = await MoodCheckInDialog.show(context);
                  if (ok == true) {
                    ref.invalidate(_mood7dProvider);
                  }
                },
                icon: const Icon(LucideIcons.plus, size: 12),
                label: Text('mood.logNow'.tr(),
                    style: AppTypography.label(size: 10)),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.bronze,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 28),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          async.when(
            loading: () => const SizedBox(
              height: 90,
              child: Center(
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.bronze),
              ),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text('mood.loadError'.tr(),
                  style: AppTypography.caption()),
            ),
            data: (data) {
              if (data.every((v) => v == null)) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text('mood.empty'.tr(),
                      style: AppTypography.body(
                          size: 12, color: AppColors.mute)),
                );
              }
              return SizedBox(
                height: 100,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _MoodChartPainter(data: data),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MoodChartPainter extends CustomPainter {
  _MoodChartPainter({required this.data});
  /// Index 0 = heute, 6 = vor 6 Tagen. Wir zeichnen 6 → 0 (links→rechts).
  final List<double?> data;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height - 16; // 16dp fuer Labels unten
    // Reverse: links = vor 6 Tagen, rechts = heute
    final values = List<double?>.from(data.reversed);
    final n = values.length;
    final stepX = w / (n - 1);

    // Grid-Linien (1..5)
    final grid = Paint()
      ..color = AppColors.line.withValues(alpha: 0.3)
      ..strokeWidth = 0.8;
    for (int i = 0; i <= 4; i++) {
      final y = h * i / 4;
      canvas.drawLine(Offset(0, y), Offset(w, y), grid);
    }

    // Linien-Pfad nur durch nicht-null Werte
    final path = Path();
    final dots = <Offset>[];
    bool started = false;
    for (int i = 0; i < n; i++) {
      final v = values[i];
      if (v == null) continue;
      // mood 1..5 → y h..0
      final y = h - ((v - 1) / 4) * h;
      final x = i * stepX;
      if (!started) {
        path.moveTo(x, y);
        started = true;
      } else {
        path.lineTo(x, y);
      }
      dots.add(Offset(x, y));
    }

    // Gradient-Fill unter der Linie (sanft)
    if (dots.isNotEmpty) {
      final fillPath = Path.from(path);
      fillPath.lineTo(dots.last.dx, h);
      fillPath.lineTo(dots.first.dx, h);
      fillPath.close();
      final fill = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.bronze.withValues(alpha: 0.35),
            AppColors.bronze.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, w, h));
      canvas.drawPath(fillPath, fill);
    }

    // Linie
    final linePaint = Paint()
      ..color = AppColors.bronze
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    // Punkte
    final dotPaint = Paint()..color = AppColors.bronze;
    for (final d in dots) {
      canvas.drawCircle(d, 3, dotPaint);
      canvas.drawCircle(
          d,
          3,
          Paint()
            ..color = AppColors.voidColor
            ..strokeWidth = 1
            ..style = PaintingStyle.stroke);
    }

    // Labels: heute / -3 / -6
    final labels = ['-6T', '-3T', 'heute'];
    final positions = [0, n ~/ 2, n - 1];
    for (int i = 0; i < labels.length; i++) {
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: AppColors.mute.withValues(alpha: 0.7),
            fontSize: 9,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (positions[i] * stepX) - tp.width / 2;
      tp.paint(canvas, Offset(x.clamp(0, w - tp.width), h + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _MoodChartPainter old) =>
      old.data != data;
}
