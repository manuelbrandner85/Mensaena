/// SKILL: mensaena-features (P12 GDPR) — Account-Verwaltung
/// Daten-Export (JSON) + Account-Löschung (14-Tage-Frist).
library;

import 'dart:convert';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show OtpType;

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../providers/wave_final_providers.dart';
import '../../services/supabase_service.dart';
import '../../repositories/profiles_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../widgets/effects/glass_card.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/app_snackbar.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});
  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _exporting = false;
  bool _requesting = false;
  bool _resending = false;

  /// V1: E-Mail-Verify-Self-Service. Supabase Auth trackt die Bestätigung
  /// nativ in user.emailConfirmedAt. Hier: Status anzeigen + Bestätigungs-
  /// Mail erneut senden, falls noch nicht bestätigt. Bei Bestätigung
  /// synchronisieren wir profiles.verified_email (Best-effort).
  Future<void> _resendVerification() async {
    final user = SupabaseService.currentUser;
    final email = user?.email;
    if (email == null) return;
    setState(() => _resending = true);
    try {
      await sb.auth.resend(type: OtpType.signup, email: email);
      if (mounted) {
        AppSnackBar.success(context, 'account.verifySent'.tr());
      }
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, 'account.verifyFailed'.tr());
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  /// Prüft beim Öffnen, ob die E-Mail inzwischen bestätigt wurde und
  /// synchronisiert das in profiles.verified_email (damit das Badge stimmt).
  Future<void> _syncVerifiedFlag() async {
    final user = SupabaseService.currentUser;
    if (user == null) return;
    final confirmed = user.emailConfirmedAt != null;
    if (!confirmed) return;
    try {
      await ProfilesRepository.update(user.id, {'verified_email': true});
    } catch (_) {/* best-effort */}
  }

  @override
  void initState() {
    super.initState();
    _syncVerifiedFlag();
  }

  Future<void> _exportData() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return;
    setState(() => _exporting = true);
    try {
      final dump = <String, dynamic>{
        'exported_at': DateTime.now().toIso8601String(),
        'user_id': uid,
      };
      // BUGFIX (D1): vorher nutzte der Export pauschal 'user_id' für ALLE
      // Tabellen außer profiles → für messages (sender_id), posts (user_id
      // ok), trust_ratings (rater_id), board_posts (author_id) usw. lieferte
      // die Query leer und der Export war unvollständig. Jetzt: korrekte
      // Owner-Spalte je Tabelle. Tabellen mit zwei möglichen Spalten
      // (z.B. trust_ratings rater/rated) werden via OR abgedeckt.
      const single = <String, String>{
        'profiles': 'id',
        'posts': 'user_id',
        'board_posts': 'author_id',
        'messages': 'sender_id',
        'interactions': 'requester_id',
        'saved_posts': 'user_id',
        'user_follows': 'follower_id',
        'karma_log': 'user_id',
        'event_attendees': 'user_id',
        'group_members': 'user_id',
        'marketplace_listings': 'user_id',
        'community_poll_votes': 'user_id',
        'notifications': 'user_id',
      };
      // Tabellen mit zwei Owner-Spalten → OR-Filter.
      const dual = <String, List<String>>{
        'trust_ratings': ['rater_id', 'rated_id'],
        'timebank_entries': ['giver_id', 'receiver_id'],
      };
      final names = [...single.keys, ...dual.keys];
      final results = await Future.wait(names.map((t) async {
        if (single.containsKey(t)) {
          return SettingsRepository.gdprRowsSingle(t, single[t]!, uid);
        }
        final cols = dual[t]!;
        return SettingsRepository.gdprRowsDual(t, cols[0], cols[1], uid);
      }));
      for (var i = 0; i < names.length; i++) {
        dump[names[i]] = results[i];
      }
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/mensaena_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.json';
      final file = File(path);
      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(dump));
      await Share.shareXFiles([XFile(path)],
          text: 'account.export_subject'.tr());
    } catch (_) {
      if (mounted) {
        AppSnackBar.error(context, 'account.export_failed'.tr());
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _requestDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('account.delete_title'.tr(),
            style: AppTypography.display(size: 18, color: AppColors.ink)),
        content: Text('account.delete_body'.tr(),
            style: AppTypography.body(size: 14, color: AppColors.inkSoft)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.herzrotWarm),
            child: Text('account.delete_confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _requesting = true);
    await ref.read(accountDeletionRepoProvider).request();
    ref.invalidate(accountDeletionStatusProvider);
    if (mounted) setState(() => _requesting = false);
  }

  Future<void> _cancelDeletion() async {
    await ref.read(accountDeletionRepoProvider).cancel();
    ref.invalidate(accountDeletionStatusProvider);
  }

  Widget _buildVerifyCard() {
    final user = SupabaseService.currentUser;
    final confirmed = user?.emailConfirmedAt != null;
    final email = user?.email ?? '';
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              confirmed ? LucideIcons.badgeCheck : LucideIcons.mailWarning,
              size: 18,
              color: confirmed ? AppColors.leben : AppColors.amber,
            ),
            const SizedBox(width: 8),
            Text('account.verifyTitle'.tr(),
                style: AppTypography.display(size: 16, color: AppColors.ink)),
          ]),
          const SizedBox(height: 8),
          Text(
            confirmed
                ? 'account.verifyDone'.tr(namedArgs: {'email': email})
                : 'account.verifyPending'.tr(namedArgs: {'email': email}),
            style: AppTypography.body(size: 13, color: AppColors.inkSoft),
          ),
          if (!confirmed) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _resending ? null : _resendVerification,
              icon: _resending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(LucideIcons.send, size: 16),
              label: Text('account.verifyResend'.tr()),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.voidColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(accountDeletionStatusProvider);
    return DashboardScaffold(
      title: 'account.title'.tr(),
      currentRoute: '/dashboard/account',
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _buildVerifyCard(),
          const SizedBox(height: 14),
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(LucideIcons.download,
                      size: 18, color: AppColors.bronze),
                  const SizedBox(width: 8),
                  Text('account.export_title'.tr(),
                      style: AppTypography.display(
                          size: 16, color: AppColors.ink)),
                ]),
                const SizedBox(height: 8),
                Text('account.export_body'.tr(),
                    style:
                        AppTypography.body(size: 13, color: AppColors.inkSoft)),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _exporting ? null : _exportData,
                  icon: _exporting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child:
                              CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(LucideIcons.fileJson, size: 16),
                  label: Text('account.export_button'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.bronze,
                    foregroundColor: AppColors.voidColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          status.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (req) {
              if (req != null) {
                final scheduledStr = req['scheduled_for'] as String?;
                final scheduled =
                    scheduledStr != null ? DateTime.tryParse(scheduledStr)?.toUtc() : null;
                return GlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(LucideIcons.clock,
                            size: 18, color: AppColors.herzrotWarm),
                        const SizedBox(width: 8),
                        Text('account.delete_pending'.tr(),
                            style: AppTypography.display(
                                size: 16, color: AppColors.ink)),
                      ]),
                      const SizedBox(height: 8),
                      if (scheduled != null)
                        Text(
                          'account.delete_scheduled_for'.tr(namedArgs: {
                            'date':
                                DateFormat('dd.MM.yyyy').format(scheduled),
                          }),
                          style: AppTypography.body(
                              size: 13, color: AppColors.inkSoft),
                        ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _cancelDeletion,
                        icon: const Icon(LucideIcons.undo2, size: 16),
                        label: Text('account.delete_cancel'.tr()),
                      ),
                    ],
                  ),
                );
              }
              return GlassCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      const Icon(LucideIcons.trash2,
                          size: 18, color: AppColors.herzrotWarm),
                      const SizedBox(width: 8),
                      Text('account.delete_title'.tr(),
                          style: AppTypography.display(
                              size: 16, color: AppColors.ink)),
                    ]),
                    const SizedBox(height: 8),
                    Text('account.delete_intro'.tr(),
                        style: AppTypography.body(
                            size: 13, color: AppColors.inkSoft)),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: _requesting ? null : _requestDeletion,
                      icon: const Icon(LucideIcons.trash2, size: 16),
                      label: Text('account.delete_button'.tr()),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.herzrot,
                        foregroundColor: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
