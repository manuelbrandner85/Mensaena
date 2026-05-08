import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../routing/routes.dart';
import '../../theme/app_colors.dart';
import 'models.dart';
import 'organizations_repository.dart';

class OrganizationsPage extends ConsumerStatefulWidget {
  const OrganizationsPage({super.key});

  @override
  ConsumerState<OrganizationsPage> createState() => _OrganizationsPageState();
}

class _OrganizationsPageState extends ConsumerState<OrganizationsPage> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _debounce;

  List<Organization> _orgs = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  int _page = 0;
  String _category = 'all';
  String _search = '';
  bool _verifiedOnly = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _page = 0;
      _hasMore = true;
    });
    try {
      final list = await ref.read(organizationsRepositoryProvider).list(
            search: _search,
            category: _category,
            verifiedOnly: _verifiedOnly,
          );
      if (!mounted) return;
      setState(() {
        _orgs = list;
        _loading = false;
        _hasMore = list.length >= 20;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final list = await ref.read(organizationsRepositoryProvider).list(
            search: _search,
            category: _category,
            verifiedOnly: _verifiedOnly,
            page: next,
          );
      if (!mounted) return;
      setState(() {
        _orgs = [..._orgs, ...list];
        _page = next;
        _loadingMore = false;
        _hasMore = list.length >= 20;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() => _search = v);
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Organisationen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Vorschlagen',
            onPressed: () => context.go(Routes.dashboardOrganizationsSuggest),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                hintText: 'Suchen…',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _CategoryChip(
                  label: 'Alle',
                  selected: _category == 'all',
                  onTap: () {
                    setState(() => _category = 'all');
                    _load();
                  },
                ),
                const SizedBox(width: 6),
                FilterChip(
                  label: const Text('Verifiziert'),
                  selected: _verifiedOnly,
                  avatar: _verifiedOnly
                      ? const Icon(Icons.verified, size: 16, color: AppColors.primary500)
                      : null,
                  onSelected: (v) {
                    setState(() => _verifiedOnly = v);
                    _load();
                  },
                  selectedColor: AppColors.primary500.withValues(alpha: 0.15),
                ),
                ...OrganizationCategory.all.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: _CategoryChip(
                      label: '${c.emoji} ${c.label}',
                      selected: _category == c.value,
                      onTap: () {
                        setState(() => _category = c.value);
                        _load();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _orgs.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Keine Organisationen gefunden',
                            style: TextStyle(color: AppColors.ink400),
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          itemCount: _orgs.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            if (i >= _orgs.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              );
                            }
                            return _OrgListTile(org: _orgs[i]);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary500.withValues(alpha: 0.15),
    );
  }
}

class _OrgListTile extends StatelessWidget {
  const _OrgListTile({required this.org});
  final Organization org;

  @override
  Widget build(BuildContext context) {
    final cat = org.categoryConfig;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => context.go('${Routes.dashboardOrganizations}/${org.slug}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: cat.accentColor.withValues(alpha: 0.15),
                backgroundImage:
                    org.logoUrl != null ? NetworkImage(org.logoUrl!) : null,
                child: org.logoUrl == null
                    ? Text(cat.emoji, style: const TextStyle(fontSize: 20))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            org.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (org.isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified,
                            size: 14,
                            color: AppColors.primary500,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat.label,
                      style: TextStyle(
                        color: cat.accentColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 12,
                          color: AppColors.ink400,
                        ),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            org.city,
                            style: const TextStyle(
                              color: AppColors.ink400,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (org.distanceKm != null) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${org.distanceKm!.toStringAsFixed(1)} km',
                            style: const TextStyle(
                              color: AppColors.ink400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (org.ratingCount > 0) ...[
                          const Icon(Icons.star, size: 12, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 2),
                          Text(
                            org.ratingAvg.toStringAsFixed(1),
                            style: const TextStyle(
                              color: AppColors.ink400,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
