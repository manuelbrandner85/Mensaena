/// SKILL: mensaena-features (Admin Phase A4 — Stub)
/// Zeitbank-Admin — delegiert vorerst an AdminTableScreen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_table_screen.dart';

class AdminZeitbankScreen extends ConsumerWidget {
  const AdminZeitbankScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AdminTableScreen(
      title: 'Zeitbank',
      tableName: 'timebank_entries',
      currentRoute: '/dashboard/admin/timebank',
      titleField: 'description',
      subtitleFields: ['category', 'status', 'hours'],
    );
  }
}
