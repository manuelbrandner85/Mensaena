import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';

/// /dashboard/marketplace/create — neues Inserat erstellen.
/// Pendant zu src/app/dashboard/marketplace/create/page.tsx.
class MarketplaceCreatePage extends ConsumerStatefulWidget {
  const MarketplaceCreatePage({super.key});

  @override
  ConsumerState<MarketplaceCreatePage> createState() =>
      _MarketplaceCreatePageState();
}

class _MarketplaceCreatePageState
    extends ConsumerState<MarketplaceCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _price = TextEditingController();
  final _location = TextEditingController();

  String _category = 'sonstiges';
  String _condition = 'gut';
  String _priceType = 'negotiable';
  bool _saving = false;
  final List<String> _imageUrls = [];

  static const _categories = [
    (value: 'moebel', label: '🛋️ Möbel'),
    (value: 'elektronik', label: '📱 Elektronik'),
    (value: 'kleidung', label: '👗 Kleidung'),
    (value: 'sport', label: '⚽ Sport & Freizeit'),
    (value: 'garten', label: '🌱 Garten'),
    (value: 'kinder', label: '🧸 Kinder'),
    (value: 'haushalt', label: '🏠 Haushalt'),
    (value: 'buecher', label: '📚 Bücher'),
    (value: 'handwerk', label: '🔧 Werkzeug'),
    (value: 'lebensmittel', label: '🥦 Lebensmittel'),
    (value: 'sonstiges', label: '📦 Sonstiges'),
  ];

  static const _conditions = [
    (value: 'neu', label: 'Neu'),
    (value: 'wie_neu', label: 'Wie neu'),
    (value: 'gut', label: 'Gut'),
    (value: 'akzeptabel', label: 'Akzeptabel'),
  ];

  static const _priceTypes = [
    (value: 'fixed', label: '💶 Festpreis', icon: Icons.euro),
    (value: 'negotiable', label: '🤝 Verhandlungsbasis', icon: Icons.handshake_outlined),
    (value: 'free', label: '🎁 Zu verschenken', icon: Icons.card_giftcard),
    (value: 'swap', label: '🔄 Tausch', icon: Icons.swap_horiz),
  ];

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _price.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_imageUrls.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Max. 5 Bilder pro Anzeige')),
      );
      return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 80,
    );
    if (picked == null) return;
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) return;
      final ext = picked.name.split('.').last.toLowerCase();
      final path = '${user.id}/listing-${DateTime.now().millisecondsSinceEpoch}.$ext';
      final bytes = await picked.readAsBytes();
      await db.storage.from('marketplace-images').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
      final url = db.storage.from('marketplace-images').getPublicUrl(path);
      if (!mounted) return;
      setState(() => _imageUrls.add(url));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload fehlgeschlagen: $e')),
      );
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) throw Exception('Nicht eingeloggt');
      final price = double.tryParse(_price.text.replaceAll(',', '.'));
      final hasPrice =
          (_priceType == 'fixed' || _priceType == 'negotiable') && price != null;
      final row = await db.from('marketplace_listings').insert(<String, dynamic>{
        'user_id': user.id,
        'title': _title.text.trim(),
        if (_description.text.trim().isNotEmpty)
          'description': _description.text.trim(),
        'category': _category,
        'condition': _condition,
        'listing_type': _priceType,
        'price_type': _priceType,
        if (hasPrice) 'price': price,
        'currency': 'EUR',
        if (_location.text.trim().isNotEmpty)
          'location_text': _location.text.trim(),
        if (_imageUrls.isNotEmpty) 'media_urls': _imageUrls,
        'status': 'active',
      }).select('id').single();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anzeige veröffentlicht')),
      );
      context.go('/dashboard/marketplace/${row['id']}');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Inserat erstellen')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _Label('Titel *'),
            TextFormField(
              controller: _title,
              maxLength: 100,
              textCapitalization: TextCapitalization.sentences,
              decoration: _deco('z. B. Sofa zu verschenken'),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Min. 3 Zeichen' : null,
            ),
            const SizedBox(height: 12),
            const _Label('Beschreibung'),
            TextFormField(
              controller: _description,
              maxLines: 5,
              maxLength: 1000,
              textCapitalization: TextCapitalization.sentences,
              decoration: _deco('Zustand, Maße, Lieferung, …'),
            ),
            const SizedBox(height: 12),
            const _Label('Kategorie *'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _categories
                  .map(
                    (c) => ChoiceChip(
                      label: Text(c.label),
                      selected: _category == c.value,
                      onSelected: (_) =>
                          setState(() => _category = c.value),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            const _Label('Preis-Typ *'),
            Row(
              children: [
                for (final pt in _priceTypes)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _priceType = pt.value),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _priceType == pt.value
                              ? AppColors.primary500.withValues(alpha: 0.15)
                              : Colors.white,
                          border: Border.all(
                            color: _priceType == pt.value
                                ? AppColors.primary500
                                : Colors.grey.shade300,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              pt.icon,
                              size: 18,
                              color: _priceType == pt.value
                                  ? AppColors.primary500
                                  : AppColors.ink400,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              pt.label.split(' ').last,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _priceType == pt.value
                                    ? AppColors.primary500
                                    : AppColors.ink400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            if (_priceType == 'fixed' || _priceType == 'negotiable') ...[
              const SizedBox(height: 12),
              const _Label('Preis (€)'),
              TextFormField(
                controller: _price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: _deco('z. B. 25.00'),
              ),
            ],
            const SizedBox(height: 12),
            const _Label('Zustand'),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _conditions
                  .map(
                    (c) => ChoiceChip(
                      label: Text(c.label),
                      selected: _condition == c.value,
                      onSelected: (_) =>
                          setState(() => _condition = c.value),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 12),
            const _Label('Ort'),
            TextFormField(
              controller: _location,
              decoration: _deco('z. B. Wien 1010'),
            ),
            const SizedBox(height: 16),
            const _Label('Bilder (max. 5)'),
            SizedBox(
              height: 90,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final url in _imageUrls)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: url,
                              width: 80,
                              height: 80,
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const ColoredBox(
                                color: Color(0xFFF5F5F4),
                              ),
                              errorWidget: (_, __, ___) =>
                                  const Icon(Icons.broken_image),
                            ),
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _imageUrls.remove(url)),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFB91C1C),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (_imageUrls.length < 5)
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey.shade300,
                            style: BorderStyle.solid,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.add_photo_alternate_outlined,
                          color: AppColors.primary500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: FilledButton.icon(
                onPressed: _saving ? null : _submit,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(_saving ? 'Veröffentliche…' : 'Veröffentlichen'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _deco(String hint) => InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide:
              const BorderSide(color: AppColors.primary500, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: AppColors.ink400,
        ),
      ),
    );
  }
}
