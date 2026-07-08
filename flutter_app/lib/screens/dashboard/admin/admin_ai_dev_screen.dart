// ignore_for_file: lines_longer_than_80_chars
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' show Random;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/ai_insights_repository.dart';
import '../../../services/image_upload_service.dart';
import '../../../utils/safe_launch.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';
import '../../../widgets/shared/app_snackbar.dart';

/// SKILL: mensaena-features + mensaena-design
/// Admin Dev Godmode — vollständige App-Entwicklung direkt aus dem Dashboard.
/// Der Admin kann (a) frei in natürlicher Sprache Aufträge stellen (Feature,
/// Bugfix, UI/UX, Konfiguration) und (b) eine KI-Tiefenanalyse der GESAMTEN
/// App starten, die logische Fehler, Bugs und Verbesserungen je Screen
/// vorschlägt — annehmbar oder ablehnbar. Während des Scans zeigt das
/// Dashboard live, welche Datei gerade analysiert wird. Angenommene
/// Vorschläge / Aufträge laufen über PR → grünes CI → Auto-Merge →
/// Shorebird-OTA an die App; der Fortschritt wird live je Auftrag angezeigt.
class AdminAiDevScreen extends ConsumerStatefulWidget {
  const AdminAiDevScreen({super.key});

  @override
  ConsumerState<AdminAiDevScreen> createState() => _AdminAiDevScreenState();
}

enum _DevCategory {
  all,
  ui,
  feature,
  bug,
  performance,
  i18n,
  database,
  security,
  config;

  String get i18nKey => 'adminDev.categories.$name';

  String get englishName {
    switch (this) {
      case _DevCategory.ui:
        return 'UI/UX';
      case _DevCategory.feature:
        return 'Feature';
      case _DevCategory.bug:
        return 'Bugfix';
      case _DevCategory.performance:
        return 'Performance';
      case _DevCategory.i18n:
        return 'i18n/Translations';
      case _DevCategory.database:
        return 'Database';
      case _DevCategory.security:
        return 'Security';
      case _DevCategory.config:
        return 'Configuration';
      default:
        return '';
    }
  }

  IconData get icon {
    switch (this) {
      case _DevCategory.all:
        return LucideIcons.layoutGrid;
      case _DevCategory.ui:
        return LucideIcons.palette;
      case _DevCategory.feature:
        return LucideIcons.sparkles;
      case _DevCategory.bug:
        return LucideIcons.bug;
      case _DevCategory.performance:
        return LucideIcons.zap;
      case _DevCategory.i18n:
        return LucideIcons.languages;
      case _DevCategory.database:
        return LucideIcons.database;
      case _DevCategory.security:
        return LucideIcons.shield;
      case _DevCategory.config:
        return LucideIcons.settings;
    }
  }
}

// Schweregrad-Rang für die Sortierung (kritisch zuerst).
const _severityRank = {'critical': 0, 'high': 1, 'medium': 2, 'low': 3};
const _severityFilters = ['all', 'critical', 'high', 'medium', 'low'];

