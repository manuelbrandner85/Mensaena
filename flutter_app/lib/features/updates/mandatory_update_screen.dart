import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/app_colors.dart';
import 'update_models.dart';
import 'update_service.dart';

/// Vollbild-Sperre die User nicht überspringen können.
/// Zeigt freundlich verfasste Changelog-Einträge + großen
/// "Jetzt aktualisieren"-Button, der die APK herunterlädt.
class MandatoryUpdateScreen extends ConsumerStatefulWidget {
  const MandatoryUpdateScreen({super.key, required this.release});
  final AppRelease release;

  @override
  ConsumerState<MandatoryUpdateScreen> createState() =>
      _MandatoryUpdateScreenState();
}

class _MandatoryUpdateScreenState
    extends ConsumerState<MandatoryUpdateScreen> {
  bool _launching = false;

  Future<void> _launchUpdate() async {
    final url = widget.release.apkUrl;
    if (url == null || _launching) return;
    setState(() => _launching = true);
    HapticFeedback.mediumImpact();
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konnte Download nicht starten: $e')),
      );
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  Future<void> _retry() async {
    // Nach dem Update klickt User u. U. zurück und der Build wurde getauscht.
    // Erneut prüfen lassen.
    ref.invalidate(updateCheckProvider);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.release;
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primary500,
                            AppColors.primary700,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.system_update_alt,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Update verfügbar',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary500.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary500.withValues(alpha: 0.25),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.primary500,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Damit alles für dich reibungslos läuft, '
                          'aktualisiere bitte auf die neueste Version. '
                          'Der Download dauert nur einen Moment.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.ink700,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (r.entries.isNotEmpty) ...[
                  const Text(
                    'Was ist neu',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      itemCount: r.entries.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) =>
                          _ChangelogTile(entry: r.entries[i]),
                    ),
                  ),
                ] else
                  const Spacer(),
                const SizedBox(height: 12),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _launching ? null : _launchUpdate,
                    icon: _launching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.download_rounded),
                    label: Text(
                      _launching ? 'Öffne Download…' : 'Jetzt aktualisieren',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: _retry,
                    child: const Text(
                      'Bereits installiert? Erneut prüfen',
                      style: TextStyle(
                        color: AppColors.ink400,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChangelogTile extends StatelessWidget {
  const _ChangelogTile({required this.entry});
  final ChangelogEntry entry;

  Color get _accent {
    switch (entry.type) {
      case ChangelogType.feature:
        return AppColors.primary500;
      case ChangelogType.improvement:
        return const Color(0xFF3B82F6);
      case ChangelogType.fix:
        return const Color(0xFFD97706);
      case ChangelogType.notice:
        return const Color(0xFF8B5CF6);
      case ChangelogType.unknown:
        return AppColors.ink400;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.stone200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              entry.type.emoji,
              style: const TextStyle(fontSize: 18),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        entry.type.label,
                        style: TextStyle(
                          color: _accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  entry.title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink800,
                  ),
                ),
                if ((entry.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    entry.description!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.ink400,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
