import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../models/timebank_entry.dart';
import '../../repositories/timebank_repository.dart';
import '../../services/haptics.dart';
import '../../services/supabase_service.dart';
import '../../widgets/layouts/dashboard_scaffold.dart';
import '../../widgets/shared/user_picker_sheet.dart';
import '../../widgets/shared/skeleton_card.dart';
import '../../widgets/shared/app_snackbar.dart';

/// SKILL: mensaena-features
/// Zeitbank-Screen: Stundenkonto + Eintraege-Historie + Bestaetigungs-System.
class TimebankScreen extends ConsumerStatefulWidget {
  const TimebankScreen({super.key});

  @override
  ConsumerState<TimebankScreen> createState() => _TimebankScreenState();
}

class _TimebankScreenState extends ConsumerState<TimebankScreen> {
  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(timebankBalanceProvider);
    final entries = ref.watch(timebankEntriesProvider);
    return DashboardScaffold(
      title: 'timebank.screenTitle'.tr(),
      currentRoute: '/dashboard/timebank',
      // Neuer Eintrag: Repo-Methode existierte schon lange, das Formular
      // fehlte — Nutzer:innen konnten faktisch keine Stunden eintragen.
      fab: FloatingActionButton.extended(
        backgroundColor: AppColors.amber,
        foregroundColor: AppColors.voidColor,
        icon: const Icon(LucideIcons.plus, size: 18),
        label: Text('timebank.newEntry'.tr(),
            style: AppTypography.label(
                size: 11,
                color: AppColors.voidColor,
                weight: FontWeight.w700)),
        onPressed: () => _openCreateSheet(context),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.amber,
          backgroundColor: AppColors.surface,
          onRefresh: () async {
            ref.invalidate(timebankBalanceProvider);
            ref.invalidate(timebankEntriesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _BalanceCard(balance: balance),
              const SizedBox(height: 16),
              Text('timebank.history'.tr(), style: AppTypography.label(size: 10)),
              const SizedBox(height: 8),
              entries.when(
                loading: () => const SkeletonList(count: 5, itemHeight: 96),
                error: (e, _) => Text(
                  'Fehler: $e',
                  style: AppTypography.caption(),
                ),
                data: (list) {
                  if (list.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.4),
                        border: Border.all(color: AppColors.line),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            LucideIcons.clock,
                            size: 28,
                            color: AppColors.mute,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'timebank.emptyHint'.tr(),
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              size: 13,
                              color: AppColors.inkSoft,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: list.map((e) => _EntryTile(entry: e)).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Öffnet das Create-Sheet, lässt den Geber den Empfänger und die Stunden
  /// wählen und legt den Eintrag (pending) an. Empfänger muss anschließend
  /// im Sheet bestätigen — entspricht dem bestehenden Confirm-Flow.
  Future<void> _openCreateSheet(BuildContext rootContext) async {
    await showModalBottomSheet<void>(
      context: rootContext,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateEntrySheet(onCreated: () {
        ref.invalidate(timebankBalanceProvider);
        ref.invalidate(timebankEntriesProvider);
      }),
    );
  }
}

/// Formular für neuen Timebank-Eintrag (als Geber). Felder: Empfänger
/// (UserPicker), Stunden (mit Komma-Toleranz), Kategorie (Chip-Auswahl),
/// Beschreibung. Submit → TimebankRepository.create.
class _CreateEntrySheet extends StatefulWidget {
  const _CreateEntrySheet({required this.onCreated});
  final VoidCallback onCreated;

  @override
  State<_CreateEntrySheet> createState() => _CreateEntrySheetState();
}

class _CreateEntrySheetState extends State<_CreateEntrySheet> {
  String? _receiverId;
  String? _receiverName;
  final _hoursCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String? _category;
  bool _submitting = false;
  String? _error;

  // Kategorie-Schlüssel passen zu timebank_entries.category-Werten der
  // bestehenden Bestätigungs-Anzeige (Hilfe/Pflege/Handwerk/Garten/Sonstiges).
  static const List<({String key, String label})> _categories = [
    (key: 'help', label: '🤝 Hilfe'),
    (key: 'care', label: '🫂 Pflege'),
    (key: 'craft', label: '🔧 Handwerk'),
    (key: 'garden', label: '🌱 Garten'),
    (key: 'other', label: '✨ Sonstiges'),
  ];

  @override
  void dispose() {
    _hoursCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickReceiver() async {
    await UserPickerSheet.show(
      context,
      title: 'timebank.pickReceiver'.tr(),
      pickedLabelKey: 'timebank.receiverChosen',
      onPick: (id, name) async {
        setState(() {
          _receiverId = id;
          _receiverName = name;
        });
        return true; // wir speichern lokal, Insert erst beim Submit
      },
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final receiverId = _receiverId;
    final hours = double.tryParse(
        _hoursCtrl.text.replaceAll(',', '.').trim());
    final desc = _descCtrl.text.trim();
    if (receiverId == null) {
      setState(() => _error = 'timebank.errReceiverMissing'.tr());
      return;
    }
    if (hours == null || hours <= 0 || hours > 24) {
      setState(() => _error = 'timebank.errHoursInvalid'.tr());
      return;
    }
    if (desc.length < 3) {
      setState(() => _error = 'timebank.errDescTooShort'.tr());
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final ok = await TimebankRepository.create(
      receiverId: receiverId,
      hours: hours,
      description: desc,
      category: _category,
    );
    if (!mounted) return;
    if (ok) {
      Haptics.confirm();
      widget.onCreated();
      Navigator.of(context).maybePop();
      AppSnackBar.info(context, 'timebank.createdPendingSnack'.tr());
    } else {
      setState(() {
        _submitting = false;
        _error = 'common.errorGeneric'.tr();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text('timebank.newEntryTitle'.tr(),
                  style:
                      AppTypography.display(size: 18, color: AppColors.ink)),
              const SizedBox(height: 4),
              Text('timebank.newEntryHint'.tr(),
                  style: AppTypography.caption()),
              const SizedBox(height: 14),
              InkWell(
                onTap: _pickReceiver,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    color: AppColors.elevated,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.userPlus,
                          size: 16, color: AppColors.amber),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _receiverName ?? 'timebank.pickReceiver'.tr(),
                          style: AppTypography.body(
                              size: 14,
                              color: _receiverName != null
                                  ? AppColors.ink
                                  : AppColors.inkSoft),
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight,
                          size: 14, color: AppColors.mute),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _hoursCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'timebank.hours'.tr(),
                  prefixIcon: const Icon(LucideIcons.clock, size: 16),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _descCtrl,
                maxLines: 3,
                maxLength: 280,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  labelText: 'timebank.description'.tr(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in _categories)
                    ChoiceChip(
                      label: Text(c.label),
                      selected: _category == c.key,
                      onSelected: (sel) =>
                          setState(() => _category = sel ? c.key : null),
                      labelStyle: AppTypography.label(
                          size: 10,
                          color: _category == c.key
                              ? AppColors.amber
                              : AppColors.inkSoft),
                      selectedColor:
                          AppColors.amber.withValues(alpha: 0.18),
                      backgroundColor:
                          AppColors.elevated.withValues(alpha: 0.6),
                      side: BorderSide(
                          color: _category == c.key
                              ? AppColors.amber
                              : AppColors.line),
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    style: AppTypography.body(
                        size: 12, color: AppColors.herzrotWarm)),
              ],
              const SizedBox(height: 14),
              SizedBox(
                height: 48,
                child: FilledButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.voidColor),
                        )
                      : const Icon(LucideIcons.check, size: 16),
                  label: Text('timebank.createBtn'.tr()),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.voidColor,
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

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.balance});
  final AsyncValue<TimebankBalance> balance;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.amber.withValues(alpha: 0.08),
        border: Border.all(color: AppColors.amber.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: balance.when(
        loading: () => const SkeletonList(count: 5, itemHeight: 96),
        error: (e, _) =>
            Text('$e', style: AppTypography.caption()),
        data: (b) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(LucideIcons.clock, color: AppColors.amber),
                const SizedBox(width: 8),
                Text(
                  'Stundenkonto',
                  style: AppTypography.label(size: 10),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  b.balance.toStringAsFixed(1),
                  style: AppTypography.display(
                    size: 38,
                    color: AppColors.ink,
                    height: 1.0,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'h',
                  style: AppTypography.mono(
                    size: 18,
                    color: AppColors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              b.balance >= 0
                  ? 'Du hast mehr Hilfe bekommen als gegeben.'
                  : 'Du hast mehr Hilfe gegeben als bekommen.',
              style: AppTypography.caption(),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Gegeben',
                    value: b.given,
                    color: AppColors.teal,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Empfangen',
                    value: b.received,
                    color: AppColors.leben,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Offen',
                    value: b.pendingAsReceiver + b.pendingAsGiver,
                    color: AppColors.amber,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTypography.label(size: 9)),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(1)}h',
          style: AppTypography.mono(size: 16, color: color),
        ),
      ],
    );
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry});
  final TimebankEntry entry;

  static const Map<String, ({String label, Color color})> _status = {
    'pending': (label: 'Wartet', color: AppColors.amber),
    'confirmed': (label: 'Bestätigt', color: AppColors.leben),
    'rejected': (label: 'Abgelehnt', color: AppColors.herzrot),
    'cancelled': (label: 'Abgebrochen', color: AppColors.mute),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = SupabaseService.currentUser?.id;
    final isReceiver = entry.receiverId == me;
    final canConfirm = isReceiver && entry.status == 'pending';
    final s = _status[entry.status ?? 'pending'] ??
        (label: entry.status ?? 'pending', color: AppColors.mute);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.4),
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: 0.18),
                  border: Border.all(color: s.color.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(s.label,
                    style: AppTypography.label(size: 9, color: s.color)),
              ),
              const SizedBox(width: 8),
              Text(
                isReceiver ? 'Du empfangen' : 'Du gegeben',
                style: AppTypography.label(size: 9),
              ),
              const Spacer(),
              Text(
                '${entry.hours.toStringAsFixed(1)}h',
                style: AppTypography.mono(size: 14, color: AppColors.amber),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            entry.description,
            style: AppTypography.body(
              size: 13,
              color: AppColors.inkSoft,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DateFormat('dd.MM.yyyy HH:mm').format(entry.createdAt),
            style: AppTypography.caption(),
          ),
          if (canConfirm) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.leben,
                      foregroundColor: AppColors.voidColor,
                    ),
                    onPressed: () async {
                      final m = ScaffoldMessenger.of(context);
                      await TimebankRepository.confirm(entry.id);
                      ref.invalidate(timebankBalanceProvider);
                      ref.invalidate(timebankEntriesProvider);
                      m.showSnackBar(SnackBar(
                        backgroundColor: AppColors.surface,
                        content: Text('timebank.confirmedSnack'.tr(),
                            style: AppTypography.body(
                                size: 13, color: AppColors.ink)),
                      ));
                    },
                    child: Text('common.confirm'.tr()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final m = ScaffoldMessenger.of(context);
                      await TimebankRepository.reject(entry.id);
                      ref.invalidate(timebankBalanceProvider);
                      ref.invalidate(timebankEntriesProvider);
                      m.showSnackBar(SnackBar(
                        backgroundColor: AppColors.surface,
                        content: Text('timebank.rejectedSnack'.tr(),
                            style: AppTypography.body(
                                size: 13, color: AppColors.ink)),
                      ));
                    },
                    child: Text('common.reject'.tr()),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