class _AdminAiDevScreenState extends ConsumerState<AdminAiDevScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  // Tab-Navigation (Übersicht / Aufträge / Vorschläge / Roadmap / Einstellungen).
  late final TabController _tabController;
  // Karten-Zustände werden lokal persistiert (übersteht App-Neustart).
  static const _uiPrefsStore = FlutterSecureStorage();
  static const _uiPrefsKey = 'godmode_ui_prefs_v1';
  List<Map<String, dynamic>> _tasks = const [];
  List<Map<String, dynamic>> _suggestions = const [];
  List<Map<String, dynamic>> _notes = const [];
  bool _notesExpanded = false;
  List<Map<String, dynamic>> _changelog = const [];
  bool _changelogExpanded = false;
  List<Map<String, dynamic>> _apiKeys = const [];
  bool _apiKeysExpanded = false;
  // Post-Merge-Gesundheitswächter: offene Crash-Anstieg-Alarme (sicherer
  // Alarm, kein Auto-Rollback — der Admin entscheidet).
  List<Map<String, dynamic>> _healthAlerts = const [];
  final Set<String> _busyAlerts = {};
  // Roadmap / Epics: thematische Initiativen mit Fortschritt.
  List<Map<String, dynamic>> _epics = const [];
  bool _epicsExpanded = false;
  // Überwachter Autopilot (täglich Top-Quick-Win mit Veto via Review-Gate).
  bool _autopilotEnabled = false;
  bool _autopilotBusy = false;
  // Modul-Health-Matrix (Bewertung je App-Modul aus dem Tiefenscan).
  List<Map<String, dynamic>> _moduleHealth = const [];
  bool _moduleHealthExpanded = false;
  // Notiz, die gerade per „Senden" zum Auftrag wird — wird nach erfolgreicher
  // Auftragserstellung automatisch gelöscht (aus dem Backlog geleert).
  String? _pendingNoteId;
  Map<String, dynamic>? _scan;
  final Set<String> _busySuggestions = {};
  final Set<String> _deletingTasks = {};
  bool _clearingTasks = false;
  bool _loading = true;
  bool _sending = false;

  // Anhänge (Screenshots/Vision) + Review-Gate für den nächsten Auftrag.
  final List<File> _pendingImages = [];
  bool _awaitReview = false;
  bool _wantScreens = false; // Vorher/Nachher-Screenshots (Golden-Tests)
  bool _planMode = false; // Multi-Step-Plan vor dem Absenden erzeugen
  bool _suggestionsLoading = false;

  // Health-Dashboard + wiederkehrende Aufträge (v4).
  Map<String, dynamic> _metrics = const {};
  bool _metricsExpanded = false;
  List<Map<String, dynamic>> _schedules = const [];
  bool _schedulesExpanded = false;
  String _categoryKey = 'all';
  List<Map<String, dynamic>> _categories = const []; // selbstlernende Kategorien
  String _severity = 'all';

  // Modul-Intelligenz (v5).
  List<Map<String, dynamic>> _moduleInsights = const [];
  Map<String, dynamic>? _moduleScan;
  bool _moduleExpanded = false;
  bool _moduleLoading = false;
  final Set<String> _busyModuleInsights = {};

  // Mehrfachauswahl
  bool _selectionMode = false;
  final Set<String> _selected = {};
  bool _batchBusy = false;

  Timer? _poll;

  // Revisions-Zähler für stilles Polling. Statt eines screen-weiten setState
  // (das Header, TabBar, InputBar usw. mit-rebuildet) bumpen die Silent-Loader
  // nur diesen Notifier — es bauen ausschließlich die daran hängenden
  // ValueListenableBuilder-Teilbäume (StatusBar/TabBar/TabBarView) neu.
  final ValueNotifier<int> _pollRev = ValueNotifier<int>(0);

  // Wendet Feld-Mutationen an: bei silent (Polling) ohne globales setState,
  // sonst regulär. So bleibt der Polling-Rebuild auf die Live-Teilbäume begrenzt.
  void _applyUpdate(bool silent, VoidCallback apply) {
    if (silent) {
      apply();
      if (mounted) _pollRev.value++;
    } else {
      setState(apply);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _saveUiPrefs();
    });
    _loadUiPrefs();
    _refresh();
    _loadSuggestions();
    _loadNotes();
    _loadMetrics();
    _loadChangelog();
    _loadApiKeys();
    _loadHealthAlerts();
    _loadEpics();
    _loadAutopilot();
    _loadModuleHealth();
    _loadSchedules();
    _loadModuleInsights();
    _poll = Timer.periodic(const Duration(seconds: 7), (_) {
      if (_scanning) _loadSuggestions(silent: true);
      if (_hasActive) _refresh(silent: true);
      if (_moduleScanning) _loadModuleInsights(silent: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _tabController.dispose();
    _poll?.cancel();
    _pollRev.dispose();
    super.dispose();
  }

  // ── UI-Zustand persistieren (Karten ein-/ausgeklappt + aktiver Tab) ─────────
  Future<void> _loadUiPrefs() async {
    try {
      final raw = await _uiPrefsStore.read(key: _uiPrefsKey);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _metricsExpanded = m['metrics'] as bool? ?? _metricsExpanded;
        _epicsExpanded = m['epics'] as bool? ?? _epicsExpanded;
        _moduleExpanded = m['module'] as bool? ?? _moduleExpanded;
        _schedulesExpanded = m['schedules'] as bool? ?? _schedulesExpanded;
        _notesExpanded = m['notes'] as bool? ?? _notesExpanded;
        _changelogExpanded = m['changelog'] as bool? ?? _changelogExpanded;
        _apiKeysExpanded = m['apiKeys'] as bool? ?? _apiKeysExpanded;
        _moduleHealthExpanded =
            m['moduleHealth'] as bool? ?? _moduleHealthExpanded;
      });
      final tab = m['tab'] as int?;
      if (tab != null && tab >= 0 && tab < _tabController.length) {
        _tabController.index = tab;
      }
    } catch (_) {/* defekte Prefs ignorieren */}
  }

  void _saveUiPrefs() {
    final data = jsonEncode({
      'metrics': _metricsExpanded,
      'epics': _epicsExpanded,
      'module': _moduleExpanded,
      'schedules': _schedulesExpanded,
      'notes': _notesExpanded,
      'changelog': _changelogExpanded,
      'apiKeys': _apiKeysExpanded,
      'moduleHealth': _moduleHealthExpanded,
      'tab': _tabController.index,
    });
    // Fire-and-forget; Schreibfehler sind unkritisch.
    _uiPrefsStore.write(key: _uiPrefsKey, value: data);
  }

  // Anzahl aktiver (in der Pipeline befindlicher) Aufträge für die Status-Leiste.
  int get _activeTaskCount => _tasks.where((t) {
        final s = t['status'] as String?;
        return s == 'queued' ||
            s == 'running' ||
            s == 'phased' ||
            s == 'pr_open' ||
            // Wartet auf automatischen Watchdog-Retry → weiterhin aktiv.
            s == 'error_retry' ||
            s == 'awaiting_review';
      }).length;

  bool get _hasActive => _tasks.any((t) {
        final s = t['status'] as String?;
        return s == 'queued' || s == 'running' || s == 'pr_open';
      });

  bool get _scanning {
    final s = _scan?['status'] as String?;
    return s == 'queued' || s == 'running';
  }

  // Sichtbare Vorschläge: nach Schweregrad gefiltert + sortiert (kritisch zuerst).
  List<Map<String, dynamic>> get _visibleSuggestions {
    var list = _suggestions;
    if (_severity != 'all') {
      list = list
          .where((s) => (s['severity'] as String? ?? 'medium') == _severity)
          .toList();
    }
    // Quick-Win-Priorisierung: hoher Nutzen (impact) + wenig Aufwand (effort)
    // zuerst. Fehlt der Score (Altbestand), neutral mit 3 werten.
    int qwScore(Map<String, dynamic> s) {
      final imp = (s['impact'] as num?)?.toInt() ?? 3;
      final eff = (s['effort'] as num?)?.toInt() ?? 3;
      return imp * 2 - eff;
    }

    final sorted = [...list]..sort((a, b) {
        final sc = qwScore(b).compareTo(qwScore(a)); // höchster Score zuerst
        if (sc != 0) return sc;
        final ra = _severityRank[a['severity'] as String? ?? 'medium'] ?? 2;
        final rb = _severityRank[b['severity'] as String? ?? 'medium'] ?? 2;
        return ra.compareTo(rb);
      });
    return sorted;
  }

  Future<void> _refresh({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final rows = await AiInsightsRepository.fetchDevTasks();
    if (!mounted) return;
    _applyUpdate(silent, () {
      _tasks = rows;
      _loading = false;
    });
  }

  // Ein abgeschlossener Auftrag ist löschbar.
  bool _deletable(String? status) =>
      status == 'merged' ||
      status == 'live' ||
      status == 'failed' ||
      status == 'patch_failed' ||
      status == 'no_changes' ||
      status == 'cancelled';

  // Anzahl löschbarer (abgeschlossener) Aufträge.
  int get _doneCount =>
      _tasks.where((t) => _deletable(t['status'] as String?)).length;

  Future<void> _deleteTask(String id) async {
    setState(() => _deletingTasks.add(id));
    final res = await AiInsightsRepository.deleteDevTask(id);
    if (!mounted) return;
    if (res['ok'] == true) {
      setState(() {
        _tasks = _tasks.where((t) => t['id'] != id).toList();
        _deletingTasks.remove(id);
      });
    } else {
      setState(() => _deletingTasks.remove(id));
      AppSnackBar.error(context, 'adminDev.deleteFailed'.tr());
    }
  }

  Future<void> _clearTasks() async {
    setState(() => _clearingTasks = true);
    final res = await AiInsightsRepository.clearDevTasks();
    if (!mounted) return;
    setState(() => _clearingTasks = false);
    if (res['ok'] == true) {
      setState(() => _tasks =
          _tasks.where((t) => !_deletable(t['status'] as String?)).toList());
    } else {
      AppSnackBar.error(context, 'adminDev.deleteFailed'.tr());
    }
  }

  // Built-in-Kategorie zum aktuellen Key (null wenn dynamische/eigene Kategorie).
  _DevCategory? get _builtinCategory {
    for (final c in _DevCategory.values) {
      if (c.name == _categoryKey) return c;
    }
    return null;
  }

  // Lesbares Label einer Kategorie (Built-in übersetzt, sonst dynamisches Label).
  String _categoryLabel(String key) {
    final builtin = _DevCategory.values.where((c) => c.name == key);
    if (builtin.isNotEmpty) return 'adminDev.categories.$key'.tr();
    final m = _categories.firstWhere(
      (c) => c['key'] == key,
      orElse: () => const {},
    );
    return (m['label'] as String?) ?? key;
  }

  Future<void> _loadSuggestions({bool silent = false}) async {
    if (!silent) setState(() => _suggestionsLoading = true);
    final data = await AiInsightsRepository.fetchDevSuggestions(
      category: _categoryKey == 'all' ? null : _categoryKey,
    );
    if (!mounted) return;
    _applyUpdate(silent, () {
      _suggestions = ((data['suggestions'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _categories = ((data['categories'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _scan = data['scan'] as Map<String, dynamic>?;
      _suggestionsLoading = false;
      // Auswahl auf noch vorhandene Vorschläge eingrenzen.
      final ids = _suggestions.map((s) => s['id'] as String?).toSet();
      _selected.removeWhere((id) => !ids.contains(id));
    });
  }

  Future<void> _startScan() async {
    final res = await AiInsightsRepository.scanApp();
    if (!mounted) return;
    if (res['ok'] == true) {
      AppSnackBar.info(context, 'adminDev.scanStarted'.tr());
      await _loadSuggestions(silent: true);
    } else {
      final notConfigured =
          (res['error'] as String?)?.contains('not_configured') == true;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              (notConfigured ? 'adminDev.notConfigured' : 'adminDev.scanFailed')
                  .tr()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  // Duplikat-/Konflikt-Check gegen AKTIVE Aufträge. true = fortfahren.
  Future<bool> _confirmNotDuplicate(String instruction) async {
    final active = _tasks
        .where((t) {
          final s = t['status'] as String?;
          return s == 'queued' ||
              s == 'running' ||
              s == 'pr_open' ||
              s == 'awaiting_review' ||
              s == 'error_retry' ||
              s == 'phased';
        })
        .map((t) => (t['instruction'] as String?) ?? '')
        .where((x) => x.isNotEmpty);
    final sim = similarInstruction(instruction, active);
    if (sim == null || !mounted) return true;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.lightSurface,
        title: Row(children: [
          const Icon(LucideIcons.copy, size: 18, color: AppColors.amber),
          const SizedBox(width: 8),
          Expanded(
              child: Text('adminDev.duplicateTitle'.tr(),
                  style: AppTypography.display(
                      size: 16, color: AppColors.lightInk))),
        ]),
        content: Text(
          'adminDev.duplicateWarning'.tr(namedArgs: {'task': sim}),
          style: AppTypography.body(size: 13, color: AppColors.lightInkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.amber),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('adminDev.duplicateProceed'.tr()),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // Vorschlag annehmen — IMMER über das Edit-Sheet: der vom Scan formulierte
  // Prompt ist vorausgefüllt und kann angepasst werden, plus die gleichen
  // Optionen wie bei freien Aufträgen (Review-Gate, Plan-Modus, Screenshots).
  // Danach wird der (ggf. bearbeitete) Auftrag erstellt und der Vorschlag
  // verknüpft-markiert.
  Future<void> _acceptWithEdit(Map<String, dynamic> s) async {
    final id = s['id'] as String? ?? '';
    if (id.isEmpty || _busySuggestions.contains(id)) return;
    final initial = (s['instruction'] as String?)?.trim().isNotEmpty == true
        ? s['instruction'] as String
        : (s['title'] as String? ?? '');
    final result = await showModalBottomSheet<_PromptEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PromptEditSheet(
        title: 'adminDev.edit.title'.tr(),
        confirmLabel: 'adminDev.edit.confirm'.tr(),
        initialText: initial,
        epics: _epics,
        initialEpicId: _bestEpicIdFor(s, _epics),
      ),
    );
    if (result == null || !mounted) return;
    if (!await _confirmNotDuplicate(result.instruction) || !mounted) return;
    setState(() => _busySuggestions.add(id));
    final res = await _submitTask(
      result.instruction,
      awaitReview: result.awaitReview,
      planMode: result.planMode,
      wantScreens: result.wantScreens,
      model: result.model,
      origin: 'suggestion',
      epicId: result.epicId,
    );
    if (!mounted) return;
    if (res['cancelled'] == true) {
      setState(() => _busySuggestions.remove(id));
      return;
    }
    if (res['ok'] == true) {
      await AiInsightsRepository.markSuggestionsAccepted(
          [id], res['task_id'] as String?);
      if (!mounted) return;
      setState(() => _busySuggestions.remove(id));
      AppSnackBar.info(context, 'adminDev.accepted'.tr());
      await _loadSuggestions(silent: true);
      await _refresh(silent: true);
    } else {
      setState(() => _busySuggestions.remove(id));
      _showError(res['error'] as String?);
    }
  }

  Future<void> _reject(String id) async {
    setState(() => _busySuggestions.add(id));
    final res = await AiInsightsRepository.rejectSuggestion(id);
    if (!mounted) return;
    setState(() => _busySuggestions.remove(id));
    if (res['ok'] == true) {
      await _loadSuggestions(silent: true);
    }
  }

  // ── Mehrfachauswahl ───────────────────────────────────────────────────────
  void _toggleSelectionMode() {
    setState(() {
      _selectionMode = !_selectionMode;
      if (!_selectionMode) _selected.clear();
    });
  }

  void _toggleSelected(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
      } else {
        _selected.add(id);
      }
    });
  }

  void _selectAllVisible() {
    setState(() {
      for (final s in _visibleSuggestions) {
        final id = s['id'] as String?;
        if (id != null) _selected.add(id);
      }
    });
  }

  // Ausgewählte Vorschläge zu EINEM editierbaren Auftrag bündeln (statt N PRs):
  // kombinierte, nummerierte Anweisung vorausfüllen → anpassbar → ein Task →
  // alle Vorschläge verknüpft als angenommen markieren.
  Future<void> _acceptSelected() async {
    if (_selected.isEmpty || _batchBusy) return;
    final ids = _selected.toList();
    final chosen =
        _suggestions.where((s) => ids.contains(s['id'])).toList();
    final buf = StringBuffer();
    for (var i = 0; i < chosen.length; i++) {
      final s = chosen[i];
      final t = (s['title'] as String?)?.trim() ?? '';
      final ins = (s['instruction'] as String?)?.trim() ?? '';
      buf.writeln('${i + 1}. ${t.isNotEmpty ? '$t — ' : ''}$ins');
      buf.writeln();
    }
    final result = await showModalBottomSheet<_PromptEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PromptEditSheet(
        title: 'adminDev.edit.bundleTitle'
            .tr(namedArgs: {'count': '${chosen.length}'}),
        confirmLabel: 'adminDev.edit.confirm'.tr(),
        hint: 'adminDev.edit.bundleHint'.tr(),
        initialText: buf.toString().trim(),
        epics: _epics,
      ),
    );
    if (result == null || !mounted) return;
    if (!await _confirmNotDuplicate(result.instruction) || !mounted) return;
    setState(() => _batchBusy = true);
    final res = await _submitTask(
      result.instruction,
      awaitReview: result.awaitReview,
      planMode: result.planMode,
      wantScreens: result.wantScreens,
      model: result.model,
      origin: 'suggestion',
      epicId: result.epicId,
    );
    if (!mounted) return;
    if (res['cancelled'] == true) {
      setState(() => _batchBusy = false);
      return;
    }
    if (res['ok'] == true) {
      await AiInsightsRepository.markSuggestionsAccepted(
          ids, res['task_id'] as String?);
      if (!mounted) return;
      setState(() {
        _batchBusy = false;
        _selectionMode = false;
        _selected.clear();
      });
      AppSnackBar.info(context,
          'adminDev.acceptedMany'.tr(namedArgs: {'count': '${ids.length}'}));
      await _loadSuggestions(silent: true);
      await _refresh(silent: true);
    } else {
      setState(() => _batchBusy = false);
      _showError(res['error'] as String?);
    }
  }

  Future<void> _rejectSelected() async {
    if (_selected.isEmpty || _batchBusy) return;
    setState(() => _batchBusy = true);
    final ids = _selected.toList();
    final res = await AiInsightsRepository.rejectManySuggestions(ids);
    if (!mounted) return;
    setState(() {
      _batchBusy = false;
      _selectionMode = false;
      _selected.clear();
    });
    if (res['ok'] == true) {
      await _loadSuggestions(silent: true);
    }
  }

  void _showError(String? error) {
    final key = error?.contains('not_configured') == true
        ? 'adminDev.notConfigured'
        : 'adminDev.failed';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(key.tr()), backgroundColor: Colors.red.shade700),
    );
  }

  String _categoryPrefix() {
    if (_categoryKey == 'all') return '';
    final bc = _builtinCategory;
    final label = bc != null
        ? bc.englishName
        : (_categories.firstWhere(
            (c) => c['key'] == _categoryKey,
            orElse: () => {'label': _categoryKey},
          )['label'] as String);
    return '[$label] ';
  }

  // Manueller Eingang → Chatbot-Modus: erst nachfragen, dann bei „Ja" absenden.
  Future<void> _send([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty || _sending) return;
    _ctrl.clear();
    FocusScope.of(context).unfocus();
    setState(() => _sending = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DevChatSheet(
        initialText: text,
        onConfirm: _confirmChatTask,
      ),
    );
    if (!mounted) return;
    setState(() => _sending = false);
    // Falls der Send über eine Notiz lief und der Auftrag NICHT erstellt wurde
    // (Admin hat im Sheet abgebrochen), bleibt die Notiz erhalten — Reset hier.
    _pendingNoteId = null;
    await _refresh(silent: true);
  }

  // Gemeinsamer Absende-Pfad: erzeugt (optional) den Multi-Step-Plan, lässt ihn
  // bestätigen und legt den Auftrag an. Geteilt von Chat-Confirm, Vorschlag-
  // Annehmen (bearbeitet), Bündeln und Retry — so verhalten sich alle Wege
  // identisch (gleiche Optionen, gleiche Plan-Bestätigung). Rückgabe:
  // {ok, task_id} | {error} | {cancelled:true} (Plan im Dialog verworfen).
  Future<Map<String, dynamic>> _submitTask(
    String instruction, {
    List<String> imageUrls = const [],
    bool awaitReview = false,
    bool planMode = false,
    bool wantScreens = false,
    String? origin,
    String? model,
    String? epicId,
  }) async {
    var plan = const <String>[];
    if (planMode) {
      final steps = await AiInsightsRepository.planDevTask(instruction);
      if (!mounted) return const {'cancelled': true};
      if (steps.isNotEmpty) {
        final ok = await _confirmPlan(steps);
        if (ok != true) return const {'cancelled': true};
        plan = steps;
      }
    }
    return AiInsightsRepository.createDevTask(
      instruction,
      imageUrls: imageUrls,
      awaitReview: awaitReview,
      plan: plan,
      wantScreens: wantScreens,
      origin: origin,
      model: model,
      epicId: epicId,
      // Auto-Phasen-Splitter aus: jeder app-initiierte Auftrag wird als EIN
      // vollständiger PR umgesetzt + gemergt (verlässlich). Die Mehr-Phasen-
      // Verkettung lieferte zuletzt nur Phase 1 (Backend), die Folgephasen
      // (u. a. UI) kamen nie an → Feature erschien nicht in der App. Wer
      // bewusst zerlegen will, nutzt den „Plan-Modus" (ein PR, Schritt-Liste).
      noSplit: true,
    );
  }

  // Wird vom Chat-Sheet aufgerufen, sobald der Admin „Ja, umsetzen" tippt.
  // Lädt zuvor angehängte Screenshots hoch und übergibt sie + das Review-Gate.
  Future<bool> _confirmChatTask(String instruction) async {
    var urls = const <String>[];
    if (_pendingImages.isNotEmpty) {
      urls = await ImageUploadService.upload(
        List<File>.from(_pendingImages),
        bucket: 'post-images',
      );
    }

    final res = await _submitTask(
      '${_categoryPrefix()}$instruction',
      imageUrls: urls,
      awaitReview: _awaitReview,
      planMode: _planMode,
      wantScreens: _wantScreens,
    );
    if (res['cancelled'] == true) return false; // Plan verworfen.
    if (res['ok'] == true) {
      setState(() {
        _pendingImages.clear();
        _awaitReview = false;
        _wantScreens = false;
        _planMode = false;
      });
      // Auftrag wurde erstellt → Notiz aus dem Backlog leeren (falls der Send
      // über eine Notiz ausgelöst wurde).
      final noteId = _pendingNoteId;
      if (noteId != null && noteId.isNotEmpty) {
        _pendingNoteId = null;
        await AiInsightsRepository.deleteDevNote(noteId);
        if (mounted) {
          setState(() =>
              _notes = _notes.where((n) => n['id'] != noteId).toList());
        }
      }
    }
    return res['ok'] == true;
  }

  // Zeigt den generierten Plan als Checkliste — Admin bestätigt oder verwirft.
  Future<bool?> _confirmPlan(List<String> steps) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(LucideIcons.listChecks, size: 18, color: AppColors.teal),
            const SizedBox(width: 8),
            Expanded(child: Text('adminDev.plan.title'.tr())),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('adminDev.plan.intro'.tr(),
                style: AppTypography.body(size: 12, color: AppColors.lightMute)),
            const SizedBox(height: 10),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.teal.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Text('${i + 1}',
                          style: AppTypography.body(
                              size: 11, color: AppColors.teal)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(steps[i],
                          style: AppTypography.body(
                              size: 13, color: AppColors.lightInk)),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            child: Text('adminDev.plan.confirm'.tr()),
          ),
        ],
      ),
    );
  }

  // Screenshots zum Auftrag auswählen (Vision — der Agent „sieht" sie).
  Future<void> _pickImages() async {
    try {
      final picked = await ImagePicker().pickMultiImage(imageQuality: 80);
      if (picked.isEmpty || !mounted) return;
      setState(() {
        for (final x in picked) {
          if (_pendingImages.length >= 6) break;
          _pendingImages.add(File(x.path));
        }
      });
    } catch (_) {/* Picker abgebrochen/kein Zugriff */}
  }

  void _removeImage(int index) {
    setState(() => _pendingImages.removeAt(index));
  }

  // Fehlgeschlagenen Auftrag wiederholen — öffnet das Edit-Sheet mit der
  // ursprünglichen Anweisung. So lässt sich der Prompt VOR dem Neustart
  // anpassen (z. B. der Grund des Fehlschlags), statt 1:1 zu wiederholen.
  Future<void> _retryTask(String instruction) async {
    if (_sending) return;
    final result = await showModalBottomSheet<_PromptEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PromptEditSheet(
        title: 'adminDev.edit.retryTitle'.tr(),
        confirmLabel: 'adminDev.edit.confirm'.tr(),
        initialText: instruction,
        epics: _epics,
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _sending = true);
    final res = await _submitTask(
      result.instruction,
      awaitReview: result.awaitReview,
      planMode: result.planMode,
      wantScreens: result.wantScreens,
      model: result.model,
      epicId: result.epicId,
    );
    if (!mounted) return;
    setState(() => _sending = false);
    if (res['cancelled'] == true) return;
    if (res['ok'] == true) {
      AppSnackBar.info(context, 'adminDev.queued'.tr());
      await _refresh(silent: true);
    } else {
      _showError(res['error'] as String?);
    }
  }

  // Laufenden Auftrag abbrechen.
  Future<void> _cancelTask(String id) async {
    setState(() => _deletingTasks.add(id));
    final res = await AiInsightsRepository.cancelDevTask(id);
    if (!mounted) return;
    setState(() => _deletingTasks.remove(id));
    if (res['ok'] == true) {
      await _refresh(silent: true);
    } else {
      AppSnackBar.error(context, 'adminDev.cancelFailed'.tr());
    }
  }

  // Wartenden Auftrag (Review-Gate) freigeben & mergen.
  Future<void> _mergeTask(String id) async {
    setState(() => _deletingTasks.add(id));
    final res = await AiInsightsRepository.mergeDevTask(id);
    if (!mounted) return;
    setState(() => _deletingTasks.remove(id));
    if (res['ok'] == true) {
      await _refresh(silent: true);
    } else {
      AppSnackBar.error(context, 'adminDev.mergeFailed'.tr());
    }
  }

  // Offenen Auftrag per Folge-Anweisung nachbessern (gleicher Branch/PR).
  Future<void> _refineTask(String id) async {
    final ctrl = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.lightSurface,
        title: Row(children: [
          const Icon(LucideIcons.messageSquarePlus,
              size: 18, color: AppColors.teal),
          const SizedBox(width: 8),
          Expanded(
              child: Text('adminDev.refine.title'.tr(),
                  style: AppTypography.display(
                      size: 16, color: AppColors.lightInk))),
        ]),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          minLines: 2,
          style: AppTypography.body(size: 13, color: AppColors.lightInk),
          decoration: InputDecoration(
            hintText: 'adminDev.refine.hint'.tr(),
            hintStyle:
                AppTypography.body(size: 12, color: AppColors.lightMute),
            filled: true,
            fillColor: AppColors.lightElevated,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('common.send'.tr()),
          ),
        ],
      ),
    );
    final text = ctrl.text.trim();
    if (go != true || text.length < 3 || !mounted) return;
    setState(() => _deletingTasks.add(id));
    final res = await AiInsightsRepository.refineDevTask(id, text);
    if (!mounted) return;
    setState(() => _deletingTasks.remove(id));
    if (res['ok'] == true) {
      AppSnackBar.info(context, 'adminDev.refine.started'.tr());
      await _refresh(silent: true);
    } else {
      _showError(res['error'] as String?);
    }
  }

  // Diff/geänderte Dateien des PRs anzeigen.
  Future<void> _showDiff(String id) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DiffSheet(taskId: id),
    );
  }

  // ── Notizen / Backlog ──────────────────────────────────────────────────────
  Future<void> _loadNotes() async {
    final rows = await AiInsightsRepository.fetchDevNotes();
    if (!mounted) return;
    setState(() => _notes = rows);
  }

  Future<void> _loadMetrics() async {
    final m = await AiInsightsRepository.fetchDevMetrics();
    if (!mounted) return;
    setState(() => _metrics = m);
  }

  Future<void> _loadChangelog() async {
    final c = await AiInsightsRepository.fetchGodmodeChangelog();
    if (!mounted) return;
    setState(() => _changelog = c);
  }

  Future<void> _loadApiKeys() async {
    final k = await AiInsightsRepository.fetchApiKeys();
    if (!mounted) return;
    setState(() => _apiKeys = k);
  }

  Future<void> _loadHealthAlerts() async {
    final a = await AiInsightsRepository.fetchHealthAlerts();
    if (!mounted) return;
    setState(() => _healthAlerts = a);
  }

  // Alarm quittieren (acknowledged) oder als erledigt markieren (resolved).
  Future<void> _setAlertStatus(String id, String status) async {
    setState(() => _busyAlerts.add(id));
    try {
      await AiInsightsRepository.setHealthAlertStatus(id, status);
      await _loadHealthAlerts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('errors.generic'.tr())),
        );
      }
    } finally {
      if (mounted) setState(() => _busyAlerts.remove(id));
    }
  }

  Future<void> _loadEpics() async {
    final e = await AiInsightsRepository.fetchEpics();
    if (!mounted) return;
    setState(() => _epics = e);
  }

  Future<void> _loadAutopilot() async {
    final on = await AiInsightsRepository.fetchAutopilotEnabled();
    if (!mounted) return;
    setState(() => _autopilotEnabled = on);
  }

  Future<void> _loadModuleHealth() async {
    final m = await AiInsightsRepository.fetchModuleHealth();
    if (!mounted) return;
    setState(() => _moduleHealth = m);
  }

  Future<void> _toggleAutopilot(bool v) async {
    setState(() => _autopilotBusy = true);
    final ok = await AiInsightsRepository.setAutopilotEnabled(v);
    if (!mounted) return;
    setState(() {
      if (ok) _autopilotEnabled = v;
      _autopilotBusy = false;
    });
    if (!ok) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('errors.generic'.tr())));
    }
  }

  // Epic anlegen/bearbeiten (Titel, Beschreibung, Farbe, Status).
  Future<void> _editEpic({Map<String, dynamic>? existing}) async {
    final titleCtrl =
        TextEditingController(text: existing?['title'] as String? ?? '');
    final descCtrl =
        TextEditingController(text: existing?['description'] as String? ?? '');
    var color = existing?['color'] as String? ?? 'teal';
    var status = existing?['status'] as String? ?? 'active';
    const colors = ['teal', 'amber', 'herzrot', 'leben', 'trust'];
    const statuses = ['active', 'done', 'archived'];

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: Text(existing == null
              ? 'adminDev.roadmap.add'.tr()
              : 'adminDev.roadmap.edit'.tr()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: InputDecoration(
                      labelText: 'adminDev.roadmap.titleLabel'.tr()),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  minLines: 1,
                  decoration: InputDecoration(
                      labelText: 'adminDev.roadmap.descLabel'.tr()),
                ),
                const SizedBox(height: 12),
                Text('adminDev.roadmap.colorLabel'.tr().toUpperCase(),
                    style: AppTypography.label(
                        size: 9, color: AppColors.lightMute)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final c in colors)
                      GestureDetector(
                        onTap: () => setLocal(() => color = c),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: _epicColor(c),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: color == c
                                  ? AppColors.lightInk
                                  : Colors.transparent,
                              width: 2.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text('adminDev.roadmap.statusLabel'.tr().toUpperCase(),
                    style: AppTypography.label(
                        size: 9, color: AppColors.lightMute)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final s in statuses)
                      ChoiceChip(
                        label: Text('adminDev.roadmap.status_$s'.tr(),
                            style: AppTypography.label(size: 10)),
                        selected: status == s,
                        onSelected: (_) => setLocal(() => status = s),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('common.save'.tr()),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;
    final title = titleCtrl.text.trim();
    if (title.isEmpty) return;
    final res = await AiInsightsRepository.saveEpic(
      id: existing?['id'] as String?,
      title: title,
      description: descCtrl.text.trim(),
      color: color,
      status: status,
    );
    if (!mounted) return;
    if (res['ok'] == true) {
      await _loadEpics();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('errors.generic'.tr())),
      );
    }
  }

  Future<void> _deleteEpic(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('adminDev.roadmap.deleteTitle'.tr()),
        content: Text('adminDev.roadmap.deleteBody'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.herzrot),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('common.delete'.tr()),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final done = await AiInsightsRepository.deleteEpic(id);
    if (!mounted) return;
    if (done) await _loadEpics();
  }

  // Neuen Auftrag direkt unter einem Epic anlegen (Epic vorausgewählt).
  Future<void> _newTaskInEpic(Map<String, dynamic> epic) async {
    final result = await showModalBottomSheet<_PromptEditResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PromptEditSheet(
        title: 'adminDev.roadmap.newTaskIn'
            .tr(namedArgs: {'epic': epic['title'] as String? ?? ''}),
        confirmLabel: 'adminDev.edit.confirm'.tr(),
        initialText: '',
        epics: _epics,
        initialEpicId: epic['id'] as String?,
      ),
    );
    if (result == null) return;
    final res = await _submitTask(
      result.instruction,
      awaitReview: result.awaitReview,
      planMode: result.planMode,
      wantScreens: result.wantScreens,
      model: result.model,
      origin: 'manual',
      epicId: result.epicId,
    );
    if (!mounted) return;
    if (res['ok'] == true) {
      await _refresh();
      await _loadEpics();
    }
  }

  Color _epicColor(String key) {
    switch (key) {
      case 'amber':
        return AppColors.amber;
      case 'herzrot':
        return AppColors.herzrot;
      case 'leben':
        return AppColors.leben;
      case 'trust':
        return AppColors.trust;
      default:
        return AppColors.teal;
    }
  }

  // Aus einem Alarm direkt einen Fix-Auftrag erstellen (vorbefüllter Prompt).
  Future<void> _fixFromAlert(Map<String, dynamic> alert) async {
    final msg = (alert['error_message'] as String? ?? '').trim();
    final pr = alert['pr_number'];
    final prefill = 'adminDev.healthAlert.fixPrompt'.tr(namedArgs: {
      'pr': pr == null ? '?' : '#$pr',
      'error': msg.length > 300 ? '${msg.substring(0, 300)}…' : msg,
    });
    _ctrl.text = prefill;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('adminDev.healthAlert.fixPrefilled'.tr())),
      );
    }
  }

  // API-Key anlegen/bearbeiten (Service + Key + optionales Ablaufdatum).
  Future<void> _editApiKey({Map<String, dynamic>? existing}) async {
    final serviceCtrl =
        TextEditingController(text: existing?['service'] as String? ?? '');
    final keyCtrl = TextEditingController();
    DateTime? expiry = existing?['expires_at'] != null
        ? DateTime.tryParse(existing!['expires_at'] as String)
        : null;
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          backgroundColor: AppColors.lightSurface,
          title: Text('adminDev.apiKeys.editTitle'.tr(),
              style:
                  AppTypography.display(size: 16, color: AppColors.lightInk)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: serviceCtrl,
                enabled: existing == null,
                style: AppTypography.body(size: 13, color: AppColors.lightInk),
                decoration: InputDecoration(
                  labelText: 'adminDev.apiKeys.service'.tr(),
                  hintText: 'tankerkoenig, openrouteservice …',
                  hintStyle:
                      AppTypography.body(size: 11, color: AppColors.lightMute),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: keyCtrl,
                obscureText: true,
                style: AppTypography.body(size: 13, color: AppColors.lightInk),
                decoration: InputDecoration(
                  labelText: existing == null
                      ? 'adminDev.apiKeys.key'.tr()
                      : 'adminDev.apiKeys.keyReplace'.tr(),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                const Icon(LucideIcons.calendarClock,
                    size: 14, color: AppColors.lightMute),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    expiry == null
                        ? 'adminDev.apiKeys.noExpiry'.tr()
                        : '${expiry!.day}.${expiry!.month}.${expiry!.year}',
                    style: AppTypography.body(
                        size: 12, color: AppColors.lightInkSoft),
                  ),
                ),
                TextButton(
                  onPressed: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: expiry ?? now.add(const Duration(days: 365)),
                      firstDate: now,
                      lastDate: now.add(const Duration(days: 3650)),
                    );
                    if (picked != null) setLocal(() => expiry = picked);
                  },
                  child: Text('adminDev.apiKeys.setExpiry'.tr()),
                ),
                if (expiry != null)
                  IconButton(
                    onPressed: () => setLocal(() => expiry = null),
                    icon: const Icon(LucideIcons.x, size: 14),
                    color: AppColors.lightMute,
                  ),
              ]),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('common.cancel'.tr()),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('common.save'.tr()),
            ),
          ],
        ),
      ),
    );
    final service = serviceCtrl.text.trim();
    final key = keyCtrl.text.trim();
    if (saved != true || !mounted) return;
    if (service.isEmpty || key.isEmpty) {
      AppSnackBar.error(context, 'adminDev.apiKeys.required'.tr());
      return;
    }
    final res = await AiInsightsRepository.setApiKey(
      service: service,
      apiKey: key,
      expiresAtIso: expiry?.toUtc().toIso8601String(),
    );
    if (!mounted) return;
    if (res['ok'] == true) {
      AppSnackBar.success(context, 'common.created'.tr());
      await _loadApiKeys();
    } else {
      _showError(res['error'] as String?);
    }
  }

  Future<void> _deleteApiKey(String service) async {
    final res = await AiInsightsRepository.deleteApiKey(service);
    if (!mounted) return;
    if (res['ok'] == true) {
      await _loadApiKeys();
    } else {
      _showError(res['error'] as String?);
    }
  }

  Future<void> _loadSchedules() async {
    final rows = await AiInsightsRepository.fetchDevSchedules();
    if (!mounted) return;
    setState(() => _schedules = rows);
  }

  // ── Modul-Intelligenz ──────────────────────────────────────────────────────

  bool get _moduleScanning {
    final s = _moduleScan?['status'] as String?;
    return s == 'queued' || s == 'running';
  }

  Future<void> _loadModuleInsights({bool silent = false}) async {
    if (!silent) setState(() => _moduleLoading = true);
    final res = await AiInsightsRepository.fetchModuleInsights();
    if (!mounted) return;
    _applyUpdate(silent, () {
      _moduleInsights = ((res['insights'] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final s = res['scan'];
      if (s != null) _moduleScan = Map<String, dynamic>.from(s as Map);
      _moduleLoading = false;
    });
  }

  Future<void> _startModuleScan() async {
    final res = await AiInsightsRepository.startModuleScan();
    if (!mounted) return;
    if (res['ok'] == true) {
      AppSnackBar.info(context, 'adminDev.modules.scanStarted'.tr());
      await _loadModuleInsights(silent: true);
    } else {
      AppSnackBar.error(context, 'adminDev.modules.scanFailed'.tr());
    }
  }

  Future<void> _acceptModuleInsight(String id) async {
    setState(() => _busyModuleInsights.add(id));
    final res = await AiInsightsRepository.acceptModuleInsight(id);
    if (!mounted) return;
    setState(() => _busyModuleInsights.remove(id));
    if (res['ok'] == true) {
      setState(() => _moduleInsights =
          _moduleInsights.where((i) => i['id'] != id).toList());
      AppSnackBar.success(context, 'adminDev.modules.acceptedOk'.tr());
      await _refresh(silent: true);
    } else {
      AppSnackBar.error(context, 'adminDev.modules.actionFailed'.tr());
    }
  }

  Future<void> _dismissModuleInsight(String id) async {
    setState(() => _busyModuleInsights.add(id));
    final res = await AiInsightsRepository.dismissModuleInsight(id);
    if (!mounted) return;
    setState(() {
      _busyModuleInsights.remove(id);
      if (res['ok'] == true) {
        _moduleInsights = _moduleInsights.where((i) => i['id'] != id).toList();
      }
    });
    if (res['ok'] == true) {
      AppSnackBar.success(context, 'adminDev.modules.dismissedOk'.tr());
    }
  }

  // Wiederkehrenden Auftrag anlegen/bearbeiten (Dialog).
  Future<void> _editSchedule({Map<String, dynamic>? existing}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ScheduleSheet(existing: existing),
    );
    if (saved == true) await _loadSchedules();
  }

  Future<void> _toggleSchedule(String id, bool enabled) async {
    await AiInsightsRepository.toggleDevSchedule(id, enabled);
    await _loadSchedules();
  }

  Future<void> _deleteSchedule(String id) async {
    final res = await AiInsightsRepository.deleteDevSchedule(id);
    if (!mounted) return;
    if (res['ok'] == true) {
      setState(() => _schedules =
          _schedules.where((s) => s['id'] != id).toList());
    }
  }

  // Gemergte Änderung zurückrollen (Revert-PR → OTA).
  Future<void> _rollbackTask(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('adminDev.rollback.confirmTitle'.tr()),
        content: Text('adminDev.rollback.confirmBody'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade600),
            child: Text('adminDev.rollback.confirm'.tr()),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _deletingTasks.add(id));
    final res = await AiInsightsRepository.rollbackDevTask(id);
    if (!mounted) return;
    setState(() => _deletingTasks.remove(id));
    if (res['ok'] == true) {
      await _refresh(silent: true);
    } else {
      AppSnackBar.error(context, 'adminDev.rollback.failed'.tr());
    }
  }

  // Notiz anlegen oder bearbeiten (Dialog mit Textfeld).
  Future<void> _editNote({Map<String, dynamic>? existing}) async {
    final ctrl = TextEditingController(
        text: existing?['content'] as String? ?? '');
    final content = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(existing == null
            ? 'adminDev.notes.add'.tr()
            : 'adminDev.notes.edit'.tr()),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 6,
          minLines: 3,
          decoration: InputDecoration(
            hintText: 'adminDev.notes.placeholder'.tr(),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            child: Text('common.save'.tr()),
          ),
        ],
      ),
    );
    if (content == null || content.isEmpty) return;
    final res = await AiInsightsRepository.saveDevNote(
        id: existing?['id'] as String?, content: content);
    if (!mounted) return;
    if (res['ok'] == true) {
      await _loadNotes();
    } else {
      AppSnackBar.error(context, 'adminDev.notes.saveFailed'.tr());
    }
  }

  Future<void> _deleteNote(String id) async {
    final res = await AiInsightsRepository.deleteDevNote(id);
    if (!mounted) return;
    if (res['ok'] == true) {
      setState(() => _notes = _notes.where((n) => n['id'] != id).toList());
    }
  }

  // Notiz „senden": macht die Notiz direkt zum Auftrag (über den normalen
  // Bestätigungs-Flow mit Ja/Nein). Nach erfolgreicher Auftragserstellung wird
  // die Notiz automatisch aus dem Backlog gelöscht. Bricht der Admin im
  // Bestätigungs-Sheet ab, bleibt die Notiz erhalten.
  Future<void> _sendNote(String id, String content) async {
    if (content.trim().isEmpty || _sending) return;
    setState(() => _notesExpanded = false);
    _pendingNoteId = id;
    await _send(content);
  }

  String get _placeholder {
    switch (_builtinCategory) {
      case _DevCategory.ui:
        return 'adminDev.placeholders.ui'.tr();
      case _DevCategory.feature:
        return 'adminDev.placeholders.feature'.tr();
      case _DevCategory.bug:
        return 'adminDev.placeholders.bug'.tr();
      case _DevCategory.performance:
        return 'adminDev.placeholders.performance'.tr();
      case _DevCategory.i18n:
        return 'adminDev.placeholders.i18n'.tr();
      case _DevCategory.database:
        return 'adminDev.placeholders.database'.tr();
      case _DevCategory.security:
        return 'adminDev.placeholders.security'.tr();
      case _DevCategory.config:
        return 'adminDev.placeholders.config'.tr();
      default:
        return 'adminDev.placeholder'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Computed once per setState-rebuild; used by TabBar badge + suggestionsTab.
    final visible = _visibleSuggestions;
    return DashboardScaffold(
      title: 'adminDev.title'.tr(),
      currentRoute: '/dashboard/admin/dev-agent',
      body: SafeArea(
        child: Column(
          children: [
            _GodmodeHeader(),
            // (b) Only _StatusBar listens to _pollRev; stilles Polling baut
            // NUR diesen schmalen Widget neu — TabBar + TabBarView bleiben
            // unangetastet. _visibleSuggestions wird direkt im Builder
            // ausgewertet, damit der Zähler auch bei silent-Polls aktuell ist.
            ValueListenableBuilder<int>(
              valueListenable: _pollRev,
              builder: (context, _, __) => _StatusBar(
                activeTasks: _activeTaskCount,
                openSuggestions: _visibleSuggestions.length,
                openAlerts: _healthAlerts.length,
                lastDelivered: _changelog.isNotEmpty
                    ? (_changelog.first['title'] as String?)
                    : null,
              ),
            ),
            // TabBar rebuildet nur bei setState (Datenänderung), nicht bei
            // jedem Poll-Tick.
            TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelColor: AppColors.teal,
              unselectedLabelColor: AppColors.lightMute,
              indicatorColor: AppColors.teal,
              labelStyle: AppTypography.body(size: 12, weight: FontWeight.w700),
              tabs: [
                Tab(text: 'adminDev.tabs.overview'.tr()),
                Tab(
                  text: 'adminDev.tabs.tasks'.tr() +
                      (_tasks.isNotEmpty ? ' (${_tasks.length})' : ''),
                ),
                Tab(
                  text: 'adminDev.tabs.suggestions'.tr() +
                      (visible.isNotEmpty ? ' (${visible.length})' : ''),
                ),
                Tab(text: 'adminDev.tabs.roadmap'.tr()),
                Tab(text: 'adminDev.tabs.settings'.tr()),
              ],
            ),
            // (a) Builder-Wrapper: TabBarView baut nur den sichtbaren Tab
            // (+ direkten Nachbarn) — alle anderen _xTab()-Methoden werden
            // NICHT aufgerufen bis der jeweilige Tab aktiv wird.
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        Builder(builder: (_) => _overviewTab()),
                        Builder(builder: (_) => _tasksTab()),
                        Builder(builder: (_) => _suggestionsTab(visible)),
                        Builder(builder: (_) => _roadmapTab()),
                        Builder(builder: (_) => _settingsTab()),
                      ],
                    ),
            ),
            if (_selectionMode && _selected.isNotEmpty)
              _BatchBar(
                count: _selected.length,
                busy: _batchBusy,
                onAccept: _acceptSelected,
                onReject: _rejectSelected,
              ),
            _InputBar(
              ctrl: _ctrl,
              sending: _sending,
              placeholder: _placeholder,
              onSend: _send,
              images: _pendingImages,
              onAttach: _pickImages,
              onRemoveImage: _removeImage,
              awaitReview: _awaitReview,
              onToggleReview: (v) => setState(() => _awaitReview = v),
              wantScreens: _wantScreens,
              onToggleScreens: (v) => setState(() => _wantScreens = v),
              planMode: _planMode,
              onTogglePlan: (v) => setState(() => _planMode = v),
              onTemplate: (t) {
                _ctrl.text = t;
                _ctrl.selection = TextSelection.collapsed(offset: t.length);
              },
              existingInstructions: _tasks
                  .map((t) => t['instruction'] as String? ?? '')
                  .where((s) => s.isNotEmpty)
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  // Gemeinsames Pull-to-Refresh-Gerüst für jeden Tab.
  Widget _refreshable(List<Widget> children) {
    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: () async {
        await _refresh();
        await _loadSuggestions(silent: true);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        children: children,
      ),
    );
  }

  // Wie _refreshable, aber lazy via ListView.builder — baut nur sichtbare
  // Items. Für lange Listen (Aufträge/Vorschläge) statt eager '...map()'.
  Widget _refreshableBuilder({
    required int itemCount,
    required IndexedWidgetBuilder itemBuilder,
  }) {
    return RefreshIndicator(
      color: AppColors.teal,
      onRefresh: () async {
        await _refresh();
        await _loadSuggestions(silent: true);
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        itemCount: itemCount,
        itemBuilder: itemBuilder,
      ),
    );
  }

  // ── Tab: Übersicht ─────────────────────────────────────────────────────────
  Widget _overviewTab() {
    final nextUp = _visibleSuggestions.take(3).toList();
    return _refreshable([
      if (_healthAlerts.isNotEmpty) ...[
        _HealthAlertsCard(
          alerts: _healthAlerts,
          busyIds: _busyAlerts,
          onAcknowledge: (id) => _setAlertStatus(id, 'acknowledged'),
          onResolve: (id) => _setAlertStatus(id, 'resolved'),
          onFix: _fixFromAlert,
        ),
        const SizedBox(height: 10),
      ],
      if (nextUp.isNotEmpty) ...[
        _NextUpCard(
          suggestions: nextUp,
          busyIds: _busySuggestions,
          onAccept: _acceptWithEdit,
          onSeeAll: () => _tabController.animateTo(2),
        ),
        const SizedBox(height: 10),
      ],
      _HealthCard(
        metrics: _metrics,
        expanded: _metricsExpanded,
        onToggle: () {
          setState(() => _metricsExpanded = !_metricsExpanded);
          _saveUiPrefs();
        },
      ),
      const SizedBox(height: 10),
      _ModuleIntelligenceCard(
        insights: _moduleInsights,
        scan: _moduleScan,
        expanded: _moduleExpanded,
        loading: _moduleLoading,
        busyIds: _busyModuleInsights,
        onToggle: () {
          setState(() => _moduleExpanded = !_moduleExpanded);
          _saveUiPrefs();
        },
        onScan: _startModuleScan,
        onAccept: _acceptModuleInsight,
        onDismiss: _dismissModuleInsight,
      ),
      const SizedBox(height: 10),
      if (_moduleHealth.isNotEmpty) ...[
        _ModuleHealthCard(
          modules: _moduleHealth,
          expanded: _moduleHealthExpanded,
          onToggle: () {
            setState(() => _moduleHealthExpanded = !_moduleHealthExpanded);
            _saveUiPrefs();
          },
        ),
        const SizedBox(height: 10),
      ],
      if (_tasks.isEmpty && _suggestions.isEmpty) _EmptyHint(),
      const SizedBox(height: 12),
    ]);
  }

  // ── Tab: Aufträge ───────────────────────────────────────────────────────────
  Widget _tasksTab() {
    if (_tasks.isEmpty) {
      return _refreshableBuilder(
        itemCount: 2,
        itemBuilder: (_, i) =>
            i == 0 ? _EmptyHint() : const SizedBox(height: 12),
      );
    }
    // [0] = Section-Label, [1..n] = Auftrags-Karten, [n+1] = Bottom-Spacing.
    return _refreshableBuilder(
      itemCount: _tasks.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) {
          return _SectionLabel(
            icon: LucideIcons.gitPullRequest,
            label: 'adminDev.tasksLabel'.tr(),
            count: _tasks.length,
            trailing: _doneCount > 0
                ? _ClearTasksButton(busy: _clearingTasks, onTap: _clearTasks)
                : null,
          );
        }
        if (i <= _tasks.length) return _taskCardFor(_tasks[i - 1]);
        return const SizedBox(height: 12);
      },
    );
  }

  // ── Tab: Vorschläge ─────────────────────────────────────────────────────────
  Widget _suggestionsTab(List<Map<String, dynamic>> visible) {
    // Feste Kopf-Items, dann lazy die (potenziell langen) Vorschlags-Karten.
    final leading = <Widget>[
      _CategoryRow(
        selectedKey: _categoryKey,
        dynamicCategories: _categories,
        onSelect: (key) {
          setState(() => _categoryKey = key);
          _loadSuggestions();
        },
      ),
      const SizedBox(height: 10),
      _LiveScanCard(
        scanning: _scanning,
        scan: _scan,
        loading: _suggestionsLoading,
        onScan: _startScan,
      ),
      const SizedBox(height: 10),
    ];
    final trailing = <Widget>[];
    final cards = _suggestions.isNotEmpty
        ? visible
        : const <Map<String, dynamic>>[];
    if (_suggestions.isNotEmpty) {
      leading.addAll([
        _SuggestionsHeader(
          count: visible.length,
          selectionMode: _selectionMode,
          selectedCount: _selected.length,
          onToggleMode: _toggleSelectionMode,
          onSelectAll: _selectAllVisible,
        ),
        _SeverityRow(
          selected: _severity,
          onSelect: (s) => setState(() => _severity = s),
        ),
        const SizedBox(height: 8),
      ]);
      trailing.add(const SizedBox(height: 14));
    } else {
      leading.add(_EmptyHint());
    }
    trailing.add(const SizedBox(height: 12));

    return _refreshableBuilder(
      itemCount: leading.length + cards.length + trailing.length,
      itemBuilder: (context, i) {
        if (i < leading.length) return leading[i];
        final ci = i - leading.length;
        if (ci < cards.length) {
          final s = cards[ci];
          return _SuggestionCard(
            suggestion: s,
            categoryLabel:
                _categoryLabel(s['category'] as String? ?? 'feature'),
            busy: _busySuggestions.contains(s['id'] as String?),
            selectionMode: _selectionMode,
            selected: _selected.contains(s['id'] as String?),
            onToggleSelect: _toggleSelected,
            onAccept: _acceptWithEdit,
            onReject: _reject,
          );
        }
        return trailing[ci - cards.length];
      },
    );
  }

  // ── Tab: Roadmap ─────────────────────────────────────────────────────────────
  Widget _roadmapTab() {
    return _refreshable([
      _RoadmapCard(
        epics: _epics,
        expanded: true,
        onToggle: () {},
        onAdd: () => _editEpic(),
        onEdit: (e) => _editEpic(existing: e),
        onDelete: _deleteEpic,
        onNewTask: _newTaskInEpic,
        colorOf: _epicColor,
      ),
      const SizedBox(height: 12),
    ]);
  }

  // ── Tab: Einstellungen ───────────────────────────────────────────────────────
  Widget _settingsTab() {
    return _refreshable([
      _AutopilotCard(
        enabled: _autopilotEnabled,
        busy: _autopilotBusy,
        onChanged: _toggleAutopilot,
      ),
      const SizedBox(height: 10),
      _SchedulesCard(
        schedules: _schedules,
        expanded: _schedulesExpanded,
        onToggle: () {
          setState(() => _schedulesExpanded = !_schedulesExpanded);
          _saveUiPrefs();
        },
        onAdd: () => _editSchedule(),
        onEdit: (s) => _editSchedule(existing: s),
        onToggleEnabled: _toggleSchedule,
        onDelete: _deleteSchedule,
      ),
      const SizedBox(height: 10),
      _NotesCard(
        notes: _notes,
        expanded: _notesExpanded,
        onToggle: () {
          setState(() => _notesExpanded = !_notesExpanded);
          _saveUiPrefs();
        },
        onAdd: () => _editNote(),
        onEdit: (n) => _editNote(existing: n),
        onDelete: (id) => _deleteNote(id),
        onUse: (id, c) => _sendNote(id, c),
      ),
      const SizedBox(height: 10),
      _ChangelogCard(
        entries: _changelog,
        expanded: _changelogExpanded,
        onToggle: () {
          setState(() => _changelogExpanded = !_changelogExpanded);
          _saveUiPrefs();
        },
      ),
      const SizedBox(height: 10),
      _ApiKeysCard(
        keys: _apiKeys,
        expanded: _apiKeysExpanded,
        onToggle: () {
          setState(() => _apiKeysExpanded = !_apiKeysExpanded);
          _saveUiPrefs();
        },
        onAdd: () => _editApiKey(),
        onEdit: (k) => _editApiKey(existing: k),
        onDelete: _deleteApiKey,
      ),
      const SizedBox(height: 12),
    ]);
  }

  // Baut eine Auftragskarte mit allen kontextabhängigen Aktionen.
  Widget _taskCardFor(Map<String, dynamic> t) {
    final id = t['id'] as String?;
    final status = t['status'] as String?;
    final canDelete = _deletable(status) && id != null;
    final canCancel = id != null &&
        (status == 'queued' ||
            status == 'running' ||
            status == 'pr_open' ||
            status == 'awaiting_review');
    final isReview = status == 'awaiting_review' && id != null;
    final canRetry = id != null &&
        (status == 'failed' ||
            status == 'no_changes' ||
            status == 'patch_failed');
    final canRollback = id != null &&
        (status == 'merged' || status == 'live') &&
        (t['merge_commit_sha'] as String?) != null &&
        (t['origin'] as String?) != 'rollback';
    final canRefine =
        id != null && (status == 'pr_open' || status == 'awaiting_review');
    return _TaskCard(
      task: t,
      busy: _deletingTasks.contains(id),
      onDelete: canDelete ? () => _deleteTask(id) : null,
      onCancel: canCancel ? () => _cancelTask(id) : null,
      onMerge: isReview ? () => _mergeTask(id) : null,
      onShowDiff: id != null && t['pr_number'] != null
          ? () => _showDiff(id)
          : null,
      onRetry:
          canRetry ? () => _retryTask(t['instruction'] as String? ?? '') : null,
      onRollback: canRollback ? () => _rollbackTask(id) : null,
      onRefine: canRefine ? () => _refineTask(id) : null,
      onDetails: () => _showTaskDetail(t),
    );
  }

  // Öffnet die Detailansicht eines Auftrags (alles auf einen Blick).
  void _showTaskDetail(Map<String, dynamic> t) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskDetailSheet(task: t),
    );
  }
}

