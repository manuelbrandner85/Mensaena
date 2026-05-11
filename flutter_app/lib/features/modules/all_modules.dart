// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables, require_trailing_commas, unused_import
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/theme/colors.dart';
import 'module_screen.dart';

/// Konfiguration eines Moduls. Wird im app_router je Route instanziiert.
class TiereModule extends StatelessWidget {
  const TiereModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Tiere',
        description: 'Vermisst, Gefunden, Betreuung. Hilf einem Tier in deiner Nachbarschaft.',
        icon: LucideIcons.dog,
        accent: MnColors.amberWarm,
        tableName: 'posts',
        filter: {'type': 'tierisches'},
      );
}

class WohnenModule extends StatelessWidget {
  const WohnenModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Wohnen',
        description: 'Wohnungsmarkt und WG-Suche fuer deine Region.',
        icon: LucideIcons.home,
        accent: MnColors.teal,
        tableName: 'posts',
        filter: {'type': 'wohnungsmarkt'},
      );
}

class MobilitaetModule extends StatelessWidget {
  const MobilitaetModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Mobilitaet',
        description: 'Mitfahrten, Fahrrad, OEPNV.',
        icon: LucideIcons.car,
        accent: MnColors.tealSoft,
        tableName: 'posts',
        filter: {'type': 'mitfahrt'},
      );
}

class ErnteModule extends StatelessWidget {
  const ErnteModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Ernte',
        description: 'Ernte teilen, Gartentipps, Saatgut tauschen.',
        icon: LucideIcons.leaf,
        accent: MnColors.leben,
        tableName: 'farm_listings',
      );
}

class CommunityModule extends StatelessWidget {
  const CommunityModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Community',
        description: 'Allgemeine Posts und Diskussionen.',
        icon: LucideIcons.users,
        accent: MnColors.amber,
        tableName: 'posts',
        filter: {'type': 'allgemein'},
      );
}

class WissenModule extends StatelessWidget {
  const WissenModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Wissen',
        description: 'Wiki-Artikel rund um Nachbarschaftshilfe.',
        icon: LucideIcons.bookOpen,
        accent: MnColors.trust,
        tableName: 'knowledge_articles',
      );
}

class EventsModule extends StatelessWidget {
  const EventsModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Veranstaltungen',
        description: 'Was passiert diese Woche in deiner Nachbarschaft?',
        icon: LucideIcons.calendar,
        accent: MnColors.amberSoft,
        tableName: 'events',
      );
}

class GruppenModule extends StatelessWidget {
  const GruppenModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Gruppen',
        description: 'Schliess dich Gruppen mit gleichen Interessen an.',
        icon: LucideIcons.users,
        accent: MnColors.teal,
        tableName: 'groups',
      );
}

class MarktplatzModule extends StatelessWidget {
  const MarktplatzModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Marktplatz',
        description: 'Verschenken, tauschen, lokal verkaufen.',
        icon: LucideIcons.shoppingBag,
        accent: MnColors.amber,
        tableName: 'marketplace_listings',
      );
}

class ChallengesModule extends StatelessWidget {
  const ChallengesModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Challenges',
        description: 'Gemeinsam Ziele erreichen.',
        icon: LucideIcons.trophy,
        accent: MnColors.amberWarm,
        tableName: 'challenges',
      );
}

class BadgesModule extends StatelessWidget {
  const BadgesModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Badges',
        description: 'Auszeichnungen fuer dein Engagement.',
        icon: LucideIcons.award,
        accent: MnColors.trust,
        tableName: 'badges',
      );
}

class ZeitbankModule extends StatelessWidget {
  const ZeitbankModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Zeitbank',
        description: 'Gib Zeit, bekomme Zeit.',
        icon: LucideIcons.clock,
        accent: MnColors.tealSoft,
        tableName: 'timebank_entries',
      );
}

class SkillsModule extends StatelessWidget {
  const SkillsModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Skills',
        description: 'Faehigkeiten anbieten, Hilfe finden.',
        icon: LucideIcons.lightbulb,
        accent: MnColors.leben,
        tableName: 'skill_offers',
      );
}
