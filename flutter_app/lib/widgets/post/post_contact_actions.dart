/// SKILL: mensaena-features + mensaena-design
/// PostContactActions (Schritt 9): Intent-spezifische CTAs im Post-Detail.
/// Lädt PostContactPreference + Helper-Count + meine Anfrage, rendert je
/// nach PostIntent unterschiedliche Layouts. Datenschutz: zeigt Telefon/
/// E-Mail/WA erst wenn meine Anfrage akzeptiert ist (revealedContactInfo).
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/post.dart';
import '../../models/post_contact_preference.dart';
import '../../models/post_intent.dart';
import '../../providers/post_contact_provider.dart';
import '../../repositories/conversations_repository.dart';
import '../../services/haptics.dart';
import '../../services/supabase_service.dart';
import '../effects/celebrate_burst.dart';
import 'contact_requests_manager.dart';

class PostContactActions extends ConsumerWidget {
  const PostContactActions({required this.post, super.key});

  final Post post;

  bool get _isMine =>
      post.userId == SupabaseService.currentUser?.id;

  Color _ctaColor(PostIntent intent) {
    switch (intent.ctaColorKey) {
      case 'error':
        return AppColors.herzrot;
      case 'success':
        return AppColors.leben;
      case 'warning':
        return AppColors.amber;
      default:
        return AppColors.bronze;
    }
  }

