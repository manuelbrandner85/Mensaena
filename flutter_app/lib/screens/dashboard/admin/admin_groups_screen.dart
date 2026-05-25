/// SKILL: mensaena-features (Admin Phase A4 — Stub)
/// Gruppen-Admin — delegiert vorerst an AdminTableScreen (generischer Browser).
/// In Phase P1 wird hier ein dedizierter Screen mit Edit-/Create-Modals stehen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_table_screen.dart';

class AdminGroupsScreen extends ConsumerWidget {
  const AdminGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AdminTableScreen(
      title: 'Gruppen',
      tableName: 'groups',
      currentRoute: '/dashboard/admin/groups',
      titleField: 'name',
      subtitleFields: ['category', 'slug'],
    );
  }
}
