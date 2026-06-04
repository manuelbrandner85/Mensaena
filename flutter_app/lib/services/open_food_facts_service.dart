/// SKILL: mensaena-features
/// Open Food Facts API — kostenfrei, keine Auth.
/// https://world.openfoodfacts.org/data
library;

import 'dart:convert';
import 'package:http/http.dart' as http;

class FoodProduct {
  const FoodProduct({
    required this.barcode,
    required this.name,
    this.brand,
    this.imageUrl,
    this.ingredients,
    this.quantity,
    this.categories,
  });

  final String barcode;
  final String name;
  final String? brand;
  final String? imageUrl;
  final String? ingredients;
  final String? quantity;
  final String? categories;

  String? get displayTitle {
    if (brand != null && brand!.isNotEmpty) return '$brand · $name';
    return name;
  }
}

class OpenFoodFactsService {
  const OpenFoodFactsService._();

  /// Sprachen, für die OFF lokalisierte Felder anbietet. ru ist
  /// ergänzt (nicht offizieller OFF-Subdomain, aber das Feld existiert).
  static const _supportedLangs = {'de', 'en', 'it', 'es', 'fr', 'tr', 'ru'};

  /// Liefert null wenn Produkt nicht gefunden.
  /// [lang] = 2-Buchstaben-Sprachcode (z.B. 'de', 'en'). Wenn vorhanden,
  /// werden lokalisierte Feldnamen bevorzugt (z.B. product_name_de).
  /// Fallback ist immer das generische Feld.
  static Future<FoodProduct?> lookup(String barcode, {String? lang}) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return null;
    final loc =
        (lang != null && _supportedLangs.contains(lang)) ? lang : null;
    // Lokalisierte Felder MIT in die fields-Query — OFF liefert sie nur
    // wenn explizit angefragt. Generic-Felder bleiben drin als Fallback.
    final fields = [
      'product_name',
      if (loc != null) 'product_name_$loc',
      'brands',
      'image_url',
      'ingredients_text',
      if (loc != null) 'ingredients_text_$loc',
      'quantity',
      'categories',
      if (loc != null) 'categories_$loc',
    ].join(',');
    final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$clean.json'
        '?fields=$fields');
    try {
      final res = await http
          .get(uri, headers: {'User-Agent': 'Mensaena/1.0 (mensaena.de)'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body['status'] != 1) return null;
      final p = body['product'] as Map<String, dynamic>?;
      if (p == null) return null;

      String? pickLocalized(String base) {
        if (loc != null) {
          final v = (p['${base}_$loc'] as String?)?.trim();
          if (v != null && v.isNotEmpty) return v;
        }
        return (p[base] as String?)?.trim();
      }

      final name = pickLocalized('product_name');
      if (name == null || name.isEmpty) return null;
      return FoodProduct(
        barcode: clean,
        name: name,
        brand: (p['brands'] as String?)?.split(',').first.trim(),
        imageUrl: p['image_url'] as String?,
        ingredients: pickLocalized('ingredients_text'),
        quantity: p['quantity'] as String?,
        categories: pickLocalized('categories'),
      );
    } catch (_) {
      return null;
    }
  }
}
