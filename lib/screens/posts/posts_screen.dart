import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/config/theme.dart';
import 'package:mensaena/providers/auth_provider.dart';
import 'package:mensaena/providers/post_provider.dart';
import 'package:mensaena/models/post.dart';
import 'package:mensaena/widgets/post_card.dart';
import 'package:mensaena/widgets/editorial_header.dart';
import 'package:mensaena/widgets/loading_skeleton.dart';

class PostsScreen extends ConsumerStatefulWidget {
  const PostsScreen({super.key});

  @override
  ConsumerState<PostsScreen> createState() => _PostsScreenState();
}

class _PostsScreenState extends ConsumerState<PostsScreen> {
  static const int _pageSize = 20;

  final _searchController = TextEditingController();
  final _locationController = TextEditingController();
  String? _selectedType;
  String? _activeTag;
  String? _urgency;
  double? _radius;
  bool _showAdvancedFilters = false;
  bool _gridView = false;

  // Pagination state
  final List<Post> _allPosts = [];
  
  bool _hasMore = true;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  Object? _error;

  // User location (needed for radius filter)
  double? _userLat;
  double? _userLng;

  // Realtime
  RealtimeChannel? _realtimeChannel;
  bool _hasNewPosts = false;
  int _newPostCount = 0;

  static const _typeFilters = [
    {'value': null, 'label': 'Alle', 'emoji': '📋'},
    {'value': 'help_needed', 'label': 'Hilfe', 'emoji': '🙏'},
    {'value': 'help_offered', 'label': 'Angebote', 'emoji': '🤝'},
    {'value': 'rescue', 'label': 'Retter', 'emoji': '🧡'},
    {'value': 'animal', 'label': 'Tiere', 'emoji': '🐾'},
    {'value': 'housing', 'label': 'Wohnen', 'emoji': '🏡'},
    {'value': 'supply', 'label': 'Versorgung', 'emoji': '🌾'},
    {'value': 'crisis', 'label': 'Notfall', 'emoji': '🚨'},
    {'value': 'mobility', 'label': 'Mobilität', 'emoji': '🚗'},
    {'value': 'sharing', 'label': 'Teilen', 'emoji': '🔄'},
    {'value': 'community', 'label': 'Community', 'emoji': '🗳️'},
  ];

  static const _popularTags = [
    'Einkauf', 'Begleitung', 'Garten', 'Handwerk', 'Kochen',
    'Transport', 'Kinderbetreuung', 'Technik', 'Haushalt', 'Tiere',
  ];

  static const _urgencyFilters = [
    (value: null, label: 'Alle'),
    (value: 'low', label: 'Niedrig'),
    (value: 'medium', label: 'Mittel'),
    (value: 'high', label: 'Hoch'),
    (value: 'critical', label: 'Kritisch'),
  ];

