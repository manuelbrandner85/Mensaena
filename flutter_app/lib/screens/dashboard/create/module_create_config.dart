import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';

/// SKILL: mensaena-features
/// 1:1-Pendant zur Web-`CreatePostPage`-Konfiguration in
/// `src/app/dashboard/<module>/create/page.tsx`.
///
/// Jedes Modul hat eine eigene Create-Page mit modul-spezifischen
/// Titel/Beschreibung, Type-Whitelist, Category-Whitelist, Theme-Color
/// und Return-Route. Die Flutter-App bildet das via diesem Config-Objekt
/// und einem gemeinsamen `_ModuleCreatePostScreen` ab.
class ModuleCreateConfig {
  const ModuleCreateConfig({
    required this.moduleKey,
    required this.title,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.createTypes,
    required this.categories,
    required this.returnRoute,
  });

  final String moduleKey;
  final String title;
  final String description;
  final IconData icon;
  final Color accentColor;
  final List<ModuleCreateType> createTypes;
  final List<ModuleCreateCategory> categories;
  final String returnRoute;
}

class ModuleCreateType {
  const ModuleCreateType({
    required this.value,
    required this.label,
    this.category,
  });

  final String value;
  final String label;
  /// Wenn gesetzt, wird category automatisch auf diesen Wert gesperrt.
  final String? category;
}

class ModuleCreateCategory {
  const ModuleCreateCategory({required this.value, required this.label});
  final String value;
  final String label;
}

/// Alle 10 Modul-Configs — 1:1 zu den Web-create-pages.
class ModuleCreateConfigs {
  ModuleCreateConfigs._();

  static const animals = ModuleCreateConfig(
    moduleKey: 'animals',
    title: 'Neuer Tier-Beitrag',
    description:
        'Suche oder biete Tierhilfe, Pflegestelle oder Fundtier-Meldung.',
    icon: LucideIcons.dog,
    accentColor: Color(0xFFEC4899),
    createTypes: [
      ModuleCreateType(
          value: 'animal', label: '🐾 Tier-Beitrag', category: 'animals'),
      ModuleCreateType(
          value: 'rescue',
          label: '🆘 Fundtier / Notfall',
          category: 'animals'),
      ModuleCreateType(
          value: 'community',
          label: '💬 Frage zur Tierhilfe',
          category: 'animals'),
    ],
    categories: [
      ModuleCreateCategory(value: 'animals', label: 'Tiere'),
      ModuleCreateCategory(value: 'general', label: 'Allgemein'),
    ],
    returnRoute: '/dashboard/animals',
  );

  static const housing = ModuleCreateConfig(
    moduleKey: 'housing',
    title: 'Neuer Wohn-Beitrag',
    description: 'Biete Wohnraum an oder suche Unterstützung.',
    icon: LucideIcons.home,
    accentColor: Color(0xFF60A5FA),
    createTypes: [
      ModuleCreateType(value: 'housing', label: '🏠 Wohnung anbieten'),
      ModuleCreateType(value: 'rescue', label: '🆘 Wohnungsnot'),
      ModuleCreateType(value: 'crisis', label: '⚠️ Krisenwohnung'),
    ],
    categories: [
      ModuleCreateCategory(value: 'housing', label: 'Wohnen'),
      ModuleCreateCategory(value: 'general', label: 'Allgemein'),
    ],
    returnRoute: '/dashboard/housing',
  );

  static const mobility = ModuleCreateConfig(
    moduleKey: 'mobility',
    title: 'Neuer Mobilitäts-Beitrag',
    description: 'Biete Mitfahrt, Transport oder suche eine Fahrgemeinschaft.',
    icon: LucideIcons.car,
    accentColor: Color(0xFF818CF8),
    createTypes: [
      ModuleCreateType(value: 'mobility', label: '🚗 Mitfahrt anbieten'),
      ModuleCreateType(value: 'rescue', label: '🆘 Mitfahrt gesucht'),
      ModuleCreateType(
          value: 'sharing', label: '📦 Transport-Hilfe', category: 'mobility'),
    ],
    categories: [
      ModuleCreateCategory(value: 'mobility', label: 'Mobilität'),
      ModuleCreateCategory(value: 'general', label: 'Allgemein'),
    ],
    returnRoute: '/dashboard/mobility',
  );

