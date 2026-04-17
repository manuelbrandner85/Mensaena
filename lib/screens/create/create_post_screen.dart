import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/post_provider.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  const CreatePostScreen({super.key});

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  int _step = 0;
  final _formKey = GlobalKey<FormState>();
  String _selectedType = 'help_needed';
  String _selectedCategory = 'general';
  String _urgency = 'medium';
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _emailContactController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _loading = false;

  final List<Uint8List> _imageBytes = [];
  final List<String> _imageNames = [];
  final _picker = ImagePicker();

  static const _postTypes = [
    {'value': 'help_needed', 'label': 'Hilfe suchen', 'emoji': '🙏', 'desc': 'Ich brauche Unterstützung', 'cat': 'everyday'},
    {'value': 'help_offered', 'label': 'Hilfe anbieten', 'emoji': '🤝', 'desc': 'Ich biete Hilfe an', 'cat': 'everyday'},
    {'value': 'rescue', 'label': 'Retter-Angebot', 'emoji': '🧡', 'desc': 'Ressourcen retten', 'cat': 'food'},
    {'value': 'animal', 'label': 'Tierhilfe', 'emoji': '🐾', 'desc': 'Tier sucht / bietet Hilfe', 'cat': 'animals'},
    {'value': 'housing', 'label': 'Wohnangebot', 'emoji': '🏡', 'desc': 'Wohnung oder Notunterkunft', 'cat': 'housing'},
    {'value': 'supply', 'label': 'Versorgung', 'emoji': '🌾', 'desc': 'Produkt anbieten / suchen', 'cat': 'food'},
    {'value': 'sharing', 'label': 'Teilen / Skill-Angebot', 'emoji': '🔄', 'desc': 'Teilen, Tauschen, Skill', 'cat': 'sharing'},
    {'value': 'mobility', 'label': 'Mobilität', 'emoji': '🚗', 'desc': 'Fahrt anbieten / suchen', 'cat': 'mobility'},
    {'value': 'community', 'label': 'Community / Wissen', 'emoji': '🗳️', 'desc': 'Idee, Abstimmung, Guide', 'cat': 'general'},
    {'value': 'crisis', 'label': 'Notfall / Mentales', 'emoji': '🚨', 'desc': 'Notfall oder Gespraech suchen', 'cat': 'emergency'},
  ];

  static const _categories = [
    {'value': 'food', 'label': '🍎 Essen & Versorgung'},
    {'value': 'everyday', 'label': '🏠 Alltag & Hilfe'},
    {'value': 'moving', 'label': '📦 Umzug'},
    {'value': 'animals', 'label': '🐾 Tiere'},
    {'value': 'housing', 'label': '🏡 Wohnen'},
    {'value': 'skills', 'label': '🛠️ Fähigkeiten'},
    {'value': 'knowledge', 'label': '📚 Bildung & Wissen'},
    {'value': 'mental', 'label': '💙 Mentales'},
    {'value': 'mobility', 'label': '🚗 Mobilität'},
    {'value': 'sharing', 'label': '🔄 Teilen/Tauschen'},
    {'value': 'emergency', 'label': '🚨 Notfall'},
    {'value': 'general', 'label': '🌿 Sonstiges'},
  ];

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _imageBytes.add(bytes);
      _imageNames.add(picked.name);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _emailContactController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    setState(() => _loading = true);

    try {
      final tags = _tagsController.text.isNotEmpty
          ? _tagsController.text.split(',').map((t) => t.trim()).where((t) => t.isNotEmpty).toList()
          : <String>[];

      // Upload images first
      final imageUrls = <String>[];
      for (int i = 0; i < _imageBytes.length; i++) {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_$i\_${_imageNames[i]}';
        final url = await ref.read(postServiceProvider).uploadImage(_imageBytes[i], fileName);
        imageUrls.add(url);
      }

      await ref.read(postServiceProvider).createPost({
        'user_id': userId,
        'type': _selectedType,
        'category': _selectedCategory,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location_text': _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
        'contact_phone': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        'contact_whatsapp': _whatsappController.text.trim().isNotEmpty ? _whatsappController.text.trim() : null,
        'contact_email': _emailContactController.text.trim().isNotEmpty ? _emailContactController.text.trim() : null,
        'tags': tags,
        'urgency': _urgency,
        'status': 'active',
        if (imageUrls.isNotEmpty) 'image_urls': imageUrls,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Beitrag erfolgreich erstellt!')),
        );
        context.go('/dashboard/posts');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(['Art wählen', 'Inhalt', 'Kontakt'][_step]),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Progress
            LinearProgressIndicator(
              value: (_step + 1) / 3,
              backgroundColor: AppColors.border,
              valueColor: const AlwaysStoppedAnimation(AppColors.primary500),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: [_buildStep0(), _buildStep1(), _buildStep2()][_step],
              ),
            ),

            // Navigation
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  if (_step > 0)
                    OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Zurück'),
                    ),
                  const Spacer(),
                  if (_step < 2)
                    ElevatedButton(
                      onPressed: () {
                        if (_step == 1 && _titleController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bitte Titel eingeben')),
                          );
                          return;
                        }
                        setState(() => _step++);
                      },
                      child: const Text('Weiter'),
                    ),
                  if (_step == 2)
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Veröffentlichen'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep0() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Was möchtest du teilen?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        ...(_postTypes.map((type) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => setState(() => _selectedType = type['value']!),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _selectedType == type['value'] ? AppColors.primary50 : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedType == type['value'] ? AppColors.primary500 : AppColors.border,
                      width: _selectedType == type['value'] ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(type['emoji']!, style: const TextStyle(fontSize: 24)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(type['label']!, style: TextStyle(
                              fontSize: 15,
                              fontWeight: _selectedType == type['value'] ? FontWeight.w600 : FontWeight.normal,
                            )),
                            if (type['desc'] != null)
                              Text(type['desc']!, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                          ],
                        ),
                      ),
                      if (_selectedType == type['value'])
                        const Icon(Icons.check_circle, color: AppColors.primary500),
                    ],
                  ),
                ),
              ),
            ))),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Beschreibe deinen Beitrag', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _titleController,
          decoration: const InputDecoration(labelText: 'Titel *', hintText: 'Kurze Beschreibung...'),
          validator: (v) => v == null || v.trim().isEmpty ? 'Bitte Titel eingeben' : null,
          maxLength: 100,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: const InputDecoration(labelText: 'Beschreibung *', hintText: 'Weitere Details...'),
          validator: (v) => v == null || v.trim().length < 20 ? 'Mindestens 20 Zeichen' : null,
          maxLines: 5,
          maxLength: 2000,
        ),
        const SizedBox(height: 16),
        const Text('Kategorie', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((cat) => FilterChip(
            label: Text(cat['label']!, style: const TextStyle(fontSize: 12)),
            selected: _selectedCategory == cat['value'],
            selectedColor: AppColors.primary50,
            onSelected: (_) => setState(() => _selectedCategory = cat['value']!),
          )).toList(),
        ),
        const SizedBox(height: 16),
        if (_selectedType == 'crisis' || _selectedType == 'rescue') ...[
          const Text('Dringlichkeit', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'low', label: Text('Niedrig')),
              ButtonSegment(value: 'medium', label: Text('Mittel')),
              ButtonSegment(value: 'high', label: Text('Hoch')),
              ButtonSegment(value: 'critical', label: Text('Kritisch')),
            ],
            selected: {_urgency},
            onSelectionChanged: (v) => setState(() => _urgency = v.first),
            style: ButtonStyle(
              foregroundColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected) ? Colors.white : AppColors.textSecondary),
              backgroundColor: WidgetStateProperty.resolveWith((s) =>
                s.contains(WidgetState.selected) ? AppColors.primary500 : AppColors.surface),
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextFormField(
          controller: _locationController,
          decoration: const InputDecoration(
            labelText: 'Standort',
            hintText: 'z.B. Wien, 1020',
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
        ),
        const SizedBox(height: 16),
        // Image upload
        const Text('Bilder (optional)', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SizedBox(
          height: 90,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ..._imageBytes.asMap().entries.map((e) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(e.value, width: 80, height: 80, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 2, right: 2,
                      child: GestureDetector(
                        onTap: () => setState(() { _imageBytes.removeAt(e.key); _imageNames.removeAt(e.key); }),
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
              if (_imageBytes.length < 4)
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    width: 80, height: 80,
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border, style: BorderStyle.solid),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate_outlined, color: AppColors.primary500, size: 28),
                        SizedBox(height: 4),
                        Text('Bild', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _tagsController,
          decoration: const InputDecoration(
            labelText: 'Tags (kommagetrennt)',
            hintText: 'z.B. einkaufen, kochen, garten',
            prefixIcon: Icon(Icons.tag),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kontaktoptionen', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text('Wie können dich Interessierte erreichen?', style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Telefonnummer (optional)',
            prefixIcon: Icon(Icons.phone_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _whatsappController,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'WhatsApp (optional)',
            hintText: 'z.B. +43 660 1234567',
            prefixIcon: Icon(Icons.chat_outlined),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emailContactController,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          decoration: const InputDecoration(
            labelText: 'E-Mail (optional)',
            hintText: 'kontakt@beispiel.de',
            prefixIcon: Icon(Icons.email_outlined),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return null;
            if (!v.contains('@')) return 'Ungültige E-Mail';
            return null;
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.primary500),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Du kannst jederzeit über Direktnachrichten kontaktiert werden.',
                  style: TextStyle(fontSize: 13, color: AppColors.primary700),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
