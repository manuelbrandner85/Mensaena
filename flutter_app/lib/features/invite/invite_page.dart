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
