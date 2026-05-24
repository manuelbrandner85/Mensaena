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

  /// Liefert null wenn Produkt nicht gefunden.
  static Future<FoodProduct?> lookup(String barcode) async {
    final clean = barcode.trim();
    if (clean.isEmpty) return null;
    final uri = Uri.parse(
        'https://world.openfoodfacts.org/api/v2/product/$clean.json'
        '?fields=product_name,brands,image_url,ingredients_text,quantity,categories');
    try {
      final res = await http
          .get(uri, headers: {'User-Agent': 'Mensaena/1.0 (mensaena.de)'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final body = json.decode(res.body) as Map<String, dynamic>;
      if (body['status'] != 1) return null;
      final p = body['product'] as Map<String, dynamic>?;
      if (p == null) return null;
      final name = (p['product_name'] as String?)?.trim();
      if (name == null || name.isEmpty) return null;
      return FoodProduct(
        barcode: clean,
        name: name,
        brand: (p['brands'] as String?)?.split(',').first.trim(),
        imageUrl: p['image_url'] as String?,
        ingredients: p['ingredients_text'] as String?,
        quantity: p['quantity'] as String?,
        categories: p['categories'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