// ── „Was als Nächstes?" ──────────────────────────────────────────────────────
// KI-Empfehlung: die Top-Quick-Wins (höchster Nutzen, kleinster Aufwand) ganz
// oben auf der Übersicht — mit Ein-Klick-Umsetzung.
class _NextUpCard extends StatelessWidget {
  const _NextUpCard({
    required this.suggestions,
    required this.busyIds,
    required this.onAccept,
    required this.onSeeAll,
  });
  final List<Map<String, dynamic>> suggestions;
  final Set<String> busyIds;
  final ValueChanged<Map<String, dynamic>> onAccept;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.teal.withValues(alpha: 0.10),
            AppColors.amber.withValues(alpha: 0.06),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.sparkles, size: 16, color: AppColors.teal),
              const SizedBox(width: 8),
              Expanded(
                child: Text('adminDev.nextUp.title'.tr(),
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.lightInk,
                        weight: FontWeight.w800)),
              ),
              InkWell(
                onTap: onSeeAll,
                child: Text('adminDev.nextUp.seeAll'.tr(),
                    style: AppTypography.label(size: 11, color: AppColors.teal)),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text('adminDev.nextUp.subtitle'.tr(),
              style: AppTypography.caption(color: AppColors.lightMute)),
          const SizedBox(height: 10),
          ...suggestions.map((s) {
            final id = s['id'] as String? ?? '';
            final busy = busyIds.contains(id);
            final title = (s['title'] as String?)?.trim().isNotEmpty == true
                ? s['title'] as String
                : (s['instruction'] as String? ?? '');
            final impact = (s['impact'] as num?)?.toInt();
            final effort = (s['effort'] as num?)?.toInt();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                                size: 12, color: AppColors.lightInk)),
                        if (impact != null && effort != null)
                          Text(
                            'adminDev.impactEffort'.tr(namedArgs: {
                              'impact': '$impact',
                              'effort': '$effort',
                            }),
                            style: AppTypography.label(
                                size: 9, color: AppColors.lightMute),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : FilledButton(
                          onPressed: () => onAccept(s),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            minimumSize: const Size(0, 30),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text('adminDev.nextUp.do'.tr(),
                              style: AppTypography.label(
                                  size: 11, color: Colors.white)),
                        ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

// ── Status-Leiste ──────────────────────────────────────────────────────────
// Kompakter Überblick ganz oben: aktive Aufträge, offene Vorschläge, offene
// Alarme und die zuletzt ausgelieferte Änderung — alles auf einen Blick.
class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.activeTasks,
    required this.openSuggestions,
    required this.openAlerts,
    required this.lastDelivered,
  });
  final int activeTasks;
  final int openSuggestions;
  final int openAlerts;
  final String? lastDelivered;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: const BoxDecoration(
        color: AppColors.lightElevated,
        border: Border(
          bottom: BorderSide(color: AppColors.lightLine),
        ),
      ),
      child: Row(
        children: [
          _StatChip(
            icon: LucideIcons.loader,
            label: 'adminDev.statusBar.active'.tr(),
            value: '$activeTasks',
            color: activeTasks > 0 ? AppColors.teal : AppColors.lightMute,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: LucideIcons.lightbulb,
            label: 'adminDev.statusBar.suggestions'.tr(),
            value: '$openSuggestions',
            color: openSuggestions > 0 ? AppColors.amber : AppColors.lightMute,
          ),
          const SizedBox(width: 8),
          _StatChip(
            icon: LucideIcons.alertTriangle,
            label: 'adminDev.statusBar.alerts'.tr(),
            value: '$openAlerts',
            color: openAlerts > 0 ? AppColors.herzrot : AppColors.lightMute,
          ),
          if (lastDelivered != null && lastDelivered!.isNotEmpty) ...[
            const SizedBox(width: 12),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(LucideIcons.gitMerge,
                      size: 12, color: AppColors.leben),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      lastDelivered!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: AppTypography.caption(color: AppColors.lightMute),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(value,
              style: AppTypography.label(size: 12, color: color)),
          const SizedBox(width: 4),
          Text(label,
              style: AppTypography.label(size: 10, color: AppColors.lightMute)),
        ],
      ),
    );
  }
}

