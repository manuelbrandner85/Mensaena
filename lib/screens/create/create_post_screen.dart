import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

    _checkForDraft();
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
    // Implemented in later prompt (Draft restore)
  }

  @override
  void dispose() {
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
    final scope = _scope;
    return Scaffold(
      appBar: AppBar(
        title: Text(scope != null ? scope['title'] as String : 'Beitrag erstellen'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.construction, size: 48, color: AppColors.primary500),
              const SizedBox(height: 16),
              Text(
                scope != null ? scope['description'] as String : 'UI wird in folgenden Schritten ergänzt.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppColors.textMuted),
              ),
              const SizedBox(height: 24),
              Text('Modul: ${widget.module ?? '—'}', style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              Text('Typen: ${_availableTypes.length} / Kategorien: ${_availableCategories.length}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              Text('Aktiv: $_selectedType · $_selectedCategory · urgency=$_urgency · step=$_step',
                  style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _availableTypes
                    .map((t) => ChoiceChip(
                          label: Text(t['label']!, style: const TextStyle(fontSize: 12)),
                          selected: _selectedType == t['value'],
                          onSelected: (_) => _handleTypeChange(t['value']!),
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
