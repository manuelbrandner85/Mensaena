import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mensaena/models/timebank_entry.dart';

class TimebankService {
  final SupabaseClient _client;

  TimebankService(this._client);

  Future<List<TimebankEntry>> getEntries(String userId) async {
    final data = await _client
        .from('timebank_entries')
        .select('*, giver:profiles!timebank_entries_giver_id_fkey(id, name, nickname, avatar_url), receiver:profiles!timebank_entries_receiver_id_fkey(id, name, nickname, avatar_url)')
        .or('giver_id.eq.$userId,receiver_id.eq.$userId')
        .order('created_at', ascending: false);
    return (data as List).map((e) => TimebankEntry.fromJson(e)).toList();
  }

  Future<TimebankEntry> createEntry(Map<String, dynamic> entryData) async {
    final data = await _client.from('timebank_entries').insert(entryData).select().single();
    return TimebankEntry.fromJson(data);
  }

  Future<void> confirmEntry(String entryId) async {
    await _client.from('timebank_entries').update({
      'status': 'confirmed',
      'confirmed_at': DateTime.now().toIso8601String(),
    }).eq('id', entryId);
  }

  Future<void> rejectEntry(String entryId) async {
    await _client.from('timebank_entries').update({'status': 'rejected'}).eq('id', entryId);
  }

  Future<Map<String, double>> getBalance(String userId) async {
    final given = await _client
        .from('timebank_entries')
        .select('hours')
        .eq('giver_id', userId)
        .eq('status', 'confirmed');
    final received = await _client
        .from('timebank_entries')
        .select('hours')
        .eq('receiver_id', userId)
        .eq('status', 'confirmed');

    double givenHours = 0;
    for (final row in given) givenHours += (row['hours'] as num).toDouble();
    double receivedHours = 0;
    for (final row in received) receivedHours += (row['hours'] as num).toDouble();

    return {
      'given': givenHours,
      'received': receivedHours,
      'balance': givenHours - receivedHours,
    };
  }
}