// ── Godmode Header ────────────────────────────────────────────────────────────

class _GodmodeHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.teal.withValues(alpha: 0.10),
            AppColors.teal.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
            bottom: BorderSide(color: AppColors.teal.withValues(alpha: 0.12))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.teal.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child:
                const Icon(LucideIcons.zap, size: 16, color: AppColors.teal),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'adminDev.subtitle'.tr(),
              style: AppTypography.body(size: 12, color: AppColors.lightMute),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'GODMODE',
              style: AppTypography.body(
                  size: 10, color: Colors.white, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Category Row ──────────────────────────────────────────────────────────────

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.selectedKey,
    required this.dynamicCategories,
    required this.onSelect,
  });
  final String selectedKey;
  final List<Map<String, dynamic>> dynamicCategories;
  final void Function(String) onSelect;

  @override
  Widget build(BuildContext context) {
    // Eigene Kategorien, die nicht schon Built-in sind (selbstlernend).
    final builtinKeys = _DevCategory.values.map((c) => c.name).toSet();
    final extras = dynamicCategories
        .where((c) => !builtinKeys.contains(c['key']))
        .toList();

    return Container(
      height: 46,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: [
          ..._DevCategory.values.map((cat) => _chip(
                key: cat.name,
                label: cat.i18nKey.tr(),
                icon: cat.icon,
                active: cat.name == selectedKey,
                isNew: false,
              )),
          ...extras.map((c) => _chip(
                key: c['key'] as String? ?? '',
                label: (c['label'] as String?) ?? (c['key'] as String? ?? ''),
                icon: LucideIcons.sparkles,
                active: c['key'] == selectedKey,
                isNew: true,
              )),
        ],
      ),
    );
  }

  Widget _chip({
    required String key,
    required String label,
    required IconData icon,
    required bool active,
    required bool isNew,
  }) {
    return GestureDetector(
      onTap: () => onSelect(key),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: active ? AppColors.teal : AppColors.lightElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? AppColors.teal
                : (isNew
                    ? AppColors.teal.withValues(alpha: 0.4)
                    : AppColors.lightLine),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 12, color: active ? Colors.white : AppColors.lightMute),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTypography.body(
                size: 12,
                color: active ? Colors.white : AppColors.lightInk,
                weight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Severity Row (Filter) ───────────────────────────────────────────────────

class _SeverityRow extends StatelessWidget {
  const _SeverityRow({required this.selected, required this.onSelect});
  final String selected;
  final void Function(String) onSelect;

  Color _color(String sev) {
    switch (sev) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
        return Colors.deepOrange.shade400;
      case 'medium':
        return AppColors.amber;
      case 'low':
        return AppColors.lightMute;
      default:
        return AppColors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: _severityFilters.map((sev) {
          final active = sev == selected;
          final c = _color(sev);
          final label = sev == 'all'
              ? 'adminDev.selectAll'.tr()
              : 'adminDev.severity.$sev'.tr();
          return GestureDetector(
            onTap: () => onSelect(sev),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: active ? c.withValues(alpha: 0.14) : AppColors.lightElevated,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active ? c : AppColors.lightLine,
                ),
              ),
              child: Text(
                label,
                style: AppTypography.body(
                  size: 11,
                  color: active ? c : AppColors.lightMute,
                  weight: active ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Live Scan Card ──────────────────────────────────────────────────────────

// ── Notizen / Backlog (ausklappbar) ─────────────────────────────────────────

class _NotesCard extends StatelessWidget {
  const _NotesCard({
    required this.notes,
    required this.expanded,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onUse,
  });
  final List<Map<String, dynamic>> notes;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(String) onDelete;
  final void Function(String id, String content) onUse;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(LucideIcons.scrollText,
                      size: 18, color: AppColors.trust),
                  const SizedBox(width: 10),
                  Text(
                    'adminDev.notes.title'.tr(),
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.lightInk,
                        weight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.lightRaised,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${notes.length}',
                        style: AppTypography.body(
                            size: 10, color: AppColors.lightMute)),
                  ),
                  const Spacer(),
                  Icon(
                    expanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 18,
                    color: AppColors.lightMute,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            if (notes.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Text('adminDev.notes.empty'.tr(),
                    style: AppTypography.body(
                        size: 12, color: AppColors.lightMute)),
              )
            else
              ...notes.map((n) => _NoteTile(
                    note: n,
                    onEdit: () => onEdit(n),
                    onDelete: () => onDelete(n['id'] as String),
                    onUse: () => onUse(
                          n['id'] as String? ?? '',
                          n['content'] as String? ?? '',
                        ),
                  )),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text('adminDev.notes.add'.tr()),
                style: TextButton.styleFrom(foregroundColor: AppColors.teal),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.onEdit,
    required this.onDelete,
    required this.onUse,
  });
  final Map<String, dynamic> note;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    final content = note['content'] as String? ?? '';
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.lightElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content,
            style: AppTypography.body(size: 12, color: AppColors.lightInk),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                onPressed: onEdit,
                icon: const Icon(LucideIcons.pencil, size: 15),
                color: AppColors.lightMute,
                visualDensity: VisualDensity.compact,
                tooltip: 'adminDev.notes.edit'.tr(),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(LucideIcons.trash2, size: 15),
                color: AppColors.lightMute,
                visualDensity: VisualDensity.compact,
                tooltip: 'common.delete'.tr(),
              ),
              TextButton.icon(
                onPressed: onUse,
                icon: const Icon(LucideIcons.send, size: 14),
                label: Text('common.send'.tr()),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LiveScanCard extends StatefulWidget {
  const _LiveScanCard({
    required this.scanning,
    required this.scan,
    required this.loading,
    required this.onScan,
  });
  final bool scanning;
  final Map<String, dynamic>? scan;
  final bool loading;
  final VoidCallback onScan;

  @override
  State<_LiveScanCard> createState() => _LiveScanCardState();
}

class _LiveScanCardState extends State<_LiveScanCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac;
  // (c) Einmalig in initState gecacht — nie neu alloziert während build().
  late final Animation<double> _fadePulse; // Scan-Icon: 0.35 → 1.0
  late final Animation<double> _fadeDot; // Fortschritts-Dot: 0.3 → 1.0
  Timer? _tick; // sekündlicher Tick für die Laufzeit-Anzeige

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    );
    _fadePulse = Tween<double>(begin: 0.35, end: 1.0).animate(_ac);
    _fadeDot = Tween<double>(begin: 0.3, end: 1.0).animate(_ac);
    // Pulse-Animation + Sekundentimer NUR bei aktivem Scan — sonst läuft der
    // Ticker (und damit ein Frame-Callback pro Vsync) dauerhaft im Leerlauf.
    _syncScanState();
  }

  @override
  void didUpdateWidget(covariant _LiveScanCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scanning != widget.scanning) _syncScanState();
  }

  // Startet/stoppt Pulse-Animation und Laufzeit-Timer passend zum Scan-Status.
  void _syncScanState() {
    if (widget.scanning) {
      if (!_ac.isAnimating) _ac.repeat(reverse: true);
      _tick ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && widget.scanning) setState(() {});
      });
    } else {
      _ac.stop();
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    _tick?.cancel();
    super.dispose();
  }

  // Laufzeit seit Scan-Start als mm:ss (aus created_at).
  String _elapsed(Map<String, dynamic>? scan) {
    final raw = scan?['created_at'] as String?;
    if (raw == null) return '';
    final start = DateTime.tryParse(raw)?.toUtc();
    if (start == null) return '';
    final secs = DateTime.now().toUtc().difference(start.toUtc()).inSeconds;
    if (secs < 0) return '';
    final m = (secs ~/ 60).toString().padLeft(2, '0');
    final s = (secs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    final scanning = widget.scanning;
    final currentFile = scan?['current_file'] as String?;
    final phase = scan?['phase'] as String?;
    final analyzed = (scan?['analyzed_files'] as num?)?.toInt() ?? 0;
    final foundSoFar = (scan?['found_so_far'] as num?)?.toInt() ?? 0;
    final found = (scan?['found'] as num?)?.toInt() ?? 0;
    final isDone = (scan?['status'] as String?) == 'done';
    final elapsed = scanning ? _elapsed(scan) : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: scanning ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: AppColors.teal.withValues(alpha: scanning ? 0.35 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              scanning
                  ? FadeTransition(
                      opacity: _fadePulse,
                      child: const Icon(LucideIcons.scanLine,
                          size: 20, color: AppColors.teal),
                    )
                  : const Icon(LucideIcons.scanLine,
                      size: 20, color: AppColors.teal),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'adminDev.scanTitle'.tr(),
                      style: AppTypography.body(
                          size: 13,
                          color: AppColors.lightInk,
                          weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scanning
                          ? 'adminDev.scanWorking'.tr()
                          : (isDone
                              ? 'adminDev.lastScan'
                                  .tr(namedArgs: {'count': '$found'})
                              : 'adminDev.scanHint'.tr()),
                      style: AppTypography.body(
                          size: 11, color: AppColors.lightMute),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              if (scanning || widget.loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.teal),
                )
              else
                FilledButton.icon(
                  onPressed: widget.onScan,
                  icon: const Icon(LucideIcons.scanLine, size: 14),
                  label: Text('adminDev.scanButton'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
          // Live-Fortschritt: aktuelle Datei + Zähler.
          if (scanning) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.teal.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  FadeTransition(
                    opacity: _fadeDot,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.teal,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (currentFile != null && currentFile.isNotEmpty)
                          ? 'adminDev.scanAnalyzing'
                              .tr(namedArgs: {'file': currentFile})
                          : 'adminDev.scanWorking'.tr(),
                      style: AppTypography.body(
                          size: 11, color: AppColors.lightInk),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(LucideIcons.fileSearch,
                    size: 12, color: AppColors.lightMute),
                const SizedBox(width: 4),
                Text(
                  'adminDev.scanFilesRead'.tr(namedArgs: {'count': '$analyzed'}),
                  style:
                      AppTypography.body(size: 10, color: AppColors.lightMute),
                ),
                if (foundSoFar > 0) ...[
                  const SizedBox(width: 12),
                  const Icon(LucideIcons.sparkles,
                      size: 12, color: AppColors.teal),
                  const SizedBox(width: 4),
                  Text(
                    'adminDev.scanFoundSoFar'
                        .tr(namedArgs: {'count': '$foundSoFar'}),
                    style:
                        AppTypography.body(size: 10, color: AppColors.teal),
                  ),
                ],
                const Spacer(),
                if (elapsed.isNotEmpty) ...[
                  const Icon(LucideIcons.clock,
                      size: 12, color: AppColors.lightMute),
                  const SizedBox(width: 4),
                  Text(elapsed,
                      style: AppTypography.body(
                          size: 10, color: AppColors.lightMute)),
                ],
              ],
            ),
            const SizedBox(height: 6),
            // Aktuelle Phase + Beruhigungs-Hinweis (Audit dauert ein paar Min.).
            Text(
              (phase != null && phase.isNotEmpty)
                  ? 'adminDev.scanPhase'.tr(namedArgs: {'phase': phase})
                  : 'adminDev.scanLongHint'.tr(),
              style: AppTypography.body(size: 10, color: AppColors.lightMute),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Suggestions Header (mit Mehrfachauswahl-Toggle) ─────────────────────────

class _SuggestionsHeader extends StatelessWidget {
  const _SuggestionsHeader({
    required this.count,
    required this.selectionMode,
    required this.selectedCount,
    required this.onToggleMode,
    required this.onSelectAll,
  });
  final int count;
  final bool selectionMode;
  final int selectedCount;
  final VoidCallback onToggleMode;
  final VoidCallback onSelectAll;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Row(
        children: [
          const Icon(LucideIcons.sparkles, size: 14, color: AppColors.lightMute),
          const SizedBox(width: 6),
          Text(
            'adminDev.suggestions'.tr(),
            style: AppTypography.body(
                size: 12, color: AppColors.lightMute, weight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.lightRaised,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count',
                style:
                    AppTypography.body(size: 10, color: AppColors.lightMute)),
          ),
          const Spacer(),
          if (selectionMode)
            TextButton(
              onPressed: onSelectAll,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 30),
              ),
              child: Text('adminDev.selectAll'.tr(),
                  style: const TextStyle(fontSize: 12)),
            ),
          TextButton.icon(
            onPressed: onToggleMode,
            icon: Icon(
                selectionMode ? LucideIcons.x : LucideIcons.checkCircle2,
                size: 13),
            label: Text(
              selectionMode ? 'adminDev.cancel'.tr() : 'adminDev.select'.tr(),
              style: const TextStyle(fontSize: 12),
            ),
            style: TextButton.styleFrom(
              foregroundColor:
                  selectionMode ? AppColors.lightMute : AppColors.teal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 30),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(
      {required this.icon,
      required this.label,
      required this.count,
      this.trailing});
  final IconData icon;
  final String label;
  final int count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 2),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppColors.lightMute),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTypography.body(
                size: 12, color: AppColors.lightMute, weight: FontWeight.w600),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.lightRaised,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count',
                style:
                    AppTypography.body(size: 10, color: AppColors.lightMute)),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

// Kleiner „Abgeschlossene löschen"-Button im Aufträge-Header.
class _ClearTasksButton extends StatelessWidget {
  const _ClearTasksButton({required this.busy, required this.onTap});
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: busy ? null : onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              const SizedBox(
                width: 11,
                height: 11,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.lightMute),
              )
            else
              const Icon(LucideIcons.trash2, size: 12, color: AppColors.lightMute),
            const SizedBox(width: 4),
            Text('adminDev.clearDone'.tr(),
                style:
                    AppTypography.body(size: 11, color: AppColors.lightMute)),
          ],
        ),
      ),
    );
  }
}

