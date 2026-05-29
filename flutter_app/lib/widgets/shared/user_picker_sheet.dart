/// SKILL: mensaena-features + mensaena-design
/// Wiederverwendbares User-Picker-Sheet mit Live-Suche.
///
/// Anders als die FriendshipsRepository.friends-Liste deckt das hier
/// ALLE User der Plattform ab (Livestream-Invite, Mentions, etc.).
/// Sortierung: Treffer mit display_name zuerst, dann Email-Prefix-Fallback.
library;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../config/theme/app_colors.dart';
import '../../config/theme/app_typography.dart';
import '../../repositories/friendships_repository.dart';
import 'sized_avatar_image.dart';

/// Öffnet ein Bottom-Sheet mit Such-Eingabe + Live-Trefferliste.
/// Tap auf einen User ruft [onPick] (id, name) auf und schließt das Sheet.
class UserPickerSheet {
  const UserPickerSheet._();

  static Future<void> show(
    BuildContext context, {
    required String title,
    required Future<bool> Function(String id, String name) onPick,
    String? pickedLabelKey, // i18n-Key für die Erfolgs-Snackbar (mit {name})
    String? failedLabelKey, // i18n-Key für die Fehler-Snackbar
  }) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xF0121A28),
      isScrollControlled: true,
      builder: (sheetCtx) => _UserPickerBody(
        title: title,
        onPick: onPick,
        pickedLabelKey: pickedLabelKey,
        failedLabelKey: failedLabelKey,
      ),
    );
  }
}

class _UserPickerBody extends StatefulWidget {
  const _UserPickerBody({
    required this.title,
    required this.onPick,
    this.pickedLabelKey,
    this.failedLabelKey,
  });
  final String title;
  final Future<bool> Function(String id, String name) onPick;
  final String? pickedLabelKey;
  final String? failedLabelKey;

  @override
  State<_UserPickerBody> createState() => _UserPickerBodyState();
}

class _UserPickerBodyState extends State<_UserPickerBody> {
  final _ctrl = TextEditingController();
  Future<List<Map<String, dynamic>>>? _future;
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    final q = v.trim();
    setState(() {
      _query = q;
      _future = q.isEmpty
          ? Future.value(const [])
          : FriendshipsRepository.searchUsers(q);
    });
  }

  String _nameOf(Map<String, dynamic> r) =>
      (r['display_name'] as String?) ??
      (r['name'] as String?) ??
      'common.neighbour'.tr();

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          children: [
            // Grabber
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 4),
              child: Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
              child: Row(
                children: [
                  const Icon(LucideIcons.userPlus,
                      size: 18, color: AppColors.bronze),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(widget.title,
                        style: AppTypography.display(
                            size: 18, color: AppColors.ink)),
                  ),
                ],
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: _onSearchChanged,
                style: AppTypography.body(size: 14, color: AppColors.ink),
                decoration: InputDecoration(
                  hintText: 'friends.findHint'.tr(),
                  hintStyle: AppTypography.caption(),
                  prefixIcon: const Icon(LucideIcons.search,
                      size: 16, color: AppColors.mute),
                  filled: true,
                  fillColor: AppColors.elevated,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            // Results
            Expanded(
              child: _query.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'friends.findPrompt'.tr(),
                          textAlign: TextAlign.center,
                          style: AppTypography.body(
                              size: 13, color: AppColors.mute),
                        ),
                      ),
                    )
                  : FutureBuilder<List<Map<String, dynamic>>>(
                      future: _future,
                      builder: (context, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.bronze),
                            ),
                          );
                        }
                        final rows = snap.data ?? const [];
                        if (rows.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                'friends.findNoResults'.tr(),
                                textAlign: TextAlign.center,
                                style: AppTypography.body(
                                    size: 13, color: AppColors.mute),
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          controller: scroll,
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 4),
                          itemBuilder: (_, i) {
                            final r = rows[i];
                            final id = r['id'] as String;
                            final name = _nameOf(r);
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: SizedAvatarImage(
                                url: r['avatar_url'] as String?,
                                size: 40,
                                fallbackInitial: name,
                              ),
                              title: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.body(
                                    size: 14, color: AppColors.ink),
                              ),
                              trailing: const Icon(LucideIcons.send,
                                  size: 18, color: AppColors.bronze),
                              onTap: () async {
                                final messenger =
                                    ScaffoldMessenger.maybeOf(context);
                                final navigator = Navigator.of(context);
                                final ok = await widget.onPick(id, name);
                                if (!mounted) return;
                                navigator.pop();
                                if (messenger == null) return;
                                final key = ok
                                    ? (widget.pickedLabelKey ??
                                        'live.inviteSent')
                                    : (widget.failedLabelKey ??
                                        'call.addFailed');
                                messenger.showSnackBar(SnackBar(
                                  backgroundColor: AppColors.surface,
                                  content: Text(
                                    ok
                                        ? key.tr(
                                            namedArgs: {'name': name})
                                        : key.tr(),
                                    style: AppTypography.body(
                                        size: 13, color: AppColors.ink),
                                  ),
                                ));
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
