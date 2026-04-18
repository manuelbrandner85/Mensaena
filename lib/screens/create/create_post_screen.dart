import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';

class CreatePostScreen extends ConsumerStatefulWidget {
  final String? module;
  final String? initialType;
  final String? initialCategory;
  const CreatePostScreen({
    super.key,
    this.module,
    this.initialType,
    this.initialCategory,
  });

  @override
  ConsumerState<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends ConsumerState<CreatePostScreen> {
  static const _globalTypes = [
    {'value': 'rescue',       'label': '🔴 Hilfe suchen/anbieten', 'desc': 'Hilfe-Anfragen & Angebote',         'cat': 'everyday'},
    {'value': 'help_offered', 'label': '🧡 Retter-Angebot',        'desc': 'Ressourcen retten',                  'cat': 'food'},
    {'value': 'animal',       'label': '🐾 Tierhilfe',              'desc': 'Tier sucht / bietet Hilfe',          'cat': 'animals'},
    {'value': 'housing',      'label': '🏡 Wohnangebot',            'desc': 'Wohnung oder Notunterkunft',         'cat': 'housing'},
    {'value': 'supply',       'label': '🌾 Versorgung',             'desc': 'Produkt anbieten / suchen',          'cat': 'food'},
    {'value': 'sharing',      'label': '🔄 Teilen / Skill-Angebot', 'desc': 'Teilen, Tauschen, Skill',            'cat': 'sharing'},
    {'value': 'mobility',     'label': '🚗 Mobilität',              'desc': 'Fahrt anbieten / suchen',            'cat': 'mobility'},
    {'value': 'community',    'label': '🗳️ Community / Wissen',    'desc': 'Idee, Abstimmung, Guide',            'cat': 'general'},
    {'value': 'crisis',       'label': '🚨 Notfall / Mentales',     'desc': 'Notfall oder Gespräch suchen',       'cat': 'emergency'},
  ];

  static const _globalCategories = [
    {'value': 'food',      'label': '🍎 Essen & Versorgung'},
    {'value': 'everyday',  'label': '🏠 Alltag & Hilfe'},
    {'value': 'moving',    'label': '📦 Umzug'},
    {'value': 'animals',   'label': '🐾 Tiere'},
    {'value': 'housing',   'label': '🏡 Wohnen'},
    {'value': 'skills',    'label': '🛠️ Fähigkeiten'},
    {'value': 'knowledge', 'label': '📚 Bildung & Wissen'},
    {'value': 'mental',    'label': '💙 Mentales'},
    {'value': 'mobility',  'label': '🚗 Mobilität'},
    {'value': 'sharing',   'label': '🔄 Teilen/Tauschen'},
    {'value': 'emergency', 'label': '🚨 Notfall'},
    {'value': 'general',   'label': '🌿 Sonstiges'},
  ];

  static const _moduleScopes = <String, Map<String, dynamic>>{
    'housing': {
      'title': 'Wohnen & Alltag',
      'description': 'Wohnungen, Notunterkünfte, Umzugshilfe – passend zum Modul Wohnen',
      'types': [
        {'value': 'housing', 'label': '🏡 Wohnung anbieten', 'desc': 'Zimmer, Wohnung oder Haus zur Verfügung', 'cat': 'housing'},
        {'value': 'rescue',  'label': '🟡 Wohnung suchen',   'desc': 'Unterkunft, Umzugshilfe oder Haushaltshilfe', 'cat': 'housing'},
        {'value': 'crisis',  'label': '🚨 Notunterkunft',    'desc': 'Dringender Bedarf an Unterkunft',         'cat': 'emergency'},
      ],
      'categories': ['housing', 'moving', 'everyday', 'emergency', 'general'],
    },
    'animals': {
      'title': 'Tiere',
      'description': 'Tierhilfe, Vermittlung, Pflege, Notfälle',
      'types': [
        {'value': 'animal',  'label': '🐾 Tier gefunden/vermisst', 'desc': 'Vermittlung oder Suche',         'cat': 'animals'},
        {'value': 'rescue',  'label': '🟡 Tierhilfe anbieten',     'desc': 'Pflegestelle oder Betreuung',    'cat': 'animals'},
        {'value': 'crisis',  'label': '🚨 Tier-Notfall',           'desc': 'Akuter Tier-Notfall',            'cat': 'animals'},
      ],
      'categories': ['animals', 'general'],
    },
    'harvest': {
      'title': 'Ernte & Versorgung',
      'description': 'Regionale Lebensmittel, Ernte, Versorgung',
      'types': [
        {'value': 'supply',  'label': '🌾 Ernte/Versorgung anbieten', 'desc': 'Obst, Gemüse, Kräuter, Produkte', 'cat': 'food'},
        {'value': 'rescue',  'label': '🔴 Helfer gesucht',             'desc': 'Helfer für Ernte oder Versorgung', 'cat': 'food'},
      ],
      'categories': ['food', 'general'],
    },
    'knowledge': {
      'title': 'Wissen & Bildung',
      'description': 'Guides, Wissen teilen, Lernpartner',
      'types': [
        {'value': 'community', 'label': '📚 Wissen teilen',     'desc': 'Guide, Anleitung, Wissens-Beitrag', 'cat': 'knowledge'},
        {'value': 'sharing',   'label': '🎓 Skill anbieten',    'desc': 'Unterricht oder Wissens-Skill',     'cat': 'knowledge'},
        {'value': 'rescue',    'label': '📘 Lernpartner suchen', 'desc': 'Lernpartner oder Nachhilfe',        'cat': 'knowledge'},
      ],
      'categories': ['knowledge', 'general'],
    },
    'sharing': {
      'title': 'Teilen & Tauschen',
      'description': 'Gegenstände teilen, tauschen, weitergeben',
      'types': [
        {'value': 'sharing', 'label': '🔄 Gegenstand anbieten', 'desc': 'Verleihen, verschenken, tauschen', 'cat': 'sharing'},
        {'value': 'rescue',  'label': '🔴 Gegenstand suchen',   'desc': 'Du brauchst etwas?',               'cat': 'sharing'},
      ],
      'categories': ['sharing', 'everyday', 'knowledge', 'general'],
    },
    'rescuer': {
      'title': 'Retter',
      'description': 'Ressourcen retten: Lebensmittel, Kleidung, mehr',
      'types': [
        {'value': 'rescue',  'label': '🧡 Ressourcen retten', 'desc': 'Lebensmittel, Kleidung, Dinge retten', 'cat': 'food'},
        {'value': 'sharing', 'label': '🟢 Hilfe anbieten',    'desc': 'Hilfe im Retter-Kontext',              'cat': 'food'},
      ],
      'categories': ['food', 'everyday', 'sharing', 'general'],
    },
    'mobility': {
      'title': 'Mobilität',
      'description': 'Mitfahrten, Transporte, Umzugshilfe',
      'types': [
        {'value': 'mobility', 'label': '🚗 Fahrt anbieten', 'desc': 'Mitfahrgelegenheit oder Transport', 'cat': 'mobility'},
        {'value': 'rescue',   'label': '🔴 Fahrt suchen',   'desc': 'Du suchst eine Mitfahrgelegenheit?', 'cat': 'mobility'},
      ],
      'categories': ['mobility', 'moving'],
    },
    'skills': {
      'title': 'Fähigkeiten',
      'description': 'Handwerk, IT, Sprachen – Skills anbieten oder suchen',
      'types': [
        {'value': 'sharing',   'label': '⭐ Skill anbieten',   'desc': 'Deine Fähigkeit zur Verfügung stellen', 'cat': 'skills'},
        {'value': 'rescue',    'label': '🔴 Skill suchen',     'desc': 'Du brauchst eine bestimmte Fähigkeit?', 'cat': 'skills'},
        {'value': 'community', 'label': '🎓 Mentoring',         'desc': 'Langfristige Begleitung anbieten',     'cat': 'skills'},
      ],
      'categories': ['skills', 'general'],
    },
    'mental-support': {
      'title': 'Mentale Unterstützung',
      'description': 'Gesprächspartner, Krisen, anonyme Hilfe',
      'types': [
        {'value': 'crisis', 'label': '💙 Unterstützung anbieten', 'desc': 'Gespräche, Zuhören, Begleitung', 'cat': 'mental'},
        {'value': 'rescue', 'label': '🔴 Gesprächspartner suchen', 'desc': 'Du brauchst jemanden zum Reden?',  'cat': 'mental'},
      ],
      'categories': ['mental', 'general'],
    },
    'community': {
      'title': 'Community',
      'description': 'Abstimmungen, Ankündigungen, lokale Ideen',
      'types': [
        {'value': 'community', 'label': '🗳️ Abstimmung starten', 'desc': 'Abstimmung oder Idee einbringen', 'cat': 'general'},
      ],
      'categories': ['general', 'everyday', 'knowledge', 'emergency'],
    },
  };

  static const _titleSuggestions = <String, List<String>>{
    'rescue':       ['Rette Lebensmittel – bitte abholen', 'Überschuss vom Garten kostenlos', 'Reste aus Catering zu vergeben'],
    'help_offered': ['Biete Hilfe beim Einkaufen an', 'Kann beim Umzug helfen', 'Stehe als Ansprechperson zur Verfügung'],
    'animal':       ['Katze entlaufen – bitte melden', 'Biete Tierbetreuung an', 'Suche Pflegestelle für Hund'],
    'housing':      ['Biete Zimmer für 1 Person', 'Suche kurzfristig Unterkunft', 'Notunterkunft für Familie verfügbar'],
    'supply':       ['Gemüse vom Garten zu verschenken', 'Suche regional erzeugte Produkte', 'Biete Holz aus eigenem Wald'],
    'mobility':     ['Fahre nach Wien – Mitfahrer willkommen', 'Suche Mitfahrt nach Salzburg', 'Biete wöchentliche Fahrt an'],
    'sharing':      ['Verleihe Werkzeug kostenlos', 'Tausche Bücher gegen Lebensmittel', 'Gebe Kindersachen weiter'],
    'community':    ['Idee für Gemeinschaftsgarten', 'Abstimmung: Neues Community-Projekt', 'Vorschlag für Treffen'],
    'crisis':       ['DRINGEND: Brauche sofortige Hilfe', 'Notfall – bitte melden', 'Medizinische Versorgung gesucht'],
    'knowledge':    ['Anleitung: Gemüse einkochen', 'Tipps für nachhaltigen Alltag', 'Guide: Erste Hilfe Grundlagen'],
    'mental':       ['Suche jemanden zum Reden', 'Biete Begleitung bei schwierigen Zeiten', 'Möchte Erfahrungen teilen'],
  };

  final _formKey = GlobalKey<FormState>();

  int _step = 1;
  String? _userId;
  bool _loading = false;
  bool _showSuggestions = false;
  bool _isAnonymous = false;
  bool _acceptedNoTrade = false;

  late List<Map<String, String>> _availableTypes;
  late List<Map<String, String>> _availableCategories;
  late String _selectedType;
  late String _selectedCategory;
  String _urgency = 'low';

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _tagInput = TextEditingController();
  final _mediaUrlInput = TextEditingController();

  List<String> _tags = [];
  List<String> _mediaUrls = [];
  String? _imageUrl;
  Uint8List? _imagePreview;
  bool _uploading = false;
  double? _userLat;
  double? _userLng;
  bool _gettingLocation = false;

  bool _draftRestored = false;
  bool _showDraftPrompt = false;
  Map<String, dynamic>? _pendingDraft;
  int? _draftSavedAt;
  Timer? _draftTimer;

  Map<String, dynamic>? get _scope =>
      widget.module != null ? _moduleScopes[widget.module] : null;

  @override
  void initState() {
    super.initState();

    final scope = _scope;
    if (scope != null) {
      _availableTypes = List<Map<String, String>>.from(
        (scope['types'] as List).map((t) => Map<String, String>.from(t as Map)),
      );
      _availableCategories = _globalCategories
          .where((c) => (scope['categories'] as List).contains(c['value']))
          .toList();
    } else {
      _availableTypes = _globalTypes;
      _availableCategories = _globalCategories;
    }

    if (widget.initialType != null &&
        _availableTypes.any((t) => t['value'] == widget.initialType)) {
      _selectedType = widget.initialType!;
    } else {
      _selectedType = _availableTypes.first['value']!;
    }

    if (widget.initialCategory != null &&
        _availableCategories.any((c) => c['value'] == widget.initialCategory)) {
      _selectedCategory = widget.initialCategory!;
    } else {
      final typeEntry = _availableTypes.firstWhere((t) => t['value'] == _selectedType);
      _selectedCategory = typeEntry['cat'] ?? _availableCategories.first['value']!;
    }

    if (_selectedType == 'crisis') _urgency = 'high';

    ref.read(supabaseProvider).auth.getUser().then((res) {
      if (res.user != null && mounted) {
        setState(() => _userId = res.user!.id);
      }
    });

    _titleController.addListener(() {
      if (mounted) setState(() {});
    });
    _descriptionController.addListener(() {
      if (mounted) setState(() {});
    });

    _checkForDraft();
    _startDraftAutoSave();
  }

  void _handleTypeChange(String typeValue) {
    final t = _availableTypes.firstWhere((x) => x['value'] == typeValue);
    final nextCat = t['cat'] != null &&
            _availableCategories.any((c) => c['value'] == t['cat'])
        ? t['cat']!
        : _availableCategories.first['value']!;
    setState(() {
      _selectedType = typeValue;
      _selectedCategory = nextCat;
      if (typeValue == 'crisis') _urgency = 'high';
    });
  }

  Future<void> _checkForDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('mensaena:create-post-draft');
      if (raw == null) return;
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = parsed['savedAt'] as int? ?? 0;
      if (DateTime.now().millisecondsSinceEpoch - savedAt >
          7 * 24 * 60 * 60 * 1000) {
        await prefs.remove('mensaena:create-post-draft');
        return;
      }
      if (mounted) {
        setState(() {
          _pendingDraft = parsed;
          _showDraftPrompt = true;
        });
      }
    } catch (_) {}
  }

  void _startDraftAutoSave() {
    for (final ctrl in [
      _titleController,
      _descriptionController,
      _locationController,
    ]) {
      ctrl.addListener(_scheduleDraftSave);
    }
  }

  void _scheduleDraftSave() {
    _draftTimer?.cancel();
    _draftTimer = Timer(const Duration(milliseconds: 800), _saveDraft);
  }

  Future<void> _saveDraft() async {
    if (_showDraftPrompt) return;
    final hasContent = _titleController.text.trim().isNotEmpty ||
        _descriptionController.text.trim().isNotEmpty ||
        _tags.isNotEmpty ||
        _mediaUrls.isNotEmpty ||
        _imageUrl != null;
    if (!hasContent) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = jsonEncode({
        'step': _step,
        'type': _selectedType,
        'category': _selectedCategory,
        'urgency': _urgency,
        'title': _titleController.text,
        'description': _descriptionController.text,
        'location': _locationController.text,
        'tags': _tags,
        'mediaUrls': _mediaUrls,
        'imageUrl': _imageUrl,
        'userLat': _userLat,
        'userLng': _userLng,
        'savedAt': DateTime.now().millisecondsSinceEpoch,
      });
      await prefs.setString('mensaena:create-post-draft', draft);
      if (mounted) {
        setState(() => _draftSavedAt = DateTime.now().millisecondsSinceEpoch);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _tagInput.dispose();
    _mediaUrlInput.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: null,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildEditorialHeader(),
                    if (_showDraftPrompt && _pendingDraft != null) _buildDraftPrompt(),
                    const SizedBox(height: 24),
                    _buildStepIndicator(),
                    const SizedBox(height: 24),
                    _buildCurrentStep(),
                  ],
                ),
              ),
            ),
            _buildNavigationBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildEditorialHeader() {
    final scope = _scope;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '§ 04 / Erstellen',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
            color: AppColors.textMuted.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary100),
              ),
              child: const Icon(Icons.note_add_outlined, size: 24, color: AppColors.primary700),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scope != null
                        ? 'Neuer Beitrag – ${scope['title']}'
                        : 'Neuer Beitrag',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    scope != null
                        ? scope['description'] as String
                        : 'Sichtbar im Feed, auf der Karte und in passenden Modulen.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (scope != null) ...[
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => context.go('/dashboard/create'),
                      child: const Text(
                        'Alle Kategorien anzeigen',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary500,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (_draftSavedAt != null && !_showDraftPrompt)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.save_outlined, size: 12, color: AppColors.primary500),
                  const SizedBox(width: 4),
                  Text(
                    _draftRestored ? 'Wiederhergestellt' : 'Entwurf gespeichert',
                    style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.grey.shade400,
                Colors.grey.shade200,
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepIndicator() {
    const steps = [
      {'n': 1, 'label': 'Art & Kategorie'},
      {'n': 2, 'label': 'Inhalt'},
      {'n': 3, 'label': 'Kontakt'},
    ];

    return Row(
      children: List.generate(steps.length * 2 - 1, (index) {
        if (index.isOdd) {
          final stepBefore = (index ~/ 2) + 1;
          return Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              color: _step > stepBefore ? AppColors.primary500 : AppColors.border,
            ),
          );
        }

        final stepData = steps[index ~/ 2];
        final n = stepData['n'] as int;
        final label = stepData['label'] as String;
        final isCompleted = _step > n;
        final isActive = _step == n;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (isCompleted || isActive)
                    ? AppColors.primary500
                    : AppColors.border.withValues(alpha: 0.3),
                border: isActive
                    ? Border.all(color: AppColors.primary100, width: 4)
                    : null,
              ),
              child: Center(
                child: isCompleted
                    ? const Icon(Icons.check_circle, size: 16, color: Colors.white)
                    : Text(
                        '$n',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isActive ? Colors.white : AppColors.textMuted,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: (isCompleted || isActive)
                    ? AppColors.primary700
                    : AppColors.textMuted,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildDraftPrompt() {
    final draft = _pendingDraft!;
    final title = (draft['title'] as String?)?.trim();
    final savedAt = draft['savedAt'] as int? ?? 0;
    final minsAgo = ((DateTime.now().millisecondsSinceEpoch - savedAt) / 60000)
        .round()
        .clamp(1, 99999);

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFDDD6FE)),
      ),
      child: Row(
        children: [
          const Icon(Icons.replay, size: 20, color: Color(0xFF7C3AED)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Entwurf gefunden',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF4C1D95),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${title?.isNotEmpty == true ? title : "Unbenannter Entwurf"} · vor $minsAgo Min',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF6D28D9)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _handleDiscardDraft,
            child: const Text('Verwerfen',
                style: TextStyle(fontSize: 11, color: Colors.grey)),
          ),
          const SizedBox(width: 4),
          ElevatedButton(
            onPressed: _handleRestoreDraft,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Wiederherstellen',
                style: TextStyle(fontSize: 11, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          if (_step > 1)
            OutlinedButton(
              onPressed: () => setState(() => _step--),
              child: const Text('Zurück'),
            ),
          const Spacer(),
          if (_step < 3)
            ElevatedButton.icon(
              onPressed: _handleNextStep,
              icon: const Text('Weiter'),
              label: const Icon(Icons.chevron_right, size: 18),
            ),
          if (_step == 3)
            ElevatedButton.icon(
              onPressed: _loading ? null : _handleSubmit,
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_circle_outline, size: 18),
              label: const Text('Veröffentlichen'),
            ),
        ],
      ),
    );
  }

  Widget _buildCurrentStep() {
    switch (_step) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      default:
        return _buildStep1();
    }
  }

  void _handleNextStep() {
    if (_step == 1 && !_validateStep1()) return;
    if (_step == 2 && !_validateStep2()) return;
    setState(() => _step++);
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Welche Art von Beitrag? *',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth > 500) {
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTypes
                    .map((t) => SizedBox(
                          width: (constraints.maxWidth - 16) / 3,
                          child: _buildTypeCard(t),
                        ))
                    .toList(),
              );
            }
            return SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _availableTypes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => SizedBox(
                  width: 180,
                  child: _buildTypeCard(_availableTypes[i]),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
            children: [
              TextSpan(text: 'Kategorie * '),
              TextSpan(
                text: '→ automatisch gewählt',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primary500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: _availableCategories.map((c) {
            final isSelected = _selectedCategory == c['value'];
            return GestureDetector(
              onTap: () => setState(() => _selectedCategory = c['value']!),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary500 : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppColors.primary500 : AppColors.border,
                  ),
                ),
                child: Text(
                  c['label']!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        const Text(
          'Dringlichkeit',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildUrgencyButton('low', '🟦 Normal', AppColors.primary500),
            const SizedBox(width: 8),
            _buildUrgencyButton('medium', '🟧 Mittel', Colors.orange),
            const SizedBox(width: 8),
            _buildUrgencyButton('high', '🔴 Dringend', Colors.red.shade600),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeCard(Map<String, String> t) {
    final isSelected = _selectedType == t['value'];
    return GestureDetector(
      onTap: () => _handleTypeChange(t['value']!),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary50 : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary500 : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary500.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t['label']!,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? AppColors.primary700 : AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              t['desc']!,
              style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUrgencyButton(String value, String label, Color activeColor) {
    final isSelected = _urgency == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _urgency = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? activeColor : AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeColor : AppColors.border,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStep2() {
    final selectedTypeData = _availableTypes.firstWhere(
      (t) => t['value'] == _selectedType,
      orElse: () => _availableTypes.first,
    );
    final suggestions = _titleSuggestions[_selectedType] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  selectedTypeData['label']!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary700,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _step = 1),
                child: const Text(
                  'Ändern',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Titel *',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            if (suggestions.isNotEmpty)
              GestureDetector(
                onTap: () =>
                    setState(() => _showSuggestions = !_showSuggestions),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 14, color: Color(0xFF7C3AED)),
                    SizedBox(width: 4),
                    Text('Vorschläge',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7C3AED),
                        )),
                  ],
                ),
              ),
          ],
        ),
        if (_showSuggestions && suggestions.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F3FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDDD6FE)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tipp: Tippe auf einen Vorschlag',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7C3AED),
                  ),
                ),
                const SizedBox(height: 6),
                ...suggestions.map(
                  (s) => GestureDetector(
                    onTap: () {
                      _titleController.text = s;
                      setState(() => _showSuggestions = false);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 4),
                      decoration:
                          BoxDecoration(borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        s,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF5B21B6)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 6),
        TextFormField(
          controller: _titleController,
          maxLength: 80,
          decoration: const InputDecoration(
            hintText: 'Kurze, klare Beschreibung deines Beitrags',
            counterText: '',
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Titel ist Pflichtfeld';
            if (v.trim().length < 5) return 'Titel muss mindestens 5 Zeichen haben';
            return null;
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_titleController.text.length}/80',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 14),
        const Text.rich(TextSpan(children: [
          TextSpan(
              text: 'Beschreibung ',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          TextSpan(
              text: 'optional, aber empfohlen',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
        ])),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText:
                'Was genau benötigst du oder was bietest du an? Je mehr Details, desto besser.',
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${_descriptionController.text.length} Zeichen',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            Icon(Icons.location_on_outlined, size: 16, color: AppColors.textMuted),
            SizedBox(width: 4),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: 'Standort / Ort ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              TextSpan(
                  text: 'optional',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ])),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: _locationController,
          decoration: const InputDecoration(
            hintText: 'z.B. Wien 1070, Graz-Mitte, München Schwabing',
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: _gettingLocation ? null : _handleGetLocation,
              icon: _gettingLocation
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 14),
              label: const Text('Meinen Standort verwenden',
                  style: TextStyle(fontSize: 12)),
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                side: const BorderSide(color: AppColors.primary300),
                backgroundColor: AppColors.primary50,
                foregroundColor: AppColors.primary700,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (_userLat != null) ...[
              const SizedBox(width: 8),
              const Icon(Icons.location_on, size: 12, color: AppColors.success),
              const SizedBox(width: 2),
              const Text('Koordinaten gesetzt',
                  style: TextStyle(fontSize: 11, color: AppColors.success)),
            ],
          ],
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            Icon(Icons.add_photo_alternate_outlined,
                size: 16, color: AppColors.textMuted),
            SizedBox(width: 4),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: 'Bild ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              TextSpan(
                  text: 'optional – max. 10 MB',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ])),
          ],
        ),
        const SizedBox(height: 6),
        if (_imagePreview != null)
          SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(_imagePreview!,
                      width: 96, height: 96, fit: BoxFit.cover),
                ),
                if (_uploading)
                  Positioned(
                    left: 0,
                    top: 0,
                    width: 96,
                    height: 96,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black45,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    ),
                  ),
                Positioned(
                  top: -4,
                  right: -4,
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _imageUrl = null;
                      _imagePreview = null;
                    }),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 4)
                        ],
                      ),
                      child:
                          const Icon(Icons.close, size: 14, color: Colors.grey),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: _handleImagePick,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
            label:
                const Text('Bild hinzufügen', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.border),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),
        const SizedBox(height: 14),
        const Row(
          children: [
            Icon(Icons.link, size: 16, color: AppColors.textMuted),
            SizedBox(width: 4),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: 'Medien-Links ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              TextSpan(
                  text: 'optional – max. 5',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ])),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _mediaUrlInput,
                decoration: const InputDecoration(
                  hintText: 'https://... (Video, Bild, etc.)',
                  isDense: true,
                ),
                enabled: _mediaUrls.length < 5,
                onFieldSubmitted: (_) => _addMediaUrl(),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: _mediaUrls.length >= 5 ? null : _addMediaUrl,
              icon: const Icon(Icons.add, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary500,
                disabledBackgroundColor: AppColors.border,
                minimumSize: const Size(36, 36),
              ),
            ),
          ],
        ),
        if (_mediaUrls.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _mediaUrls
                .asMap()
                .entries
                .map(
                  (e) => Chip(
                    label: Text(
                      Uri.tryParse(e.value)?.host ?? e.value,
                      style: const TextStyle(fontSize: 11),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () =>
                        setState(() => _mediaUrls.removeAt(e.key)),
                    backgroundColor: Colors.blue.shade50,
                    labelStyle: TextStyle(color: Colors.blue.shade700),
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 14),
        const Row(
          children: [
            Icon(Icons.tag, size: 16, color: AppColors.textMuted),
            SizedBox(width: 4),
            Text.rich(TextSpan(children: [
              TextSpan(
                  text: 'Tags ',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              TextSpan(
                  text: 'optional – max. 5',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ])),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _tagInput,
                maxLength: 20,
                decoration: const InputDecoration(
                  hintText: 'Tag eingeben + Enter',
                  counterText: '',
                  isDense: true,
                ),
                enabled: _tags.length < 5,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-ZäöüÄÖÜß0-9\-]')),
                ],
                onFieldSubmitted: (_) => _addTag(),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: _tags.length >= 5 ? null : _addTag,
              icon: const Icon(Icons.add, size: 18),
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF7C3AED),
                disabledBackgroundColor: AppColors.border,
                minimumSize: const Size(36, 36),
              ),
            ),
          ],
        ),
        if (_tags.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _tags
                .map(
                  (tag) => Chip(
                    label: Text(
                      '#$tag',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6D28D9),
                      ),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () => setState(() => _tags.remove(tag)),
                    backgroundColor: const Color(0xFFEDE9FE),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Kontaktoptionen',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        const Text('Wie können dich Interessierte erreichen?',
            style: TextStyle(color: AppColors.textMuted)),
        const SizedBox(height: 16),
        if (!_isAnonymous) ...[
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Telefon',
              hintText: '+43 xxx xxx',
              prefixIcon: Icon(Icons.phone_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _whatsappController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'WhatsApp',
              hintText: '+43 xxx xxx',
              prefixIcon: Icon(Icons.chat_outlined),
            ),
          ),
          const SizedBox(height: 14),
        ],
        GestureDetector(
          onTap: () => setState(() => _isAnonymous = !_isAnonymous),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _isAnonymous ? const Color(0xFFECFEFF) : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    _isAnonymous ? const Color(0xFF67E8F9) : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _isAnonymous ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                  color: _isAnonymous
                      ? const Color(0xFF0891B2)
                      : AppColors.textMuted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Anonym posten',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(
                        _isAnonymous
                            ? 'Anonym aktiv – kein Kontakt nötig'
                            : 'Name & Kontakt werden angezeigt',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: _isAnonymous
                        ? const Color(0xFF06B6D4)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: _isAnonymous
                          ? const Color(0xFF06B6D4)
                          : AppColors.border,
                    ),
                  ),
                  child: _isAnonymous
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => setState(() => _acceptedNoTrade = !_acceptedNoTrade),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: _acceptedNoTrade
                      ? AppColors.primary500
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _acceptedNoTrade
                        ? AppColors.primary500
                        : Colors.amber.shade400,
                    width: 2,
                  ),
                ),
                child: _acceptedNoTrade
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Kein Handel / kein Geldgeschäft *',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    const Text.rich(
                      TextSpan(children: [
                        TextSpan(text: 'Ich bestätige, dass dieser Beitrag '),
                        TextSpan(
                          text:
                              'keinen kommerziellen Handel, Verkauf oder Geldgeschäfte',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(text: ' beinhaltet. '),
                        TextSpan(
                          text: 'Siehe AGB §4',
                          style: TextStyle(
                            color: AppColors.primary500,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ]),
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _validateStep1() {
    if (_selectedType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Art auswählen')),
      );
      return false;
    }
    return true;
  }

  bool _validateStep2() {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Titel eingeben')),
      );
      return false;
    }
    if (_titleController.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Titel muss mindestens 5 Zeichen haben')),
      );
      return false;
    }
    return true;
  }

  void _addTag() {
    final t = _tagInput.text.trim().toLowerCase();
    if (t.isNotEmpty && !_tags.contains(t) && _tags.length < 5) {
      setState(() {
        _tags.add(t);
        _tagInput.clear();
      });
    }
  }

  void _addMediaUrl() {
    final url = _mediaUrlInput.text.trim();
    if (url.isEmpty) return;
    if (Uri.tryParse(url)?.hasScheme != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ungültige URL')),
      );
      return;
    }
    if (_mediaUrls.length >= 5) return;
    if (!_mediaUrls.contains(url)) {
      setState(() {
        _mediaUrls.add(url);
        _mediaUrlInput.clear();
      });
    }
  }

  Future<void> _handleGetLocation() async {
    setState(() => _gettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Standort-Berechtigung verweigert')),
            );
          }
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text(
                    'Standort dauerhaft deaktiviert. Bitte in den Einstellungen aktivieren.')),
          );
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      if (!mounted) return;
      setState(() {
        _userLat = position.latitude;
        _userLng = position.longitude;
      });

      try {
        final uri = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse?lat=${position.latitude}&lon=${position.longitude}&format=json');
        final response = await http
            .get(uri, headers: {'User-Agent': 'MensaenaApp/1.0'});
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final displayName = data['display_name'] as String?;
          if (displayName != null && _locationController.text.isEmpty) {
            final parts = displayName.split(',');
            _locationController.text = parts.take(3).join(',').trim();
          }
        }
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Standort-Fehler: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<bool> _checkRateLimit() async {
    try {
      final result =
          await ref.read(supabaseProvider).rpc('check_rate_limit', params: {
        'p_user_id': _userId,
        'p_action': 'create_post',
        'p_max_per_hour': 10,
        'p_max_per_minute': 2,
      });
      return result == true;
    } catch (_) {
      return true;
    }
  }

  Future<void> _handleImagePick() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
        source: ImageSource.gallery, maxWidth: 1200, imageQuality: 80);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.length > 10 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Bild zu groß (max. 10 MB)')),
        );
      }
      return;
    }
    if (!mounted) return;
    setState(() {
      _imagePreview = bytes;
      _uploading = true;
    });
    try {
      final ext = picked.name.contains('.') ? picked.name.split('.').last : 'jpg';
      final uid = _userId ?? 'anon';
      final path =
          '$uid/${DateTime.now().millisecondsSinceEpoch}_${UniqueKey()}.$ext';
      await ref
          .read(supabaseProvider)
          .storage
          .from('post-images')
          .uploadBinary(path, bytes);
      final url = ref
          .read(supabaseProvider)
          .storage
          .from('post-images')
          .getPublicUrl(path);
      if (mounted) setState(() => _imageUrl = url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload fehlgeschlagen: $e')),
        );
        setState(() {
          _imagePreview = null;
          _imageUrl = null;
        });
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }
  Future<void> _handleSubmit() async {
    if (_userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nicht eingeloggt')),
      );
      return;
    }
    if (!_acceptedNoTrade) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Bitte bestätige, dass kein Handel oder Geldgeschäft stattfindet.')),
      );
      return;
    }
    if (!_isAnonymous &&
        _phoneController.text.trim().isEmpty &&
        _whatsappController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Mindestens Telefon oder WhatsApp ist Pflicht (oder wähle "Anonym posten")')),
      );
      return;
    }

    setState(() => _loading = true);

    final allowed = await _checkRateLimit();
    if (!allowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Zu viele Beiträge in kurzer Zeit. Bitte warte etwas.')),
        );
        setState(() => _loading = false);
      }
      return;
    }

    try {
      final allMediaUrls = <String>[
        if (_imageUrl != null) _imageUrl!,
        ..._mediaUrls,
      ];

      final payload = <String, dynamic>{
        'user_id': _userId,
        'type': _selectedType,
        'category': _selectedCategory,
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : 'Keine weiteren Details angegeben.',
        'location_text': _locationController.text.trim().isNotEmpty
            ? _locationController.text.trim()
            : null,
        if (_userLat != null) 'latitude': _userLat,
        if (_userLng != null) 'longitude': _userLng,
        'contact_phone': _isAnonymous
            ? null
            : (_phoneController.text.trim().isNotEmpty
                ? _phoneController.text.trim()
                : null),
        'contact_whatsapp': _isAnonymous
            ? null
            : (_whatsappController.text.trim().isNotEmpty
                ? _whatsappController.text.trim()
                : null),
        'urgency': _urgency,
        'is_anonymous': _isAnonymous,
        if (_tags.isNotEmpty) 'tags': _tags,
        if (allMediaUrls.isNotEmpty) 'media_urls': allMediaUrls,
        'status': 'active',
      };

      await ref.read(supabaseProvider).from('posts').insert(payload);

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('mensaena:create-post-draft');
      } catch (_) {}

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Beitrag erfolgreich veröffentlicht! 🌿'),
            backgroundColor: AppColors.success,
          ),
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

  void _handleRestoreDraft() {
    if (_pendingDraft == null) return;
    final d = _pendingDraft!;
    _titleController.text = d['title'] as String? ?? '';
    _descriptionController.text = d['description'] as String? ?? '';
    _locationController.text = d['location'] as String? ?? '';
    _selectedType =
        d['type'] as String? ?? _availableTypes.first['value']!;
    _selectedCategory =
        d['category'] as String? ?? _availableCategories.first['value']!;
    _urgency = d['urgency'] as String? ?? 'low';
    _tags = List<String>.from(d['tags'] ?? []);
    _mediaUrls = List<String>.from(d['mediaUrls'] ?? []);
    _imageUrl = d['imageUrl'] as String?;
    _userLat = (d['userLat'] as num?)?.toDouble();
    _userLng = (d['userLng'] as num?)?.toDouble();
    _step = d['step'] as int? ?? 1;
    setState(() {
      _draftRestored = true;
      _showDraftPrompt = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Entwurf wiederhergestellt'),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _handleDiscardDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('mensaena:create-post-draft');
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _showDraftPrompt = false;
      _pendingDraft = null;
      _draftSavedAt = null;
    });
  }
}