  IconData _ctaIcon(PostIntent intent) {
    switch (intent.ctaIconName) {
      case 'hand_helping':
        return LucideIcons.helpingHand;
      case 'package':
        return LucideIcons.package;
      case 'calendar_check':
        return LucideIcons.calendarCheck;
      case 'search':
        return LucideIcons.search;
      case 'alert_triangle':
        return LucideIcons.alertTriangle;
      case 'info':
        return LucideIcons.info;
      case 'users':
        return LucideIcons.users;
      default:
        return LucideIcons.messageCircle;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final intent = post.postIntent;

    // Eigenes Post → Manage-Anfragen statt CTA (R8)
    if (_isMine) {
      return _OwnerManageBar(post: post);
    }

    // info_share / warning → kein Kontakt-Button
    if (!intent.requiresContact) {
      return _NonContactRow(post: post, intent: intent);
    }

    final prefAsync = ref.watch(postContactPreferenceProvider(post.id));
    final myReqAsync = ref.watch(myRequestForPostProvider(post.id));
    final revealedAsync = ref.watch(revealedContactInfoProvider(post.id));
    final helperCountAsync =
        intent.isHelpRelated || intent == PostIntent.eventInvite
            ? ref.watch(helperCountProvider(post.id))
            : const AsyncValue<int>.data(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status-Banner falls Anfrage bereits laeuft
        myReqAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (req) {
            if (req == null || req.isCompleted) return const SizedBox.shrink();
            if (req.isPending) {
              return _StatusBanner(
                icon: LucideIcons.hourglass,
                color: AppColors.amber,
                text: 'contact.request_pending'.tr(),
              );
            }
            if (req.isAccepted) {
              return _StatusBanner(
                icon: LucideIcons.checkCircle,
                color: AppColors.leben,
                text: 'contact.request_accepted'.tr(),
              );
            }
            if (req.isDeclined) {
              return _StatusBanner(
                icon: LucideIcons.xCircle,
                color: AppColors.herzrotWarm,
                text: 'contact.request_declined'.tr(),
              );
            }
            return const SizedBox.shrink();
          },
        ),

        // Primaerer CTA
        prefAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.bronze),
              ),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (pref) {
            final myReq = myReqAsync.valueOrNull;
            final alreadyOpen =
                myReq != null && (myReq.isPending || myReq.isAccepted);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PrimaryCta(
                  intent: intent,
                  color: _ctaColor(intent),
                  icon: _ctaIcon(intent),
                  disabled: alreadyOpen,
                  onPressed: () => _openContactSheet(
                      context, ref, pref, intent),
                ),
                if (helperCountAsync.valueOrNull != null &&
                    helperCountAsync.value! > 0) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      intent == PostIntent.eventInvite
                          ? 'contact.requests.participants_count'
                              .tr(namedArgs: {'count': '${helperCountAsync.value}'})
                          : 'contact.requests.helpers_count'
                              .tr(namedArgs: {'count': '${helperCountAsync.value}'}),
                      style: AppTypography.caption(),
                    ),
                  ),
                ],
                // Sekundaere Methoden + revealed Kontaktdaten
                const SizedBox(height: 8),
                _SecondaryMethodsRow(
                  pref: pref,
                  revealed: revealedAsync.valueOrNull,
                  intent: intent,
                  postOwnerId: post.userId,
                ),
                if (pref != null && pref.hasAvailability) ...[
                  const SizedBox(height: 8),
                  _AvailabilityChip(pref: pref),
                ],
                if (pref?.contactNote != null &&
                    pref!.contactNote!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(pref.contactNote!,
                      style: AppTypography.body(
                          size: 12,
                          color: AppColors.inkSoft,
                          height: 1.4)),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _openContactSheet(
    BuildContext context,
    WidgetRef ref,
    PostContactPreference? pref,
    PostIntent intent,
  ) async {
    Haptics.confirm();
    final methods = pref?.enabledMethods ?? const ['in_app_chat'];
    final msgCtrl = TextEditingController();
    String selectedMethod = methods.first;

    final result = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 22,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 22,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('contact.requests.choose_method'.tr(),
                    style: AppTypography.display(
                        size: 16, color: AppColors.ink)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final m in methods)
                      ChoiceChip(
                        label: Text(_methodLabel(m)),
                        selected: selectedMethod == m,
                        onSelected: (_) =>
                            setState(() => selectedMethod = m),
                        selectedColor:
                            AppColors.bronze.withValues(alpha: 0.3),
                        backgroundColor: AppColors.elevated,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: selectedMethod == m
                                ? AppColors.bronze
                                : AppColors.line,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: msgCtrl,
                  maxLines: 4,
                  maxLength: 400,
                  style:
                      AppTypography.body(size: 14, color: AppColors.ink),
                  decoration: InputDecoration(
                    hintText:
                        'contact.requests.message_placeholder'.tr(),
                    filled: true,
                    fillColor: AppColors.elevated,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () =>
                        Navigator.pop(ctx, selectedMethod),
                    icon: const Icon(LucideIcons.send, size: 14),
                    label: Text(intent.primaryCtaKey.tr()),
                    style: FilledButton.styleFrom(
                      backgroundColor: _ctaColor(intent),
                      foregroundColor: AppColors.voidColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        });
      },
    );

    if (result == null) return;
    try {
      await ref
          .read(postContactRepositoryProvider)
          .createContactRequest(
            postId: post.id,
            postOwnerId: post.userId,
            contactMethod: result,
            message: msgCtrl.text.trim().isEmpty ? null : msgCtrl.text.trim(),
          );
      ref.invalidate(myRequestForPostProvider(post.id));
      ref.invalidate(helperCountProvider(post.id));
      if (!context.mounted) return;
      // Animation je nach Intent
      if (intent == PostIntent.eventInvite) {
        CelebrateBurst.fire(context, ref: ref);
      } else {
        Haptics.success();
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('contact.request_sent'.tr(),
            style:
                AppTypography.body(size: 13, color: AppColors.ink)),
      ));
    } on StateError catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text(
          e.message == 'already_open'
              ? 'contact.already_requested'.tr()
              : e.message,
          style: AppTypography.body(size: 13, color: AppColors.ink),
        ),
      ));
    } catch (_) {
      // ignore – silent fail beyond debug log in repo
    }
  }

  String _methodLabel(String m) {
    switch (m) {
      case 'in_app_chat':
        return 'contact.in_app_chat'.tr();
      case 'phone':
        return 'contact.phone'.tr();
      case 'email':
        return 'contact.email'.tr();
      case 'whatsapp':
        return 'contact.whatsapp'.tr();
      case 'location_meetup':
        return 'contact.location_meetup'.tr();
      default:
        return m;
    }
  }
}

