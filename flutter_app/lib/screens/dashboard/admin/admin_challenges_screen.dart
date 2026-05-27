/// SKILL: mensaena-features (Admin Phase A4 — Stub)
/// Challenges-Admin — delegiert vorerst an AdminTableScreen.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_table_screen.dart';

class AdminChallengesScreen extends ConsumerWidget {
  const AdminChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminTableScreen(
      title: 'admin.screens.challenges'.tr(),
      tableName: 'challenges',
      currentRoute: '/dashboard/admin/challenges',
      titleField: 'title',
      subtitleFields: const ['category', 'difficulty', 'status'],
    );
  }
}
