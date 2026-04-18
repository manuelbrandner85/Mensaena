import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/services/skill_service.dart';
import 'package:mensaena/models/skill_offer.dart';
import 'package:mensaena/widgets/avatar_widget.dart';
import 'package:mensaena/widgets/empty_state.dart';
import 'package:mensaena/widgets/editorial_header.dart';

// ---------- Inline providers ----------

final _skillServiceProvider = Provider<SkillService>((ref) {
  return SkillService(ref.watch(supabaseProvider));
});

final _skillOffersProvider =
    FutureProvider.family<List<SkillOffer>, Map<String, String?>>((ref, params) async {
  return ref.read(_skillServiceProvider).getSkillOffers(
    category: params['category'],
    search: params['search'],
  );
});

// ---------- Constants ----------

const _skillCategories = [
  'Alle',
  'Handwerk',
  'IT & Technik',
  'Sprachen',
  'Musik',
  'Nachhilfe',
  'Haushalt',
  'Garten',
  'Kochen',
  'Sport',
  'Sonstiges',
];

Color _levelColor(String? level) {
  switch (level) {
    case 'anfaenger':
      return AppColors.success;
    case 'fortgeschritten':
      return AppColors.info;
    case 'experte':
      return const Color(0xFF9333EA);
    default:
      return AppColors.textMuted;
  }
}

String _levelLabel(String? level) {
  switch (level) {
    case 'anfaenger':
      return 'Anfaenger';
    case 'fortgeschritten':
      return 'Fortgeschritten';
    case 'experte':
      return 'Experte';
    default:
      return level ?? 'Unbekannt';
  }
}

// ---------- Screen ----------

class SkillsScreen extends ConsumerStatefulWidget {
  const SkillsScreen({super.key});

  @override
  ConsumerState<SkillsScreen> createState() => _SkillsScreenState();
}

class _SkillsScreenState extends ConsumerState<SkillsScreen> {
  String _selectedCategory = 'Alle';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Map<String, String?> get _params => {
        'category':
            _selectedCategory == 'Alle' ? null : _selectedCategory.toLowerCase(),
        'search': _searchQuery.isNotEmpty ? _searchQuery : null,
      };

  @override
  Widget build(BuildContext context) {
    final offersAsync = ref.watch(_skillOffersProvider(_params));

    return Scaffold(
      appBar: AppBar(title: const Text('Skill-Netzwerk')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: EditorialHeader(
              section: 'FÄHIGKEITEN',
              number: '27',
              title: 'Skills',
              subtitle: 'Fähigkeiten teilen und lernen',
              icon: Icons.build_outlined,
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Skills suchen...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24)),
                filled: true,
                fillColor: AppColors.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (v) => setState(() => _searchQuery = v),
            ),
          ),

          // Category filter chips
          SizedBox(
            height: 42,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _skillCategories.length,
              itemBuilder: (context, index) {
                final cat = _skillCategories[index];
                final isSelected = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(
                      cat,
                      style: TextStyle(
                        fontSize: 13,
                        color: isSelected
                            ? Colors.white
                            : AppColors.textSecondary,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _selectedCategory = cat),
                    backgroundColor: AppColors.surface,
                    selectedColor: AppColors.primary500,
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary500
                          : AppColors.border,
                    ),
                    showCheckmark: false,
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Skill offers list
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(_skillOffersProvider(_params));
              },
              color: AppColors.primary500,
              child: offersAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          size: 48, color: AppColors.error),
                      const SizedBox(height: 12),
                      Text('Fehler: $e',
                          style: const TextStyle(color: AppColors.textMuted)),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: () =>
                            ref.invalidate(_skillOffersProvider(_params)),
                        child: const Text('Erneut versuchen'),
                      ),
                    ],
                  ),
                ),
                data: (offers) {
                  if (offers.isEmpty) {
                    return const EmptyState(
                      icon: Icons.build_outlined,
                      title: 'Keine Skill-Angebote',
                      message:
                          'In dieser Kategorie gibt es noch keine Angebote. Sei der Erste!',
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: offers.length,
                    itemBuilder: (_, i) => _SkillCard(offer: offers[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dashboard/create?module=skills'),
        icon: const Icon(Icons.add),
        label: const Text('Anbieten'),
      ),
    );
  }
}

// ---------- Skill Card Widget ----------

class _SkillCard extends StatelessWidget {
  final SkillOffer offer;

  const _SkillCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    final authorName =
        offer.profile?['nickname'] ?? offer.profile?['name'] ?? 'Unbekannt';
    final authorAvatar = offer.profile?['avatar_url'] as String?;
    final lColor = _levelColor(offer.level);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title + free/paid badge
            Row(
              children: [
                Expanded(
                  child: Text(
                    offer.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: offer.isFree
                        ? AppColors.success.withValues(alpha: 0.1)
                        : AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    offer.isFree
                        ? 'Kostenlos'
                        : offer.hourlyRate != null
                            ? '${offer.hourlyRate!.toStringAsFixed(0)} EUR/h'
                            : 'Kostenpflichtig',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: offer.isFree
                          ? AppColors.success
                          : AppColors.warning,
                    ),
                  ),
                ),
              ],
            ),

            // Description
            if (offer.description != null &&
                offer.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                offer.description!,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: 12),

            // Category + Level badges
            Row(
              children: [
                if (offer.skillCategory != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      offer.skillCategory!,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                if (offer.level != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: lColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _levelLabel(offer.level),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: lColor,
                      ),
                    ),
                  ),
                if (offer.city != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.location_on,
                      size: 14, color: AppColors.textMuted),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      offer.city!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 12),

            // Author row
            Row(
              children: [
                AvatarWidget(
                  imageUrl: authorAvatar,
                  name: authorName,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Text(
                  authorName,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
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
