import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../core/atmosphere/cinema_scaffold.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/cinema_appbar.dart';
import '../../core/widgets/cinema_avatar.dart';
import '../../core/widgets/cinema_empty_state.dart';
import '../../core/widgets/cinema_input.dart';
import '../../core/widgets/cinema_tabs.dart';
import '../../services/supabase/supabase_service.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _q = '';
  List<Map<String, dynamic>> _people = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _ctrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQuery(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _run(v));
  }

  Future<void> _run(String q) async {
    setState(() {
      _q = q.trim();
      _loading = true;
    });
    if (_q.isEmpty) {
      setState(() {
        _people = [];
        _loading = false;
      });
      return;
    }
    try {
      final res = await supabase.client
          .from('profiles')
          .select('id, full_name, avatar_url, location')
          .ilike('full_name', '%$_q%')
          .limit(20);
      setState(() {
        _people = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CinemaScaffold(
      appBar: const CinemaAppBar(title: 'SUCHE'),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: CinemaInput(
                controller: _ctrl,
                placeholder: 'Nachbarschaft durchsuchen...',
                variant: CinemaInputVariant.search,
                autofocus: true,
                onChanged: _onQuery,
              ),
            ),
            CinemaTabs(
              controller: _tabs,
              labels: const ['Beitraege', 'Personen', 'Gruppen', 'Events', 'Wiki'],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  _empty('Beitraege folgen.'),
                  _peopleList(),
                  _empty('Gruppen folgen.'),
                  _empty('Events folgen.'),
                  _empty('Wiki folgt.'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(String label) => CinemaEmptyState(
        icon: LucideIcons.search,
        title: _q.isEmpty ? 'Tippe einen Suchbegriff ein.' : 'Keine Treffer fuer "$_q".',
        message: label,
      );

  Widget _peopleList() {
    if (_loading) return const Center(child: CircularProgressIndicator(color: MnColors.amber));
    if (_people.isEmpty) return _empty('Personen folgen.');
    return ListView.builder(
      itemCount: _people.length,
      itemBuilder: (_, i) {
        final p = _people[i];
        return ListTile(
          leading: CinemaAvatar(
            imageUrl: p['avatar_url'] as String?,
            displayName: p['full_name'] as String?,
          ),
          title: Text(
            (p['full_name'] as String?) ?? 'Nachbar*in',
            style: MnTypography.body(color: MnColors.ink),
          ),
          subtitle: Text(
            (p['location'] as String?) ?? '',
            style: MnTypography.caption(),
          ),
          onTap: () => GoRouter.of(context).push('/profile/${p['id']}'),
        );
      },
    );
  }
}
