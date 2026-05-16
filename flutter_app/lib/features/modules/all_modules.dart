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

class SharingModule extends StatelessWidget {
  const SharingModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Sharing',
        description: 'Teile Werkzeuge, Gegenstaende, Zeit.',
        icon: LucideIcons.share2,
        accent: MnColors.amberSoft,
        tableName: 'posts',
        filter: {'type': 'tausch'},
        currentRoute: '/sharing',
      );
}

class SupplyModule extends StatelessWidget {
  const SupplyModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Supply',
        description: 'Versorgung & Lager fuer Krisenfaelle.',
        icon: LucideIcons.package,
        accent: MnColors.teal,
        tableName: 'posts',
        filter: {'type': 'werkzeug'},
        currentRoute: '/supply',
      );
}

class RescuerModule extends StatelessWidget {
  const RescuerModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Retter',
        description: 'Erste-Hilfe-Profis und Helfer in der Naehe.',
        icon: LucideIcons.shieldCheck,
        accent: MnColors.leben,
        tableName: 'posts',
        filter: {'type': 'krisenhilfe'},
        currentRoute: '/rescuer',
      );
}

class JobsModule extends StatelessWidget {
  const JobsModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Jobs',
        description: 'Mini-Jobs und kleine Auftraege in der Nachbarschaft.',
        icon: LucideIcons.briefcase,
        accent: MnColors.amberWarm,
        tableName: 'posts',
        filter: {'type': 'hilfeSuchen'},
        currentRoute: '/jobs',
      );
}

class KnowledgeModule extends StatelessWidget {
  const KnowledgeModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Wissen',
        description: 'Knowledge-Base und Anleitungen.',
        icon: LucideIcons.lightbulb,
        accent: MnColors.trust,
        tableName: 'knowledge_articles',
        currentRoute: '/knowledge',
      );
}

class PostsModule extends StatelessWidget {
  const PostsModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Beitraege',
        description: 'Alle Beitraege deiner Nachbarschaft.',
        icon: LucideIcons.fileText,
        accent: MnColors.amber,
        tableName: 'posts',
        currentRoute: '/posts',
      );
}

class OrganizationsModule extends StatelessWidget {
  const OrganizationsModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Organisationen',
        description: 'Vereine, NGOs und Initiativen in deiner Naehe.',
        icon: LucideIcons.building,
        accent: MnColors.teal,
        tableName: 'organizations',
        currentRoute: '/organizations',
      );
}

class InteractionsModule extends StatelessWidget {
  const InteractionsModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Interaktionen',
        description: 'Deine Interaktionen mit anderen Nachbarn.',
        icon: LucideIcons.activity,
        accent: MnColors.tealSoft,
        tableName: 'interactions',
        currentRoute: '/interactions',
      );
}

class MatchingModule extends StatelessWidget {
  const MatchingModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Matching',
        description: 'Treffer zwischen Angeboten und Anfragen.',
        icon: LucideIcons.sparkles,
        accent: MnColors.amber,
        tableName: 'matches',
        currentRoute: '/matching',
      );
}

class CrisisListModule extends StatelessWidget {
  const CrisisListModule({super.key});
  @override
  Widget build(BuildContext context) => const ModuleScreen(
        title: 'Krise',
        description: 'Aktive Krisen in deiner Region.',
        icon: LucideIcons.alertTriangle,
        accent: MnColors.herzrot,
        tableName: 'crises',
        currentRoute: '/crisis',
      );
}
