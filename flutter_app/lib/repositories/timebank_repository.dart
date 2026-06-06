import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/timebank_entry.dart';
import '../models/zeitbank_notification.dart';
import '../services/supabase_service.dart';

/// SKILL: supabase + mensaena-features
/// Zeitbank-Repository. Eintraege + Bestaetigungs-System + Banner-Realtime.
class TimebankRepository {
  const TimebankRepository._();

  /// Eigene Eintraege (als Geber ODER Empfaenger).
  static Future<List<TimebankEntry>> listMine() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await sb
          .from('timebank_entries')
          .select()
          .or('giver_id.eq.$uid,receiver_id.eq.$uid')
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List)
          .whereType<Map<String, dynamic>>()
          .map(TimebankEntry.fromJson)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Stundenkonto-Saldo: given / received / balance / pending.
  static Future<TimebankBalance> balance() async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return const TimebankBalance.empty();
    try {
      final rows = await sb
          .from('timebank_entries')
          .select('hours,giver_id,receiver_id,status')
          .or('giver_id.eq.$uid,receiver_id.eq.$uid');
      double given = 0;
      double received = 0;
      double pendingAsGiver = 0;
      double pendingAsReceiver = 0;
      for (final r in (rows as List).whereType<Map<String, dynamic>>()) {
        final h = (r['hours'] as num?)?.toDouble() ?? 0;
        final status = r['status'] as String? ?? 'pending';
        final isGiver = r['giver_id'] == uid;
        if (status == 'confirmed') {
          if (isGiver) {
            given += h;
          } else {
            received += h;
          }
        } else if (status == 'pending') {
          if (isGiver) {
            pendingAsGiver += h;
          } else {
            pendingAsReceiver += h;
          }
        }
      }
      return TimebankBalance(
        given: given,
        received: received,
        pendingAsGiver: pendingAsGiver,
        pendingAsReceiver: pendingAsReceiver,
      );
    } catch (_) {
      return const TimebankBalance.empty();
    }
  }

  /// Neuen Eintrag erstellen (als Geber: ich habe geholfen).
  static Future<bool> create({
    required String receiverId,
    required double hours,
    required String description,
    String? category,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return false;
    try {
      await sb.from('timebank_entries').insert({
        'giver_id': uid,
        'receiver_id': receiverId,
        'hours': hours,
        'description': description,
        'category': category,
        'status': 'pending',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Empfaenger bestaetigt.
  static Future<bool> confirm(String entryId) async {
    try {
      await sb
          .from('timebank_entries')
          .update({
            'status': 'confirmed',
            'confirmed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', entryId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Empfaenger lehnt ab.
  static Future<bool> reject(String entryId) async {
    try {
      await sb
          .from('timebank_entries')
          .update({'status': 'rejected'})
          .eq('id', entryId);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Realtime-Stream: unseen confirmation_requests fuer den aktuellen User.
  static Stream<List<ZeitbankNotification>> watchUnseenNotifications() {
    final uid = SupabaseService.currentUser?.id;
    if (uid == null) return Stream.value(const []);
    return sb
        .from('zeitbank_notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(100)
        .map((rows) => rows
            .map(ZeitbankNotification.fromJson)
            .where((n) => !n.seen && n.type == 'confirmation_request')
            .toList());
  }

  static Future<void> markNotificationSeen(String id, {bool clicked = false}) async {
    try {
      await sb
          .from('zeitbank_notifications')
          .update({'seen': true, 'clicked': clicked})
          .eq('id', id);
    } catch (_) {}
  }
}

class TimebankBalance {
  const TimebankBalance({
    required this.given,
    required this.received,
    required this.pendingAsGiver,
    required this.pendingAsReceiver,
  });

  const TimebankBalance.empty()
      : given = 0,
        received = 0,
        pendingAsGiver = 0,
        pendingAsReceiver = 0;

  final double given;
  final double received;
  final double pendingAsGiver;
  final double pendingAsReceiver;

  double get balance => received - given;
}

final timebankEntriesProvider =
    FutureProvider<List<TimebankEntry>>((ref) async {
  return TimebankRepository.listMine();
});

final timebankBalanceProvider = FutureProvider<TimebankBalance>((ref) async {
  return TimebankRepository.balance();
});

final zeitbankNotificationsStreamProvider =
    StreamProvider<List<ZeitbankNotification>>((ref) {
  return TimebankRepository.watchUnseenNotifications();
});
