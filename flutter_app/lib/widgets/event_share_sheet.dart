/// SKILL: mensaena-features
/// Bottom-Sheet fuer Native-Share / Link kopieren / Text kopieren.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../config/theme/app_colors.dart';
import '../config/theme/app_typography.dart';
import '../widgets/shared/app_snackbar.dart';

class EventShareSheet {
  const EventShareSheet._();

  /// Shows the share sheet for an event. [startsAt] is currently unused but
  /// reserved for future enrichments (e.g. calendar export entries).
  static void show(
    BuildContext context, {
    required String eventId,
    required String title,
    DateTime? startsAt,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ShareBody(
        eventId: eventId,
        title: title,
        startsAt: startsAt,
      ),
    );
  }
}

class _ShareBody extends StatelessWidget {
  const _ShareBody({
    required this.eventId,
    required this.title,
    this.startsAt,
  });

  final String eventId;
  final String title;
  final DateTime? startsAt;

  String get _url => 'https://www.mensaena.de/get/events/$eventId';
  String get _text =>
      '${'events.shareBody'.tr(namedArgs: {'title': title})}\n$_url';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.mute,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'events.share'.tr(),
              style: AppTypography.display(size: 16, color: AppColors.ink),
            ),
            const SizedBox(height: 12),
            _buildTile(
              context,
              icon: LucideIcons.link,
              label: 'events.shareLink'.tr(),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: _url));
                if (!context.mounted) return;
                Navigator.pop(context);
                AppSnackBar.success(context, 'events.linkCopied'.tr());
              },
            ),
            _buildTile(
              context,
              icon: LucideIcons.copy,
              label: 'events.shareText'.tr(),
              onTap: () async {
                await Clipboard.setData(ClipboardData(text: _text));
                if (!context.mounted) return;
                Navigator.pop(context);
                AppSnackBar.success(context, 'events.textCopied'.tr());
              },
            ),
            _buildTile(
              context,
              icon: LucideIcons.share2,
              label: 'events.shareNative'.tr(),
              onTap: () async {
                await Share.share(_text, subject: title);
                if (!context.mounted) return;
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.amber, size: 20),
      title: Text(
        label,
        style: AppTypography.body(size: 14, color: AppColors.ink),
      ),
      onTap: onTap,
    );
  }
}