// ── Suggestion Card ───────────────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.categoryLabel,
    required this.busy,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelect,
    required this.onAccept,
    required this.onReject,
  });
  final Map<String, dynamic> suggestion;
  final String categoryLabel;
  final bool busy;
  final bool selectionMode;
  final bool selected;
  final void Function(String) onToggleSelect;
  final void Function(Map<String, dynamic>) onAccept;
  final void Function(String) onReject;

  @override
  Widget build(BuildContext context) {
    final id = suggestion['id'] as String? ?? '';
    final title = suggestion['title'] as String? ?? '';
    final description = suggestion['description'] as String? ?? '';
    final reason = suggestion['reason'] as String?;
    final kind = suggestion['kind'] as String? ?? 'improvement';
    final severity = suggestion['severity'] as String? ?? 'medium';
    final fileHint = suggestion['file_hint'] as String?;
    final sevColor = _severityColor(severity);
    final kindColor = _kindColor(kind);
    final kindIcon = _kindIcon(kind);
    final impact = (suggestion['impact'] as num?)?.toInt();
    final effort = (suggestion['effort'] as num?)?.toInt();
    final quickWin =
        impact != null && effort != null && impact >= 4 && effort <= 2;

    final card = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? AppColors.teal.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: selected ? AppColors.teal : AppColors.lightLine),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (selectionMode) ...[
                Icon(
                  selected
                      ? LucideIcons.checkSquare
                      : LucideIcons.circle,
                  size: 18,
                  color: selected ? AppColors.teal : AppColors.lightMute,
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    // Typ-Marker zuerst (Bug/Neuerung/Verbesserung) mit Icon.
                    _KindBadge(
                        text: 'adminDev.kind.$kind'.tr(),
                        color: kindColor,
                        icon: kindIcon),
                    _Badge(text: categoryLabel, color: AppColors.teal),
                    _Badge(
                        text: 'adminDev.severity.$severity'.tr(),
                        color: sevColor),
                    if (quickWin)
                      _Badge(
                          text: 'adminDev.quickWin'.tr(),
                          color: AppColors.leben),
                    if (impact != null && effort != null)
                      _Badge(
                        text: 'adminDev.impactEffort'.tr(namedArgs: {
                          'impact': '$impact',
                          'effort': '$effort',
                        }),
                        color: AppColors.bronze,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: AppTypography.body(
                size: 13, color: AppColors.lightInk, weight: FontWeight.w600),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: AppTypography.body(size: 12, color: AppColors.lightMute),
            ),
          ],
          // „Warum" — leicht verständliche Begründung.
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.lightbulb,
                      size: 13, color: AppColors.amber),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: AppTypography.body(
                            size: 11, color: AppColors.lightInk),
                        children: [
                          TextSpan(
                            text: '${'adminDev.why'.tr()}: ',
                            style: AppTypography.body(
                                size: 11,
                                color: AppColors.lightInk,
                                weight: FontWeight.w700),
                          ),
                          TextSpan(text: reason),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (fileHint != null && fileHint.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(LucideIcons.scrollText,
                    size: 11, color: AppColors.lightMute),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    fileHint,
                    style: AppTypography.body(
                        size: 10, color: AppColors.lightMute),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          // Im Auswahlmodus keine Einzel-Buttons (Sammel-Aktion über die Leiste).
          if (!selectionMode) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => onAccept(suggestion),
                    icon: busy
                        ? const SizedBox(
                            width: 13,
                            height: 13,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(LucideIcons.check, size: 14),
                    label: Text('adminDev.accept'.tr()),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => onReject(id),
                  icon: const Icon(LucideIcons.x, size: 14),
                  label: Text('adminDev.reject'.tr()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.lightMute,
                    side: BorderSide(color: AppColors.lightLine),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    textStyle: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );

    if (!selectionMode) return card;
    return GestureDetector(
      onTap: () => onToggleSelect(id),
      child: card,
    );
  }

  Color _severityColor(String severity) {
    switch (severity) {
      case 'critical':
        return Colors.red.shade700;
      case 'high':
        return Colors.deepOrange.shade400;
      case 'medium':
        return AppColors.amber;
      default:
        return AppColors.lightMute;
    }
  }

  Color _kindColor(String kind) {
    switch (kind) {
      case 'bug':
        return Colors.red.shade700;
      case 'new':
        return Colors.indigo.shade400;
      default: // improvement
        return AppColors.teal;
    }
  }

  IconData _kindIcon(String kind) {
    switch (kind) {
      case 'bug':
        return LucideIcons.bug;
      case 'new':
        return LucideIcons.sparkles;
      default: // improvement
        return LucideIcons.settings;
    }
  }
}

// Typ-Marker mit Icon (Bug/Neuerung/Verbesserung).
class _KindBadge extends StatelessWidget {
  const _KindBadge(
      {required this.text, required this.color, required this.icon});
  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            text,
            style: AppTypography.body(
                size: 10, color: color, weight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style:
            AppTypography.body(size: 10, color: color, weight: FontWeight.w600),
      ),
    );
  }
}

// ── Batch-Aktionsleiste ──────────────────────────────────────────────────────

class _BatchBar extends StatelessWidget {
  const _BatchBar({
    required this.count,
    required this.busy,
    required this.onAccept,
    required this.onReject,
  });
  final int count;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.06),
        border: Border(top: BorderSide(color: AppColors.teal.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          Text(
            'adminDev.selectedCount'.tr(namedArgs: {'count': '$count'}),
            style: AppTypography.body(
                size: 12, color: AppColors.lightInk, weight: FontWeight.w600),
          ),
          const Spacer(),
          if (busy)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.teal),
            )
          else ...[
            OutlinedButton.icon(
              onPressed: onReject,
              icon: const Icon(LucideIcons.x, size: 14),
              label: Text('adminDev.reject'.tr()),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.lightMute,
                side: BorderSide(color: AppColors.lightLine),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onAccept,
              icon: const Icon(LucideIcons.check, size: 14),
              label: Text('adminDev.accept'.tr()),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                textStyle: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Empty Hint ────────────────────────────────────────────────────────────────

class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          const Icon(LucideIcons.bot, size: 40, color: AppColors.teal),
          const SizedBox(height: 10),
          Text(
            'adminDev.empty'.tr(),
            textAlign: TextAlign.center,
            style: AppTypography.body(size: 13, color: AppColors.lightMute),
          ),
        ],
      ),
    );
  }
}

