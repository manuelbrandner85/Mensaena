import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../theme/app_colors.dart';
import 'challenges_repository.dart';
import 'models.dart';

class ChallengesPage extends ConsumerStatefulWidget {
  const ChallengesPage({super.key});

  @override
  ConsumerState<ChallengesPage> createState() => _ChallengesPageState();
}

class _ChallengesPageState extends ConsumerState<ChallengesPage> {
  List<Challenge> _items = [];
  Set<String> _joined = const {};
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
      final repo = ref.read(challengesRepositoryProvider);
      final list = await repo.list();
      final joined = await repo.myJoinedIds();
      if (!mounted) return;
      setState(() {
        _items = list;
        _joined = joined;
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

  Future<void> _toggle(Challenge c) async {
    HapticFeedback.mediumImpact();
    setState(() => _busyId = c.id);
    try {
      final repo = ref.read(challengesRepositoryProvider);
      if (_joined.contains(c.id)) {
        await repo.leave(c.id);
      } else {
        await repo.join(c.id);
      }
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _checkIn(Challenge c) async {
    HapticFeedback.mediumImpact();
    setState(() => _busyId = c.id);
    try {
      await ref.read(challengesRepositoryProvider).checkIn(c.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Check-In erfasst!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Challenges'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('🎯', style: TextStyle(fontSize: 48)),
                        SizedBox(height: 12),
                        Text(
                          'Keine Challenges aktiv',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _ChallengeCard(
                      challenge: _items[i],
                      isJoined: _joined.contains(_items[i].id),
                      busy: _busyId == _items[i].id,
                      onJoinToggle: () => _toggle(_items[i]),
                      onCheckIn: () => _checkIn(_items[i]),
                    ),
                  ),
                ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.challenge,
    required this.isJoined,
    required this.busy,
    required this.onJoinToggle,
    required this.onCheckIn,
  });

  final Challenge challenge;
  final bool isJoined;
  final bool busy;
  final VoidCallback onJoinToggle;
  final VoidCallback onCheckIn;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('d. MMM', 'de');
    final dateRange =
        '${dateFmt.format(challenge.startDate)} – ${dateFmt.format(challenge.endDate)}';
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: challenge.difficulty.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    challenge.difficulty.label,
                    style: TextStyle(
                      color: challenge.difficulty.color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primary500.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${challenge.points} Punkte',
                    style: const TextStyle(
                      color: AppColors.primary500,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  dateRange,
                  style: const TextStyle(color: AppColors.ink400, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              challenge.title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            if ((challenge.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                challenge.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.ink700,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.people_outline, size: 14, color: AppColors.ink400),
                const SizedBox(width: 4),
                Text(
                  challenge.maxParticipants != null
                      ? '${challenge.participantCount}/${challenge.maxParticipants}'
                      : '${challenge.participantCount}',
                  style: const TextStyle(color: AppColors.ink400, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (isJoined) ...[
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: FilledButton.icon(
                        onPressed: busy || !challenge.isActive ? null : onCheckIn,
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Check-In heute'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary500,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    height: 36,
                    child: OutlinedButton(
                      onPressed: busy ? null : onJoinToggle,
                      child: const Text('Verlassen'),
                    ),
                  ),
                ] else
                  Expanded(
                    child: SizedBox(
                      height: 36,
                      child: FilledButton(
                        onPressed: busy ? null : onJoinToggle,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary500,
                        ),
                        child: busy
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Mitmachen'),
                      ),
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
