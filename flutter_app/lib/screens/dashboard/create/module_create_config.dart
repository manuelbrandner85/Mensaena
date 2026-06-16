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
    required this.emoji,
    this.category,
  });

  final String value;
  /// i18n-Key, z. B. 'create.types.animals.animal' — mit .tr() rendern.
  final String label;
  final String emoji;
  /// Wenn gesetzt, wird category automatisch auf diesen Wert gesperrt.
  final String? category;
}

class ModuleCreateCategory {
  const ModuleCreateCategory({required this.value, required this.label});
  final String value;
  /// i18n-Key, z. B. 'create.categories.animals' — mit .tr() rendern.
  final String label;
}

/// Alle 10 Modul-Configs — 1:1 zu den Web-create-pages.
class ModuleCreateConfigs {
  ModuleCreateConfigs._();

  static const animals = ModuleCreateConfig(
    moduleKey: 'animals',
    title: 'create.newAnimalPost',
    description: 'create.descriptions.animals',
    icon: LucideIcons.dog,
    accentColor: Color(0xFFEC4899),
    createTypes: [
      ModuleCreateType(
          value: 'animal',
          label: 'create.types.animals.animal',
          emoji: '🐾',
          category: 'animals'),
      ModuleCreateType(
          value: 'rescue',
          label: 'create.types.animals.rescue',
          emoji: '🆘',
          category: 'animals'),
      ModuleCreateType(
          value: 'community',
          label: 'create.types.animals.community',
          emoji: '💬',
          category: 'animals'),
    ],
    categories: [
      ModuleCreateCategory(value: 'animals', label: 'create.categories.animals'),
      ModuleCreateCategory(value: 'general', label: 'create.categories.general'),
    ],
    returnRoute: '/dashboard/animals',
  );

  static const housing = ModuleCreateConfig(
    moduleKey: 'housing',
    title: 'create.newHousingPost',
    description: 'create.descriptions.housing',
    icon: LucideIcons.home,
    accentColor: Color(0xFF60A5FA),
    createTypes: [
      ModuleCreateType(
          value: 'housing',
          label: 'create.types.housing.housing',
          emoji: '🏠'),
      ModuleCreateType(
          value: 'rescue',
          label: 'create.types.housing.rescue',
          emoji: '🆘'),
      ModuleCreateType(
          value: 'crisis',
          label: 'create.types.housing.crisis',
          emoji: '⚠️'),
    ],
    categories: [
      ModuleCreateCategory(value: 'housing', label: 'create.categories.housing'),
      ModuleCreateCategory(value: 'general', label: 'create.categories.general'),
    ],
    returnRoute: '/dashboard/housing',
  );

  static const mobility = ModuleCreateConfig(
    moduleKey: 'mobility',
    title: 'create.newMobilityPost',
    description: 'create.descriptions.mobility',
    icon: LucideIcons.car,
    accentColor: Color(0xFF818CF8),
    createTypes: [
      ModuleCreateType(
          value: 'mobility',
          label: 'create.types.mobility.mobility',
          emoji: '🚗'),
      ModuleCreateType(
          value: 'rescue',
          label: 'create.types.mobility.rescue',
          emoji: '🆘'),
      ModuleCreateType(
          value: 'sharing',
          label: 'create.types.mobility.sharing',
          emoji: '📦',
          category: 'mobility'),
    ],
    categories: [
      ModuleCreateCategory(value: 'mobility', label: 'create.categories.mobility'),
      ModuleCreateCategory(value: 'general', label: 'create.categories.general'),
    ],
    returnRoute: '/dashboard/mobility',
  );

  static const sharing = ModuleCreateConfig(
    moduleKey: 'sharing',
    title: 'create.newSharingPost',
    description: 'create.descriptions.sharing',
    icon: LucideIcons.repeat,
    accentColor: AppColors.teal,
    createTypes: [
      ModuleCreateType(
          value: 'sharing',
          label: 'create.types.sharing.sharing',
          emoji: '🔄'),
      ModuleCreateType(
          value: 'rescue',
          label: 'create.types.sharing.rescue',
          emoji: '🔍'),
    ],
    categories: [
      ModuleCreateCategory(value: 'tools', label: 'create.categories.tools'),
      ModuleCreateCategory(value: 'books', label: 'create.categories.books'),
      ModuleCreateCategory(value: 'devices', label: 'create.categories.devices'),
      ModuleCreateCategory(value: 'kitchen', label: 'create.categories.kitchen'),
      ModuleCreateCategory(value: 'sports', label: 'create.categories.sports'),
      ModuleCreateCategory(value: 'general', label: 'create.categories.general'),
    ],
    returnRoute: '/dashboard/sharing',
  );

  static const harvest = ModuleCreateConfig(
    moduleKey: 'harvest',
    title: 'create.newHarvestPost',
    description: 'create.descriptions.harvest',
    icon: LucideIcons.wheat,
    accentColor: AppColors.leben,
    createTypes: [
      ModuleCreateType(
          value: 'sharing',
          label: 'create.types.harvest.sharing',
          emoji: '🌾',
          category: 'food'),
      ModuleCreateType(
          value: 'community',
          label: 'create.types.harvest.community',
          emoji: '🤝',
          category: 'food'),
      ModuleCreateType(
          value: 'rescue',
          label: 'create.types.harvest.rescue',
          emoji: '🍎',
          category: 'food'),
    ],
    categories: [
      ModuleCreateCategory(value: 'food', label: 'create.categories.food'),
      ModuleCreateCategory(value: 'general', label: 'create.categories.general'),
    ],
    returnRoute: '/dashboard/harvest',
  );

