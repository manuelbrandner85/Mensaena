import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

/// SKILL: mensaena-features
/// Mentale Unterstuetzung — verifizierte Krisenhotlines DE/AT/CH.
/// Quellen: telefonseelsorge.de/at, 143.ch, rataufdraht.at, hilfetelefon.de.
class MentalSupportScreen extends ConsumerStatefulWidget {
  const MentalSupportScreen({super.key});

  @override
  ConsumerState<MentalSupportScreen> createState() =>
      _MentalSupportScreenState();
}

class _MentalSupportScreenState extends ConsumerState<MentalSupportScreen> {
  String _country = 'DE';

  @override
  void initState() {
    super.initState();
    final countryCode =
        WidgetsBinding.instance.platformDispatcher.locale.countryCode;
    if (countryCode == 'AT') {
      _country = 'AT';
    } else if (countryCode == 'CH') {
      _country = 'CH';
    } else {
      _country = 'DE';
    }
  }

  static const Map<String, _CountryCfg> _hotlines = {
    'DE': _CountryCfg(flag: '🇩🇪', label: 'Deutschland', lines: [
      _Hotline(
        name: 'TelefonSeelsorge (evangelisch)',
        number: '0800 111 0 111',
        desc: 'Kostenlos, anonym, 24/7',
        kind: _Kind.crisis,
      ),
      _Hotline(
        name: 'TelefonSeelsorge (katholisch)',
        number: '0800 111 0 222',
        desc: 'Kostenlos, anonym, 24/7',
        kind: _Kind.crisis,
      ),
      _Hotline(
        name: 'EU-Helpline',
        number: '116 123',
        desc: 'Kostenlos, anonym, 24/7',
        kind: _Kind.crisis,
      ),
      _Hotline(
        name: 'Nummer gegen Kummer — Kinder & Jugend',
        number: '116 111',
        desc: 'Mo–Sa 14–20 Uhr, kostenlos',
        kind: _Kind.youth,
      ),
      _Hotline(
        name: 'Elterntelefon',
        number: '0800 111 0 550',
        desc: 'Mo–Fr 9–11 & 17–19 Uhr, kostenlos',
        kind: _Kind.youth,
      ),
      _Hotline(
        name: 'Hilfetelefon — Gewalt gegen Frauen',
        number: '116 016',
        desc: 'Kostenlos, anonym, 24/7, viele Sprachen',
        kind: _Kind.violence,
      ),
      _Hotline(
        name: 'Online-Beratung TelefonSeelsorge',
        number: 'online.telefonseelsorge.de',
        desc: 'Chat & E-Mail, kostenlos',
        kind: _Kind.online,
        url: 'https://online.telefonseelsorge.de',
      ),
    ]),
    'AT': _CountryCfg(flag: '🇦🇹', label: 'Österreich', lines: [
      _Hotline(
        name: 'Telefonseelsorge Österreich',
        number: '142',
        desc: 'Kostenlos, anonym, 24/7',
        kind: _Kind.crisis,
      ),
      _Hotline(
        name: 'Rat auf Draht — Kinder & Jugend',
        number: '147',
        desc: 'Kostenlos, anonym, 24/7',
        kind: _Kind.youth,
      ),
      _Hotline(
        name: 'Frauenhelpline gegen Gewalt',
        number: '0800 222 555',
        desc: 'Kostenlos, anonym, 24/7',
        kind: _Kind.violence,
      ),
      _Hotline(
        name: 'Männernotruf',
        number: '0800 400 777',
        desc: 'Kostenlos, 24/7',
        kind: _Kind.crisis,
      ),
      _Hotline(
        name: 'PSD Wien — Sozialpsychiatrischer Notdienst',
        number: '01 31330',
        desc: 'Psychiatrische Krisenintervention, 24/7',
        kind: _Kind.crisis,
      ),
      _Hotline(
        name: 'Suizidprävention (Online-Chat)',
        number: 'suizid-praevention.gv.at',
        desc: 'Online-Chat, 10–22 Uhr',
        kind: _Kind.online,
        url: 'https://www.suizid-praevention.gv.at',
      ),
      _Hotline(
        name: 'Online-Beratung Telefonseelsorge AT',
        number: 'onlineberatung-telefonseelsorge.at',
        desc: 'Chat & E-Mail, kostenlos',
        kind: _Kind.online,
        url: 'https://onlineberatung-telefonseelsorge.at',
      ),
    ]),
    'CH': _CountryCfg(flag: '🇨🇭', label: 'Schweiz', lines: [
      _Hotline(
        name: 'Die Dargebotene Hand',
        number: '143',
        desc: 'Kostenlos, anonym, 24/7',
        kind: _Kind.crisis,
      ),
      _Hotline(
        name: 'Dargebotene Hand (Englisch)',
        number: '0800 143 000',
        desc: 'English helpline, kostenlos',
        kind: _Kind.crisis,
      ),
      _Hotline(
        name: 'Kinder-/Jugendtelefon',
        number: '147',
        desc: 'Kostenlos, anonym, 24/7',
        kind: _Kind.youth,
      ),
      _Hotline(
        name: 'Hilfetelefon Häusliche Gewalt',
        number: '0800 040 040',
        desc: 'Kostenlos, 24/7',
        kind: _Kind.violence,
      ),
      _Hotline(
        name: 'Online-Chat Dargebotene Hand',
        number: '143.ch/chat',
        desc: 'Chat, kostenlos',
        kind: _Kind.online,
        url: 'https://www.143.ch/hilfesuchende/chat/',
      ),
    ]),
  };