// ── Task Card (mit Live-Pipeline) ───────────────────────────────────────────

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    this.onDelete,
    this.onCancel,
    this.onMerge,
    this.onShowDiff,
    this.onRetry,
    this.onRollback,
    this.onRefine,
    this.onDetails,
    this.busy = false,
  });
  final Map<String, dynamic> task;
  final VoidCallback? onDelete;
  final VoidCallback? onCancel;
  final VoidCallback? onMerge;
  final VoidCallback? onShowDiff;
  final VoidCallback? onRetry;
  final VoidCallback? onRollback;
  final VoidCallback? onRefine;
  final VoidCallback? onDetails;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final status = task['status'] as String? ?? 'queued';
    final ciStatus = task['ci_status'] as String?;
    final instruction = task['instruction'] as String? ?? '';
    final prUrl = task['pr_url'] as String?;
    final runUrl = task['run_url'] as String?;
    final ciRunUrl = task['ci_run_url'] as String?;
    final summary = task['summary'] as String?;
    final error = task['error'] as String?;
    final location = (task['location'] as String?)?.trim();
    final showLocation = location != null &&
        location.isNotEmpty &&
        !location.toLowerCase().startsWith('nicht sichtbar');
    final imageCount = (task['image_urls'] as List?)?.length ?? 0;
    final meta = _statusMeta(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lightLine),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(meta.icon, size: 15, color: meta.color),
              const SizedBox(width: 6),
              Text(
                'adminDev.status.$status'.tr(),
                style: AppTypography.body(
                    size: 12, color: meta.color, weight: FontWeight.w600),
              ),
              if (_modelShortLabel(task['model'] as String?) != null) ...[
                const SizedBox(width: 6),
                _Badge(
                  text: _modelShortLabel(task['model'] as String?)!,
                  color: AppColors.trust,
                ),
              ],
              // Retry-Zähler: sichtbar, sobald der Watchdog den Auftrag
              // mindestens einmal erneut angestoßen hat (max. 3 Versuche).
              if (((task['retry_count'] as num?)?.toInt() ?? 0) > 0) ...[
                const SizedBox(width: 6),
                _Badge(
                  text: 'adminDev.retryBadge'.tr(namedArgs: {
                    'n': '${(task['retry_count'] as num?)?.toInt() ?? 0}',
                  }),
                  color: AppColors.amber,
                ),
              ],
              if (imageCount > 0) ...[
                const SizedBox(width: 6),
                const Icon(LucideIcons.image, size: 12, color: AppColors.lightMute),
                const SizedBox(width: 2),
                Text('$imageCount',
                    style: AppTypography.body(
                        size: 11, color: AppColors.lightMute)),
              ],
              const Spacer(),
              if (_relativeTime(task['updated_at'] as String?) != null) ...[
                Text(
                  _relativeTime(task['updated_at'] as String?)!,
                  style: AppTypography.label(size: 10, color: AppColors.lightMute),
                ),
                const SizedBox(width: 6),
              ],
              if (onDetails != null) ...[
                InkWell(
                  onTap: onDetails,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(LucideIcons.maximize2,
                        size: 14, color: AppColors.lightMute),
                  ),
                ),
                const SizedBox(width: 6),
              ],
              if (busy)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.lightMute),
                )
              else if (onCancel != null)
                InkWell(
                  onTap: onCancel,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(LucideIcons.x,
                        size: 16, color: AppColors.lightMute),
                  ),
                )
              else if (onDelete != null)
                InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(8),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(LucideIcons.trash2,
                        size: 15, color: AppColors.lightMute),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          _PipelineStepper(status: status, ciStatus: ciStatus),
          const SizedBox(height: 10),
          Text(
            instruction,
            style: AppTypography.body(size: 13, color: AppColors.lightInk),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          // Multi-Step-Plan als Checkliste (wenn vorhanden). Bei 'merged' gelten
          // alle Schritte als erledigt.
          if (task['plan'] is List && (task['plan'] as List).isNotEmpty) ...[
            const SizedBox(height: 8),
            ...List.generate((task['plan'] as List).length, (i) {
              final step = (task['plan'] as List)[i].toString();
              final done = status == 'merged' || status == 'live';
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      done ? LucideIcons.checkCircle2 : LucideIcons.circle,
                      size: 13,
                      color: done ? AppColors.leben : AppColors.lightMute,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(step,
                          style: AppTypography.body(
                              size: 11, color: AppColors.lightMute)),
                    ),
                  ],
                ),
              );
            }),
          ],
          // Auto-Phasen: Parent zeigt Phasen-Fortschritt, Child zeigt sein
          // Phasen-Badge. (plan ist hier eine Map, nicht die Legacy-List.)
          if (task['plan'] is Map) ...[
            Builder(builder: (_) {
              final p = task['plan'] as Map;
              final phases = p['phases'];
              if (phases is List && phases.isNotEmpty) {
                final total = phases.length;
                final current = (p['current'] as num?)?.toInt() ?? 0;
                final allDone = status == 'merged' || status == 'live';
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(total, (i) {
                      final ph = phases[i];
                      final title = (ph is Map ? ph['title'] : null)?.toString() ??
                          'Phase ${i + 1}';
                      final done = allDone || i < current;
                      final active = !allDone && i == current;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              done
                                  ? LucideIcons.checkCircle2
                                  : active
                                      ? LucideIcons.loader
                                      : LucideIcons.circle,
                              size: 13,
                              color: done
                                  ? AppColors.leben
                                  : active
                                      ? AppColors.teal
                                      : AppColors.lightMute,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${'adminDev.phaseOf'.tr(namedArgs: {
                                      'n': '${i + 1}',
                                      'total': '$total',
                                    })} · $title',
                                style: AppTypography.body(
                                    size: 11,
                                    color: active
                                        ? AppColors.lightInk
                                        : AppColors.lightMute),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                );
              }
              final idx = (p['phase_index'] as num?)?.toInt();
              final ptot = (p['phase_total'] as num?)?.toInt();
              if (idx != null && ptot != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.layers,
                          size: 12, color: AppColors.teal),
                      const SizedBox(width: 5),
                      Text(
                        'adminDev.phaseOf'.tr(
                            namedArgs: {'n': '${idx + 1}', 'total': '$ptot'}),
                        style: AppTypography.body(
                            size: 11,
                            color: AppColors.teal,
                            weight: FontWeight.w600),
                      ),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            }),
          ],
          // Fundort: WO in der App die Änderung sichtbar ist (aus dem
          // "📍 Zu finden:"-Pflichtblock des Agent-PRs extrahiert).
          if (showLocation) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(LucideIcons.mapPin,
                    size: 12, color: AppColors.teal),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${'adminDev.location'.tr()}: $location',
                    style: AppTypography.body(
                        size: 11,
                        color: AppColors.teal,
                        weight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          if (summary != null && summary.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(summary,
                style:
                    AppTypography.body(size: 11, color: AppColors.lightMute)),
          ],
          if (error != null && error.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(error,
                style:
                    AppTypography.body(size: 11, color: Colors.red.shade600)),
          ],
          if (prUrl != null || runUrl != null || ciRunUrl != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (prUrl != null)
                  _LinkButton(
                    icon: LucideIcons.gitPullRequest,
                    label: 'adminDev.openPr'.tr(),
                    url: prUrl,
                  ),
                if (ciRunUrl != null)
                  _LinkButton(
                    icon: LucideIcons.checkCircle2,
                    label: 'adminDev.stage.ci'.tr(),
                    url: ciRunUrl,
                  ),
                if (runUrl != null)
                  _LinkButton(
                    icon: LucideIcons.terminal,
                    label: 'adminDev.openRun'.tr(),
                    url: runUrl,
                  ),
              ],
            ),
          ],
          // Wiederholen-Button für fehlgeschlagene Aufträge.
          if (onRetry != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onRetry,
                icon: const Icon(LucideIcons.refreshCw, size: 14),
                label: Text('adminDev.retry'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  side: BorderSide(color: AppColors.teal.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
          // Ein-Tap-Rollback für gemergte Änderungen.
          if (onRollback != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onRollback,
                icon: const Icon(LucideIcons.rotateCcw, size: 14),
                label: Text('adminDev.rollback.button'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade600,
                  side: BorderSide(color: Colors.red.shade200),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
          // Diff-Vorschau + (bei Review-Gate) manuelle Freigabe.
          if (onShowDiff != null || onMerge != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (onShowDiff != null)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onShowDiff,
                    icon: const Icon(LucideIcons.fileSearch, size: 14),
                    label: Text('adminDev.viewDiff'.tr()),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.teal,
                      side: BorderSide(
                          color: AppColors.teal.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (onMerge != null) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: busy ? null : onMerge,
                      icon: busy
                          ? const SizedBox(
                              width: 13,
                              height: 13,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(LucideIcons.checkCircle2, size: 15),
                      label: Text('adminDev.approveMerge'.tr()),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.teal,
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (onRefine != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: busy ? null : onRefine,
                icon: const Icon(LucideIcons.messageSquarePlus, size: 14),
                label: Text('adminDev.refine.button'.tr()),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.bronze,
                  side: BorderSide(
                      color: AppColors.bronze.withValues(alpha: 0.4)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  _StatusMeta _statusMeta(String status) {
    switch (status) {
      case 'live':
        return const _StatusMeta(LucideIcons.radio, AppColors.leben);
      case 'merged':
        return const _StatusMeta(LucideIcons.checkCircle2, AppColors.leben);
      case 'phased':
        return const _StatusMeta(LucideIcons.layers, AppColors.teal);
      case 'pr_open':
        return const _StatusMeta(LucideIcons.gitPullRequest, AppColors.teal);
      case 'awaiting_review':
        return const _StatusMeta(LucideIcons.eye, AppColors.amber);
      case 'running':
        return const _StatusMeta(LucideIcons.loader, AppColors.amber);
      case 'error_retry':
        return const _StatusMeta(LucideIcons.rotateCw, AppColors.amber);
      case 'failed':
        return const _StatusMeta(LucideIcons.xCircle, Colors.red);
      case 'patch_failed':
        return const _StatusMeta(LucideIcons.alertTriangle, Colors.red);
      case 'cancelled':
        return const _StatusMeta(LucideIcons.ban, AppColors.lightMute);
      case 'no_changes':
        return const _StatusMeta(LucideIcons.minusCircle, AppColors.lightMute);
      default:
        return const _StatusMeta(LucideIcons.clock, AppColors.lightMute);
    }
  }
}

class _StatusMeta {
  const _StatusMeta(this.icon, this.color);
  final IconData icon;
  final Color color;
}

// ── Pipeline-Stepper: Agent → PR → CI → Merge → OTA ─────────────────────────

enum _Stage { done, active, pending, error }

/// Detailansicht eines Auftrags — alle Infos auf einen Blick (Instruction,
/// Pipeline, Plan, Modell, PR/CI-Links, Zusammenfassung, vollständiges
/// Fehler-Log, Zeitstempel). Öffnet sich beim Tippen auf das Detail-Icon.
class _TaskDetailSheet extends StatelessWidget {
  const _TaskDetailSheet({required this.task});
  final Map<String, dynamic> task;

  @override
  Widget build(BuildContext context) {
    final status = task['status'] as String? ?? 'queued';
    final ciStatus = task['ci_status'] as String?;
    final instruction = task['instruction'] as String? ?? '';
    final summary = task['summary'] as String?;
    final location = (task['location'] as String?)?.trim();
    final error = task['error'] as String?;
    final prUrl = task['pr_url'] as String?;
    final runUrl = task['run_url'] as String?;
    final ciRunUrl = task['ci_run_url'] as String?;
    final model = _modelShortLabel(task['model'] as String?);
    final created = _relativeTime(task['created_at'] as String?);
    final updated = _relativeTime(task['updated_at'] as String?);
    final prNumber = task['pr_number'];

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: ListView(
          controller: scrollCtrl,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.lightLine,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Text('adminDev.detail.title'.tr(),
                    style: AppTypography.body(
                        size: 15,
                        color: AppColors.lightInk,
                        weight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, size: 18),
                  color: AppColors.lightMute,
                ),
              ],
            ),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Badge(text: 'adminDev.status.$status'.tr(), color: AppColors.teal),
                if (model != null) _Badge(text: model, color: AppColors.trust),
                if (prNumber != null)
                  _Badge(text: '#$prNumber', color: AppColors.lightMute),
              ],
            ),
            const SizedBox(height: 12),
            _PipelineStepper(status: status, ciStatus: ciStatus),
            const SizedBox(height: 14),
            _detailLabel('adminDev.detail.instruction'.tr()),
            const SizedBox(height: 4),
            SelectableText(
              instruction,
              style: AppTypography.body(size: 13, color: AppColors.lightInk),
            ),
            if (location != null &&
                location.isNotEmpty &&
                !location.toLowerCase().startsWith('nicht sichtbar')) ...[
              const SizedBox(height: 14),
              _detailLabel('adminDev.location'.tr()),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(LucideIcons.mapPin,
                      size: 13, color: AppColors.teal),
                  const SizedBox(width: 5),
                  Expanded(
                    child: SelectableText(location,
                        style: AppTypography.body(
                            size: 12,
                            color: AppColors.teal,
                            weight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
            if (summary != null && summary.isNotEmpty) ...[
              const SizedBox(height: 14),
              _detailLabel('adminDev.detail.summary'.tr()),
              const SizedBox(height: 4),
              SelectableText(summary,
                  style: AppTypography.body(
                      size: 12, color: AppColors.lightMute)),
            ],
            if (error != null && error.isNotEmpty) ...[
              const SizedBox(height: 14),
              _detailLabel('adminDev.detail.errorLog'.tr()),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade100),
                ),
                child: SelectableText(
                  error,
                  style: AppTypography.body(
                      size: 11, color: Colors.red.shade700),
                ),
              ),
            ],
            if (prUrl != null || ciRunUrl != null || runUrl != null) ...[
              const SizedBox(height: 14),
              _detailLabel('adminDev.detail.links'.tr()),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (prUrl != null)
                    _LinkButton(
                        icon: LucideIcons.gitPullRequest,
                        label: 'adminDev.openPr'.tr(),
                        url: prUrl),
                  if (ciRunUrl != null)
                    _LinkButton(
                        icon: LucideIcons.checkCircle2,
                        label: 'adminDev.stage.ci'.tr(),
                        url: ciRunUrl),
                  if (runUrl != null)
                    _LinkButton(
                        icon: LucideIcons.terminal,
                        label: 'adminDev.openRun'.tr(),
                        url: runUrl),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                if (created != null)
                  Text('adminDev.detail.created'.tr(namedArgs: {'t': created}),
                      style: AppTypography.label(
                          size: 10, color: AppColors.lightMute)),
                if (created != null && updated != null)
                  Text('  ·  ',
                      style: AppTypography.label(
                          size: 10, color: AppColors.lightMute)),
                if (updated != null)
                  Text('adminDev.detail.updated'.tr(namedArgs: {'t': updated}),
                      style: AppTypography.label(
                          size: 10, color: AppColors.lightMute)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailLabel(String text) => Text(
        text.toUpperCase(),
        style: AppTypography.label(size: 9, color: AppColors.lightMute),
      );
}

class _PipelineStepper extends StatelessWidget {
  const _PipelineStepper({required this.status, required this.ciStatus});
  final String status;
  final String? ciStatus;

  List<_Stage> _stages() {
    final s = List<_Stage>.filled(5, _Stage.pending);
    switch (status) {
      case 'queued':
      case 'running':
        s[0] = _Stage.active;
        break;
      case 'no_changes':
        s[0] = _Stage.done;
        break;
      case 'pr_open':
        s[0] = _Stage.done;
        s[1] = _Stage.done;
        if (ciStatus == 'success') {
          s[2] = _Stage.done;
          s[3] = _Stage.active;
        } else if (ciStatus == 'failure') {
          s[2] = _Stage.error;
        } else {
          s[2] = _Stage.active; // pending/running
        }
        break;
      case 'awaiting_review':
        // CI grün, wartet auf manuelle Freigabe (Merge-Schritt aktiv).
        s[0] = _Stage.done;
        s[1] = _Stage.done;
        s[2] = _Stage.done;
        s[3] = _Stage.active;
        break;
      case 'merged':
        s[0] = _Stage.done;
        s[1] = _Stage.done;
        s[2] = _Stage.done;
        s[3] = _Stage.done;
        s[4] = _Stage.active; // OTA läuft
        break;
      case 'live':
        // Live-Verify hat die Auslieferung bestätigt → Pipeline komplett.
        for (var i = 0; i < 5; i++) {
          s[i] = _Stage.done;
        }
        break;
      case 'patch_failed':
        // Merge ok, aber der OTA-Patch-Run war rot.
        s[0] = _Stage.done;
        s[1] = _Stage.done;
        s[2] = _Stage.done;
        s[3] = _Stage.done;
        s[4] = _Stage.error;
        break;
      case 'error_retry':
        // Agent-API-Fehler — der Watchdog wiederholt automatisch.
        s[0] = _Stage.active;
        break;
      case 'failed':
        s[0] = _Stage.error;
        break;
      case 'cancelled':
        s[0] = _Stage.error;
        break;
      default:
        s[0] = _Stage.active;
    }
    return s;
  }

  Color _color(_Stage st) {
    switch (st) {
      case _Stage.done:
        return AppColors.teal;
      case _Stage.active:
        return AppColors.amber;
      case _Stage.error:
        return Colors.red.shade600;
      case _Stage.pending:
        return AppColors.lightGhost;
    }
  }

  @override
  Widget build(BuildContext context) {
    final stages = _stages();
    const labels = [
      'adminDev.stage.agent',
      'adminDev.stage.pr',
      'adminDev.stage.ci',
      'adminDev.stage.merge',
      'adminDev.stage.ota',
    ];
    return Row(
      children: List.generate(5, (i) {
        final st = stages[i];
        final c = _color(st);
        final dot = Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: st == _Stage.pending ? Colors.transparent : c.withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: c, width: 1.5),
              ),
              child: Icon(
                st == _Stage.done
                    ? LucideIcons.check
                    : st == _Stage.error
                        ? LucideIcons.x
                        : st == _Stage.active
                            ? LucideIcons.loader
                            : LucideIcons.circle,
                size: 9,
                color: c,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              labels[i].tr(),
              style: AppTypography.body(
                size: 8,
                color: st == _Stage.pending ? AppColors.lightMute : c,
                weight: st == _Stage.pending ? FontWeight.normal : FontWeight.w600,
              ),
            ),
          ],
        );
        if (i == 4) return dot;
        return Expanded(
          child: Row(
            children: [
              dot,
              Expanded(
                child: Container(
                  height: 1.5,
                  margin: const EdgeInsets.only(bottom: 14, left: 2, right: 2),
                  color: stages[i + 1] == _Stage.pending
                      ? AppColors.lightGhost
                      : AppColors.teal.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _LinkButton extends StatelessWidget {
  const _LinkButton(
      {required this.icon, required this.label, required this.url});
  final IconData icon;
  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => safeLaunch(url, context: context),
      icon: Icon(icon, size: 13),
      label: Text(label, style: const TextStyle(fontSize: 11)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.teal,
        side: BorderSide(color: AppColors.teal.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        minimumSize: const Size(0, 32),
      ),
    );
  }
}

// ── Input Bar ─────────────────────────────────────────────────────────────────

// Vollständiger Pool aller Auftrags-Vorlagen. Bei jedem Tap werden 4 zufällige
// aus diesem Pool angezeigt — so erscheinen nie zweimal dieselben Chips.
const _allTemplateKeys = [
  'i18nCheck', 'perfCheck', 'darkMode', 'a11y',
  'onboarding', 'security', 'animations', 'crashes',
  'dependencies', 'notifications', 'offline', 'emptyStates',
];

class _InputBar extends StatefulWidget {
  const _InputBar({
    required this.ctrl,
    required this.sending,
    required this.placeholder,
    required this.onSend,
    required this.images,
    required this.onAttach,
    required this.onRemoveImage,
    required this.awaitReview,
    required this.onToggleReview,
    required this.wantScreens,
    required this.onToggleScreens,
    required this.planMode,
    required this.onTogglePlan,
    required this.onTemplate,
    required this.existingInstructions,
  });
  final TextEditingController ctrl;
  final bool sending;
  final String placeholder;
  final Future<void> Function([String?]) onSend;
  final List<File> images;
  final VoidCallback onAttach;
  final void Function(int) onRemoveImage;
  final bool awaitReview;
  final void Function(bool) onToggleReview;
  final bool wantScreens;
  final void Function(bool) onToggleScreens;
  final bool planMode;
  final void Function(bool) onTogglePlan;
  final void Function(String) onTemplate;
  // Für Duplikat-Erkennung (simple Keyword-Überschneidung).
  final List<String> existingInstructions;

  @override
  State<_InputBar> createState() => _InputBarState();
}

class _InputBarState extends State<_InputBar> {
  late List<String> _visibleTemplates;

  // Voice-Eingabe (Speech-to-Text).
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _speechAvailable = false;
  bool _listening = false;
  String _baseTextBeforeListen = '';

  // Eingabeleiste standardmäßig eingeklappt: unten nur das Eingabefeld. Tippt
  // der Admin ins Feld, klappt der volle Funktionsumfang aus (Vorlagen,
  // Schalter, Anhänge, Mikro). Manuelles Einklappen über den Chevron oben.
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _visibleTemplates = _pickTemplates();
  }

  @override
  void dispose() {
    if (_listening) _speech.stop();
    super.dispose();
  }

  // Mikrofon: Diktat starten/stoppen. Erkannter Text wird ans Eingabefeld
  // angehängt (an das, was vor dem Start drinstand).
  Future<void> _toggleListening() async {
    final localeId = context.locale.toString().replaceAll('_', '-');
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    if (!_speechAvailable) {
      _speechAvailable = await _speech.initialize(
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && mounted) {
            setState(() => _listening = false);
          }
        },
        onError: (_) {
          if (mounted) setState(() => _listening = false);
        },
      );
    }
    if (!_speechAvailable) {
      if (mounted) {
        AppSnackBar.info(context, 'adminDev.voice.unavailable'.tr());
      }
      return;
    }
    _baseTextBeforeListen = widget.ctrl.text;
    setState(() => _listening = true);
    await _speech.listen(
      listenOptions: stt.SpeechListenOptions(localeId: localeId),
      onResult: (r) {
        final spoken = r.recognizedWords;
        final sep = _baseTextBeforeListen.isEmpty ||
                _baseTextBeforeListen.endsWith(' ')
            ? ''
            : ' ';
        widget.ctrl.text = '$_baseTextBeforeListen$sep$spoken';
        widget.ctrl.selection =
            TextSelection.collapsed(offset: widget.ctrl.text.length);
        setState(() {});
      },
    );
  }

  // Wählt 4 zufällige Templates aus dem Pool.
  List<String> _pickTemplates() {
    final pool = List<String>.from(_allTemplateKeys)..shuffle(Random());
    return pool.take(4).toList();
  }

  void _onTemplateTap(String key) {
    widget.onTemplate('adminDev.templateTexts.$key'.tr());
    // Nach jedem Tap neuen Mix anzeigen.
    setState(() => _visibleTemplates = _pickTemplates());
  }

  // Einfache Duplikat-Warnung: prüft ob der Eingabe-Text signifikante
  // Wortüberschneidung mit einem bestehenden Auftrag hat.
  String? _duplicateWarning(String text) =>
      similarInstruction(text, widget.existingInstructions);

  // Kompakte Schalter-Zeile (Icon + Label + Switch).
  Widget _toggleRow({
    required IconData icon,
    required String label,
    required bool value,
    required void Function(bool)? onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppColors.lightMute),
        const SizedBox(width: 6),
        Expanded(
          child: Text(label,
              style: AppTypography.body(size: 11, color: AppColors.lightMute)),
        ),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.teal,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final inputText = widget.ctrl.text;
    final dupWarning = _duplicateWarning(inputText);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.lightLine)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Collapse-Handle — nur sichtbar wenn ausgeklappt. Tap klappt ein.
          if (_expanded)
            Center(
              child: InkWell(
                onTap: () {
                  FocusScope.of(context).unfocus();
                  setState(() => _expanded = false);
                },
                borderRadius: BorderRadius.circular(12),
                child: const Padding(
                  padding: EdgeInsets.symmetric(
                      horizontal: 24, vertical: 2),
                  child: Icon(LucideIcons.chevronDown,
                      size: 20, color: AppColors.lightMute),
                ),
              ),
            ),
          // Vorlagen-Chips (rotierender Pool — ändert sich nach jedem Tap).
          if (_expanded)
            SizedBox(
              height: 30,
              child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final k in _visibleTemplates)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ActionChip(
                      label: Text('adminDev.templates.$k'.tr(),
                          style: AppTypography.body(
                              size: 11, color: AppColors.teal)),
                      backgroundColor: AppColors.teal.withValues(alpha: 0.07),
                      side: BorderSide(
                          color: AppColors.teal.withValues(alpha: 0.25)),
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.sending ? null : () => _onTemplateTap(k),
                    ),
                  ),
              ],
            ),
          ),
          // Duplikat-Warnung: nur wenn starke Überschneidung mit bestehendem Auftrag.
          if (_expanded && dupWarning != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.amber.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.amber.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.alertTriangle,
                      size: 13, color: AppColors.amberDeep),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'adminDev.duplicateWarning'
                          .tr(namedArgs: {'task': dupWarning}),
                      style: AppTypography.body(
                          size: 10, color: AppColors.amberDeep),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Angehängte Screenshots (Vorschau + Entfernen).
          if (_expanded && widget.images.isNotEmpty) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 60,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: widget.images.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) => Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(widget.images[i],
                          width: 60, height: 60, fit: BoxFit.cover),
                    ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => widget.onRemoveImage(i),
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(LucideIcons.x,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Optionen-Schalter: Review-Gate · Plan-Modus · Screenshots.
          if (_expanded)
            _toggleRow(
              icon: LucideIcons.gitPullRequest,
              label: 'adminDev.reviewBeforeMerge'.tr(),
              value: widget.awaitReview,
              onChanged: widget.sending ? null : widget.onToggleReview,
            ),
          if (_expanded)
            _toggleRow(
              icon: LucideIcons.listChecks,
              label: 'adminDev.plan.toggle'.tr(),
              value: widget.planMode,
              onChanged: widget.sending ? null : widget.onTogglePlan,
            ),
          if (_expanded)
            _toggleRow(
              icon: LucideIcons.image,
              label: 'adminDev.screens.toggle'.tr(),
              value: widget.wantScreens,
              onChanged: widget.sending ? null : widget.onToggleScreens,
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (_expanded)
                IconButton(
                  onPressed: widget.sending || widget.images.length >= 6
                      ? null
                      : widget.onAttach,
                  icon: const Icon(LucideIcons.imagePlus, size: 20),
                  color: AppColors.teal,
                  tooltip: 'adminDev.attachImage'.tr(),
                ),
              if (_expanded)
                IconButton(
                  onPressed: widget.sending ? null : _toggleListening,
                  icon: Icon(_listening ? LucideIcons.micOff : LucideIcons.mic,
                      size: 20),
                  color: _listening ? Colors.red.shade600 : AppColors.teal,
                  tooltip: 'adminDev.voice.tooltip'.tr(),
                ),
              Expanded(
                child: TextField(
                  controller: widget.ctrl,
                  onChanged: (_) => setState(() {}),
                  onTap: _expanded
                      ? null
                      : () => setState(() => _expanded = true),
                  enabled: !widget.sending,
                  maxLines: _expanded ? 4 : 1,
                  minLines: 1,
                  decoration: InputDecoration(
                    hintText: widget.placeholder,
                    hintStyle: AppTypography.body(
                        size: 13, color: AppColors.lightMute),
                    filled: true,
                    fillColor: AppColors.lightElevated,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(color: AppColors.lightLine),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide(color: AppColors.lightLine),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: const BorderSide(color: AppColors.teal),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: widget.sending ? null : () => widget.onSend(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(14),
                ),
                child: widget.sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(LucideIcons.send,
                        size: 18, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Chat-Sheet (manueller Modus, Bestätigung wie bei Claude) ────────────────

class _DevChatSheet extends StatefulWidget {
  const _DevChatSheet({required this.initialText, required this.onConfirm});
  final String initialText;
  final Future<bool> Function(String) onConfirm;

  @override
  State<_DevChatSheet> createState() => _DevChatSheetState();
}

class _DevChatSheetState extends State<_DevChatSheet> {
  final _ctrl = TextEditingController();
  final _scroll = ScrollController();
  final List<Map<String, String>> _messages = [];
  bool _sending = false;
  bool _ready = false;
  bool _confirming = false;
  String _instruction = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialText.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _sendMessage(widget.initialText),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add({'role': 'user', 'content': text});
      _sending = true;
      _ready = false;
      _ctrl.clear();
    });
    _scrollToEnd();
    final res = await AiInsightsRepository.chatDev(_messages);
    if (!mounted) return;
    final reply = (res['reply'] as String?) ?? 'adminDev.chat.error'.tr();
    setState(() {
      _messages.add({'role': 'assistant', 'content': reply});
      _ready = res['ready'] == true;
      _instruction = (res['instruction'] as String?) ?? '';
      _sending = false;
    });
    _scrollToEnd();
  }

  Future<void> _confirm() async {
    if (_instruction.isEmpty || _confirming) return;
    setState(() => _confirming = true);
    final ok = await widget.onConfirm(_instruction);
    if (!mounted) return;
    setState(() => _confirming = false);
    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.surface,
        content: Text('adminDev.queued'.tr(),
            style: AppTypography.body(size: 13, color: AppColors.ink)),
        duration: const Duration(milliseconds: 4000),
      ));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('adminDev.failed'.tr()),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.82,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightLine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
              child: Row(
                children: [
                  const Icon(LucideIcons.bot, size: 18, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Text(
                    'adminDev.chat.title'.tr(),
                    style: AppTypography.body(
                        size: 14,
                        color: AppColors.lightInk,
                        weight: FontWeight.w700),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, size: 18),
                    color: AppColors.lightMute,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                itemCount: _messages.length + (_sending ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= _messages.length) return const _ChatThinking();
                  final m = _messages[i];
                  return _ChatBubble(
                    text: m['content'] ?? '',
                    isUser: m['role'] == 'user',
                  );
                },
              ),
            ),
            if (_ready)
              Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.06),
                  border: Border(
                      top: BorderSide(
                          color: AppColors.teal.withValues(alpha: 0.2))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _confirming ? null : _confirm,
                        icon: _confirming
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Icon(LucideIcons.check, size: 15),
                        label: Text('adminDev.chat.confirmYes'.tr()),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _confirming
                          ? null
                          : () => setState(() => _ready = false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.lightMute,
                        side: BorderSide(color: AppColors.lightLine),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                      ),
                      child: Text('adminDev.chat.confirmNo'.tr()),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.lightLine)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrl,
                      enabled: !_sending,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'adminDev.chat.placeholder'.tr(),
                        hintStyle: AppTypography.body(
                            size: 13, color: AppColors.lightMute),
                        filled: true,
                        fillColor: AppColors.lightElevated,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: AppColors.lightLine),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: BorderSide(color: AppColors.lightLine),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(22),
                          borderSide: const BorderSide(color: AppColors.teal),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _sending ? null : () => _sendMessage(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(13),
                    ),
                    child: const Icon(LucideIcons.send,
                        size: 17, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.text, required this.isUser});
  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? AppColors.teal : AppColors.lightRaised,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isUser ? 14 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 14),
          ),
        ),
        child: Text(
          text,
          style: AppTypography.body(
            size: 13,
            color: isUser ? Colors.white : AppColors.lightInk,
          ),
        ),
      ),
    );
  }
}

class _ChatThinking extends StatelessWidget {
  const _ChatThinking();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.lightRaised,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: AppColors.teal),
            ),
            const SizedBox(width: 8),
            Text(
              'adminDev.chat.thinking'.tr(),
              style: AppTypography.body(size: 12, color: AppColors.lightMute),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Diff-Sheet: zeigt die geänderten Dateien (Patch) des PRs ────────────────

class _DiffSheet extends StatefulWidget {
  const _DiffSheet({required this.taskId});
  final String taskId;

  @override
  State<_DiffSheet> createState() => _DiffSheetState();
}

class _DiffSheetState extends State<_DiffSheet> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _files = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final res = await AiInsightsRepository.fetchDevTaskDiff(widget.taskId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res['ok'] == true) {
        _files = ((res['files'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      } else {
        _error = 'adminDev.diffError'.tr();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.lightLine,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 8),
            child: Row(
              children: [
                const Icon(LucideIcons.fileSearch,
                    size: 18, color: AppColors.teal),
                const SizedBox(width: 8),
                Text(
                  'adminDev.diffTitle'.tr(),
                  style: AppTypography.body(
                      size: 14,
                      color: AppColors.lightInk,
                      weight: FontWeight.w700),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.x, size: 18),
                  color: AppColors.lightMute,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Text(_error!,
                            style: AppTypography.body(
                                size: 13, color: AppColors.lightMute)))
                    : ListView.builder(
                        padding: const EdgeInsets.all(14),
                        itemCount: _files.length,
                        itemBuilder: (context, i) => _DiffFileTile(file: _files[i]),
                      ),
          ),
        ],
      ),
    );
  }
}

class _DiffFileTile extends StatelessWidget {
  const _DiffFileTile({required this.file});
  final Map<String, dynamic> file;

  @override
  Widget build(BuildContext context) {
    final name = file['filename'] as String? ?? '';
    final additions = file['additions'] as int? ?? 0;
    final deletions = file['deletions'] as int? ?? 0;
    final patch = file['patch'] as String?;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.lightElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: EdgeInsets.zero,
          title: Text(
            name,
            style: AppTypography.body(
                size: 12, color: AppColors.lightInk, weight: FontWeight.w600),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Text('+$additions',
                  style: AppTypography.body(
                      size: 11, color: AppColors.leben)),
              const SizedBox(width: 8),
              Text('-$deletions',
                  style: AppTypography.body(
                      size: 11, color: Colors.red.shade600)),
            ],
          ),
          children: [
            if (patch != null && patch.isNotEmpty)
              Container(
                width: double.infinity,
                color: const Color(0xFF0D1117),
                padding: const EdgeInsets.all(10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: _DiffPatch(patch: patch),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('adminDev.diffBinary'.tr(),
                    style: AppTypography.body(
                        size: 11, color: AppColors.lightMute)),
              ),
          ],
        ),
      ),
    );
  }
}

// Färbt Diff-Zeilen (+ grün, - rot, @@ teal) im Monospace-Stil.
class _DiffPatch extends StatelessWidget {
  const _DiffPatch({required this.patch});
  final String patch;

  @override
  Widget build(BuildContext context) {
    final lines = patch.split('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in lines)
          Text(
            line.isEmpty ? ' ' : line,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              height: 1.35,
              color: line.startsWith('+')
                  ? const Color(0xFF7EE787)
                  : line.startsWith('-')
                      ? const Color(0xFFFFA198)
                      : line.startsWith('@@')
                          ? const Color(0xFF79C0FF)
                          : const Color(0xFFC9D1D9),
            ),
          ),
      ],
    );
  }
}

// ── Health-/Metrics-Dashboard ───────────────────────────────────────────────