  static const community = ModuleCreateConfig(
    moduleKey: 'community',
    title: 'create.newCommunityPost',
    description: 'create.descriptions.community',
    icon: LucideIcons.users,
    accentColor: Color(0xFFC084FC),
    createTypes: [
      ModuleCreateType(
          value: 'community',
          label: 'create.types.community.community',
          emoji: '💡'),
      ModuleCreateType(
          value: 'rescue',
          label: 'create.types.community.rescue',
          emoji: '❓'),
    ],
    categories: [
      ModuleCreateCategory(value: 'community', label: 'create.categories.community'),
      ModuleCreateCategory(value: 'general', label: 'create.categories.general'),
    ],
    returnRoute: '/dashboard/community',
  );

  static const knowledge = ModuleCreateConfig(
    moduleKey: 'knowledge',
    title: 'create.newKnowledgePost',
    description: 'create.descriptions.knowledge',
    icon: LucideIcons.bookOpen,
    accentColor: Color(0xFF6366F1),
    createTypes: [
      ModuleCreateType(
          value: 'community',
          label: 'create.types.knowledge.community',
          emoji: '📚',
          category: 'knowledge'),
      ModuleCreateType(
          value: 'sharing',
          label: 'create.types.knowledge.sharing',
          emoji: '🎓',
          category: 'knowledge'),
      ModuleCreateType(
          value: 'rescue',
          label: 'create.types.knowledge.rescue',
          emoji: '❓',
          category: 'knowledge'),
    ],
    categories: [
      ModuleCreateCategory(value: 'knowledge', label: 'create.categories.knowledge'),
      ModuleCreateCategory(value: 'skills', label: 'create.categories.skills'),
      ModuleCreateCategory(value: 'general', label: 'create.categories.general'),
    ],
    returnRoute: '/dashboard/knowledge',
  );

  static const skills = ModuleCreateConfig(
    moduleKey: 'skills',
    title: 'create.newSkillPost',
    description: 'create.descriptions.skills',
    icon: LucideIcons.wrench,
    accentColor: AppColors.bronze,
    createTypes: [
      ModuleCreateType(
          value: 'sharing',
          label: 'create.types.skills.sharing',
          emoji: '⭐',
          category: 'skills'),
      ModuleCreateType(
          value: 'rescue',
          label: 'create.types.skills.rescue',
          emoji: '🔍',
          category: 'skills'),
      ModuleCreateType(
          value: 'community',
          label: 'create.types.skills.community',
          emoji: '🎯',
          category: 'skills'),
    ],
    categories: [
      ModuleCreateCategory(value: 'skills', label: 'create.categories.skills'),
      ModuleCreateCategory(value: 'knowledge', label: 'create.categories.knowledge'),
      ModuleCreateCategory(value: 'general', label: 'create.categories.general'),
    ],
    returnRoute: '/dashboard/skills',
  );

  static const jobs = ModuleCreateConfig(
    moduleKey: 'jobs',
    title: 'create.newJobPost',
    description: 'create.descriptions.jobs',
    icon: LucideIcons.briefcase,
    accentColor: Color(0xFFA78BFA),
    createTypes: [
      ModuleCreateType(
          value: 'job',
          label: 'create.types.jobs.job',
          emoji: '💼'),
      ModuleCreateType(
          value: 'rescue',
          label: 'create.types.jobs.rescue',
          emoji: '🔍'),
      ModuleCreateType(
          value: 'community',
          label: 'create.types.jobs.community',
          emoji: '❤️'),
    ],
    categories: [
      ModuleCreateCategory(value: 'fulltime', label: 'create.categories.fulltime'),
      ModuleCreateCategory(value: 'parttime', label: 'create.categories.parttime'),
      ModuleCreateCategory(value: 'minijob', label: 'create.categories.minijob'),
      ModuleCreateCategory(value: 'volunteer', label: 'create.categories.volunteer'),
      ModuleCreateCategory(value: 'general', label: 'create.categories.general'),
    ],
    returnRoute: '/dashboard/jobs',
  );

  static const rescuer = ModuleCreateConfig(
    moduleKey: 'rescuer',
    title: 'create.newRescuerPost',
    description: 'create.descriptions.rescuer',
    icon: LucideIcons.lifeBuoy,
    accentColor: Color(0xFFFB923C),
    createTypes: [
      ModuleCreateType(
          value: 'rescue',
          label: 'create.types.rescuer.food',
          emoji: '🍎',
          category: 'food'),
      ModuleCreateType(
          value: 'rescue',
          label: 'create.types.rescuer.everyday',
          emoji: '👕',
          category: 'everyday'),
      ModuleCreateType(
          value: 'rescue',
          label: 'create.types.rescuer.sharing',
          emoji: '📦',
          category: 'sharing'),
    ],
    categories: [
      ModuleCreateCategory(value: 'food', label: 'create.categories.food'),
      ModuleCreateCategory(value: 'everyday', label: 'create.categories.everyday'),
      ModuleCreateCategory(value: 'sharing', label: 'create.categories.sharing'),
      ModuleCreateCategory(value: 'general', label: 'create.categories.general'),
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
