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

  Widget _buildStep2() => const Placeholder(fallbackHeight: 400);
  Widget _buildStep3() => const Placeholder(fallbackHeight: 400);

  bool _validateStep1() {
    if (_selectedType.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Art auswählen')),
      );
      return false;
    }
    return true;
  }

  bool _validateStep2() => true;
  Future<void> _handleSubmit() async {}
  void _handleRestoreDraft() {}
  void _handleDiscardDraft() {
    setState(() {
      _showDraftPrompt = false;
      _pendingDraft = null;
      _draftSavedAt = null;
    });
  }
}
