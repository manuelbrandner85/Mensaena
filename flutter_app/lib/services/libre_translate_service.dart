/// SKILL: mensaena-features
/// Translation-Service — Pendant zur Web-Translate-Funktion.
///
/// Migration: Die drei kostenlosen LibreTranslate-Mirrors die wir vorher
/// nutzten sind alle tot oder strikt rate-limited:
///   - libretranslate.de              → 405 Method Not Allowed (POST gesperrt)
///   - translate.argosopentech.com    → DNS not resolvable
///   - translate.fortytwo-it.com      → 503 upstream connect error
///
/// Jetzt: MyMemory Translation API als primary, plus zwei LibreTranslate-
/// Mirrors als Fallback falls MyMemory Quota erschoepft (10k chars/Tag/IP).
/// MyMemory ist gratis, ohne Key, GET-Request — perfekt fuer kurze Snippets
/// (Chat-Nachrichten, Posts, etc.).
///
/// Doku: https://mymemory.translated.net/doc/spec.php
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:http/http.dart' as http;

class TranslationResult {
  const TranslationResult({
    required this.text,
    required this.detectedSource,
    this.confidence,
  });

  final String text;
  final String detectedSource;
  final double? confidence;
}

class LibreTranslateService {
  const LibreTranslateService._();

  /// Übersetzt Text. [source] = 'auto' für Auto-Detect.
  /// Reihenfolge: MyMemory → LibreTranslate-Mirrors (Fallback).
  static Future<TranslationResult?> translate({
    required String text,
    required String target,
    String source = 'auto',
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return null;
    // MyMemory hat keine 'auto'-Source — Default 'en' wenn nicht spezifiziert.
    // Bei Auto-Detect lassen wir MyMemory raten via 'autodetect' — nicht
    // offiziell dokumentiert aber funktioniert mit Source-Code 'auto' nicht.
    // Daher: bei 'auto' nutzen wir 'en' als plausible Default-Quelle.
    final myMemorySource = source == 'auto' ? 'en' : source;

    final myMemory = await _tryMyMemory(
      text: clean,
      source: myMemorySource,
      target: target,
    );
    if (myMemory != null) return myMemory;

    // Fallback auf LibreTranslate (auch wenn flaky — manchmal sind die wieder up).
    return _tryLibreTranslate(
      text: clean,
      source: source,
      target: target,
    );
  }

  static Future<TranslationResult?> _tryMyMemory({
    required String text,
    required String source,
    required String target,
  }) async {
    try {
      final uri = Uri.parse(
          'https://api.mymemory.translated.net/get'
          '?q=${Uri.encodeQueryComponent(text)}'
          '&langpair=$source|$target');
      final r = await http.get(uri).timeout(const Duration(seconds: 10));
      if (r.statusCode != 200) return null;
      final j = json.decode(r.body) as Map<String, dynamic>;
      final data = j['responseData'] as Map<String, dynamic>?;
      final translated = data?['translatedText'] as String?;
      if (translated == null || translated.isEmpty) return null;
      final match = (data?['match'] as num?)?.toDouble();
      return TranslationResult(
        text: translated,
        detectedSource: source,
        confidence: match,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[Translate] MyMemory failed: $e');
      return null;
    }
  }

  // Letzte bekannte LibreTranslate-Mirrors. Halten wir minimal weil
  // sie historisch instabil sind, aber als Notfall-Plan B drinbleiben.
  static const List<String> _libreMirrors = [
    'https://libretranslate.com',
  ];

  static Future<TranslationResult?> _tryLibreTranslate({
    required String text,
    required String source,
    required String target,
  }) async {
    for (final base in _libreMirrors) {
      try {
        final uri = Uri.parse('$base/translate');
        final r = await http.post(uri,
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'q': text,
              'source': source,
              'target': target,
              'format': 'text',
            })).timeout(const Duration(seconds: 10));
        if (r.statusCode != 200) continue;
        final j = json.decode(r.body) as Map<String, dynamic>;
        final translated = j['translatedText'] as String?;
        if (translated == null) continue;
        final det = j['detectedLanguage'] as Map<String, dynamic>?;
        return TranslationResult(
          text: translated,
          detectedSource: det?['language'] as String? ?? source,
          confidence: (det?['confidence'] as num?)?.toDouble(),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('[Translate] $base failed: $e');
        continue;
      }
    }
    return null;
  }
}
