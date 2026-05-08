import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_colors.dart';
import 'groups_repository.dart';
import 'models.dart';

class GroupDetailPage extends ConsumerStatefulWidget {
  const GroupDetailPage({super.key, required this.idOrSlug});
  final String idOrSlug;

  @override
  ConsumerState<GroupDetailPage> createState() => _GroupDetailPageState();
}

class _GroupDetailPageState extends ConsumerState<GroupDetailPage> {
  Group? _group;
  bool _loading = true;
  bool _isMember = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(groupsRepositoryProvider);
      final group = await repo.fetch(widget.idOrSlug);
      if (group == null) {
        if (!mounted) return;
        setState(() {
          _error = 'Gruppe nicht gefunden';
          _loading = false;
        });
        return;
      }
      final mine = await repo.myGroupIds();
      if (!mounted) return;
      setState(() {
        _group = group;
        _isMember = mine.contains(group.id);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  Future<void> _toggle() async {
    final group = _group;
    if (group == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      final repo = ref.read(groupsRepositoryProvider);
      if (_isMember) {
        await repo.leave(group.id);
      } else {
        await repo.join(group.id);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_group?.name ?? 'Gruppe')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(_group!),
    );
  }

  Widget _buildBody(Group g) {
    final cat = g.categoryConfig;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (g.bannerUrl != null || g.coverImageUrl != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              (g.bannerUrl ?? g.coverImageUrl)!,
              width: double.infinity,
              height: 160,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          )
        else
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: cat.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(cat.emoji, style: const TextStyle(fontSize: 48)),
          ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: cat.accent.withValues(alpha: 0.15),
              backgroundImage: g.displayImage != null
                  ? NetworkImage(g.displayImage!)
                  : null,
              child: g.displayImage == null
                  ? Text(cat.emoji, style: const TextStyle(fontSize: 24))
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    g.name,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    cat.label,
                    style: TextStyle(
                      color: cat.accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${g.memberCount} Mitglieder · ${g.postCount} Beiträge',
                    style: const TextStyle(color: AppColors.ink400, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if ((g.description ?? '').isNotEmpty)
          Text(
            g.description!,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: _isMember
              ? OutlinedButton.icon(
                  onPressed: _busy ? null : _toggle,
                  icon: const Icon(Icons.exit_to_app),
                  label: const Text('Gruppe verlassen'),
                )
              : FilledButton.icon(
                  onPressed: _busy ? null : _toggle,
                  icon: const Icon(Icons.add),
                  label: const Text('Beitreten'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                  ),
                ),
        ),
      ],
    );
  }
}
