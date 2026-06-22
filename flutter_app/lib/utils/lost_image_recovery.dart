/// SKILL: mensaena-architektur
/// Android verliert image_picker-Ergebnisse, wenn die Activity während der
/// geöffneten Galerie unter Speicherdruck zerstört und neu erstellt wird
/// (RAM-schwache Geräte). Symptom: „Galerie öffnet, aber das gewählte Bild
/// erscheint nicht — kein Fehler". Lösung: beim Wieder-Aufbau des Screens
/// `retrieveLostData()` aufrufen und die verlorenen Bilder zurückholen.
///
/// Verwendung in einer State-initState:
///   WidgetsBinding.instance.addPostFrameCallback((_) async {
///     final lost = await recoverLostImages(_picker);
///     if (lost.isNotEmpty && mounted) {
///       setState(() => _images.addAll(lost.map((x) => File(x.path))));
///     }
///   });
library;

import 'dart:async';

import 'package:image_picker/image_picker.dart';

import '../repositories/extra_repositories.dart';

/// Holt von Android verlorene image_picker-Ergebnisse zurück. Liefert eine
/// (ggf. leere) Liste — bei intakter Activity passiert nichts (kein Fehler).
Future<List<XFile>> recoverLostImages(ImagePicker picker) async {
  try {
    final lost = await picker.retrieveLostData();
    if (lost.isEmpty) return const <XFile>[];
    final files = lost.files ??
        (lost.file != null ? <XFile>[lost.file!] : const <XFile>[]);
    if (files.isNotEmpty) {
      unawaited(ErrorLogsRepository.log(
        errorType: 'image_lost_recovered',
        message: '${files.length} Bild(er) nach Activity-Recreation '
            'wiederhergestellt',
      ));
    }
    return files;
  } catch (e) {
    unawaited(ErrorLogsRepository.log(
      errorType: 'image_lost_error',
      message: '$e',
    ));
    return const <XFile>[];
  }
}
