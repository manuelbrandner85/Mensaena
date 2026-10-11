import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Abschluss-Screen: Mensaena wurde eingestellt (2026-10-11).
///
/// Wird per Shorebird-OTA-Patch ausgeliefert und ersetzt die gesamte App.
/// AUSNAHME von der i18n-Pflicht (CLAUDE.md): Shorebird-Patches tauschen nur
/// Dart-Code aus, nicht die Asset-JSONs in `assets/translations/`. Neue Keys
/// kämen auf den Geräten nie an. Deshalb liegen die Texte hier direkt im Code,
/// in allen 7 unterstützten Sprachen, ausgewählt nach Gerätesprache.
class AppDiscontinuedApp extends StatelessWidget {
  const AppDiscontinuedApp({super.key});

  static const Map<String, List<String>> _texts = {
    'de': [
      'Mensaena wurde eingestellt',
      'Vielen Dank an alle, die Mensaena genutzt und ihre Nachbarschaft unterstützt haben. Die App steht nicht mehr zur Verfügung und kann deinstalliert werden.',
    ],
    'en': [
      'Mensaena has been discontinued',
      'Thank you to everyone who used Mensaena and supported their neighbourhood. The app is no longer available and can be uninstalled.',
    ],
    'it': [
      'Mensaena è stata chiusa',
      'Grazie a tutti coloro che hanno usato Mensaena e sostenuto il proprio quartiere. L’app non è più disponibile e può essere disinstallata.',
    ],
    'es': [
      'Mensaena ha dejado de funcionar',
      'Gracias a todas las personas que usaron Mensaena y apoyaron a su vecindario. La aplicación ya no está disponible y se puede desinstalar.',
    ],
    'fr': [
      'Mensaena a été arrêtée',
      'Merci à toutes celles et ceux qui ont utilisé Mensaena et soutenu leur quartier. L’application n’est plus disponible et peut être désinstallée.',
    ],
    'tr': [
      'Mensaena kapatıldı',
      'Mensaena’yı kullanan ve mahallesine destek olan herkese teşekkür ederiz. Uygulama artık kullanılamıyor ve kaldırılabilir.',
    ],
    'ru': [
      'Mensaena прекратила работу',
      'Спасибо всем, кто пользовался Mensaena и помогал своим соседям. Приложение больше недоступно, его можно удалить.',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final lang = ui.PlatformDispatcher.instance.locale.languageCode;
    final t = _texts[lang] ?? _texts['de']!;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mensaena',
      home: Scaffold(
        backgroundColor: const Color(0xFFEEF9F9),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFFD0F5F3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_outline,
                      color: Color(0xFF147170),
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    t[0],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t[1],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      height: 1.5,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
