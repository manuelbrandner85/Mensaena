/// SKILL: mensaena-features (UX-Welle1 G2)
/// Badge-Detail-Sheet — zeigt Name, Beschreibung, Wie-Bekomme-Ich-Das,
/// Rarity + Punkte. Cinema-GlassCard mit Rarity-Tint.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/badge.dart';

class BadgeDetailSheet {
  const BadgeDetailSheet._();

  static Future<void> show(BuildContext context, BadgeModel badge,
      {bool earned = false}) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.sheetBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _Body(badge: badge, earned: earned),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.badge, required this.earned});
  final BadgeModel badge;
  final bool earned;

  Color _rarityColor() {
    switch (badge.rarity) {
      case 'legendary':
        return AppColors.amber;
      case 'epic':
        return AppColors.bronze;
      case 'rare':
        return AppColors.tealSoft;
      case 'uncommon':
        return AppColors.leben;
      default:
        return AppColors.mute;
    }
  }

  String _howToUnlock() {
    final v = badge.requirementValue;
    switch (badge.requirementType) {
      case 'register':
        return 'Registrierung in Mensaena abschließen.';
      case 'posts_created':
        return 'Erstelle $v Beiträge — egal welcher Art.';
      case 'help_offered':
        return 'Biete $v mal Hilfe an und werde angenommen.';
      case 'groups_joined':
        return 'Tritt $v Gruppen bei.';
      case 'groups_created':
        return 'Gründe $v Gruppen.';
      case 'events_created':
        return 'Erstelle $v Veranstaltungen.';
      case 'event_min_attendees':
        return 'Erstelle ein Event mit mindestens $v Teilnehmenden.';
      case 'articles_written':
        return 'Schreibe $v Wiki-Artikel.';
      case 'courses_created':
        return 'Erstelle $v Bildungs-Kurse.';
      case 'trust_score':
        return 'Erreiche einen Trust-Score von $v Sternen.';
      case 'challenges_completed':
        return 'Schließe $v Challenges erfolgreich ab.';
      case 'rescue_completed':
        return 'Mache erfolgreich $v Tier-Rettungs-Posts.';
      case 'species_identified':
        return 'Bestimme $v Pflanzen/Tiere via Foto.';
      case 'items_given':
        return 'Verschenke $v Sachen über den Marktplatz.';
      case 'foodsharing':
        return 'Mache deine erste Foodsharing-Aktion.';
      case 'timebank_hours':
        return 'Investiere $v Stunden in die Zeitbank.';
      case 'comments_written':
        return 'Schreibe $v Kommentare auf Beiträgen.';
      case 'invitees_joined':
        return 'Lade $v Personen ein die wirklich beitreten.';
      case 'followers':
        return 'Sammle $v Follower:innen.';
      case 'streak_days':
        return 'Logge dich $v Tage in Folge ein.';
      case 'legendary_helper':
        return 'Erreiche $v Hilfsangebote bei Trust-Score 4.5+.';
      default:
        return badge.description ?? 'Unbekannte Bedingung.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _rarityColor();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Großes Icon mit Glow
            Container(
              width: 80,
              height: 80,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: earned ? 0.25 : 0.10),
                border: Border.all(
                    color: color.withValues(alpha: earned ? 0.9 : 0.4),
                    width: 2),
                boxShadow: earned
                    ? [
                        BoxShadow(
                          color: color.withValues(alpha: 0.45),
                          blurRadius: 16,
                          spreadRadius: -2,
                        ),
                      ]
                    : null,
              ),
              child: Icon(
                _iconFor(badge.icon),
                size: 38,
                color: color,
              ),
            ),
            const SizedBox(height: 14),
            Text(badge.name,
                style: AppTypography.display(size: 20, color: AppColors.ink)),
            const SizedBox(height: 4),
            // Rarity-Pill + Punkte
            Wrap(spacing: 6, children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(badge.rarity.toUpperCase(),
                    style: AppTypography.label(size: 9, color: color)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.amber.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.4)),
                ),
                child: Text('+${badge.points} Karma',
                    style: AppTypography.label(
                        size: 9, color: AppColors.amber)),
              ),
            ]),
            const SizedBox(height: 18),
            if (badge.description != null &&
                badge.description!.trim().isNotEmpty) ...[
              Text(badge.description!,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                      size: 13, color: AppColors.inkSoft, height: 1.5)),
              const SizedBox(height: 18),
            ],
            // "Wie bekomme ich das?" — der eigentliche G2-Wert
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.bronze.withValues(alpha: 0.10),
                border: Border.all(
                    color: AppColors.bronze.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.bronze.withValues(alpha: 0.25),
                      ),
                      child: Icon(
                        earned
                            ? LucideIcons.checkCircle2
                            : LucideIcons.target,
                        size: 16,
                        color: earned ? AppColors.leben : AppColors.bronze,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            earned
                                ? 'Bereits erspielt 🎉'
                                : 'Wie bekomme ich das?',
                            style: AppTypography.label(
                                size: 10,
                                color: earned
                                    ? AppColors.leben
                                    : AppColors.bronze),
                          ),
                          const SizedBox(height: 4),
                          Text(_howToUnlock(),
                              style: AppTypography.body(
                                  size: 13,
                                  color: AppColors.ink,
                                  height: 1.4)),
                        ],
                      ),
                    ),
                  ]),
            ),
            const SizedBox(height: 16),
            // F55 Achievement-Sharing: nur sichtbar wenn earned.
            if (earned)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final caption = 'badges.shareCaption'.tr(
                          namedArgs: {
                            'name': badge.name,
                          });
                      await Share.share(
                        '$caption\n\nhttps://www.mensaena.de',
                        subject: badge.name,
                      );
                    },
                    icon: const Icon(LucideIcons.share2, size: 16),
                    label: Text('badges.shareBtn'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.bronze,
                      side: BorderSide(
                          color: AppColors.bronze.withValues(alpha: 0.5)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.bronze,
                  foregroundColor: AppColors.voidColor,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text('common.close'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String? key) {
    switch (key) {
      case 'star':
        return LucideIcons.star;
      case 'zap':
        return LucideIcons.zap;
      case 'heart':
        return LucideIcons.heart;
      case 'users':
      case 'users-round':
        return LucideIcons.users;
      case 'flame':
        return LucideIcons.flame;
      case 'calendar':
      case 'calendar-check':
        return LucideIcons.calendar;
      case 'book':
      case 'book-open':
      case 'library':
        return LucideIcons.bookOpen;
      case 'trophy':
        return LucideIcons.trophy;
      case 'shield':
      case 'shield-check':
        return LucideIcons.shield;
      case 'target':
        return LucideIcons.target;
      case 'crown':
        return LucideIcons.crown;
      case 'medal':
        return LucideIcons.medal;
      case 'magnet':
        return LucideIcons.magnet;
      case 'paw-print':
        return LucideIcons.heart;
      case 'leaf':
        return LucideIcons.leaf;
      case 'flower-2':
        return LucideIcons.flower2;
      case 'gift':
        return LucideIcons.gift;
      case 'recycle':
        return LucideIcons.recycle;
      case 'clock':
        return LucideIcons.clock;
      case 'message-square':
        return LucideIcons.messageSquare;
      case 'send':
        return LucideIcons.send;
      case 'sunrise':
        return LucideIcons.sunrise;
      case 'graduation-cap':
        return LucideIcons.graduationCap;
      default:
        return LucideIcons.award;
    }
  }
}