  @override
  void initState() {
    super.initState();
    _loadUserLocation();
    _loadPosts();
    _subscribeToNewPosts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _locationController.dispose();
    _realtimeChannel?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadUserLocation() async {
    final profile = await ref.read(currentProfileProvider.future);
    if (!mounted) return;
    if (profile?.latitude != null && profile?.longitude != null) {
      setState(() {
        _userLat = profile!.latitude;
        _userLng = profile.longitude;
      });
    }
  }

  void _subscribeToNewPosts() {
    final postService = ref.read(postServiceProvider);
    _realtimeChannel = postService.subscribeToNewPosts((_) {
      if (mounted) {
        setState(() {
          _hasNewPosts = true;
          _newPostCount++;
        });
      }
    });
  }

  Future<void> _loadPosts() async {
    setState(() {
      _loadingInitial = true;
      _error = null;
      
      _hasMore = true;
      _allPosts.clear();
    });

    try {
      final posts = await _fetchPage(offset: 0);
      if (!mounted) return;
      setState(() {
        _allPosts.addAll(posts);
        _hasMore = posts.length >= _pageSize;
        _loadingInitial = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loadingInitial = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final posts = await _fetchPage(offset: _allPosts.length);
      if (!mounted) return;
      setState(() {
        _allPosts.addAll(posts);
        _hasMore = posts.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<List<Post>> _fetchPage({required int offset}) async {
    final service = ref.read(postServiceProvider);
    final searchText = _searchController.text.trim();
    final locationText = _locationController.text.trim();

    // Compose search query with location/tag terms when advanced filters are used
    final queryParts = <String>[];
    if (searchText.isNotEmpty) queryParts.add(searchText);
    if (locationText.isNotEmpty) queryParts.add(locationText);
    if (_activeTag != null) queryParts.add(_activeTag!.replaceAll('#', ''));
    final combinedQuery = queryParts.isEmpty ? null : queryParts.join(' ');

    return service.getPosts(
      type: _selectedType,
      search: combinedQuery,
      urgency: _urgency,
      lat: _radius != null ? _userLat : null,
      lng: _radius != null ? _userLng : null,
      radiusKm: _radius,
      limit: _pageSize,
      offset: offset,
    );
  }

  void _resetAllFilters() {
    _searchController.clear();
    _locationController.clear();
    setState(() {
      _selectedType = null;
      _activeTag = null;
      _urgency = null;
      _radius = null;
    });
    _loadPosts();
  }

  void _onNewPostsBannerTap() {
    setState(() {
      _hasNewPosts = false;
      _newPostCount = 0;
    });
    _loadPosts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('§ 03 · Beiträge'),
        actions: [
          IconButton(
            icon: Icon(_gridView ? Icons.list : Icons.grid_view, size: 22),
            tooltip: _gridView ? 'Listenansicht' : 'Rasteransicht',
            onPressed: () => setState(() => _gridView = !_gridView),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_hasNewPosts)
            GestureDetector(
              onTap: _onNewPostsBannerTap,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                color: AppColors.primary500,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.arrow_upward, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      _newPostCount == 1 ? '1 neuer Beitrag' : '$_newPostCount neue Beiträge',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    const Text('- Tippe zum Aktualisieren',
                        style: TextStyle(color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() {
                  _hasNewPosts = false;
                  _newPostCount = 0;
                });
                await _loadPosts();
              },
              color: AppColors.primary500,
              child: _buildContent(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/dashboard/create'),
        icon: const Icon(Icons.add),
        label: const Text('Erstellen'),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const EditorialHeader(
          section: 'Beiträge',
          number: '03',
          title: 'Beiträge in deiner Nähe',
          subtitle: 'Finde und biete Hilfe in deiner Nachbarschaft',
          icon: Icons.article_outlined,
        ),
        const SizedBox(height: 16),
        _buildSearchField(),
        const SizedBox(height: 8),
        _buildLocationField(),
        const SizedBox(height: 12),
        _buildTypeFilters(),
        const SizedBox(height: 8),
        TextButton.icon(
          icon: Icon(_showAdvancedFilters ? Icons.expand_less : Icons.tune, size: 18),
          label: const Text('Erweiterte Filter'),
          onPressed: () => setState(() => _showAdvancedFilters = !_showAdvancedFilters),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _showAdvancedFilters ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          firstChild: _buildAdvancedFilters(),
          secondChild: const SizedBox.shrink(),
        ),
        _buildActiveFilterChips(),
        const SizedBox(height: 12),
        _buildList(),
      ],
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Beiträge suchen...',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  _loadPosts();
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border)),
        filled: true,
        fillColor: AppColors.background,
      ),
      onSubmitted: (_) => _loadPosts(),
    );
  }

  Widget _buildLocationField() {
    return TextField(
      controller: _locationController,
      decoration: InputDecoration(
        hintText: 'Ort eingeben...',
        prefixIcon: const Icon(Icons.location_on_outlined, size: 20),
        suffixIcon: _locationController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _locationController.clear();
                  _loadPosts();
                },
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: AppColors.border)),
        filled: true,
        fillColor: AppColors.background,
      ),
      onSubmitted: (_) => _loadPosts(),
    );
  }

  Widget _buildTypeFilters() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _typeFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = _typeFilters[i];
          final isSelected = _selectedType == f['value'];
          return FilterChip(
            label: Text('${f['emoji']} ${f['label']}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                )),
            selected: isSelected,
            selectedColor: AppColors.primary500,
            backgroundColor: AppColors.surface,
            side: BorderSide(color: isSelected ? AppColors.primary500 : AppColors.border),
            onSelected: (_) {
              setState(() => _selectedType = f['value'] );
              _loadPosts();
            },
          );
        },
      ),
    );
  }

  Widget _buildAdvancedFilters() {
    final hasLocation = _userLat != null && _userLng != null;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (hasLocation) ...[
            Text('Radius: ${(_radius ?? 50).round()} km',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            Slider(
              value: _radius ?? 50,
              min: 5,
              max: 200,
              divisions: 39,
              activeColor: AppColors.primary500,
              onChanged: (v) => setState(() => _radius = v),
              onChangeEnd: (_) => _loadPosts(),
            ),
            const SizedBox(height: 4),
          ] else
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'Standort in Profil hinterlegen, um Radius zu nutzen',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ),
          const Text('Dringlichkeit',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _urgencyFilters.map((u) => ChoiceChip(
              label: Text(u.label, style: const TextStyle(fontSize: 11)),
              selected: _urgency == u.value,
              selectedColor: u.value == 'critical' ? AppColors.emergency.withValues(alpha: 0.2) : AppColors.primary100,
              onSelected: (_) {
                setState(() => _urgency = _urgency == u.value ? null : u.value);
                _loadPosts();
              },
            )).toList(),
          ),
          const SizedBox(height: 12),
          const Text('Beliebte Tags',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _popularTags.map((tag) => FilterChip(
              label: Text(tag, style: const TextStyle(fontSize: 11)),
              selected: _activeTag == tag,
              selectedColor: AppColors.primary100,
              onSelected: (_) {
                setState(() => _activeTag = _activeTag == tag ? null : tag);
                _loadPosts();
              },
            )).toList(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _resetAllFilters,
              child: const Text('Filter zurücksetzen'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChips() {
    final chips = <Widget>[];
    if (_searchController.text.isNotEmpty) {
      chips.add(Chip(
        label: Text('Suche: ${_searchController.text}'),
        onDeleted: () {
          _searchController.clear();
          _loadPosts();
        },
      ));
    }
    if (_locationController.text.isNotEmpty) {
      chips.add(Chip(
        label: Text('Ort: ${_locationController.text}'),
        onDeleted: () {
          _locationController.clear();
          _loadPosts();
        },
      ));
    }
    if (_activeTag != null) {
      chips.add(Chip(
        label: Text(_activeTag!),
        onDeleted: () {
          setState(() => _activeTag = null);
          _loadPosts();
        },
      ));
    }
    if (_urgency != null) {
      final label = _urgencyFilters.firstWhere((u) => u.value == _urgency, orElse: () => (value: null, label: _urgency!)).label;
      chips.add(Chip(
        label: Text('Dringlichkeit: $label'),
        onDeleted: () {
          setState(() => _urgency = null);
          _loadPosts();
        },
      ));
    }
    if (_radius != null) {
      chips.add(Chip(
        label: Text('${_radius!.round()} km'),
        onDeleted: () {
          setState(() => _radius = null);
          _loadPosts();
        },
      ));
    }
    if (chips.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(spacing: 6, runSpacing: 4, children: chips),
    );
  }

  Widget _buildList() {
    if (_loadingInitial) {
      return const Padding(
        padding: EdgeInsets.only(top: 24),
        child: LoadingSkeleton(type: SkeletonType.postList),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 32),
        child: Center(
          child: Column(
            children: [
              const Icon(Icons.error_outline, size: 48, color: AppColors.error),
              const SizedBox(height: 16),
              const Text('Fehler beim Laden'),
              const SizedBox(height: 8),
              ElevatedButton(onPressed: _loadPosts, child: const Text('Erneut versuchen')),
            ],
          ),
        ),
      );
    }
    if (_allPosts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(top: 32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.inbox_outlined, size: 48, color: AppColors.textMuted),
              SizedBox(height: 12),
              Text('Keine Beiträge', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text('Erstelle den ersten Beitrag!',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            ],
          ),
        ),
      );
    }
    return Column(
      children: [
        if (_gridView)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.3,
            ),
            itemCount: _allPosts.length,
            itemBuilder: (_, i) {
              final post = _allPosts[i];
              return _CompactPostCard(
                post: post,
                onTap: () => context.push('/dashboard/posts/${post.id}'),
              );
            },
          )
        else
          ..._allPosts.map((post) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: PostCard(
                  post: post,
                  onTap: () => context.push('/dashboard/posts/${post.id}'),
                ),
              )),
        if (_hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: TextButton(
                onPressed: _loadingMore ? null : _loadMore,
                child: _loadingMore
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Weitere Beiträge laden'),
              ),
            ),
          ),
      ],
    );
  }
}

class _CompactPostCard extends StatelessWidget {
  final Post post;
  final VoidCallback onTap;
  const _CompactPostCard({required this.post, required this.onTap});

  String _typeEmoji(PostType type) {
    switch (type) {
      case PostType.helpNeeded: return '🙏';
      case PostType.helpOffered: return '🤝';
      case PostType.rescue: return '🧡';
      case PostType.animal: return '🐾';
      case PostType.housing: return '🏡';
      case PostType.supply: return '🌾';
      case PostType.mobility: return '🚗';
      case PostType.sharing: return '🔄';
      case PostType.crisis: return '🚨';
      case PostType.community: return '🗳️';
    }
  }

  Color _urgencyDotColor(String? urgency) {
    switch (urgency) {
      case 'critical': return AppColors.emergency;
      case 'high': return AppColors.warning;
      case 'medium': return const Color(0xFFF59E0B);
      default: return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(_typeEmoji(post.postType), style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _urgencyDotColor(post.urgency),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Expanded(
              child: Text(
                post.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.3),
              ),
            ),
            Text(
              post.locationText ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}
