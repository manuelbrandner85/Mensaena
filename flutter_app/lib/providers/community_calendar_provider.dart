import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/community_calendar_entry.dart';
import '../services/supabase_service.dart';

/// Aggregiert Kalender-Einträge aus events, timebank_entries, groups
/// und skill_offers innerhalb eines Radius um (lat, lng).
///
/// Regeln:
/// - Nur FutureProvider.autoDispose (kein dauerhafter Realtime-Channel).
/// - Server-Filter via .gte/.lte, kein client-seitiges Volllade-Filtering.
final communityCalendarProvider =
    FutureProvider.autoDispose.family<List<CommunityCalendarEntry>, CalendarParams>(
        (ref, params) async {
  final now = DateTime.now().toUtc();
  final cutoff = now.add(const Duration(days: 60)).toIso8601String();
  final nowIso = now.toIso8601String();

  final results = await Future.wait([
    _fetchEvents(nowIso, cutoff, params),
    _fetchTimebankSlots(nowIso, cutoff, params),
    _fetchGroupMeetings(params),
    _fetchSkillWindows(nowIso, cutoff, params),
  ]);

  final all = results.expand((list) => list).toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));
  return all;
});

Future<List<CommunityCalendarEntry>> _fetchEvents(
  String from,
  String to,
  CalendarParams p,
) async {
  try {
    final rows = await sb
        .from('events')
        .select('id, title, category, start_date, end_date, description, location_name, latitude, longitude')
        .gte('start_date', from)
        .lte('start_date', to)
        .neq('status', 'cancelled')
        .order('start_date')
        .limit(100);

    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .where((r) => _withinRadius(r['latitude'], r['longitude'], p))
        .map((r) => CommunityCalendarEntry(
              id: 'event_${r['id']}',
              type: CommunityCalendarType.event,
              title: r['title'] as String? ?? '',
              startDate: DateTime.parse(r['start_date'] as String).toLocal(),
              endDate: r['end_date'] != null
                  ? DateTime.parse(r['end_date'] as String).toLocal()
                  : null,
              description: r['description'] as String?,
              locationName: r['location_name'] as String?,
              latitude: (r['latitude'] as num?)?.toDouble(),
              longitude: (r['longitude'] as num?)?.toDouble(),
              category: r['category'] as String?,
              sourceId: r['id'] as String?,
              routePath: '/dashboard/events/${r['id']}',
            ))
        .toList();
  } catch (_) {
    return const [];
  }
}

Future<List<CommunityCalendarEntry>> _fetchTimebankSlots(
  String from,
  String to,
  CalendarParams p,
) async {
  try {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];

    final rows = await sb
        .from('timebank_entries')
        .select('id, description, created_at, category, hours, giver_id')
        .eq('status', 'pending')
        .gte('created_at', from)
        .lte('created_at', to)
        .neq('giver_id', uid)
        .order('created_at')
        .limit(50);

    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .map((r) {
          final created = DateTime.parse(r['created_at'] as String).toLocal();
          return CommunityCalendarEntry(
            id: 'timebank_${r['id']}',
            type: CommunityCalendarType.timebankSlot,
            title: r['description'] as String? ?? '',
            startDate: created,
            category: r['category'] as String?,
            sourceId: r['id'] as String?,
            routePath: '/dashboard/timebank',
          );
        })
        .toList();
  } catch (_) {
    return const [];
  }
}

Future<List<CommunityCalendarEntry>> _fetchGroupMeetings(
  CalendarParams p,
) async {
  try {
    final rows = await sb
        .from('groups')
        .select('id, name, category, next_meeting_at, latitude, longitude, description')
        .eq('is_archived', false)
        .not('next_meeting_at', 'is', null)
        .order('next_meeting_at')
        .limit(50);

    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .where((r) => _withinRadius(r['latitude'], r['longitude'], p))
        .where((r) => r['next_meeting_at'] != null)
        .map((r) {
          final meetingAt =
              DateTime.parse(r['next_meeting_at'] as String).toLocal();
          return CommunityCalendarEntry(
            id: 'group_${r['id']}',
            type: CommunityCalendarType.groupMeeting,
            title: r['name'] as String? ?? '',
            startDate: meetingAt,
            description: r['description'] as String?,
            latitude: (r['latitude'] as num?)?.toDouble(),
            longitude: (r['longitude'] as num?)?.toDouble(),
            category: r['category'] as String?,
            sourceId: r['id'] as String?,
            routePath: '/dashboard/groups/${r['id']}',
          );
        })
        .toList();
  } catch (_) {
    return const [];
  }
}

Future<List<CommunityCalendarEntry>> _fetchSkillWindows(
  String from,
  String to,
  CalendarParams p,
) async {
  try {
    final rows = await sb
        .from('skill_offers')
        .select('id, title, description, available_from, available_until, location_lat, location_lng, skill_category')
        .eq('is_active', true)
        .not('available_from', 'is', null)
        .gte('available_until', from)
        .lte('available_from', to)
        .order('available_from')
        .limit(50);

    return (rows as List)
        .whereType<Map<String, dynamic>>()
        .where((r) => _withinRadius(r['location_lat'], r['location_lng'], p))
        .map((r) => CommunityCalendarEntry(
              id: 'skill_${r['id']}',
              type: CommunityCalendarType.skillWindow,
              title: r['title'] as String? ?? '',
              startDate: DateTime.parse(r['available_from'] as String).toLocal(),
              endDate: r['available_until'] != null
                  ? DateTime.parse(r['available_until'] as String).toLocal()
                  : null,
              description: r['description'] as String?,
              latitude: (r['location_lat'] as num?)?.toDouble(),
              longitude: (r['location_lng'] as num?)?.toDouble(),
              category: r['skill_category'] as String?,
              sourceId: r['id'] as String?,
              routePath: '/dashboard/skills',
            ))
        .toList();
  } catch (_) {
    return const [];
  }
}

bool _withinRadius(dynamic rawLat, dynamic rawLng, CalendarParams p) {
  final lat = (rawLat as num?)?.toDouble();
  final lng = (rawLng as num?)?.toDouble();
  if (lat == null || lng == null) return true;
  return _haversineKm(p.lat, p.lng, lat, lng) <= p.radiusKm;
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _deg(lat2 - lat1);
  final dLon = _deg(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(_deg(lat1)) *
          math.cos(_deg(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return r * 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
}

double _deg(double d) => d * math.pi / 180;
