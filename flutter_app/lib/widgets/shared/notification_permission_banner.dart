/// SKILL: mensaena-features
/// NotificationPermissionBanner (V4) — soft prompt for push permission.
///
/// Behaviour:
///   1. After a 5-second warm-up delay, ask FirebaseMessaging for the
///      current permission settings.
///   2. If the user has not been prompted yet (`notDetermined`) or denied
///      previously (`denied`), AND we have not already shown this banner,
///      slide a GlassCard banner in from the top.
///   3. CTA triggers `requestPermission()`; either way (CTA or close-X)
///      we set `mensaena_push_banner_shown=true` in secure storage so the
///      banner stays dismissed across sessions.
///
/// Returns `SizedBox.shrink()` when nothing should be shown.
library;

import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../effects/glass_card.dart';

const String kPushBannerShownKey = 'mensaena_push_banner_shown';

class NotificationPermissionBanner extends ConsumerStatefulWidget {
  const NotificationPermissionBanner({super.key});

  @override
  ConsumerState<NotificationPermissionBanner> createState() =>
      _NotificationPermissionBannerState();
}

class _NotificationPermissionBannerState
    extends ConsumerState<NotificationPermissionBanner>
    with SingleTickerProviderStateMixin {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  Timer? _delayTimer;
  bool _visible = false;
  bool _decided = false; // true once we know whether to show or hide
  late final AnimationController _slideCtrl;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic),
    );

    _delayTimer = Timer(const Duration(seconds: 5), _evaluate);
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _evaluate() async {
    if (!mounted) return;
    try {
      final shown = await _storage.read(key: kPushBannerShownKey);
      if (shown == 'true') {
        if (mounted) setState(() => _decided = true);
        return;
      }
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      final shouldShow =
          settings.authorizationStatus == AuthorizationStatus.notDetermined ||
              settings.authorizationStatus == AuthorizationStatus.denied;
      if (!mounted) return;
      setState(() {
        _decided = true;
        _visible = shouldShow;
      });
      if (shouldShow) {
        _slideCtrl.forward();
      }
    } catch (e) {
      debugPrint('NotificationPermissionBanner: evaluate failed: $e');
      if (mounted) setState(() => _decided = true);
    }
  }

  Future<void> _markShown() async {
    try {
      await _storage.write(key: kPushBannerShownKey, value: 'true');
    } catch (_) {/* non-fatal */}
  }

  Future<void> _onEnable() async {
    try {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    } catch (e) {
      debugPrint('NotificationPermissionBanner: request failed: $e');
    }
    await _markShown();
    await _dismiss();
  }

  Future<void> _onClose() async {
    await _markShown();
    await _dismiss();
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _slideCtrl.reverse();
    if (!mounted) return;
    setState(() => _visible = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_decided || !_visible) return const SizedBox.shrink();

    final mq = MediaQuery.of(context);
    return SlideTransition(
      position: _slideAnim,
      child: Padding(
        // Sit above any AppBar / SafeArea — caller is expected to place this
        // at the very top of the body (e.g. inside a Column above the rest).
        padding: EdgeInsets.fromLTRB(
          12,
          mq.padding.top + 8,
          12,
          8,
        ),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          borderRadius: 14,
          child: Container(
            constraints: const BoxConstraints(minHeight: 60),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  AppColors.amberGlow,
                  Colors.transparent,
                ],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.amberGlow,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    LucideIcons.bell,
                    size: 18,
                    color: AppColors.amber,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'notif.bannerTitle'.tr(),
                        style: AppTypography.body(
                          size: 13,
                          color: AppColors.ink,
                          weight: FontWeight.w600,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'notif.bannerBody'.tr(),
                        style: AppTypography.body(
                          size: 11,
                          color: AppColors.inkSoft,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _onEnable,
                  style: TextButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.voidColor,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    minimumSize: const Size(0, 32),
                  ),
                  child: Text(
                    'notif.enable'.tr(),
                    style: AppTypography.body(
                      size: 12,
                      color: AppColors.voidColor,
                      weight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _onClose,
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints(minWidth: 32, minHeight: 32),
                  icon: const Icon(
                    LucideIcons.x,
                    size: 16,
                    color: AppColors.inkSoft,
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