class _PrimaryCta extends StatelessWidget {
  const _PrimaryCta({
    required this.intent,
    required this.color,
    required this.icon,
    required this.disabled,
    required this.onPressed,
  });
  final PostIntent intent;
  final Color color;
  final IconData icon;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: disabled ? null : onPressed,
      icon: Icon(icon, size: 18),
      label: Text(intent.primaryCtaKey.tr(),
          style: AppTypography.body(
              size: 15,
              color: AppColors.voidColor,
              weight: FontWeight.w700)),
      style: FilledButton.styleFrom(
        backgroundColor: color,
        foregroundColor: AppColors.voidColor,
        disabledBackgroundColor: color.withValues(alpha: 0.4),
        padding: const EdgeInsets.symmetric(vertical: 16),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _SecondaryMethodsRow extends ConsumerWidget {
  const _SecondaryMethodsRow({
    required this.pref,
    required this.revealed,
    required this.intent,
    required this.postOwnerId,
  });
  final PostContactPreference? pref;
  final PostContactPreference? revealed;
  final PostIntent intent;
  final String postOwnerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = pref;
    if (p == null) return const SizedBox.shrink();
    final methods = p.enabledMethods;
    if (methods.length <= 1) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      children: [
        for (final m in methods.where((x) => x != 'in_app_chat'))
          _MethodChip(
            method: m,
            revealed: revealed,
            onTap: () => _onTap(context, m, revealed),
          ),
        if (methods.contains('in_app_chat'))
          _MethodChip(
            method: 'in_app_chat',
            revealed: revealed,
            onTap: () async {
              final convId =
                  await ConversationsRepository.getOrCreateDm(postOwnerId);
              if (!context.mounted || convId == null) return;
              context.go('/dashboard/messages/$convId');
            },
          ),
      ],
    );
  }

  Future<void> _onTap(
      BuildContext context, String method, PostContactPreference? revealed) async {
    if (method != 'in_app_chat' && method != 'location_meetup') {
      // Telefon / Email / WhatsApp → nur wenn revealed
      if (revealed == null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          backgroundColor: AppColors.surface,
          content: Text('contact.request_pending'.tr(),
              style: AppTypography.body(
                  size: 13, color: AppColors.ink)),
        ));
        return;
      }
    }
    switch (method) {
      case 'phone':
        final p = revealed!.phoneNumber;
        if (p == null || p.isEmpty) return;
        await launchUrl(Uri.parse('tel:$p'));
        break;
      case 'email':
        final e = revealed!.emailAddress;
        if (e == null || e.isEmpty) return;
        await launchUrl(Uri.parse('mailto:$e'));
        break;
      case 'whatsapp':
        final w = revealed!.whatsappNumber;
        if (w == null || w.isEmpty) return;
        final clean = w.replaceAll(RegExp(r'[^0-9+]'), '');
        await launchUrl(
            Uri.parse('https://wa.me/${clean.replaceAll('+', '')}'));
        break;
      case 'location_meetup':
        final note = revealed?.meetupNote ?? pref?.meetupNote;
        if (note == null) return;
        showModalBottomSheet<void>(
          context: context,
          backgroundColor: AppColors.surface,
          builder: (_) => Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(LucideIcons.mapPin,
                        size: 18, color: AppColors.bronze),
                    const SizedBox(width: 8),
                    Text('contact.location_meetup'.tr(),
                        style: AppTypography.display(
                            size: 16, color: AppColors.ink)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(note,
                    style: AppTypography.body(
                        size: 14,
                        color: AppColors.inkSoft,
                        height: 1.5)),
              ],
            ),
          ),
        );
        break;
    }
  }
}

class _MethodChip extends StatelessWidget {
  const _MethodChip({
    required this.method,
    required this.revealed,
    required this.onTap,
  });
  final String method;
  final PostContactPreference? revealed;
  final VoidCallback onTap;

