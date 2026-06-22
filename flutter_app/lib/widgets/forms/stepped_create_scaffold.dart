/// SKILL: mensaena-design
/// Mehrstufiges Erstell-Gerüst (Stepper) — isoliert vom bestehenden
/// CreatePostScaffold, damit Screens OPT-IN umsteigen können ohne andere zu
/// beeinflussen. Gradient-Kopf + Fortschrittsbalken + PageView aus [steps] +
/// Zurück/Weiter/Absenden-Navigation. Der letzte Schritt zeigt den Submit-Button.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../effects/animated_entrance.dart';

/// Ein Schritt im Stepper: Titel + Icon + die Card-Sektionen dieses Schritts.
class CreateStep {
  const CreateStep({
    required this.title,
    required this.icon,
    required this.sections,
  });
  final String title;
  final IconData icon;
  final List<Widget> sections;
}

class SteppedCreateScaffold extends StatefulWidget {
  const SteppedCreateScaffold({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.icon,
    required this.returnRoute,
    required this.steps,
    required this.onSubmit,
    this.submitting = false,
    this.submitLabel,
    super.key,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final IconData icon;
  final String returnRoute;
  final List<CreateStep> steps;
  final VoidCallback onSubmit;
  final bool submitting;
  final String? submitLabel;

  @override
  State<SteppedCreateScaffold> createState() => _SteppedCreateScaffoldState();
}

class _SteppedCreateScaffoldState extends State<SteppedCreateScaffold> {
  int _i = 0;
  final _pageCtrl = PageController();

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  void _go(int next) {
    if (next < 0 || next >= widget.steps.length) return;
    FocusScope.of(context).unfocus();
    _pageCtrl.animateToPage(
      next,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final n = widget.steps.length;
    final isLast = _i >= n - 1;
    final step = widget.steps[_i.clamp(0, n - 1)];

    return Scaffold(
      backgroundColor: AppColors.voidColor,
      body: Column(
        children: [
          // ── Gradient-Kopf ──────────────────────────────────────────
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, media.padding.top + 14, 20, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  widget.accent,
                  Color.lerp(widget.accent, AppColors.voidColor, 0.55) ??
                      widget.accent,
                ],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => context.go(widget.returnRoute),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.arrowLeft,
                            size: 16, color: Colors.white),
                        const SizedBox(width: 6),
                        Text('create.backToModule'.tr(),
                            style: AppTypography.label(
                                size: 11, color: Colors.white)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(widget.icon, size: 22, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(widget.title,
                          style: AppTypography.display(
                              size: 22, color: Colors.white)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Fortschritt: Segmente + „Schritt i/n · Titel"
                Row(
                  children: [
                    for (var k = 0; k < n; k++) ...[
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: k <= _i
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      if (k < n - 1) const SizedBox(width: 4),
                    ],
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(step.icon, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      'create.stepOf'.tr(namedArgs: {
                        'i': '${_i + 1}',
                        'n': '$n',
                      }),
                      style: AppTypography.label(
                          size: 10,
                          color: Colors.white.withValues(alpha: 0.9)),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        step.title,
                        style: AppTypography.body(
                            size: 12,
                            color: Colors.white,
                            weight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Seiten ─────────────────────────────────────────────────
          Expanded(
            child: PageView.builder(
              controller: _pageCtrl,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: n,
              onPageChanged: (i) => setState(() => _i = i),
              itemBuilder: (context, pageIndex) {
                final s = widget.steps[pageIndex];
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    for (var j = 0; j < s.sections.length; j++)
                      AnimatedEntrance(
                        index: j,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: s.sections[j],
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          // ── Navigation ─────────────────────────────────────────────
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  if (_i > 0) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed:
                            widget.submitting ? null : () => _go(_i - 1),
                        icon: const Icon(LucideIcons.arrowLeft, size: 16),
                        label: Text('create.back'.tr()),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.inkSoft,
                          side: const BorderSide(color: AppColors.line),
                          minimumSize: const Size.fromHeight(50),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    flex: _i > 0 ? 1 : 1,
                    child: FilledButton.icon(
                      onPressed: widget.submitting
                          ? null
                          : (isLast ? widget.onSubmit : () => _go(_i + 1)),
                      icon: widget.submitting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.voidColor),
                            )
                          : Icon(
                              isLast ? LucideIcons.check : LucideIcons.arrowRight,
                              size: 16),
                      label: Text(isLast
                          ? (widget.submitLabel ?? 'create.publish'.tr())
                          : 'create.next'.tr()),
                      style: FilledButton.styleFrom(
                        backgroundColor: widget.accent,
                        foregroundColor: AppColors.voidColor,
                        minimumSize: const Size.fromHeight(50),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
