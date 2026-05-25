import 'dart:convert';

import 'package:http/http.dart' as http;

import 'supabase_service.dart';

/// SKILL: mensaena-features
/// Ruft den existierenden Web-Endpunkt `/api/posts/ai-assist` mit dem
/// aktuellen Supabase-JWT auf. Pendant zu `src/components/shared/AiPostAssistant.tsx`.
class AiPostAssistService {
  const AiPostAssistService._();

  static const _endpoint =
      'https://www.mensaena.de/api/posts/ai-assist';

  /// Liefert KI-Vorschlaege fuer Title/Description/Category.
  /// Bei Fehler null.
  static Future<AiPostSuggestions?> suggest({
    required String input,
    String? type,
  }) async {
    final token = sb.auth.currentSession?.accessToken;
    if (token == null) return null;
    try {
      final res = await http
          .post(
            Uri.parse(_endpoint),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'input': input, 'type': type}),
          )
          .timeout(const Duration(seconds: 25));
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return AiPostSuggestions(
        titles: (data['titles'] as List?)?.cast<String>() ?? const [],
        description: data['description'] as String?,
        category: data['category'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}

class AiPostSuggestions {
  const AiPostSuggestions({
    required this.titles,
    this.description,
    this.category,
  });

  final List<String> titles;
  final String? description;
  final String? category;

  bool get isEmpty =>
      titles.isEmpty && (description == null || description!.isEmpty);
  bool get isNotEmpty => !isEmpty;
}