// Freie-API-Key-Verwaltung (Klapp-Karte). Zeigt NUR Metadaten, nie den Key.
class _ApiKeysCard extends StatelessWidget {
  const _ApiKeysCard({
    required this.keys,
    required this.expanded,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });
  final List<Map<String, dynamic>> keys;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(String service) onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  const Icon(LucideIcons.keyRound,
                      size: 16, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('adminDev.apiKeys.title'.tr(),
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.lightInk,
                            weight: FontWeight.w700)),
                  ),
                  if (keys.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text('${keys.length}',
                          style: AppTypography.label(
                              size: 10, color: AppColors.lightMute)),
                    ),
                  Icon(
                      expanded
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 16,
                      color: AppColors.lightMute),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            if (keys.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('adminDev.apiKeys.empty'.tr(),
                    style: AppTypography.caption()),
              )
            else
              ...keys.map((k) {
                final service = k['service'] as String? ?? '';
                final exp = k['expires_at'] != null
                    ? DateTime.tryParse(k['expires_at'] as String)
                    : null;
                final expired =
                    exp != null && exp.isBefore(DateTime.now());
                return Padding(
                  padding: const EdgeInsets.fromLTRB(13, 6, 6, 6),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.key,
                          size: 13, color: AppColors.lightMute),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(service,
                                style: AppTypography.body(
                                    size: 12, color: AppColors.lightInk)),
                            if (exp != null)
                              Text(
                                'adminDev.apiKeys.expires'.tr(namedArgs: {
                                  'date':
                                      '${exp.day}.${exp.month}.${exp.year}'
                                }),
                                style: AppTypography.label(
                                    size: 9,
                                    color: expired
                                        ? AppColors.herzrotWarm
                                        : AppColors.lightMute),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'common.edit'.tr(),
                        onPressed: () => onEdit(k),
                        icon: const Icon(LucideIcons.pencil,
                            size: 14, color: AppColors.bronze),
                      ),
                      IconButton(
                        tooltip: 'common.delete'.tr(),
                        onPressed: () => onDelete(service),
                        icon: const Icon(LucideIcons.trash2,
                            size: 14, color: AppColors.herzrotWarm),
                      ),
                    ],
                  ),
                );
              }),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 0, 13, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(LucideIcons.plus, size: 14),
                  label: Text('adminDev.apiKeys.add'.tr()),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.teal),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Auto-Changelog: gemergte Godmode-Änderungen (Klapp-Karte).
class _ChangelogCard extends StatelessWidget {
  const _ChangelogCard({
    required this.entries,
    required this.expanded,
    required this.onToggle,
  });
  final List<Map<String, dynamic>> entries;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  const Icon(LucideIcons.history,
                      size: 16, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('adminDev.changelog.title'.tr(),
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.lightInk,
                            weight: FontWeight.w700)),
                  ),
                  if (entries.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text('${entries.length}',
                          style: AppTypography.label(
                              size: 10, color: AppColors.lightMute)),
                    ),
                  Icon(
                      expanded
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 16,
                      color: AppColors.lightMute),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('adminDev.changelog.empty'.tr(),
                    style: AppTypography.caption()),
              )
            else
              ...entries.take(50).map((e) {
                final title = e['title'] as String? ?? '';
                final pr = e['pr_number'];
                final summary = (e['summary'] as String?)?.trim() ?? '';
                final loc = (e['location'] as String?)?.trim() ?? '';
                final showLoc = loc.isNotEmpty &&
                    !loc.toLowerCase().startsWith('nicht sichtbar');
                final files = (e['files'] as List?)
                        ?.map((f) => f.toString())
                        .toList() ??
                    const <String>[];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(13, 8, 13, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(LucideIcons.gitMerge,
                              size: 13, color: AppColors.leben),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              pr != null ? '$title  (#$pr)' : title,
                              style: AppTypography.body(
                                  size: 12,
                                  color: AppColors.lightInk,
                                  weight: FontWeight.w600),
                            ),
                          ),
                          if (files.isNotEmpty)
                            Text(
                              'adminDev.changelog.fileCount'
                                  .tr(namedArgs: {'n': '${files.length}'}),
                              style: AppTypography.label(
                                  size: 9, color: AppColors.lightMute),
                            ),
                        ],
                      ),
                      if (summary.isNotEmpty &&
                          summary.toLowerCase() != title.toLowerCase()) ...[
                        const Padding(
                          padding: EdgeInsets.only(left: 21),
                          child: SizedBox(height: 2),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(left: 21),
                          child: Text(
                            summary,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption(
                                color: AppColors.lightMute),
                          ),
                        ),
                      ],
                      if (showLoc) ...[
                        const SizedBox(height: 3),
                        Padding(
                          padding: const EdgeInsets.only(left: 21),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(LucideIcons.mapPin,
                                  size: 11, color: AppColors.teal),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  loc,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption(
                                      color: AppColors.teal),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      if (files.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(left: 21),
                          child: Wrap(
                            spacing: 5,
                            runSpacing: 4,
                            children: files.take(6).map((f) {
                              final name = f.split('/').last;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.lightRaised,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(name,
                                    style: AppTypography.label(
                                        size: 9, color: AppColors.lightMute)),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }
}

/// Post-Merge-Gesundheitswächter: zeigt offene Crash-Anstieg-Alarme nach einem
/// Godmode-Merge. SICHERER ALARM — der Wächter rollt NICHTS automatisch zurück;
/// der Admin entscheidet (quittieren, als erledigt markieren oder Fix-Auftrag).
class _HealthAlertsCard extends StatelessWidget {
  const _HealthAlertsCard({
    required this.alerts,
    required this.busyIds,
    required this.onAcknowledge,
    required this.onResolve,
    required this.onFix,
  });
  final List<Map<String, dynamic>> alerts;
  final Set<String> busyIds;
  final ValueChanged<String> onAcknowledge;
  final ValueChanged<String> onResolve;
  final ValueChanged<Map<String, dynamic>> onFix;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.herzrot.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.herzrot.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 12, 13, 6),
            child: Row(
              children: [
                const Icon(LucideIcons.alertTriangle,
                    size: 16, color: AppColors.herzrot),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('adminDev.healthAlert.title'.tr(),
                      style: AppTypography.body(
                          size: 13,
                          color: AppColors.herzrot,
                          weight: FontWeight.w800)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.herzrot,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${alerts.length}',
                      style: AppTypography.label(
                          size: 10, color: Colors.white)),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(13, 0, 13, 8),
            child: Text('adminDev.healthAlert.subtitle'.tr(),
                style: AppTypography.caption(color: AppColors.lightMute)),
          ),
          ...alerts.map((a) {
            final id = a['id'] as String;
            final busy = busyIds.contains(id);
            final pr = a['pr_number'];
            final mergeTitle = a['merge_title'] as String? ?? '';
            final msg = (a['error_message'] as String? ?? '').trim();
            final etype = a['error_type'] as String? ?? '';
            final crashes = a['crash_count'] ?? 0;
            final users = a['affected_users'] ?? 0;
            return Container(
              margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.lightLine),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'adminDev.healthAlert.spike'.tr(namedArgs: {
                      'crashes': '$crashes',
                      'users': '$users',
                    }),
                    style: AppTypography.body(
                        size: 12,
                        color: AppColors.herzrot,
                        weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    etype.isEmpty ? msg : '$etype: $msg',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                        size: 11, color: AppColors.lightInk),
                  ),
                  if (mergeTitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      pr != null
                          ? '$mergeTitle  (#$pr)'
                          : mergeTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.caption(
                          color: AppColors.lightMute),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _AlertAction(
                          icon: LucideIcons.wrench,
                          label: 'adminDev.healthAlert.fix'.tr(),
                          primary: true,
                          onTap: () => onFix(a),
                        ),
                        _AlertAction(
                          icon: LucideIcons.check,
                          label: 'adminDev.healthAlert.acknowledge'.tr(),
                          onTap: () => onAcknowledge(id),
                        ),
                        _AlertAction(
                          icon: LucideIcons.checkCheck,
                          label: 'adminDev.healthAlert.resolve'.tr(),
                          onTap: () => onResolve(id),
                        ),
                      ],
                    ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AlertAction extends StatelessWidget {
  const _AlertAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : AppColors.lightInk;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: primary ? AppColors.herzrot : AppColors.lightRaised,
          borderRadius: BorderRadius.circular(8),
          border: primary
              ? null
              : Border.all(color: AppColors.lightLine),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 5),
            Text(label,
                style: AppTypography.label(size: 11, color: fg)),
          ],
        ),
      ),
    );
  }
}

/// Modul-Health-Matrix: Bewertung jedes App-Moduls aus dem Tiefenscan —
/// schwächste zuerst, damit klar ist, wo Godmode als Nächstes ansetzen sollte.
class _ModuleHealthCard extends StatelessWidget {
  const _ModuleHealthCard({
    required this.modules,
    required this.expanded,
    required this.onToggle,
  });
  final List<Map<String, dynamic>> modules;
  final bool expanded;
  final VoidCallback onToggle;

  Color _scoreColor(int s) {
    if (s >= 75) return AppColors.leben;
    if (s >= 50) return AppColors.amber;
    return AppColors.herzrot;
  }

  @override
  Widget build(BuildContext context) {
    final avg = modules.isEmpty
        ? 0
        : (modules
                    .map((m) => (m['score'] as num?)?.toInt() ?? 0)
                    .reduce((a, b) => a + b) /
                modules.length)
            .round();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  const Icon(LucideIcons.layoutGrid,
                      size: 16, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('adminDev.moduleHealth.title'.tr(),
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.lightInk,
                            weight: FontWeight.w700)),
                  ),
                  Text('Ø $avg',
                      style: AppTypography.label(
                          size: 11, color: _scoreColor(avg))),
                  const SizedBox(width: 6),
                  Icon(
                      expanded
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 16,
                      color: AppColors.lightMute),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            ...modules.map((m) {
              final label = m['label'] as String? ?? m['module'] as String? ?? '';
              final score = (m['score'] as num?)?.toInt() ?? 0;
              final comp = (m['completeness'] as num?)?.toInt() ?? 0;
              final qual = (m['quality'] as num?)?.toInt() ?? 0;
              final tests = (m['tests'] as num?)?.toInt() ?? 0;
              final notes = (m['notes'] as String?)?.trim() ?? '';
              final c = _scoreColor(score);
              return Padding(
                padding: const EdgeInsets.fromLTRB(13, 9, 13, 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(label,
                              style: AppTypography.body(
                                  size: 12.5,
                                  color: AppColors.lightInk,
                                  weight: FontWeight.w600)),
                        ),
                        Text('$score',
                            style: AppTypography.label(size: 12, color: c)),
                      ],
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: score / 100,
                        minHeight: 6,
                        backgroundColor: AppColors.lightRaised,
                        valueColor: AlwaysStoppedAnimation(c),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'adminDev.moduleHealth.subscores'.tr(namedArgs: {
                        'comp': '$comp',
                        'qual': '$qual',
                        'tests': '$tests',
                      }),
                      style: AppTypography.label(
                          size: 9, color: AppColors.lightMute),
                    ),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(notes,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.caption(
                              color: AppColors.lightMute)),
                    ],
                    const Divider(height: 14),
                  ],
                ),
              );
            }),
            const SizedBox(height: 4),
          ],
        ],
      ),
    );
  }
}

/// Überwachter Autopilot: Godmode nimmt täglich den Top-Quick-Win und liefert
/// ihn — mit Veto via Review-Gate (CI baut, Merge erst nach Freigabe).
class _AutopilotCard extends StatelessWidget {
  const _AutopilotCard({
    required this.enabled,
    required this.busy,
    required this.onChanged,
  });
  final bool enabled;
  final bool busy;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.teal.withValues(alpha: 0.08)
            : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: enabled
              ? AppColors.teal.withValues(alpha: 0.4)
              : AppColors.lightLine,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
      child: Row(
        children: [
          Icon(LucideIcons.activity,
              size: 18,
              color: enabled ? AppColors.teal : AppColors.lightMute),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('adminDev.autopilot.title'.tr(),
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.lightInk,
                        weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('adminDev.autopilot.subtitle'.tr(),
                    style: AppTypography.caption(color: AppColors.lightMute)),
              ],
            ),
          ),
          busy
              ? const Padding(
                  padding: EdgeInsets.all(8),
                  child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : Switch(
                  value: enabled,
                  onChanged: onChanged,
                  activeColor: AppColors.teal,
                ),
        ],
      ),
    );
  }
}

/// Roadmap / Epics: thematische Initiativen mit Fortschritt. Bündelt Aufträge
/// & Vorschläge zu größeren Vorhaben und zeigt den Liefer-Fortschritt.
class _RoadmapCard extends StatelessWidget {
  const _RoadmapCard({
    required this.epics,
    required this.expanded,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.onNewTask,
    required this.colorOf,
  });
  final List<Map<String, dynamic>> epics;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final ValueChanged<Map<String, dynamic>> onEdit;
  final ValueChanged<String> onDelete;
  final ValueChanged<Map<String, dynamic>> onNewTask;
  final Color Function(String) colorOf;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(13),
            child: Padding(
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  const Icon(LucideIcons.map,
                      size: 16, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('adminDev.roadmap.title'.tr(),
                        style: AppTypography.body(
                            size: 13,
                            color: AppColors.lightInk,
                            weight: FontWeight.w700)),
                  ),
                  if (epics.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text('${epics.length}',
                          style: AppTypography.label(
                              size: 10, color: AppColors.lightMute)),
                    ),
                  Icon(
                      expanded
                          ? LucideIcons.chevronUp
                          : LucideIcons.chevronDown,
                      size: 16,
                      color: AppColors.lightMute),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            if (epics.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text('adminDev.roadmap.empty'.tr(),
                    style: AppTypography.caption()),
              )
            else
              ...epics.map((e) => _epicTile(context, e)),
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 4, 13, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onAdd,
                  icon: const Icon(LucideIcons.plus, size: 15),
                  label: Text('adminDev.roadmap.add'.tr()),
                  style: TextButton.styleFrom(
                      foregroundColor: AppColors.teal),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _epicTile(BuildContext context, Map<String, dynamic> e) {
    final id = e['id'] as String;
    final title = e['title'] as String? ?? '';
    final desc = e['description'] as String? ?? '';
    final color = colorOf(e['color'] as String? ?? 'teal');
    final status = e['status'] as String? ?? 'active';
    final total = (e['total_tasks'] as num?)?.toInt() ?? 0;
    final done = (e['done_tasks'] as num?)?.toInt() ?? 0;
    final pending = (e['pending_suggestions'] as num?)?.toInt() ?? 0;
    final progress = total > 0 ? done / total : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Expanded(
                child: Text(title,
                    style: AppTypography.body(
                        size: 12.5,
                        color: AppColors.lightInk,
                        weight: FontWeight.w700)),
              ),
              if (status == 'done')
                const Icon(LucideIcons.checkCheck,
                    size: 14, color: AppColors.leben)
              else if (status == 'archived')
                const Icon(LucideIcons.archive,
                    size: 14, color: AppColors.lightMute),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => onNewTask(e),
                icon: const Icon(LucideIcons.plus, size: 15),
                color: AppColors.teal,
                tooltip: 'adminDev.roadmap.addTaskTooltip'.tr(),
              ),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => onEdit(e),
                icon: const Icon(LucideIcons.pencil, size: 14),
                color: AppColors.lightMute,
              ),
              const SizedBox(width: 8),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => onDelete(id),
                icon: const Icon(LucideIcons.trash2, size: 14),
                color: AppColors.lightMute,
              ),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(desc,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption(color: AppColors.lightMute)),
          ],
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: AppColors.lightRaised,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'adminDev.roadmap.progress'.tr(namedArgs: {
              'done': '$done',
              'total': '$total',
              'pending': '$pending',
            }),
            style: AppTypography.label(size: 10, color: AppColors.lightMute),
          ),
          const Divider(height: 16),
        ],
      ),
    );
  }
}

class _HealthCard extends StatelessWidget {
  const _HealthCard({
    required this.metrics,
    required this.expanded,
    required this.onToggle,
  });
  final Map<String, dynamic> metrics;
  final bool expanded;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final total = (metrics['total'] as num?)?.toInt() ?? 0;
    final merged = (metrics['merged'] as num?)?.toInt() ?? 0;
    final failed = (metrics['failed'] as num?)?.toInt() ?? 0;
    final active = (metrics['active'] as num?)?.toInt() ?? 0;
    final rate = (metrics['success_rate'] as num?)?.toInt() ?? 0;
    final avgMin = (metrics['avg_merge_minutes'] as num?)?.toInt() ?? 0;
    final accepted = (metrics['suggestions_accepted'] as num?)?.toInt() ?? 0;
    final rejected = (metrics['suggestions_rejected'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(LucideIcons.activity,
                      size: 18, color: AppColors.teal),
                  const SizedBox(width: 10),
                  Text(
                    'adminDev.health.title'.tr(),
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.lightInk,
                        weight: FontWeight.w600),
                  ),
                  const SizedBox(width: 8),
                  // Erfolgsquote als kompakter Badge immer sichtbar.
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('$rate%',
                        style: AppTypography.body(
                            size: 11,
                            color: AppColors.teal,
                            weight: FontWeight.w700)),
                  ),
                  const Spacer(),
                  Icon(
                    expanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 18,
                    color: AppColors.lightMute,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _stat('adminDev.health.total'.tr(), '$total',
                      LucideIcons.gitPullRequest),
                  _stat('adminDev.health.merged'.tr(), '$merged',
                      LucideIcons.checkCircle2, color: AppColors.leben),
                  _stat('adminDev.health.active'.tr(), '$active',
                      LucideIcons.loader, color: AppColors.amber),
                  _stat('adminDev.health.failed'.tr(), '$failed',
                      LucideIcons.xCircle, color: Colors.red.shade600),
                  _stat('adminDev.health.successRate'.tr(), '$rate%',
                      LucideIcons.trendingUp, color: AppColors.teal),
                  _stat('adminDev.health.avgMerge'.tr(),
                      avgMin > 0 ? '$avgMin min' : '—', LucideIcons.clock),
                  _stat('adminDev.health.accepted'.tr(), '$accepted',
                      LucideIcons.checkCheck, color: AppColors.leben),
                  _stat('adminDev.health.rejected'.tr(), '$rejected',
                      LucideIcons.x, color: AppColors.lightMute),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stat(String label, String value, IconData icon, {Color? color}) {
    return Container(
      width: 96,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.lightElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: color ?? AppColors.lightMute),
          const SizedBox(height: 4),
          Text(value,
              style: AppTypography.body(
                  size: 15,
                  color: AppColors.lightInk,
                  weight: FontWeight.w700)),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.body(size: 10, color: AppColors.lightMute)),
        ],
      ),
    );
  }
}

// ── Wiederkehrende Aufträge ──────────────────────────────────────────────────

class _SchedulesCard extends StatelessWidget {
  const _SchedulesCard({
    required this.schedules,
    required this.expanded,
    required this.onToggle,
    required this.onAdd,
    required this.onEdit,
    required this.onToggleEnabled,
    required this.onDelete,
  });
  final List<Map<String, dynamic>> schedules;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final void Function(Map<String, dynamic>) onEdit;
  final void Function(String, bool) onToggleEnabled;
  final void Function(String) onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(LucideIcons.repeat,
                      size: 18, color: AppColors.trust),
                  const SizedBox(width: 10),
                  Text(
                    'adminDev.schedules.title'.tr(),
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.lightInk,
                        weight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.lightRaised,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('${schedules.length}',
                        style: AppTypography.body(
                            size: 10, color: AppColors.lightMute)),
                  ),
                  const Spacer(),
                  Icon(
                    expanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 18,
                    color: AppColors.lightMute,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1),
            if (schedules.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: Text('adminDev.schedules.empty'.tr(),
                    style: AppTypography.body(
                        size: 12, color: AppColors.lightMute)),
              )
            else
              ...schedules.map((s) => _ScheduleTile(
                    schedule: s,
                    onEdit: () => onEdit(s),
                    onDelete: () => onDelete(s['id'] as String),
                    onToggleEnabled: (v) =>
                        onToggleEnabled(s['id'] as String, v),
                  )),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
              child: TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(LucideIcons.plus, size: 16),
                label: Text('adminDev.schedules.add'.tr()),
                style: TextButton.styleFrom(foregroundColor: AppColors.teal),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  const _ScheduleTile({
    required this.schedule,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleEnabled,
  });
  final Map<String, dynamic> schedule;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final void Function(bool) onToggleEnabled;

  String _cadenceLabel() {
    final c = schedule['cadence'] as String? ?? 'weekly';
    return 'adminDev.schedules.cadence.$c'.tr();
  }

