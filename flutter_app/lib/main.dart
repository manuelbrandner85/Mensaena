import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'services/supabase_service.dart';

/// SKILL: mensaena-architektur
/// Bootstrap: Supabase initialisieren, dann MaterialApp.router starten.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.init();
  runApp(const ProviderScope(child: MensaenaApp()));
}
