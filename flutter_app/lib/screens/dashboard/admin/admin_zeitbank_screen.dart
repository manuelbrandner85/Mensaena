/// SKILL: mensaena-features (Admin Phase A4 — Stub)
/// Zeitbank-Admin — delegiert vorerst an AdminTableScreen.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_table_screen.dart';

class AdminZeitbankScreen extends ConsumerWidget {
  const AdminZeitbankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminTableScreen(
      title: 'admin.screens.timebank'.tr(),
      tableName: 'timebank_entries',
      currentRoute: '/dashboard/admin/timebank',
      titleField: 'description',
      subtitleFields: const ['category', 'status', 'hours'],
    );
  }
}
