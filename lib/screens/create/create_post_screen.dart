import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/post_provider.dart';
import 'package:mensaena/models/post.dart';

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
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _tagsController = TextEditingController();
  bool _isAnonymous = false;
  bool _loading = false;

  final _postTypes = [
    {'value': 'help_needed', 'label': 'Hilfe gesucht', 'emoji': '🆘'},
    {'value': 'help_offered', 'label': 'Hilfe angeboten', 'emoji': '🤝'},
    {'value': 'rescue', 'label': 'Lebensmittelrettung', 'emoji': '🍎'},
    {'value': 'animal', 'label': 'Tierhilfe', 'emoji': '🐾'},
    {'value': 'housing', 'label': 'Wohnen', 'emoji': '🏠'},
    {'value': 'supply', 'label': 'Versorgung', 'emoji': '📦'},
    {'value': 'mobility', 'label': 'Mobilität', 'emoji': '🚗'},
    {'value': 'sharing', 'label': 'Teilen & Tauschen', 'emoji': '🔄'},
    {'value': 'community', 'label': 'Gemeinschaft', 'emoji': '👥'},
    {'value': 'knowledge', 'label': 'Wissen', 'emoji': '📚'},
    {'value': 'skill', 'label': 'Fähigkeit', 'emoji': '🛠️'},
    {'value': 'marketplace', 'label': 'Marktplatz', 'emoji': '🛒'},
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
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

      await ref.read(postServiceProvider).createPost({
        'user_id': userId,
        'type': _selectedType,
        'category': _selectedCategory,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location_text': _locationController.text.trim().isNotEmpty ? _locationController.text.trim() : null,
        'contact_phone': _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
        'tags': tags,
        'is_anonymous': _isAnonymous,
        'status': 'active',
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
                      Text(type['label']!, style: TextStyle(
                        fontSize: 15,
                        fontWeight: _selectedType == type['value'] ? FontWeight.w600 : FontWeight.normal,
                      )),
                      const Spacer(),
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
          decoration: const InputDecoration(labelText: 'Beschreibung', hintText: 'Weitere Details...'),
          maxLines: 5,
          maxLength: 2000,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _locationController,
          decoration: const InputDecoration(
            labelText: 'Standort',
            hintText: 'z.B. Wien, 1020',
            prefixIcon: Icon(Icons.location_on_outlined),
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
        SwitchListTile(
          value: _isAnonymous,
          onChanged: (v) => setState(() => _isAnonymous = v),
          title: const Text('Anonym posten'),
          subtitle: const Text('Dein Name wird nicht angezeigt'),
          activeColor: AppColors.primary500,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 24),
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