  IconData get _icon {
    switch (method) {
      case 'in_app_chat':
        return LucideIcons.messageCircle;
      case 'phone':
        return LucideIcons.phone;
      case 'email':
        return LucideIcons.mail;
      case 'whatsapp':
        return LucideIcons.messageSquare;
      case 'location_meetup':
        return LucideIcons.mapPin;
      default:
        return LucideIcons.circle;
    }
  }

  bool get _locked =>
      method != 'in_app_chat' &&
      method != 'location_meetup' &&
      revealed == null;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(_locked ? LucideIcons.lock : _icon,
          size: 14,
          color: _locked ? AppColors.mute : AppColors.bronze),
      label: Text(
        () {
          switch (method) {
            case 'in_app_chat':
              return 'contact.in_app_chat'.tr();
            case 'phone':
              return 'contact.cta.call_now'.tr();
            case 'email':
              return 'contact.email'.tr();
            case 'whatsapp':
              return 'contact.whatsapp'.tr();
            case 'location_meetup':
              return 'contact.location_meetup'.tr();
            default:
              return method;
          }
        }(),
        style: AppTypography.body(
          size: 12,
          color: _locked ? AppColors.mute : AppColors.ink,
          weight: FontWeight.w600,
        ),
      ),
      onPressed: onTap,
      backgroundColor: AppColors.elevated,
      side: BorderSide(
          color: _locked
              ? AppColors.line
              : AppColors.bronze.withValues(alpha: 0.4)),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8)),
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({required this.pref});
  final PostContactPreference pref;

  @override
  Widget build(BuildContext context) {
    final fromTo = [
      if (pref.availableFrom != null)
        pref.availableFrom!.substring(0, 5),
      if (pref.availableUntil != null)
        pref.availableUntil!.substring(0, 5),
    ].join(' – ');
    final days = pref.availableDays?.join('·') ?? '';
    final txt = [fromTo, days].where((s) => s.isNotEmpty).join('  ·  ');
    if (txt.isEmpty) return const SizedBox.shrink();
    return Row(
      children: [
        const Icon(LucideIcons.clock, size: 12, color: AppColors.mute),
        const SizedBox(width: 4),
        Text(txt, style: AppTypography.caption()),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 8),
            Text(text,
                style: AppTypography.body(
                    size: 12, color: color, weight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _OwnerManageBar extends ConsumerWidget {
  const _OwnerManageBar({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reqs = ref.watch(postContactRequestsProvider(post.id));
    final pending = reqs.maybeWhen(
      data: (l) => l.where((r) => r.isPending).length,
      orElse: () => 0,
    );
    return FilledButton.icon(
      onPressed: () => ContactRequestsManager.show(context, post.id),
      icon: const Icon(LucideIcons.inbox, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('contact.manage_requests'.tr(),
              style: AppTypography.body(
                  size: 14,
                  color: AppColors.voidColor,
                  weight: FontWeight.w700)),
          if (pending > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.voidColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$pending',
                  style: AppTypography.body(
                      size: 11,
                      color: AppColors.voidColor,
                      weight: FontWeight.w700)),
            ),
          ],
        ],
      ),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.bronze,
        foregroundColor: AppColors.voidColor,
        padding: const EdgeInsets.symmetric(vertical: 14),
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

/// Info-Share / Warning → kein Kontakt, nur Danke + Teilen
class _NonContactRow extends StatelessWidget {
  const _NonContactRow({required this.post, required this.intent});
  final Post post;
  final PostIntent intent;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () {
              Haptics.tap();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(intent.primaryCtaKey.tr()),
              ));
            },
            icon: Icon(intent == PostIntent.warning
                ? LucideIcons.megaphone
                : LucideIcons.heart),
            label: Text(intent.primaryCtaKey.tr()),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.elevated,
              foregroundColor: AppColors.ink,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton.icon(
          onPressed: () {
            Share.share(
              '${post.title}\nhttps://www.mensaena.de/dashboard/posts/${post.id}',
            );
          },
          icon: const Icon(LucideIcons.share2, size: 14),
          label: Text('contact.cta.share'.tr()),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.bronze,
            side: BorderSide(
                color: AppColors.bronze.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ],
    );
  }
}