  Future<void> _tap(_Hotline h) async {
    final raw = h.url ?? 'tel:${h.number.replaceAll(RegExp(r'[^0-9+]'), '')}';
    final mode = h.url != null
        ? LaunchMode.externalApplication
        : LaunchMode.platformDefault;
    await safeLaunchHotline(context, raw, mode);
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _hotlines[_country]!;

    return DashboardScaffold(
      title: 'modules.mentalSupport'.tr(),
      currentRoute: '/dashboard/mental-support',
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            await Future<void>.delayed(const Duration(milliseconds: 400));
            if (mounted) setState(() {});
          },
          child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _Banner(),
            const SizedBox(height: 14),
            _CountrySwitcher(
              active: _country,
              onChange: (c) => setState(() => _country = c),
            ),
            const SizedBox(height: 14),
            ...cfg.lines.map((h) => _HotlineTile(
                  hotline: h,
                  onTap: () => _tap(h),
                )),
            const SizedBox(height: 18),
            _EmergencyFooter(),
          ],
          ),
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.shield,
              color: AppColors.tealSoft, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Du bist nicht allein.',
                  style: AppTypography.body(
                    size: 14,
                    color: AppColors.ink,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Krisenhotlines sind kostenlos, anonym und erreichbar — '
                  'rund um die Uhr. Tippe eine Nummer zum Anrufen.',
                  style: AppTypography.body(
                    size: 12,
                    color: AppColors.inkSoft,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountrySwitcher extends StatelessWidget {
  const _CountrySwitcher({required this.active, required this.onChange});
  final String active;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final entry in _MentalSupportScreenState._hotlines.entries) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChange(entry.key),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active == entry.key
                      ? AppColors.amber.withValues(alpha: 0.18)
                      : AppColors.elevated,
                  border: Border.all(
                    color: active == entry.key
                        ? AppColors.amber.withValues(alpha: 0.6)
                        : AppColors.line,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Text(entry.value.flag,
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 2),
                    Text(entry.value.label,
                        style: AppTypography.label(
                          size: 9,
                          color: active == entry.key
                              ? AppColors.amber
                              : AppColors.inkSoft,
                        )),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _HotlineTile extends StatelessWidget {
  const _HotlineTile({required this.hotline, required this.onTap});
  final _Hotline hotline;
  final VoidCallback onTap;

  Color _accent() {
    switch (hotline.kind) {
      case _Kind.crisis:
        return AppColors.tealSoft;
      case _Kind.youth:
        return AppColors.herzrotWarm;
      case _Kind.violence:
        return AppColors.herzrot;
      case _Kind.online:
        return AppColors.amber;
    }
  }

  IconData _icon() {
    switch (hotline.kind) {
      case _Kind.crisis:
        return LucideIcons.phone;
      case _Kind.youth:
        return LucideIcons.heart;
      case _Kind.violence:
        return LucideIcons.shieldAlert;
      case _Kind.online:
        return LucideIcons.messageCircle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _accent();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface.withValues(alpha: 0.6),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_icon(), color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hotline.name,
                    style: AppTypography.body(
                      size: 13,
                      color: AppColors.ink,
                      weight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    hotline.number,
                    style: AppTypography.mono(size: 15, color: color),
                  ),
                  const SizedBox(height: 3),
                  Text(hotline.desc, style: AppTypography.caption()),
                ],
              ),
            ),
            Icon(
              hotline.url != null
                  ? LucideIcons.externalLink
                  : LucideIcons.phoneCall,
              color: color,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

/// Robuster Hotline-Launch: vorher konnten Notruf-/Hotline-Taps still
/// crashen (Uri.parse-Exception oder fehlender Handler). Jetzt Uri.tryParse
/// + try/catch + Snackbar-Hinweis bei Misserfolg.
Future<void> safeLaunchHotline(
    BuildContext context, String raw, LaunchMode mode) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(raw);
  var ok = false;
  if (uri != null) {
    try {
      ok = await launchUrl(uri, mode: mode);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok) {
    messenger.showSnackBar(SnackBar(
      content: Text('mentalSupport.launchFailed'.tr()),
    ));
  }
}

class _EmergencyFooter extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.herzrot.withValues(alpha: 0.10),
        border: Border.all(color: AppColors.herzrot.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.alertTriangle,
              color: AppColors.herzrotWarm, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Im akuten Notfall: 112 (EU-weit)',
                  style: AppTypography.body(
                    size: 13,
                    color: AppColors.herzrotWarm,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Bei Lebensgefahr — Polizei, Feuerwehr, Rettung.',
                  style: AppTypography.caption(),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () =>
                safeLaunchHotline(context, 'tel:112', LaunchMode.platformDefault),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.herzrot,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '112',
                style: AppTypography.mono(
                  size: 14,
                  color: AppColors.ink,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _Kind { crisis, youth, violence, online }

class _CountryCfg {
  const _CountryCfg({
    required this.flag,
    required this.label,
    required this.lines,
  });
  final String flag;
  final String label;
  final List<_Hotline> lines;
}

class _Hotline {
  const _Hotline({
    required this.name,
    required this.number,
    required this.desc,
    required this.kind,
    this.url,
  });
  final String name;
  final String number;
  final String desc;
  final _Kind kind;
  final String? url;
}
