import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:mensaena/config/supabase_config.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  timeago.setLocaleMessages('de', timeago.DeMessages());

  // Show splash immediately
  runApp(const _SplashApp());

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(
    const ProviderScope(
      child: MensaenaApp(),
    ),
  );
}

class _SplashApp extends StatelessWidget {
  const _SplashApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.warmBg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/images/mensaena-logo.png', width: 200, height: 134),
              const SizedBox(height: 24),
              const Text('Mensaena', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary500, letterSpacing: 1)),
              const SizedBox(height: 8),
              const Text('Nachbarschaftshilfe', style: TextStyle(fontSize: 14, color: AppColors.textMuted)),
              const SizedBox(height: 32),
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary500)),
            ],
          ),
        ),
      ),
    );
  }
}
