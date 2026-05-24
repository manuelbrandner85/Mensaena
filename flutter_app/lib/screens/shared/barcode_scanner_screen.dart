/// SKILL: mensaena-features + mensaena-design
/// Barcode/QR-Scanner — pops mit dem gescannten Code-String zurück.
/// Wird genutzt von: Marketplace-Create (Food-Lookup), Org-Invite (Code).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({this.title, super.key});

  final String? title;

  /// Öffnet den Scanner als Modal und gibt den String zurück (oder null).
  static Future<String?> open(BuildContext context, {String? title}) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(title: title),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  late final MobileScannerController _ctrl;
  bool _captured = false;

  @override
  void initState() {
    super.initState();
    _ctrl = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_captured) return;
    final code = cap.barcodes.firstOrNull?.rawValue;
    if (code == null || code.isEmpty) return;
    _captured = true;
    HapticFeedback.heavyImpact();
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.voidColor,
      body: Stack(
        children: [
          MobileScanner(controller: _ctrl, onDetect: _onDetect),
          // Cutout-Overlay
          IgnorePointer(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.bronze, width: 3),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.bronze.withValues(alpha: 0.4),
                    blurRadius: 22,
                    spreadRadius: -2,
                  ),
                ],
              ),
            ),
          ),
          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(LucideIcons.x, color: AppColors.ink),
                    ),
                    Expanded(
                      child: Text(
                        widget.title ?? 'Barcode scannen',
                        style: AppTypography.body(
                          size: 14,
                          color: AppColors.ink,
                          weight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _ctrl.toggleTorch(),
                      icon: const Icon(LucideIcons.zap,
                          color: AppColors.amber),
                    ),
                    IconButton(
                      onPressed: () => _ctrl.switchCamera(),
                      icon: const Icon(LucideIcons.switchCamera,
                          color: AppColors.ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Hint
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Text(
                    'Halte den Barcode in das Bronze-Rechteck. Erkennung erfolgt automatisch.',
                    textAlign: TextAlign.center,
                    style: AppTypography.body(
                        size: 12, color: AppColors.inkSoft),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
