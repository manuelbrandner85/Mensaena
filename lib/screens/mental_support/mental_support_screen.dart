import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/post_provider.dart';
import 'package:mensaena/models/post.dart';
import 'package:mensaena/widgets/post_card.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/loading_skeleton.dart';
import 'package:mensaena/widgets/editorial_header.dart';

class MentalSupportScreen extends ConsumerStatefulWidget {
  const MentalSupportScreen({super.key});

  @override
  ConsumerState<MentalSupportScreen> createState() => _MentalSupportScreenState();
}

class _MentalSupportScreenState extends ConsumerState<MentalSupportScreen> {
  List<Post> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final service = ref.read(postServiceProvider);
      final results = await Future.wait([
        service.getPosts(search: 'mental'),
        service.getPosts(search: 'seele'),
        service.getPosts(search: 'psyche'),
      ]);
      final seen = <String>{};
      final posts = <Post>[];
      for (final list in results) {
        for (final p in list) {
          if (seen.add(p.id)) posts.add(p);
        }
      }
      posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (mounted) setState(() => _posts = posts);
    } catch (_) {}
    finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mentale Unterstützung')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary500,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const EditorialHeader(
              section: 'Unterstützung',
              number: '26',
              title: 'Mentale Unterstützung',
              subtitle: 'Du bist nicht allein.',
              icon: Icons.psychology_outlined,
            ),
            const SizedBox(height: 20),
            const _HotlineCard(
              title: 'Telefonseelsorge',
              number: '0800 111 0 111',
              description: '24/7 anonym und kostenlos',
              icon: Icons.phone_in_talk,
            ),
            const SizedBox(height: 10),
            const _HotlineCard(
              title: 'Krisenchat',
              number: 'krisenchat.de',
              description: 'Chat-Beratung für Jugendliche',
              icon: Icons.chat_outlined,
              isUrl: true,
            ),
            const SizedBox(height: 10),
            const _HotlineCard(
              title: 'Hilfetelefon für Frauen',
              number: '08000 116 016',
              description: '24/7 kostenlos und vertraulich',
              icon: Icons.support_outlined,
            ),
            const SizedBox(height: 10),
            const _HotlineCard(
              title: 'Notfallnummer',
              number: '112',
              description: 'Akute Notfälle',
              icon: Icons.warning,
              emergency: true,
            ),
            const SizedBox(height: 24),
            const Text(
              'Community-Beiträge zum Thema',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const LoadingSkeleton(type: SkeletonType.postList)
            else if (_posts.isEmpty)
              const EmptyState(
                icon: Icons.forum_outlined,
                title: 'Noch keine Beiträge',
                message: 'Sei der Erste, der einen Beitrag zum Thema teilt.',
              )
            else
              ..._posts.take(20).map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: PostCard(
                      post: p,
                      onTap: () => context.push('/dashboard/posts/${p.id}'),
                    ),
                  )),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dashboard/create?module=mental-support'),
        icon: const Icon(Icons.add),
        label: const Text('Beitrag'),
      ),
    );
  }
}

class _HotlineCard extends StatelessWidget {
  final String title;
  final String number;
  final String description;
  final IconData icon;
  final bool isUrl;
  final bool emergency;
  const _HotlineCard({
    required this.title,
    required this.number,
    required this.description,
    required this.icon,
    this.isUrl = false,
    this.emergency = false,
  });

  Future<void> _launch() async {
    final uri = isUrl
        ? Uri.parse('https://$number')
        : Uri.parse('tel:${number.replaceAll(' ', '')}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final color = emergency ? AppColors.emergency : AppColors.primary500;
    return InkWell(
      onTap: _launch,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: emergency ? color : AppColors.border),
          boxShadow: AppShadows.soft,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    number,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
                  ),
                  const SizedBox(height: 2),
                  Text(description, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
                ],
              ),
            ),
            Icon(isUrl ? Icons.open_in_new : Icons.phone, color: color, size: 20),
          ],
        ),
      ),
    );
  }
}
