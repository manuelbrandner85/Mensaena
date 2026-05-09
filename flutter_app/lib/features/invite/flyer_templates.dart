import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../theme/app_colors.dart';

/// Mehrere Designs für teilbare Einladungs-Flyer.
/// Jedes Template ist ein Widget mit fester 1080×1080-Größe (Instagram-Square).
/// Über RepaintBoundary → toImage() → PNG-Bytes wird daraus ein
/// teilbares Bild via share_plus.
enum FlyerTemplate {
  classic('Klassisch', '🎁'),
  family('Familie', '👨‍👩‍👧'),
  minimal('Minimal', '✨'),
  action('Aktion', '🚀');

  const FlyerTemplate(this.label, this.emoji);
  final String label;
  final String emoji;
}

class FlyerCanvas extends StatelessWidget {
  const FlyerCanvas({
    super.key,
    required this.template,
    required this.code,
    required this.shareUrl,
    this.userName,
  });

  final FlyerTemplate template;
  final String code;
  final String shareUrl;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    switch (template) {
      case FlyerTemplate.classic:
        return _ClassicFlyer(code: code, shareUrl: shareUrl, userName: userName);
      case FlyerTemplate.family:
        return _FamilyFlyer(code: code, shareUrl: shareUrl, userName: userName);
      case FlyerTemplate.minimal:
        return _MinimalFlyer(code: code, shareUrl: shareUrl, userName: userName);
      case FlyerTemplate.action:
        return _ActionFlyer(code: code, shareUrl: shareUrl, userName: userName);
    }
  }
}

class _ClassicFlyer extends StatelessWidget {
  const _ClassicFlyer({
    required this.code,
    required this.shareUrl,
    this.userName,
  });
  final String code;
  final String shareUrl;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      height: 1080,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary500, AppColors.primary700],
        ),
      ),
      padding: const EdgeInsets.all(80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'mensaena',
            style: TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 60),
          const Text('🎁', style: TextStyle(fontSize: 100)),
          const SizedBox(height: 32),
          const Text(
            'Du bist eingeladen.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 64,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 16),
          if (userName != null)
            Text(
              'Von $userName',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 32,
                fontWeight: FontWeight.w500,
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DEIN CODE',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 80,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            shareUrl,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _FamilyFlyer extends StatelessWidget {
  const _FamilyFlyer({
    required this.code,
    required this.shareUrl,
    this.userName,
  });
  final String code;
  final String shareUrl;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      height: 1080,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFEF3C7), Color(0xFFFFFBEB)],
        ),
      ),
      padding: const EdgeInsets.all(80),
      child: Column(
        children: [
          const SizedBox(height: 40),
          const Text(
            '🏘️',
            style: TextStyle(fontSize: 200),
          ),
          const SizedBox(height: 32),
          const Text(
            'Nachbarschaft.\nNeu erlebt.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.ink800,
              fontSize: 72,
              fontWeight: FontWeight.w900,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 32),
          if (userName != null)
            Text(
              '$userName lädt dich zu Mensaena ein',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.ink700,
                fontSize: 28,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            const Text(
              'Werde Teil deiner Mensaena-Community',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.ink700,
                fontSize: 28,
                fontWeight: FontWeight.w500,
              ),
            ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.primary500,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                const Text(
                  'Code',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  code,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            shareUrl,
            style: const TextStyle(
              color: AppColors.ink400,
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _MinimalFlyer extends StatelessWidget {
  const _MinimalFlyer({
    required this.code,
    required this.shareUrl,
    this.userName,
  });
  final String code;
  final String shareUrl;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      height: 1080,
      color: Colors.white,
      padding: const EdgeInsets.all(120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'mensaena',
            style: TextStyle(
              color: AppColors.primary500,
              fontSize: 48,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const Spacer(),
          const Text(
            'Komm dazu.',
            style: TextStyle(
              color: AppColors.ink800,
              fontSize: 96,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          if (userName != null)
            Text(
              'Eine Einladung von $userName.',
              style: const TextStyle(
                color: AppColors.ink400,
                fontSize: 32,
                fontWeight: FontWeight.w400,
              ),
            ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.primary500,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Code',
                  style: TextStyle(
                    color: AppColors.ink400,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  code,
                  style: const TextStyle(
                    color: AppColors.primary500,
                    fontSize: 80,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            shareUrl,
            style: const TextStyle(
              color: AppColors.ink400,
              fontSize: 24,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionFlyer extends StatelessWidget {
  const _ActionFlyer({
    required this.code,
    required this.shareUrl,
    this.userName,
  });
  final String code;
  final String shareUrl;
  final String? userName;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1080,
      height: 1080,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF111827), Color(0xFF1F2937)],
        ),
      ),
      padding: const EdgeInsets.all(80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary500,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'mensaena',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          const Text(
            '🚀',
            style: TextStyle(fontSize: 140),
          ),
          const SizedBox(height: 24),
          const Text(
            'Mach mit.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 110,
              fontWeight: FontWeight.w900,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hilf. Tausch. Teil.',
            style: TextStyle(
              color: AppColors.primary500,
              fontSize: 56,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 24),
          if (userName != null)
            Text(
              '$userName ist schon dabei.',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 28,
                fontWeight: FontWeight.w500,
              ),
            ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'CODE',
                      style: TextStyle(
                        color: AppColors.primary500,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 72,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w900,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            shareUrl,
            style: const TextStyle(
              color: Colors.white60,
              fontSize: 22,
            ),
          ),
        ],
      ),
    );
  }
}

/// Rendert ein Flyer-Widget zu PNG-Bytes via RepaintBoundary.
Future<Uint8List?> renderFlyerToPng(GlobalKey boundaryKey) async {
  final boundary = boundaryKey.currentContext?.findRenderObject()
      as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: 1);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData?.buffer.asUint8List();
}
