/// SKILL: mensaena-features + mensaena-design
/// Vorschau-Widgets fuer den Marketing-Admin-Bereich.
/// - EmailPreview: rendert das Kampagnen-HTML wie ein E-Mail-Client (heller
///   Rahmen, damit der Admin das echte Aussehen sieht).
/// - PushPreview: stellt eine Push-Notification als realitaetsnahes Mockup dar.
/// - sampleFill: ersetzt {platzhalter} durch Beispieldaten fuer die Vorschau.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';

/// Ersetzt die üblichen Personalisierungs-Platzhalter durch Beispielwerte,
/// damit die Vorschau nicht „{vorname}" roh anzeigt.
String sampleFill(String input) {
  const samples = <String, String>{
    '{vorname}': 'Anna',
    '{name}': 'Anna Becker',
    '{nickname}': 'anna',
    '{region}': 'Berlin-Mitte',
    '{karma}': '128',
    '{stadt}': 'Berlin',
  };
  var out = input;
  samples.forEach((k, v) => out = out.replaceAll(k, v));
  return out;
}

/// Rendert E-Mail-HTML in einem hellen „Postfach"-Rahmen.
class EmailPreview extends StatelessWidget {
  const EmailPreview({super.key, required this.subject, required this.html});
  final String subject;
  final String html;

  @override
  Widget build(BuildContext context) {
    final filledHtml = sampleFill(html);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Betreffzeile wie im Posteingang.
          Container(
            color: const Color(0xFFF3F4F6),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('marketing.pv_from'.tr(),
                    style: const TextStyle(
                        fontSize: 11, color: Color(0xFF6B7280))),
                const SizedBox(height: 2),
                Text(
                  sampleFill(subject).isEmpty
                      ? 'marketing.pv_no_subject'.tr()
                      : sampleFill(subject),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827)),
                ),
              ],
            ),
          ),
          // Gerendertes HTML auf weißem Grund (DefaultTextStyle dunkel,
          // damit unstyled Text auf Weiß lesbar bleibt).
          Padding(
            padding: const EdgeInsets.all(14),
            child: DefaultTextStyle(
              style: const TextStyle(color: Color(0xFF111827), fontSize: 14),
              child: filledHtml.trim().isEmpty
                  ? Text('marketing.pv_empty_body'.tr(),
                      style: const TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 13))
                  : HtmlWidget(filledHtml,
                      textStyle:
                          const TextStyle(color: Color(0xFF111827), fontSize: 14)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Realitätsnahes Push-Notification-Mockup (Android-Stil).
class PushPreview extends StatelessWidget {
  const PushPreview({super.key, required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.raised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.bronze,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(LucideIcons.heartHandshake,
                size: 20, color: AppColors.voidColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Mensaena',
                      style: AppTypography.label(
                          size: 11, color: AppColors.inkSoft)),
                  Text('  ·  ${'marketing.pv_now'.tr()}',
                      style: AppTypography.label(size: 11, color: AppColors.mute)),
                ]),
                const SizedBox(height: 2),
                Text(
                  sampleFill(title).isEmpty
                      ? 'marketing.pv_push_title_ph'.tr()
                      : sampleFill(title),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(
                      size: 14, color: AppColors.ink, weight: FontWeight.w700),
                ),
                const SizedBox(height: 1),
                Text(
                  sampleFill(body).isEmpty
                      ? 'marketing.pv_push_body_ph'.tr()
                      : sampleFill(body),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body(size: 13, color: AppColors.inkSoft),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
