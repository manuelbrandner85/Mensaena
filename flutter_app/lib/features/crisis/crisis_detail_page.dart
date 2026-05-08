import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/supabase.dart';
import '../../theme/app_colors.dart';
import 'crisis_repository.dart';
import 'models.dart';

class CrisisDetailPage extends ConsumerStatefulWidget {
  const CrisisDetailPage({super.key, required this.crisisId});
  final String crisisId;

  @override
  ConsumerState<CrisisDetailPage> createState() => _CrisisDetailPageState();
}

class _CrisisDetailPageState extends ConsumerState<CrisisDetailPage> {
  Crisis? _crisis;
  List<CrisisHelper> _helpers = [];
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(crisisRepositoryProvider);
      final crisis = await repo.fetch(widget.crisisId);
      final helpers = await repo.helpersFor(widget.crisisId);
      if (!mounted) return;
      if (crisis == null) {
        setState(() {
          _error = 'Krise nicht gefunden';
          _loading = false;
        });
        return;
      }
      setState(() {
        _crisis = crisis;
        _helpers = helpers;
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

  Future<void> _offerHelp() async {
    final crisis = _crisis;
    if (crisis == null) return;
    final message = await showDialog<String?>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Hilfe anbieten'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Wie kannst du helfen? (optional)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('Anbieten'),
            ),
          ],
        );
      },
    );
    if (message == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      await ref
          .read(crisisRepositoryProvider)
          .offerHelp(crisisId: crisis.id, message: message);
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

  Future<void> _markResolved() async {
    final crisis = _crisis;
    if (crisis == null) return;
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    try {
      await ref.read(crisisRepositoryProvider).markResolved(crisis.id);
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

  Future<void> _launch(String uri) async {
    final url = Uri.parse(uri);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Krise')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _buildBody(_crisis!),
    );
  }

  Widget _buildBody(Crisis crisis) {
    final cat = crisis.categoryConfig;
    final myId = ref.read(supabaseProvider).auth.currentUser?.id;
    final isMine = myId == crisis.creatorId;
    final iAlreadyOffered = _helpers.any(
      (h) => h.userId == myId && h.status != 'withdrawn',
    );
    final fullDate = DateFormat('d. MMMM yyyy · HH:mm', 'de')
        .format(crisis.createdAt);
    final canHelp =
        !isMine && !iAlreadyOffered && crisis.status == CrisisStatus.active;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: crisis.urgency.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${cat.emoji} ${cat.label} · ${crisis.urgency.label}',
                style: TextStyle(
                  color: crisis.urgency.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: crisis.status.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                crisis.status.label,
                style: TextStyle(
                  color: crisis.status.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          crisis.title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Text(
          fullDate,
          style: const TextStyle(color: AppColors.ink400, fontSize: 12),
        ),
        const SizedBox(height: 16),
        if (crisis.description.isNotEmpty)
          Text(
            crisis.description,
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),
        if (crisis.imageUrls.isNotEmpty) ...[
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: crisis.imageUrls.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  crisis.imageUrls[i],
                  width: 240,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 240,
                    height: 180,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.broken_image),
                  ),
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),
        // Meta
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Column(
            children: [
              if (crisis.locationText != null)
                _meta(
                  Icons.location_on_outlined,
                  'Ort',
                  crisis.locationText!,
                  onTap: () => _launch(
                    'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(crisis.locationText!)}',
                  ),
                ),
              _meta(
                Icons.shield_outlined,
                'Radius',
                '${crisis.radiusKm.toStringAsFixed(0)} km',
              ),
              _meta(
                Icons.people_outline,
                'Helfer',
                '${crisis.helperCount} von ${crisis.neededHelpers} benötigt',
              ),
              if (crisis.affectedCount > 0)
                _meta(
                  Icons.group_outlined,
                  'Betroffen',
                  '${crisis.affectedCount} Person(en)',
                ),
              if (crisis.contactPhone != null)
                _meta(
                  Icons.phone_outlined,
                  'Telefon',
                  crisis.contactPhone!,
                  onTap: () => _launch('tel:${crisis.contactPhone}'),
                ),
            ],
          ),
        ),
        if (crisis.neededSkills.isNotEmpty) ...[
          const SizedBox(height: 16),
          const _SectionLabel('Benötigte Skills'),
          const SizedBox(height: 6),
          _ChipWrap(items: crisis.neededSkills),
        ],
        if (crisis.neededResources.isNotEmpty) ...[
          const SizedBox(height: 12),
          const _SectionLabel('Benötigte Ressourcen'),
          const SizedBox(height: 6),
          _ChipWrap(items: crisis.neededResources),
        ],
        const SizedBox(height: 20),
        if (_helpers.isNotEmpty) ...[
          const _SectionLabel('Helfer'),
          const SizedBox(height: 8),
          ..._helpers.map((h) => _HelperTile(helper: h)),
          const SizedBox(height: 12),
        ],
        if (canHelp)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton.icon(
              onPressed: _busy ? null : _offerHelp,
              icon: const Icon(Icons.volunteer_activism_outlined),
              label: const Text('Hilfe anbieten'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary500,
              ),
            ),
          ),
        if (iAlreadyOffered)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () async {
                      await ref
                          .read(crisisRepositoryProvider)
                          .withdrawHelp(crisis.id);
                      await _load();
                    },
              icon: const Icon(Icons.close),
              label: const Text('Hilfsangebot zurückziehen'),
            ),
          ),
        if (isMine && crisis.status == CrisisStatus.active) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _busy ? null : _markResolved,
              icon: const Icon(Icons.check),
              label: const Text('Als geklärt markieren'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _meta(IconData icon, String label, String value, {VoidCallback? onTap}) {
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.ink400),
          const SizedBox(width: 8),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.ink400, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: onTap != null ? FontWeight.w600 : FontWeight.w400,
                color: onTap != null ? AppColors.primary500 : AppColors.ink700,
              ),
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
        color: AppColors.ink400,
      ),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.items});
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: items
          .map(
            (s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(s, style: const TextStyle(fontSize: 12)),
            ),
          )
          .toList(),
    );
  }
}

class _HelperTile extends StatelessWidget {
  const _HelperTile({required this.helper});
  final CrisisHelper helper;

  @override
  Widget build(BuildContext context) {
    final name = helper.profileName ?? 'Helfer';
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary500.withValues(alpha: 0.18),
            backgroundImage: helper.profileAvatarUrl != null
                ? NetworkImage(helper.profileAvatarUrl!)
                : null,
            child: helper.profileAvatarUrl == null
                ? Text(initial, style: const TextStyle(fontSize: 12))
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                if (helper.message != null && helper.message!.isNotEmpty)
                  Text(
                    helper.message!,
                    style: const TextStyle(fontSize: 12, color: AppColors.ink400),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              helper.status,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.primary500,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