  @override
  Widget build(BuildContext context) {
    final title = schedule['title'] as String? ?? '';
    final enabled = schedule['enabled'] == true;
    final hour = (schedule['hour_utc'] as num?)?.toInt() ?? 6;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 6, 6),
      decoration: BoxDecoration(
        color: AppColors.lightElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lightLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title,
                    style: AppTypography.body(
                        size: 13,
                        color: AppColors.lightInk,
                        weight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: enabled,
                  onChanged: onToggleEnabled,
                  activeColor: AppColors.teal,
                ),
              ),
            ],
          ),
          Row(
            children: [
              const Icon(LucideIcons.clock, size: 11, color: AppColors.lightMute),
              const SizedBox(width: 4),
              Text(
                '${_cadenceLabel()} · ${hour.toString().padLeft(2, '0')}:00 UTC',
                style: AppTypography.body(size: 10, color: AppColors.lightMute),
              ),
              const Spacer(),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(LucideIcons.pencil, size: 14),
                color: AppColors.lightMute,
                visualDensity: VisualDensity.compact,
                tooltip: 'common.edit'.tr(),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(LucideIcons.trash2, size: 14),
                color: AppColors.lightMute,
                visualDensity: VisualDensity.compact,
                tooltip: 'common.delete'.tr(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Bottom-Sheet zum Anlegen/Bearbeiten eines wiederkehrenden Auftrags.
class _ScheduleSheet extends StatefulWidget {
  const _ScheduleSheet({this.existing});
  final Map<String, dynamic>? existing;

  @override
  State<_ScheduleSheet> createState() => _ScheduleSheetState();
}

class _ScheduleSheetState extends State<_ScheduleSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _instrCtrl;
  String _cadence = 'weekly';
  int _dayOfWeek = 1;
  int _hourUtc = 6;
  bool _awaitReview = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _titleCtrl = TextEditingController(text: e?['title'] as String? ?? '');
    _instrCtrl =
        TextEditingController(text: e?['instruction'] as String? ?? '');
    _cadence = e?['cadence'] as String? ?? 'weekly';
    _dayOfWeek = (e?['day_of_week'] as num?)?.toInt() ?? 1;
    _hourUtc = (e?['hour_utc'] as num?)?.toInt() ?? 6;
    _awaitReview = e?['await_review'] == true;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _instrCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().length < 2 ||
        _instrCtrl.text.trim().length < 5) {
      return;
    }
    setState(() => _saving = true);
    final res = await AiInsightsRepository.saveDevSchedule(
      id: widget.existing?['id'] as String?,
      title: _titleCtrl.text.trim(),
      instruction: _instrCtrl.text.trim(),
      cadence: _cadence,
      dayOfWeek: _dayOfWeek,
      hourUtc: _hourUtc,
      awaitReview: _awaitReview,
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (res['ok'] == true) {
      Navigator.of(context).pop(true);
    } else {
      AppSnackBar.error(context, 'adminDev.schedules.saveFailed'.tr());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: AppColors.lightLine,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text('adminDev.schedules.add'.tr(),
                style: AppTypography.body(
                    size: 16,
                    color: AppColors.lightInk,
                    weight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'adminDev.schedules.titleField'.tr(),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _instrCtrl,
              maxLines: 4,
              minLines: 2,
              decoration: InputDecoration(
                labelText: 'adminDev.schedules.instructionField'.tr(),
                hintText: 'adminDev.placeholder'.tr(),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            // Frequenz-Auswahl.
            Row(
              children: [
                for (final c in const ['daily', 'weekly', 'monthly'])
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('adminDev.schedules.cadence.$c'.tr(),
                          style: AppTypography.body(
                              size: 11,
                              color: _cadence == c
                                  ? Colors.white
                                  : AppColors.lightInk)),
                      selected: _cadence == c,
                      selectedColor: AppColors.teal,
                      onSelected: (_) => setState(() => _cadence = c),
                    ),
                  ),
              ],
            ),
            if (_cadence == 'weekly') ...[
              const SizedBox(height: 10),
              Text('adminDev.schedules.weekday'.tr(),
                  style:
                      AppTypography.body(size: 11, color: AppColors.lightMute)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                children: [
                  for (var d = 0; d < 7; d++)
                    ChoiceChip(
                      label: Text('adminDev.schedules.weekdays.$d'.tr(),
                          style: AppTypography.body(
                              size: 11,
                              color: _dayOfWeek == d
                                  ? Colors.white
                                  : AppColors.lightInk)),
                      selected: _dayOfWeek == d,
                      selectedColor: AppColors.teal,
                      onSelected: (_) => setState(() => _dayOfWeek = d),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Text('adminDev.schedules.hour'.tr(),
                    style: AppTypography.body(
                        size: 11, color: AppColors.lightMute)),
                const SizedBox(width: 10),
                Expanded(
                  child: Slider(
                    value: _hourUtc.toDouble(),
                    min: 0,
                    max: 23,
                    divisions: 23,
                    label: '${_hourUtc.toString().padLeft(2, '0')}:00 UTC',
                    activeColor: AppColors.teal,
                    onChanged: (v) => setState(() => _hourUtc = v.round()),
                  ),
                ),
                Text('${_hourUtc.toString().padLeft(2, '0')}:00',
                    style: AppTypography.body(
                        size: 12, color: AppColors.lightInk)),
              ],
            ),
            _MiniToggle(
              label: 'adminDev.reviewBeforeMerge'.tr(),
              value: _awaitReview,
              onChanged: (v) => setState(() => _awaitReview = v),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style:
                    FilledButton.styleFrom(backgroundColor: AppColors.teal),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text('common.save'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Modul-Intelligenz ────────────────────────────────────────────────────────

class _ModuleIntelligenceCard extends StatelessWidget {
  const _ModuleIntelligenceCard({
    required this.insights,
    required this.scan,
    required this.expanded,
    required this.loading,
    required this.busyIds,
    required this.onToggle,
    required this.onScan,
    required this.onAccept,
    required this.onDismiss,
  });

  final List<Map<String, dynamic>> insights;
  final Map<String, dynamic>? scan;
  final bool expanded;
  final bool loading;
  final Set<String> busyIds;
  final VoidCallback onToggle;
  final VoidCallback onScan;
  final void Function(String) onAccept;
  final void Function(String) onDismiss;

  bool get _scanning {
    final s = scan?['status'] as String?;
    return s == 'queued' || s == 'running';
  }

  Color _severityColor(String s) {
    switch (s) {
      case 'critical':
        return Colors.red.shade600;
      case 'high':
        return Colors.orange.shade600;
      case 'medium':
        return Colors.amber.shade700;
      default:
        return AppColors.leben;
    }
  }

  Color _typeColor(String t) {
    switch (t) {
      case 'vulnerability':
        return Colors.red.shade600;
      case 'new_module':
        return Colors.indigo.shade500;
      case 'extension':
        return Colors.purple.shade500;
      case 'inspiration':
        return Colors.blue.shade500;
      default:
        return AppColors.teal;
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = insights.length;
    final scanDone = scan?['status'] == 'done';
    final insightsCount = scan?['insights_count'] as int? ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0D000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(LucideIcons.brain,
                        size: 16, color: Colors.indigo.shade500),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'adminDev.modules.title'.tr(),
                          style: AppTypography.body(
                                  size: 13, color: AppColors.lightInk)
                              .copyWith(fontWeight: FontWeight.w600),
                        ),
                        if (_scanning)
                          Text(
                            'adminDev.modules.scanning'.tr(),
                            style: AppTypography.body(
                                size: 11, color: AppColors.lightMute),
                          )
                        else if (scanDone && insightsCount > 0)
                          Text(
                            'adminDev.modules.scanDone'
                                .tr(namedArgs: {'count': '$insightsCount'}),
                            style: AppTypography.body(
                                size: 11, color: AppColors.lightMute),
                          )
                        else
                          Text(
                            'adminDev.modules.subtitle'.tr(),
                            style: AppTypography.body(
                                size: 11, color: AppColors.lightMute),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  if (count > 0)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: AppTypography.body(
                            size: 11, color: Colors.indigo.shade600),
                      ),
                    ),
                  if (_scanning)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: onScan,
                      icon: const Icon(LucideIcons.sparkles, size: 13),
                      label: Text('adminDev.modules.scanStart'.tr(),
                          style: AppTypography.body(size: 11)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.indigo.shade600,
                        side: BorderSide(color: Colors.indigo.shade200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  const SizedBox(width: 4),
                  Icon(
                    expanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 16,
                    color: AppColors.lightMute,
                  ),
                ],
              ),
            ),
          ),
          // Body
          if (expanded) ...[
            const Divider(height: 1),
            if (loading && insights.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (insights.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'adminDev.modules.empty'.tr(),
                  style: AppTypography.body(
                      size: 12, color: AppColors.lightMute),
                  textAlign: TextAlign.center,
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                itemCount: insights.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final ins = insights[i];
                  final id = ins['id'] as String? ?? '';
                  final busy = busyIds.contains(id);
                  return _ModuleInsightCard(
                    insight: ins,
                    busy: busy,
                    severityColor: _severityColor(
                        ins['severity'] as String? ?? 'medium'),
                    typeColor:
                        _typeColor(ins['insight_type'] as String? ?? ''),
                    onAccept: () => onAccept(id),
                    onDismiss: () => onDismiss(id),
                  );
                },
              ),
          ],
        ],
      ),
    );
  }
}

class _ModuleInsightCard extends StatelessWidget {
  const _ModuleInsightCard({
    required this.insight,
    required this.busy,
    required this.severityColor,
    required this.typeColor,
    required this.onAccept,
    required this.onDismiss,
  });

  final Map<String, dynamic> insight;
  final bool busy;
  final Color severityColor;
  final Color typeColor;
  final VoidCallback onAccept;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final module = insight['module_name'] as String? ?? '';
    final type = insight['insight_type'] as String? ?? 'improvement';
    final severity = insight['severity'] as String? ?? 'medium';
    final title = insight['title'] as String? ?? '';
    final description = insight['description'] as String? ?? '';
    final source = insight['source'] as String? ?? 'analysis';
    final refUrl = insight['reference_url'] as String?;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Module + type + severity badges
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  module,
                  style: AppTypography.body(
                      size: 10, color: AppColors.teal),
                ),
              ),
              const SizedBox(width: 5),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  'adminDev.modules.types.$type'.tr(),
                  style: AppTypography.body(size: 10, color: typeColor),
                ),
              ),
              const Spacer(),
              // Severity dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: severityColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                'adminDev.severity.$severity'.tr(),
                style: AppTypography.body(
                    size: 10, color: AppColors.lightMute),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            title,
            style: AppTypography.body(size: 12, color: AppColors.lightInk)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              description,
              style:
                  AppTypography.body(size: 11, color: AppColors.lightMute),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          // Source + ref
          const SizedBox(height: 5),
          Row(
            children: [
              Icon(
                source == 'github'
                    ? LucideIcons.github
                    : source == 'research'
                        ? LucideIcons.search
                        : LucideIcons.terminal,
                size: 11,
                color: AppColors.lightMute,
              ),
              const SizedBox(width: 4),
              Text(
                'adminDev.modules.sources.$source'.tr(),
                style: AppTypography.body(
                    size: 10, color: AppColors.lightMute),
              ),
              if (refUrl != null && refUrl.isNotEmpty) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => safeLaunch(refUrl),
                  child: Text(
                    '↗',
                    style: AppTypography.body(
                        size: 11, color: AppColors.teal),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          // Actions
          if (busy)
            const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDismiss,
                    icon: const Icon(LucideIcons.x, size: 12),
                    label: Text('adminDev.modules.dismiss'.tr(),
                        style: AppTypography.body(size: 11)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.lightMute,
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                      padding:
                          const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: Size.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: onAccept,
                    icon: const Icon(LucideIcons.play, size: 12),
                    label: Text('adminDev.modules.accept'.tr(),
                        style: AppTypography.body(
                            size: 11, color: Colors.white)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo.shade500,
                      padding:
                          const EdgeInsets.symmetric(vertical: 6),
                      minimumSize: Size.zero,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// Findet einen Auftrag mit starker Wortüberschneidung zu [text] in [existing]
// (Duplikat-/Konflikt-Erkennung). Gibt den (gekürzten) Treffer zurück oder null.
/// Wählt automatisch das am besten passende Epic für einen Vorschlag — per
/// Wort-Überlappung zwischen Vorschlag (Titel + Instruction) und Epic
/// (Titel + Beschreibung). Liefert die Epic-ID oder null (keine klare Zuordnung).
String? _bestEpicIdFor(
    Map<String, dynamic> suggestion, List<Map<String, dynamic>> epics) {
  if (epics.isEmpty) return null;
  Set<String> tokens(String? s) => (s ?? '')
      .toLowerCase()
      .split(RegExp(r'\W+'))
      .where((w) => w.length > 3)
      .toSet();
  final sugTokens = tokens(suggestion['title'] as String?)
    ..addAll(tokens(suggestion['instruction'] as String?));
  if (sugTokens.isEmpty) return null;
  String? bestId;
  var bestOverlap = 0;
  for (final e in epics) {
    if ((e['status'] as String?) == 'archived') continue;
    final epicTokens = tokens(e['title'] as String?)
      ..addAll(tokens(e['description'] as String?));
    final overlap = sugTokens.intersection(epicTokens).length;
    if (overlap > bestOverlap) {
      bestOverlap = overlap;
      bestId = e['id'] as String?;
    }
  }
  // Mindestens 2 gemeinsame Wörter für eine sinnvolle Zuordnung.
  return bestOverlap >= 2 ? bestId : null;
}

/// Relative Zeitangabe ("vor 3 min", "vor 2 h", "vor 4 d") aus ISO-Timestamp.
String? _relativeTime(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final dt = DateTime.tryParse(iso);
  if (dt == null) return null;
  final diff = DateTime.now().difference(dt.toLocal());
  if (diff.inSeconds < 60) return 'adminDev.time.now'.tr();
  if (diff.inMinutes < 60) {
    return 'adminDev.time.min'.tr(namedArgs: {'n': '${diff.inMinutes}'});
  }
  if (diff.inHours < 24) {
    return 'adminDev.time.hour'.tr(namedArgs: {'n': '${diff.inHours}'});
  }
  return 'adminDev.time.day'.tr(namedArgs: {'n': '${diff.inDays}'});
}

/// Kurzes Label für die Modell-ID eines Auftrags (Badge im Dashboard).
String? _modelShortLabel(String? id) {
  if (id == null || id.isEmpty) return null;
  if (id.contains('opus')) return 'Opus';
  if (id.contains('sonnet')) return 'Sonnet';
  if (id.contains('haiku')) return 'Haiku';
  return null;
}

String? similarInstruction(String text, Iterable<String> existing) {
  if (text.length < 10) return null;
  final words =
      text.toLowerCase().split(RegExp(r'\W+')).where((w) => w.length > 4).toSet();
  if (words.isEmpty) return null;
  for (final instr in existing) {
    final ew = instr
        .toLowerCase()
        .split(RegExp(r'\W+'))
        .where((w) => w.length > 4)
        .toSet();
    final overlap = words.intersection(ew).length;
    if (overlap >= 3 && overlap / words.length > 0.4) {
      return instr.length > 60 ? '${instr.substring(0, 60)}…' : instr;
    }
  }
  return null;
}

// Ergebnis des Edit-Sheets: der (bearbeitete) Prompt + die gewählten Optionen.
class _PromptEditResult {
  const _PromptEditResult({
    required this.instruction,
    required this.awaitReview,
    required this.planMode,
    required this.wantScreens,
    required this.model,
    this.epicId,
  });
  final String instruction;
  final bool awaitReview;
  final bool planMode;
  final bool wantScreens;
  final String model; // 'standard' (Sonnet 5) | 'thorough' (Opus 4.8)
  final String? epicId; // optionale Roadmap-Zuordnung
}

// Wiederverwendbares Sheet zum Bearbeiten eines Prompts vor dem Absenden.
// Genutzt für: Vorschlag annehmen (bearbeitbar), mehrere Vorschläge bündeln,
// und fehlgeschlagene Aufträge mit angepasstem Prompt neu starten. Bietet
// dieselben Optionen wie das freie Eingabefeld (Review-Gate, Plan, Screenshots).
class _PromptEditSheet extends StatefulWidget {
  const _PromptEditSheet({
    required this.title,
    required this.confirmLabel,
    required this.initialText,
    this.hint,
    this.epics = const [],
    this.initialEpicId,
  });
  final String title;
  final String confirmLabel;
  final String initialText;
  final String? hint;
  final List<Map<String, dynamic>> epics;
  final String? initialEpicId;

  @override
  State<_PromptEditSheet> createState() => _PromptEditSheetState();
}

class _PromptEditSheetState extends State<_PromptEditSheet> {
  late final TextEditingController _ctrl;
  bool _awaitReview = false;
  bool _planMode = false;
  bool _wantScreens = false;
  String _model = 'standard'; // standard (Sonnet 5) | thorough (Opus 4.8)
  String? _epicId;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialText);
    _epicId = widget.initialEpicId;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('adminDev.edit.emptyPrompt'.tr()),
          backgroundColor: Colors.red.shade700,
        ),
      );
      return;
    }
    Navigator.of(context).pop(_PromptEditResult(
      instruction: text,
      awaitReview: _awaitReview,
      planMode: _planMode,
      wantScreens: _wantScreens,
      model: _model,
      epicId: _epicId,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.lightLine,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(LucideIcons.pencil, size: 18, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: AppTypography.body(
                          size: 14,
                          color: AppColors.lightInk,
                          weight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, size: 18),
                    color: AppColors.lightMute,
                  ),
                ],
              ),
              if (widget.hint != null) ...[
                const SizedBox(height: 2),
                Text(
                  widget.hint!,
                  style:
                      AppTypography.body(size: 12, color: AppColors.lightMute),
                ),
              ],
              const SizedBox(height: 10),
              TextField(
                controller: _ctrl,
                autofocus: true,
                maxLines: 12,
                minLines: 4,
                style: AppTypography.body(size: 13, color: AppColors.lightInk),
                decoration: InputDecoration(
                  labelText: 'adminDev.edit.promptLabel'.tr(),
                  alignLabelWithHint: true,
                  filled: true,
                  fillColor: AppColors.lightElevated,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _MiniToggle(
                label: 'adminDev.reviewBeforeMerge'.tr(),
                value: _awaitReview,
                onChanged: (v) => setState(() => _awaitReview = v),
              ),
              _MiniToggle(
                label: 'adminDev.plan.toggle'.tr(),
                value: _planMode,
                onChanged: (v) => setState(() => _planMode = v),
              ),
              _MiniToggle(
                label: 'adminDev.screens.toggle'.tr(),
                value: _wantScreens,
                onChanged: (v) => setState(() => _wantScreens = v),
              ),
              const SizedBox(height: 10),
              Text('adminDev.model.label'.tr().toUpperCase(),
                  style: AppTypography.label(
                      size: 9, color: AppColors.lightMute)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                children: [
                  for (final m in const ['standard', 'thorough'])
                    ChoiceChip(
                      label: Text('adminDev.model.$m'.tr(),
                          style: AppTypography.label(size: 10)),
                      selected: _model == m,
                      onSelected: (_) => setState(() => _model = m),
                      selectedColor: AppColors.teal.withValues(alpha: 0.25),
                      backgroundColor: AppColors.lightRaised,
                    ),
                ],
              ),
              if (widget.epics.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('adminDev.roadmap.assignLabel'.tr().toUpperCase(),
                    style: AppTypography.label(
                        size: 9, color: AppColors.lightMute)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      label: Text('adminDev.roadmap.noEpic'.tr(),
                          style: AppTypography.label(size: 10)),
                      selected: _epicId == null,
                      onSelected: (_) => setState(() => _epicId = null),
                      selectedColor: AppColors.teal.withValues(alpha: 0.25),
                      backgroundColor: AppColors.lightRaised,
                    ),
                    for (final e in widget.epics)
                      ChoiceChip(
                        label: Text(e['title'] as String? ?? '',
                            style: AppTypography.label(size: 10)),
                        selected: _epicId == e['id'],
                        onSelected: (_) =>
                            setState(() => _epicId = e['id'] as String?),
                        selectedColor: AppColors.teal.withValues(alpha: 0.25),
                        backgroundColor: AppColors.lightRaised,
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(LucideIcons.check, size: 16),
                  label: Text(widget.confirmLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniToggle extends StatelessWidget {
  const _MiniToggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label,
              style: AppTypography.body(size: 12, color: AppColors.lightMute)),
        ),
        Transform.scale(
          scale: 0.8,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: AppColors.teal,
          ),
        ),
      ],
    );
  }
}
