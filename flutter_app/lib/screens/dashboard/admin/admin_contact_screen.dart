/// SKILL: mensaena-features (Admin Phase A4 — Stub)
/// Kontakt-Postfach-Admin — delegiert vorerst an AdminTableScreen.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_table_screen.dart';

class AdminContactScreen extends ConsumerWidget {
  const AdminContactScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AdminTableScreen(
      title: 'Kontakt-Postfach',
      tableName: 'contact_messages',
      currentRoute: '/dashboard/admin/contact',
      titleField: 'subject',
      subtitleFields: ['name', 'email'],
    );
  }
}
