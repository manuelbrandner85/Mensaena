import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_empty_state.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_loading_skeleton.dart';
import '../../core/widgets/cinema_modal.dart';
import '../../core/widgets/cinema_sheet.dart';
import '../../core/widgets/cinema_table.dart';
import '../../core/widgets/cinema_toast.dart';
import '../../core/widgets/glow_button.dart';
import '../../services/supabase/database_service.dart';

final channelsListProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) async {
  return db.listChannels();
});

/// Admin-Channel-Verwaltung: Liste vorhandener Kanaele, anlegen,
/// bearbeiten und loeschen.
class ChannelsScreen extends ConsumerWidget {
  const ChannelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final channels = ref.watch(channelsListProvider);

    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'KANAELE'),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Channels verwalten',
                      style: MnTypography.display(size: 22),
                    ),
                  ),
                  GlowButton(
                    label: 'Neuer Channel',
                    icon: LucideIcons.plus,
                    onPressed: () => _openCreate(context, ref),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: channels.when(
                  loading: () => const CinemaLoadingSkeleton(
                    variant: SkeletonVariant.list,
                  ),
                  error: (e, _) => CinemaEmptyState(
                    icon: LucideIcons.alertCircle,
                    title: 'Fehler beim Laden',
                    message: e.toString(),
                  ),
                  data: (rows) {
                    if (rows.isEmpty) {
                      return const CinemaEmptyState(
                        icon: LucideIcons.hash,
                        title: 'Noch keine Channels.',
                        message: 'Lege den ersten Channel an.',
                      );
                    }
                    return SingleChildScrollView(
                      child: CinemaTable<Map<String, dynamic>>(
                        columns: [
                          CinemaTableColumn(
                            label: 'Name',
                            width: 160,
                            cellBuilder: (r) => Text(
                              (r['name'] as String?) ?? '—',
                              style: MnTypography.body(
                                weight: FontWeight.w600,
                              ),
                            ),
                          ),
                          CinemaTableColumn(
                            label: 'Slug',
                            width: 140,
                            cellBuilder: (r) => Text(
                              (r['slug'] as String?) ?? '',
                              style: MnTypography.mono(
                                size: 12,
                                color: MnColors.mute,
                              ),
                            ),
                          ),
                          CinemaTableColumn(
                            label: 'Beschreibung',
                            width: 220,
                            cellBuilder: (r) => Text(
                              (r['description'] as String?) ?? '',
                              style: MnTypography.body(
                                color: MnColors.inkSoft,
                                size: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          CinemaTableColumn(
                            label: 'Aktionen',
                            width: 120,
                            cellBuilder: (r) => Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    LucideIcons.pencil,
                                    size: 16,
                                    color: MnColors.amber,
                                  ),
                                  onPressed: () => _openEdit(context, ref, r),
                                  tooltip: 'Bearbeiten',
                                ),
                                IconButton(
                                  icon: const Icon(
                                    LucideIcons.trash2,
                                    size: 16,
                                    color: MnColors.herzrot,
                                  ),
                                  onPressed: () =>
                                      _confirmDelete(context, ref, r),
                                  tooltip: 'Loeschen',
                                ),
                              ],
                            ),
                          ),
                        ],
                        rows: rows,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    await CinemaSheet.show<void>(
      context,
      initialSize: 0.55,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'NEUER CHANNEL',
              style: MnTypography.mono(
                size: 11,
                color: MnColors.mute,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 16),
            CinemaInput(
              controller: nameCtrl,
              label: 'Name',
              placeholder: 'z.B. Allgemein',
              autofocus: true,
            ),
            const SizedBox(height: 12),
            CinemaInput(
              controller: descCtrl,
              label: 'Beschreibung',
              variant: CinemaInputVariant.multiline,
              placeholder: 'Worum geht es hier?',
            ),
            const SizedBox(height: 20),
            GlowButton(
              label: 'Channel anlegen',
              icon: LucideIcons.plus,
              fullWidth: true,
              onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) return;
                try {
                  await db.createChannel(
                    name: name,
                    description: descCtrl.text.trim().isEmpty
                        ? null
                        : descCtrl.text.trim(),
                  );
                  // ignore: unused_result
                  ref.refresh(channelsListProvider);
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  CinemaToast.show(
                    context,
                    message: 'Channel angelegt.',
                    variant: ToastVariant.success,
                  );
                } catch (e) {
                  if (!context.mounted) return;
                  CinemaToast.show(
                    context,
                    message: 'Anlegen fehlgeschlagen: $e',
                    variant: ToastVariant.error,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openEdit(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
  ) async {
    final nameCtrl = TextEditingController(
      text: (row['name'] as String?) ?? '',
    );
    final descCtrl = TextEditingController(
      text: (row['description'] as String?) ?? '',
    );
    final saved = await CinemaModal.show<bool>(
      context,
      title: 'Channel bearbeiten',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CinemaInput(controller: nameCtrl, label: 'Name'),
          const SizedBox(height: 12),
          CinemaInput(
            controller: descCtrl,
            label: 'Beschreibung',
            variant: CinemaInputVariant.multiline,
          ),
        ],
      ),
      actions: [
        GlowButton(
          label: 'Abbrechen',
          variant: GlowVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        GlowButton(
          label: 'Speichern',
          icon: LucideIcons.check,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (saved != true) return;
    try {
      await db.updateChannel(row['id'] as String, {
        'name': nameCtrl.text.trim(),
        'description': descCtrl.text.trim(),
      });
      // ignore: unused_result
      ref.refresh(channelsListProvider);
      if (!context.mounted) return;
      CinemaToast.show(
        context,
        message: 'Gespeichert.',
        variant: ToastVariant.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      CinemaToast.show(
        context,
        message: 'Speichern fehlgeschlagen: $e',
        variant: ToastVariant.error,
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Map<String, dynamic> row,
  ) async {
    final confirmed = await CinemaModal.show<bool>(
      context,
      title: 'Channel loeschen?',
      child: Text(
        'Der Channel "${row['name']}" und alle zugehoerigen Daten '
        'werden entfernt. Unwiderruflich.',
        style: MnTypography.body(color: MnColors.inkSoft),
      ),
      actions: [
        GlowButton(
          label: 'Abbrechen',
          variant: GlowVariant.ghost,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        GlowButton(
          label: 'Loeschen',
          icon: LucideIcons.trash2,
          variant: GlowVariant.crisis,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true) return;
    try {
      await db.deleteChannel(row['id'] as String);
      // ignore: unused_result
      ref.refresh(channelsListProvider);
      if (!context.mounted) return;
      CinemaToast.show(
        context,
        message: 'Geloescht.',
        variant: ToastVariant.success,
      );
    } catch (e) {
      if (!context.mounted) return;
      CinemaToast.show(
        context,
        message: 'Loeschen fehlgeschlagen: $e',
        variant: ToastVariant.error,
      );
    }
  }
}
