import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../theme/app_colors.dart';

/// Pendant zu /dashboard/jobs. Sucht externe Stellenangebote über die
/// Cloudflare-Workers-Route /api/jobs (Bundesagentur-Schnittstelle).
class JobsPage extends ConsumerStatefulWidget {
  const JobsPage({super.key});

  @override
  ConsumerState<JobsPage> createState() => _JobsPageState();
}

class _JobsPageState extends ConsumerState<JobsPage> {
  final _plz = TextEditingController(text: '1010');
  final _query = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>> _jobs = const [];
  bool _loading = false;
  String? _error;
  Set<String> _worktime = const {};

  static const _worktimeOptions = [
    (key: 'vz', label: 'Vollzeit'),
    (key: 'tz', label: 'Teilzeit'),
    (key: 'mj', label: 'Minijob'),
    (key: 'snw', label: 'Schicht'),
    (key: 'ho', label: 'Homeoffice'),
  ];

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _plz.dispose();
    _query.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await ref.read(apiClientProvider).get<Map<String, dynamic>>(
        '/api/jobs',
        query: <String, dynamic>{
          'plz': _plz.text.trim().isEmpty ? '1010' : _plz.text.trim(),
          if (_query.text.trim().isNotEmpty) 'query': _query.text.trim(),
          if (_worktime.isNotEmpty) 'worktime': _worktime.join(';'),
          'radius': 25,
          'limit': 30,
        },
      );
      if (!mounted) return;
      final data = response.data ?? const <String, dynamic>{};
      final list = (data['jobs'] as List?) ?? const [];
      setState(() {
        _jobs = list.whereType<Map<String, dynamic>>().toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  void _onChanged() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), _search);
  }

  Future<void> _open(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Jobs')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _plz,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => _onChanged(),
                    decoration: const InputDecoration(
                      labelText: 'PLZ',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _query,
                    onChanged: (_) => _onChanged(),
                    decoration: const InputDecoration(
                      labelText: 'Suchbegriff',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: _worktimeOptions
                  .map(
                    (w) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(w.label),
                        selected: _worktime.contains(w.key),
                        onSelected: (sel) {
                          setState(() {
                            _worktime = {..._worktime};
                            if (sel) {
                              _worktime.add(w.key);
                            } else {
                              _worktime.remove(w.key);
                            }
                          });
                          _search();
                        },
                        selectedColor:
                            AppColors.primary500.withValues(alpha: 0.15),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'Fehler: $_error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppColors.ink400),
                          ),
                        ),
                      )
                    : _jobs.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text(
                                'Keine Jobs gefunden',
                                style: TextStyle(color: AppColors.ink400),
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _search,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _jobs.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (_, i) =>
                                  _JobCard(data: _jobs[i], onOpen: _open),
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

class _JobCard extends StatelessWidget {
  const _JobCard({required this.data, required this.onOpen});
  final Map<String, dynamic> data;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final published = data['publishedDate'] as String?;
    final publishedFmt = published != null
        ? DateFormat('d. MMM', 'de').format(DateTime.parse(published))
        : '';
    final url = data['url'] as String?;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: url != null ? () => onOpen(url) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data['title'] as String? ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data['employer'] as String? ?? '',
                style: const TextStyle(
                  color: AppColors.ink700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 12, color: AppColors.ink400),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      [data['plz'], data['city']].whereType<String>().join(' '),
                      style: const TextStyle(
                        color: AppColors.ink400,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  if ((data['worktime'] as String?) != null) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.access_time,
                        size: 12, color: AppColors.ink400),
                    const SizedBox(width: 2),
                    Text(
                      data['worktime'] as String,
                      style: const TextStyle(
                        color: AppColors.ink400,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    publishedFmt,
                    style: const TextStyle(
                      color: AppColors.ink400,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
