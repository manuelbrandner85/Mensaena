// ignore_for_file: lines_longer_than_80_chars
import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../config/theme/app_colors.dart';
import '../../../config/theme/app_typography.dart';
import '../../../repositories/ai_insights_repository.dart';
import '../../../utils/safe_launch.dart';
import '../../../widgets/layouts/dashboard_scaffold.dart';

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

class _AdminAiDevScreenState extends ConsumerState<AdminAiDevScreen> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _tasks = const [];
  List<Map<String, dynamic>> _suggestions = const [];
  Map<String, dynamic>? _scan;
  final Set<String> _busySuggestions = {};
  bool _loading = true;
  bool _sending = false;
  bool _suggestionsLoading = false;
  _DevCategory _category = _DevCategory.all;
  String _severity = 'all';

  // Mehrfachauswahl
  bool _selectionMode = false;
  final Set<String> _selected = {};
  bool _batchBusy = false;

  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _refresh();
    _loadSuggestions();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_scanning) _loadSuggestions(silent: true);
      if (_hasActive) _refresh(silent: true);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _poll?.cancel();
    super.dispose();
  }

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
    final sorted = [...list]..sort((a, b) {
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
    setState(() {
      _tasks = rows;
      _loading = false;
    });
  }

  Future<void> _loadSuggestions({bool silent = false}) async {
    if (!silent) setState(() => _suggestionsLoading = true);
    final data = await AiInsightsRepository.fetchDevSuggestions(
      category: _category == _DevCategory.all ? null : _category.name,
    );
    if (!mounted) return;
    setState(() {
      _suggestions = ((data['suggestions'] as List?) ?? const [])
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('adminDev.scanStarted'.tr())),
      );
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

  Future<void> _accept(String id) async {
    setState(() => _busySuggestions.add(id));
    final res = await AiInsightsRepository.acceptSuggestion(id);
    if (!mounted) return;
    setState(() => _busySuggestions.remove(id));
    if (res['ok'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('adminDev.accepted'.tr())),
      );
      await _loadSuggestions(silent: true);
      await _refresh(silent: true);
    } else {
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

  Future<void> _acceptSelected() async {
    if (_selected.isEmpty || _batchBusy) return;
    setState(() => _batchBusy = true);
    final ids = _selected.toList();
    final res = await AiInsightsRepository.acceptManySuggestions(ids);
    if (!mounted) return;
    setState(() {
      _batchBusy = false;
      _selectionMode = false;
      _selected.clear();
    });
    if (res['ok'] == true) {
      final n = (res['accepted'] as num?)?.toInt() ?? ids.length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('adminDev.acceptedMany'
                .tr(namedArgs: {'count': '$n'}))),
      );
      await _loadSuggestions(silent: true);
      await _refresh(silent: true);
    } else {
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

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _ctrl.text).trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);

    final prefix =
        _category != _DevCategory.all ? '[${_category.englishName}] ' : '';
    final res = await AiInsightsRepository.createDevTask('$prefix$text');
    if (!mounted) return;

    final error = res['error'] as String?;
    final ok = res['ok'] == true;
    setState(() => _sending = false);

    if (ok) {
      _ctrl.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('adminDev.queued'.tr())),
      );
      await _refresh(silent: true);
    } else {
      _showError(error);
    }
  }

  String get _placeholder {
    switch (_category) {
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
    final visible = _visibleSuggestions;
    return DashboardScaffold(
      title: 'adminDev.title'.tr(),
      currentRoute: '/dashboard/admin/dev-agent',
      body: SafeArea(
        child: Column(
          children: [
            _GodmodeHeader(),
            _CategoryRow(
              selected: _category,
              onSelect: (c) {
                setState(() => _category = c);
                _loadSuggestions();
              },
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.teal,
                onRefresh: () async {
                  await _refresh();
                  await _loadSuggestions(silent: true);
                },
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        children: [
                          _LiveScanCard(
                            scanning: _scanning,
                            scan: _scan,
                            loading: _suggestionsLoading,
                            onScan: _startScan,
                          ),
                          const SizedBox(height: 10),
                          if (_suggestions.isNotEmpty) ...[
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
                            ...visible.map((s) => _SuggestionCard(
                                  suggestion: s,
                                  busy: _busySuggestions
                                      .contains(s['id'] as String?),
                                  selectionMode: _selectionMode,
                                  selected:
                                      _selected.contains(s['id'] as String?),
                                  onToggleSelect: _toggleSelected,
                                  onAccept: _accept,
                                  onReject: _reject,
                                )),
                            const SizedBox(height: 14),
                          ],
                          if (_tasks.isNotEmpty)
                            _SectionLabel(
                              icon: LucideIcons.gitPullRequest,
                              label: 'adminDev.tasksLabel'.tr(),
                              count: _tasks.length,
                            ),
                          if (_tasks.isEmpty && _suggestions.isEmpty)
                            _EmptyHint(),
                          ..._tasks.map((t) => _TaskCard(task: t)),
                          const SizedBox(height: 12),
                        ],
                      ),
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
            ),
          ],
        ),
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
  const _CategoryRow({required this.selected, required this.onSelect});
  final _DevCategory selected;
  final void Function(_DevCategory) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      color: Colors.white,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        children: _DevCategory.values.map((cat) {
          final active = cat == selected;
          return GestureDetector(
            onTap: () => onSelect(cat),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
              decoration: BoxDecoration(
                color: active ? AppColors.teal : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? AppColors.teal : Colors.grey.shade200,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat.icon,
                      size: 12,
                      color: active ? Colors.white : AppColors.lightMute),
                  const SizedBox(width: 5),
                  Text(
                    cat.i18nKey.tr(),
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
        }).toList(),
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
                color: active ? c.withValues(alpha: 0.14) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: active ? c : Colors.grey.shade200,
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

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scan = widget.scan;
    final scanning = widget.scanning;
    final currentFile = scan?['current_file'] as String?;
    final analyzed = (scan?['analyzed_files'] as num?)?.toInt() ?? 0;
    final foundSoFar = (scan?['found_so_far'] as num?)?.toInt() ?? 0;
    final found = (scan?['found'] as num?)?.toInt() ?? 0;
    final isDone = (scan?['status'] as String?) == 'done';

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
                      opacity:
                          Tween(begin: 0.35, end: 1.0).animate(_ac),
                      child: const Icon(LucideIcons.radar,
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
                    opacity: Tween(begin: 0.3, end: 1.0).animate(_ac),
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
              ],
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
              color: Colors.grey.shade100,
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
                selectionMode ? LucideIcons.x : LucideIcons.listChecks,
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
      {required this.icon, required this.label, required this.count});
  final IconData icon;
  final String label;
  final int count;

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
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('$count',
                style:
                    AppTypography.body(size: 10, color: AppColors.lightMute)),
          ),
        ],
      ),
    );
  }
}

