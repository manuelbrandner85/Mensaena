import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';
import 'flyer_templates.dart';

/// /dashboard/invite – Referral-Code generieren / teilen.
class InvitePage extends ConsumerStatefulWidget {
  const InvitePage({super.key});

  @override
  ConsumerState<InvitePage> createState() => _InvitePageState();
}

class _InvitePageState extends ConsumerState<InvitePage> {
  String? _code;
  String? _userName;
  int _accepted = 0;
  bool _loading = true;
  bool _renderingFlyer = false;
  FlyerTemplate _flyer = FlyerTemplate.classic;
  final _flyerBoundaryKey = GlobalKey();
  List<_LeaderEntry> _leaderboard = const [];

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
        setState(() => _loading = false);
        return;
      }
      // Existierenden Code holen oder neu erstellen
      final row = await db
          .from('referrals')
          .select('invite_code')
          .eq('inviter_id', user.id)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      String code;
      if (row != null) {
        code = row['invite_code'] as String;
      } else {
        code = _generateCode();
        await db.from('referrals').insert(<String, dynamic>{
          'inviter_id': user.id,
          'invite_code': code,
          'status': 'pending',
        });
      }

      // Acceptances zählen
      final acceptedRows = await db
          .from('referrals')
          .select('id')
          .eq('inviter_id', user.id)
          .eq('status', 'accepted');

      // Leaderboard (Top-5 Botschafter — client-seitige Aggregation,
      // identisch zur Web-Implementierung in invite/page.tsx).
      final boardRows = await db
          .from('referrals')
          .select(
            'inviter_id, inviter:profiles!referrals_inviter_id_fkey(name, avatar_url)',
          )
          .eq('status', 'accepted')
          .limit(500);
      final inviterMap = <String, _LeaderEntry>{};
      for (final r in boardRows) {
        final id = r['inviter_id'] as String?;
        if (id == null) continue;
        final inviter = r['inviter'] as Map<String, dynamic>?;
        final existing = inviterMap[id];
        if (existing == null) {
          inviterMap[id] = _LeaderEntry(
            id: id,
            name: inviter?['name'] as String?,
            avatarUrl: inviter?['avatar_url'] as String?,
            count: 1,
            isMe: id == user.id,
          );
        } else {
          inviterMap[id] = existing.copyWith(count: existing.count + 1);
        }
      }
      final leaderboard = inviterMap.values.toList()
        ..sort((a, b) => b.count.compareTo(a.count));
      final topFive = leaderboard.take(5).toList(growable: false);

      // Eigener Name (für Flyer-Personalisierung)
      String? userName;
      try {
        final profile = await db
            .from('profiles')
            .select('name')
            .eq('id', user.id)
            .maybeSingle();
        userName = profile?['name'] as String?;
      } catch (_) {}

      if (!mounted) return;
      setState(() {
        _code = code;
        _userName = userName;
        _accepted = acceptedRows.length;
        _leaderboard = topFive;
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

  String _generateCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    var seed = now;
    final buf = StringBuffer();
    for (var i = 0; i < 8; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      buf.write(chars[seed % chars.length]);
    }
    return buf.toString();
  }

  String get _shareUrl =>
      'https://www.mensaena.de/auth?mode=register&ref=$_code';

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _shareUrl));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Link kopiert')),
    );
  }

  Future<void> _share() async {
    await Share.share(
      'Schließ dich Mensaena an – Nachbarschaftshilfe einfach gemacht: $_shareUrl',
      subject: 'Mensaena Einladung',
    );
  }

  Future<void> _shareFlyer() async {
    if (_renderingFlyer || _code == null) return;
    setState(() => _renderingFlyer = true);
    HapticFeedback.lightImpact();
    try {
      // Kurz warten, damit der Frame mit dem aktuellen Template gerendert ist.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      final bytes = await renderFlyerToPng(_flyerBoundaryKey);
      if (bytes == null) throw Exception('Render fehlgeschlagen');
      final dir = await getTemporaryDirectory();
      final path =
          '${dir.path}/mensaena-einladung-${DateTime.now().millisecondsSinceEpoch}.png';
      final file = File(path);
      await file.writeAsBytes(bytes);
      await Share.shareXFiles(
        [XFile(path, mimeType: 'image/png')],
        text:
            'Schließ dich Mensaena an – Nachbarschaftshilfe einfach gemacht: $_shareUrl',
        subject: 'Mensaena Einladung',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Flyer konnte nicht erstellt werden: $e')),
      );
    } finally {
      if (mounted) setState(() => _renderingFlyer = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Einladen')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary500, AppColors.primary700],
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '🎁 Lade Nachbarn ein',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Mit deinem persönlichen Code wird dein Netz größer – '
                        'jede Anmeldung über deinen Link zählt.',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.confirmation_number_outlined,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _code ?? '—',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFamily: 'monospace',
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          onPressed: _copy,
                          icon: const Icon(Icons.copy_outlined),
                          label: const Text('Kopieren'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: FilledButton.icon(
                          onPressed: _share,
                          icon: const Icon(Icons.share_outlined),
                          label: const Text('Teilen'),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        color: AppColors.primary500,
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_accepted',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary500,
                            ),
                          ),
                          const Text(
                            'Eingeladene Nachbarn',
                            style: TextStyle(
                              color: AppColors.ink400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildFlyerSection(),
                if (_leaderboard.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _LeaderboardCard(entries: _leaderboard),
                ],
              ],
            ),
    );
  }

  Widget _buildFlyerSection() {
    if (_code == null) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Flyer zum Teilen',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.ink800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Wähle ein Design – du kannst es als Bild teilen oder per Story posten.',
          style: TextStyle(color: AppColors.ink400, fontSize: 12),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: FlyerTemplate.values.length,
            separatorBuilder: (_, __) => const SizedBox(width: 6),
            itemBuilder: (_, i) {
              final t = FlyerTemplate.values[i];
              final selected = _flyer == t;
              return ChoiceChip(
                selected: selected,
                onSelected: (_) => setState(() => _flyer = t),
                label: Text('${t.emoji} ${t.label}'),
                selectedColor: AppColors.primary500.withValues(alpha: 0.15),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? AppColors.primary500 : AppColors.ink700,
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        // Flyer preview (skaliert auf Bildschirmbreite, original 1080×1080)
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              width: double.infinity,
              child: AspectRatio(
                aspectRatio: 1,
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: RepaintBoundary(
                    key: _flyerBoundaryKey,
                    child: FlyerCanvas(
                      template: _flyer,
                      code: _code!,
                      shareUrl: _shareUrl,
                      userName: _userName,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 48,
          child: FilledButton.icon(
            onPressed: _renderingFlyer ? null : _shareFlyer,
            icon: _renderingFlyer
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.image_outlined),
            label: Text(_renderingFlyer ? 'Erstelle Bild…' : 'Flyer teilen'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary500,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ),
      ],
    );
  }
}


class _LeaderEntry {
  const _LeaderEntry({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.count,
    required this.isMe,
  });
  final String id;
  final String? name;
  final String? avatarUrl;
  final int count;
  final bool isMe;

  _LeaderEntry copyWith({int? count}) => _LeaderEntry(
        id: id,
        name: name,
        avatarUrl: avatarUrl,
        count: count ?? this.count,
        isMe: isMe,
      );
}

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({required this.entries});
  final List<_LeaderEntry> entries;

  static const _ranks = [
    (medal: '🥇', bg: Color(0xFFFEF3C7), border: Color(0xFFFDE68A), text: Color(0xFFB45309)),
    (medal: '🥈', bg: Color(0xFFF5F5F4), border: Color(0xFFE7E5E4), text: Color(0xFF57534E)),
    (medal: '🥉', bg: Color(0xFFFFEDD5), border: Color(0xFFFED7AA), text: Color(0xFFC2410C)),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.stone200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.emoji_events_outlined,
                size: 18,
                color: AppColors.primary500,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Botschafter-Bestenliste',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink800,
                      ),
                    ),
                    Text(
                      'Die aktivsten Nachbarschafts-Botschafter',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.ink400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...entries.asMap().entries.map((e) {
            final i = e.key;
            final entry = e.value;
            final rank = i < _ranks.length
                ? _ranks[i]
                : (
                    medal: '${i + 1}',
                    bg: const Color(0xFFFAFAF9),
                    border: AppColors.stone200,
                    text: AppColors.ink400
                  );
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: rank.bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: entry.isMe ? AppColors.primary500 : rank.border,
                    width: entry.isMe ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Center(
                        child: Text(
                          rank.medal,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.stone200,
                      backgroundImage: entry.avatarUrl != null
                          ? NetworkImage(entry.avatarUrl!)
                          : null,
                      child: entry.avatarUrl == null
                          ? Text(
                              (entry.name ?? '?').characters.first.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.ink400,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "${entry.name ?? "Nachbar:in"}${entry.isMe ? " (Du)" : ""}",
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.ink800,
                        ),
                      ),
                    ),
                    Text(
                      "${entry.count} ${entry.count == 1 ? "Einladung" : "Einladungen"}",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: rank.text,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
