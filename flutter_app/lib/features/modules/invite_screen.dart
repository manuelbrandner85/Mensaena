// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, require_trailing_commas
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/colors.dart';
import '../../core/theme/dimensions.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_app_shell.dart';
import '../../core/widgets/cinema_toast.dart';
import '../../core/widgets/glow_button.dart';
import '../../providers/auth_provider.dart';

/// Web-Pendant `/dashboard/invite` — User teilt einen Code/Link, Nachbarn
/// kommen durch die Einladung in die Plattform.
class InviteScreen extends ConsumerWidget {
  const InviteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final code = (user?.id ?? '').substring(0, user == null ? 0 : 8);
    final link = 'https://www.mensaena.de/i/$code';

    return CinemaAppShell(
      currentRoute: '/invite',
      title: 'EINLADEN',
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Lade deine Nachbarn ein',
              style: MnTypography.display(size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              'Je mehr Menschen mitmachen, desto staerker wird unsere '
              'Nachbarschaftshilfe.',
              style: MnTypography.body(color: MnColors.inkSoft, height: 1.6),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: MnColors.surface,
                borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
                border: Border.all(color: MnColors.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DEIN EINLADUNGSLINK',
                    style: MnTypography.label(color: MnColors.mute),
                  ),
                  const SizedBox(height: 12),
                  SelectableText(
                    link,
                    style: MnTypography.mono(
                      size: 14,
                      color: MnColors.amber,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GlowButton(
                          label: 'Kopieren',
                          icon: LucideIcons.copy,
                          variant: GlowVariant.ghost,
                          fullWidth: true,
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: link));
                            if (context.mounted) {
                              CinemaToast.show(
                                context,
                                variant: ToastVariant.success,
                                message: 'Link kopiert.',
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GlowButton(
                          label: 'Teilen',
                          icon: LucideIcons.share2,
                          variant: GlowVariant.primary,
                          fullWidth: true,
                          onPressed: () => Share.share(
                            'Komm zu Mensaena, der Nachbarschaftshilfe-App: $link',
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: MnColors.amber.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(MnDimensions.radiusCard),
                border: Border.all(color: MnColors.amber.withValues(alpha: 0.20)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.gift, size: 18, color: MnColors.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Fuer jede erfolgreiche Einladung bekommst du das '
                      '"Botschafter"-Badge.',
                      style: MnTypography.body(color: MnColors.inkSoft, size: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