  static const sharing = ModuleCreateConfig(
    moduleKey: 'sharing',
    title: 'Neuer Teil-Beitrag',
    description: 'Werkzeug, Bücher, Geräte verleihen oder ausleihen.',
    icon: LucideIcons.repeat,
    accentColor: AppColors.teal,
    createTypes: [
      ModuleCreateType(value: 'sharing', label: '🔄 Teile etwas'),
      ModuleCreateType(value: 'rescue', label: '🔍 Suche zum Ausleihen'),
    ],
    categories: [
      ModuleCreateCategory(value: 'tools', label: 'Werkzeug'),
      ModuleCreateCategory(value: 'books', label: 'Bücher'),
      ModuleCreateCategory(value: 'devices', label: 'Geräte'),
      ModuleCreateCategory(value: 'kitchen', label: 'Küche'),
      ModuleCreateCategory(value: 'sports', label: 'Sport'),
      ModuleCreateCategory(value: 'general', label: 'Allgemein'),
    ],
    returnRoute: '/dashboard/sharing',
  );

  static const harvest = ModuleCreateConfig(
    moduleKey: 'harvest',
    title: 'Neuer Ernte-Beitrag',
    description: 'Teile Ernte, suche Erntehelfer oder biete Lebensmittel an.',
    icon: LucideIcons.wheat,
    accentColor: AppColors.leben,
    createTypes: [
      ModuleCreateType(
          value: 'sharing', label: '🌾 Ernte teilen', category: 'food'),
      ModuleCreateType(
          value: 'community',
          label: '🤝 Erntehelfer gesucht',
          category: 'food'),
      ModuleCreateType(
          value: 'rescue',
          label: '🍎 Lebensmittel retten',
          category: 'food'),
    ],
    categories: [
      ModuleCreateCategory(value: 'food', label: 'Lebensmittel'),
      ModuleCreateCategory(value: 'general', label: 'Allgemein'),
    ],
    returnRoute: '/dashboard/harvest',
  );

  static const community = ModuleCreateConfig(
    moduleKey: 'community',
    title: 'Neuer Community-Beitrag',
    description: 'Starte eine Diskussion, teile eine Idee oder stelle eine Frage.',
    icon: LucideIcons.users,
    accentColor: Color(0xFFC084FC),
    createTypes: [
      ModuleCreateType(value: 'community', label: '💡 Idee / Vorschlag'),
      ModuleCreateType(value: 'rescue', label: '❓ Frage an die Community'),
    ],
    categories: [
      ModuleCreateCategory(value: 'community', label: 'Community'),
      ModuleCreateCategory(value: 'general', label: 'Allgemein'),
    ],
    returnRoute: '/dashboard/community',
  );

  static const knowledge = ModuleCreateConfig(
    moduleKey: 'knowledge',
    title: 'Neuer Wissens-Beitrag',
    description: 'Teile Wissen, erstelle Anleitungen oder biete Kurse an.',
    icon: LucideIcons.bookOpen,
    accentColor: Color(0xFF6366F1),
    createTypes: [
      ModuleCreateType(
          value: 'community',
          label: '📚 Anleitung / Guide',
          category: 'knowledge'),
      ModuleCreateType(
          value: 'sharing', label: '🎓 Kurs anbieten', category: 'knowledge'),
      ModuleCreateType(
          value: 'rescue', label: '❓ Wissen gesucht', category: 'knowledge'),
    ],
    categories: [
      ModuleCreateCategory(value: 'knowledge', label: 'Wissen'),
      ModuleCreateCategory(value: 'skills', label: 'Skills'),
      ModuleCreateCategory(value: 'general', label: 'Allgemein'),
    ],
    returnRoute: '/dashboard/knowledge',
  );

