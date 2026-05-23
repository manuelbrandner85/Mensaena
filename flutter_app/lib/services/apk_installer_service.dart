import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

/// SKILL: mensaena-architektur
/// In-App APK-Download + Install fuer Pflicht-Updates.
/// Streamed Download mit Progress, danach OpenFilex.open() triggert
/// Androids PackageInstaller-Intent.
///
/// AndroidManifest hat bereits REQUEST_INSTALL_PACKAGES; User muss bei
/// erstem Install ggf. "Apps aus unbekannten Quellen" zulassen.
class ApkInstallerService {
  const ApkInstallerService._();

  /// Laedt eine APK von [url] in den Temp-Ordner und triggert den Install.
  /// [onProgress] wird mit Werten 0.0-1.0 gefuettert.
  static Future<ApkInstallResult> downloadAndInstall({
    required String url,
    required String version,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final tempDir = await getTemporaryDirectory();
      // Vorhandene APKs gleichen Namens entfernen.
      final fileName =
          'mensaena-${version.replaceAll(RegExp(r'[^A-Za-z0-9._+-]'), '_')}.apk';
      final file = File('${tempDir.path}/$fileName');
      if (await file.exists()) {
        await file.delete();
      }

      final client = http.Client();
      try {
        final req = http.Request('GET', Uri.parse(url));
        final resp = await client.send(req).timeout(
              const Duration(seconds: 120),
            );
        if (resp.statusCode != 200) {
          return ApkInstallResult.failure(
            'Server antwortete mit ${resp.statusCode}.',
          );
        }
        final total = resp.contentLength ?? 0;
        var received = 0;
        final sink = file.openWrite();
        await resp.stream.listen(
          (chunk) {
            sink.add(chunk);
            received += chunk.length;
            if (total > 0 && onProgress != null) {
              onProgress(received / total);
            }
          },
          onError: (_) {},
          cancelOnError: true,
        ).asFuture<void>();
        await sink.flush();
        await sink.close();
      } finally {
        client.close();
      }

      // Trigger Install-Intent via FileProvider (Manifest hat das schon).
      final openResult = await OpenFilex.open(file.path);
      if (openResult.type == ResultType.done) {
        return ApkInstallResult.success(file.path);
      }
      return ApkInstallResult.failure(
        openResult.message,
        downloadedPath: file.path,
      );
    } catch (e) {
      return ApkInstallResult.failure(e.toString());
    }
  }
}

class ApkInstallResult {
  const ApkInstallResult._({
    required this.ok,
    this.path,
    this.errorMessage,
  });

  final bool ok;
  final String? path;
  final String? errorMessage;

  factory ApkInstallResult.success(String path) =>
      ApkInstallResult._(ok: true, path: path);

  factory ApkInstallResult.failure(String message, {String? downloadedPath}) =>
      ApkInstallResult._(
        ok: false,
        path: downloadedPath,
        errorMessage: message,
      );
}
