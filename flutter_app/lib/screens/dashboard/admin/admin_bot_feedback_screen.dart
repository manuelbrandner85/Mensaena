/// SKILL: mensaena-features (Admin Phase A4 — Stub)
/// Bot-Feedback-Admin — delegiert vorerst an AdminTableScreen.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'admin_table_screen.dart';

class AdminBotFeedbackScreen extends ConsumerWidget {
  const AdminBotFeedbackScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AdminTableScreen(
      title: 'admin.screens.botFeedback'.tr(),
      tableName: 'bot_feedback',
      currentRoute: '/dashboard/admin/bot-feedback',
      titleField: 'question',
      subtitleFields: const ['rating', 'route'],
    );
  }
}
