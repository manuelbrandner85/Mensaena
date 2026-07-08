import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// SKILL: mensaena-features
/// Generische Entwurf-Persistenz für lange Erstellungs-Formulare
/// (Marktplatz, Events, …). Pendant zu [PostDraftService], aber pro
/// `draftType`-Kennung ein eigener Slot — so braucht kein Formular eine
/// eigene Klasse/Tabelle. Gespeichert wird lokal & verschlüsselt via
/// [FlutterSecureStorage] (keine Netzwerk-/Supabase-Calls), Nutzlast ist
/// eine simple JSON-Map. Auto-Save periodisch, Wiederherstellung beim
/// erneuten Öffnen, Löschen nach erfolgreichem Erstellen.
class FormDraftService {
  const FormDraftService._();

  static const _storage = FlutterSecureStorage();

  static String _key(String draftType) => 'form_draft_${draftType}_v1';

  static Future<void> save(String draftType, Map<String, dynamic> data) async {
    try {
      await _storage.write(
        key: _key(draftType),
        value: jsonEncode({
          'data': data,
          'saved_at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {/* Storage-Fehler dürfen das Formular nie blockieren. */}
  }

  static Future<FormDraft?> load(String draftType) async {
    try {
      final raw = await _storage.read(key: _key(draftType));
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final data = (map['data'] as Map?)?.cast<String, dynamic>() ?? {};
      if (data.isEmpty) return null;
      final savedRaw = map['saved_at'];
      final savedAt = savedRaw is String ? DateTime.tryParse(savedRaw) : null;
      return FormDraft(data: data, savedAt: savedAt);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear(String draftType) async {
    try {
      await _storage.delete(key: _key(draftType));
    } catch (_) {}
  }
}

/// Gelesener Entwurf: rohe Feld-Map + Speicherzeitpunkt. Die typisierten
/// Getter geben `null` zurück, wenn ein Feld fehlt oder den falschen Typ hat
/// (robust gegen Schema-Änderungen zwischen App-Versionen).
class FormDraft {
  const FormDraft({required this.data, this.savedAt});

  final Map<String, dynamic> data;
  final DateTime? savedAt;

  String? getString(String key) {
    final v = data[key];
    return v is String ? v : null;
  }

  bool? getBool(String key) {
    final v = data[key];
    return v is bool ? v : null;
  }

  double? getDouble(String key) {
    final v = data[key];
    return v is num ? v.toDouble() : null;
  }

  DateTime? getDateTime(String key) {
    final v = data[key];
    return v is String ? DateTime.tryParse(v) : null;
  }
}