  static const skills = ModuleCreateConfig(
    moduleKey: 'skills',
    title: 'Neuer Skill-Beitrag',
    description: 'Teile deine Fähigkeiten, suche Mentoren oder biete Workshops an.',
    icon: LucideIcons.wrench,
    accentColor: AppColors.bronze,
    createTypes: [
      ModuleCreateType(
          value: 'sharing', label: '⭐ Skill anbieten', category: 'skills'),
      ModuleCreateType(
          value: 'rescue', label: '🔍 Skill suchen', category: 'skills'),
      ModuleCreateType(
          value: 'community', label: '🎯 Mentoring', category: 'skills'),
    ],
    categories: [
      ModuleCreateCategory(value: 'skills', label: 'Skills'),
      ModuleCreateCategory(value: 'knowledge', label: 'Wissen'),
      ModuleCreateCategory(value: 'general', label: 'Allgemein'),
    ],
    returnRoute: '/dashboard/skills',
  );

  static const jobs = ModuleCreateConfig(
    moduleKey: 'jobs',
    title: 'Neuer Job-Beitrag',
    description:
        'Biete einen Mini-Job, suche Tätigkeit oder organisiere ehrenamtliche Arbeit.',
    icon: LucideIcons.briefcase,
    accentColor: Color(0xFFA78BFA),
    createTypes: [
      ModuleCreateType(value: 'job', label: '💼 Job anbieten'),
      ModuleCreateType(value: 'rescue', label: '🔍 Job suchen'),
      ModuleCreateType(value: 'community', label: '❤️ Ehrenamtliche Hilfe'),
    ],
    categories: [
      ModuleCreateCategory(value: 'fulltime', label: 'Vollzeit'),
      ModuleCreateCategory(value: 'parttime', label: 'Teilzeit'),
      ModuleCreateCategory(value: 'minijob', label: 'Mini-Job'),
      ModuleCreateCategory(value: 'volunteer', label: 'Ehrenamt'),
      ModuleCreateCategory(value: 'general', label: 'Allgemein'),
    ],
    returnRoute: '/dashboard/jobs',
  );

  static const rescuer = ModuleCreateConfig(
    moduleKey: 'rescuer',
    title: 'Neuer Rettungs-Beitrag',
    description: 'Rette Lebensmittel, Kleidung oder Gegenstände vor dem Wegwerfen.',
    icon: LucideIcons.lifeBuoy,
    accentColor: Color(0xFFFB923C),
    createTypes: [
      ModuleCreateType(
          value: 'rescue', label: '🍎 Lebensmittel retten', category: 'food'),
      ModuleCreateType(
          value: 'rescue', label: '👕 Kleidung retten', category: 'everyday'),
      ModuleCreateType(
          value: 'rescue',
          label: '📦 Gegenstände retten',
          category: 'sharing'),
    ],
    categories: [
      ModuleCreateCategory(value: 'food', label: 'Lebensmittel'),
      ModuleCreateCategory(value: 'everyday', label: 'Kleidung'),
      ModuleCreateCategory(value: 'sharing', label: 'Gegenstände'),
      ModuleCreateCategory(value: 'general', label: 'Allgemein'),
    ],
    returnRoute: '/dashboard/rescuer',
  );

  /// Lookup nach Modul-Key.
  static ModuleCreateConfig? forKey(String key) {
    switch (key) {
      case 'animals':
        return animals;
      case 'housing':
        return housing;
      case 'mobility':
        return mobility;
      case 'sharing':
        return sharing;
      case 'harvest':
        return harvest;
      case 'community':
        return community;
      case 'knowledge':
        return knowledge;
      case 'skills':
        return skills;
      case 'jobs':
        return jobs;
      case 'rescuer':
        return rescuer;
      default:
        return null;
    }
  }
}
