import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';

/// /dashboard/settings/blocked — Pendant zu `BlockedUsersList.tsx`.
/// Zeigt alle Personen, die der User blockiert hat, und erlaubt das Entsperren.
class BlockedUsersPage extends ConsumerStatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  ConsumerState<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends ConsumerState<BlockedUsersPage> {
  List<Map<String, dynamic>> _blocks = const [];
  bool _loading = true;
  String? _busyId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final db = ref.read(supabaseProvider);
      final user = db.auth.currentUser;
      if (user == null) {
        setState(() {
          _blocks = const [];
          _loading = false;
        });
        return;
      }
      final rows = await db
          .from('user_blocks')
          .select(
            'id, blocked_id, created_at, profiles:blocked_id(id, name, avatar_url)',
          )
          .eq('blocker_id', user.id)
          .order('created_at', ascending: false);
      if (!mounted) return;
      setState(() {
        _blocks = List<Map<String, dynamic>>.from(rows);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _unblock(String blockId) async {
    setState(() => _busyId = blockId);
    try {
      await ref.read(supabaseProvider).from('user_blocks').delete().eq(
            'id',
            blockId,
          );
      if (!mounted) return;
      setState(() {
        _blocks = _blocks.where((b) => b['id'] != blockId).toList();
        _busyId = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Person entsperrt')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _busyId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  String _relative(String? createdAt) {
    if (createdAt == null) return '';
    final t = DateTime.tryParse(createdAt);
    if (t == null) return '';
    final delta = DateTime.now().difference(t);
    if (delta.inDays >= 30) return DateFormat('d. MMM yyyy', 'de').format(t);
    if (delta.inDays >= 1) return 'vor ${delta.inDays} Tagen';
    if (delta.inHours >= 1) return 'vor ${delta.inHours} Std.';
    if (delta.inMinutes >= 1) return 'vor ${delta.inMinutes} Min.';
    return 'gerade eben';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Blockierte Personen')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _blocks.isEmpty
              ? _Empty()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _blocks.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final block = _blocks[i];
                      final profile =
                          (block['profiles'] as Map<String, dynamic>?) ??
                              const {};
                      final name =
                          (profile['name'] as String?) ?? 'Unbekannt';
                      final avatar = profile['avatar_url'] as String?;
                      final since = _relative(block['created_at'] as String?);
                      final isBusy = _busyId == block['id'];
                      return Material(
                        borderRadius: BorderRadius.circular(12),
                        color: Colors.white,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: AppColors.stone200,
                                backgroundImage: avatar != null
                                    ? NetworkImage(avatar)
                                    : null,
                                child: avatar == null
                                    ? const Icon(
                                        Icons.person_off_outlined,
                                        size: 18,
                                        color: AppColors.ink400,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      'Blockiert $since',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.ink400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              TextButton(
                                onPressed: isBusy
                                    ? null
                                    : () => _unblock(block['id'] as String),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.emergency500,
                                  backgroundColor: AppColors.emergency500
                                      .withValues(alpha: 0.1),
                                ),
                                child: isBusy
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text(
                                        'Entsperren',
                                        style:
                                            TextStyle(fontSize: 12),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _Empty extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined,
                size: 48, color: AppColors.stone400,),
            SizedBox(height: 12),
            Text(
              'Niemand blockiert',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'Wenn du jemanden blockierst, sieht diese Person deine Posts und kann dich nicht mehr anschreiben.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.ink400),
            ),
          ],
        ),
      ),
    );
  }
}