// ── Suggestion Card ───────────────────────────────────────────────────────────

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.busy,
    required this.selectionMode,
    required this.selected,
    required this.onToggleSelect,
    required this.onAccept,
    required this.onReject,
  });
  final Map<String, dynamic> suggestion;
  final bool busy;
  final bool selectionMode;
  final bool selected;
  final void Function(String) onToggleSelect;
  final void Function(String) onAccept;
  final void Function(String) onReject;

  @override
  Widget build(BuildContext context) {
    final id = suggestion['id'] as String? ?? '';
    final title = suggestion['title'] as String? ?? '';
    final description = suggestion['description'] as String? ?? '';
    final category = suggestion['category'] as String? ?? 'feature';
    final severity = suggestion['severity'] as String? ?? 'medium';
    final fileHint = suggestion['file_hint'] as String?;
    final sevColor = _severityColor(severity);

    final card = Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: selected ? AppColors.teal.withValues(alpha: 0.06) : Colors.white,
        borderRadius: BorderRadius.circular(13),
        border: Border(
          left: BorderSide(color: sevColor, width: 3),
          top: BorderSide(
              color: selected ? AppColors.teal : Colors.transparent),
          right: BorderSide(
              color: selected ? AppColors.teal : Colors.transparent),
          bottom: BorderSide(
              color: selected ? AppColors.teal : Colors.transparent),
        ),
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
                      : LucideIcons.square,
                  size: 18,
                  color: selected ? AppColors.teal : AppColors.lightMute,
                ),
                const SizedBox(width: 8),
              ],
              _Badge(
                  text: 'adminDev.categories.$category'.tr(),
                  color: AppColors.teal),
              const SizedBox(width: 6),
              _Badge(
                  text: 'adminDev.severity.$severity'.tr(), color: sevColor),
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
                    onPressed: busy ? null : () => onAccept(id),
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
                    side: BorderSide(color: Colors.grey.shade300),
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
                side: BorderSide(color: Colors.grey.shade300),
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
  const _TaskCard({required this.task});
  final Map<String, dynamic> task;

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
    final meta = _statusMeta(status);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: meta.color, width: 3)),
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
              const Spacer(),
              if (status == 'queued' ||
                  status == 'running' ||
                  status == 'pr_open')
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.teal),
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
        ],
      ),
    );
  }

  _StatusMeta _statusMeta(String status) {
    switch (status) {
      case 'merged':
        return _StatusMeta(LucideIcons.checkCircle2, Colors.green.shade600);
      case 'pr_open':
        return _StatusMeta(LucideIcons.gitPullRequest, AppColors.teal);
      case 'running':
        return _StatusMeta(LucideIcons.loader, AppColors.amber);
      case 'failed':
        return _StatusMeta(LucideIcons.xCircle, Colors.red.shade600);
      case 'no_changes':
        return _StatusMeta(LucideIcons.minusCircle, AppColors.lightMute);
      default:
        return _StatusMeta(LucideIcons.clock, AppColors.lightMute);
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
      case 'merged':
        s[0] = _Stage.done;
        s[1] = _Stage.done;
        s[2] = _Stage.done;
        s[3] = _Stage.done;
        s[4] = _Stage.active; // OTA läuft
        break;
      case 'failed':
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
        return Colors.grey.shade300;
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
                      ? Colors.grey.shade300
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

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.ctrl,
    required this.sending,
    required this.placeholder,
    required this.onSend,
  });
  final TextEditingController ctrl;
  final bool sending;
  final String placeholder;
  final Future<void> Function([String?]) onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              enabled: !sending,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: placeholder,
                hintStyle:
                    AppTypography.body(size: 13, color: AppColors.lightMute),
                filled: true,
                fillColor: Colors.grey.shade50,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(22),
                  borderSide: BorderSide(color: Colors.grey.shade200),
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
            onPressed: sending ? null : () => onSend(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(14),
            ),
            child: sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(LucideIcons.send, size: 18, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
