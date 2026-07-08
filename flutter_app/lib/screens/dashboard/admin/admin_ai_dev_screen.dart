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

part 'admin_ai_dev/overview_tab_widgets.dart';
part 'admin_ai_dev/suggestions_tab_widgets.dart';
part 'admin_ai_dev/tasks_tab_widgets.dart';
part 'admin_ai_dev/chat_widgets.dart';
part 'admin_ai_dev/settings_tab_widgets.dart';
part 'admin_ai_dev/roadmap_tab_widgets.dart';
part 'admin_ai_dev/module_intelligence_widgets.dart';
part 'admin_ai_dev/prompt_edit_widgets.dart';

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
      status == 'already_done' ||
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

  // Duplikat-/Konflikt-Check. true = fortfahren.
  // (B) Prüft zwei Fälle: (1) ein ähnlicher Auftrag LÄUFT gerade, (2) ein
  // ähnlicher Auftrag wurde kürzlich schon ERLEDIGT (merged/live/already_done)
  // — verhindert, dass bereits Umgesetztes erneut abgeschickt wird und als
  // Dead-End im Dashboard landet.
  Future<bool> _confirmNotDuplicate(String instruction) async {
    String? instr(Map<String, dynamic> t) =>
        (t['instruction'] as String?)?.trim();

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
        .map((t) => instr(t) ?? '')
        .where((x) => x.isNotEmpty);
    // Kürzlich erfolgreich abgeschlossen (nicht failed/cancelled — die dürfen
    // bewusst neu versucht werden).
    final doneRecently = _tasks
        .where((t) {
          final s = t['status'] as String?;
          return s == 'merged' ||
              s == 'live' ||
              s == 'already_done';
        })
        .map((t) => instr(t) ?? '')
        .where((x) => x.isNotEmpty);

    final simActive = similarInstruction(instruction, active);
    final simDone =
        simActive == null ? similarInstruction(instruction, doneRecently) : null;
    if ((simActive == null && simDone == null) || !mounted) return true;

    final isDone = simActive == null;
    final match = simActive ?? simDone!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.lightSurface,
        title: Row(children: [
          Icon(isDone ? LucideIcons.checkCheck : LucideIcons.copy,
              size: 18, color: isDone ? AppColors.leben : AppColors.amber),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  (isDone
                          ? 'adminDev.alreadyDoneTitle'
                          : 'adminDev.duplicateTitle')
                      .tr(),
                  style: AppTypography.display(
                      size: 16, color: AppColors.lightInk))),
        ]),
        content: Text(
          (isDone ? 'adminDev.alreadyDoneWarning' : 'adminDev.duplicateWarning')
              .tr(namedArgs: {'task': match}),
          style: AppTypography.body(size: 13, color: AppColors.lightInkSoft),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('common.cancel'.tr()),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor:
                    isDone ? AppColors.leben : AppColors.amber),
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
                    tooltip: 'common.remove'.tr(),
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
