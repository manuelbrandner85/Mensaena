import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase.dart';
import 'models.dart';

final interactionsRepositoryProvider = Provider<InteractionsRepository>(
  (ref) => InteractionsRepository(ref.read(supabaseProvider)),
);

class InteractionsRepository {
  InteractionsRepository(this._db);
  final SupabaseClient _db;

  Future<List<Interaction>> list({String filter = 'all', int limit = 30, int offset = 0}) async {
    final user = _db.auth.currentUser;
    if (user == null) return const [];
    final data = await _db.rpc<List<dynamic>>(
      'get_my_interactions',
      params: <String, dynamic>{
        'p_user_id': user.id,
        'p_status': filter == 'all' ? null : filter,
        'p_limit': limit,
        'p_offset': offset,
      },
    );
    return data
        .map((e) => Interaction.fromRpc(e as Map<String, dynamic>, user.id))
        .toList();
  }

  Future<void> respond(String id, {required bool accept, String? responseMessage}) async {
    await _db.from('interactions').update(<String, dynamic>{
      'status': accept ? 'accepted' : 'cancelled_by_helper',
      if (responseMessage != null) 'response_message': responseMessage,
    }).eq('id', id);
  }

  Future<void> startProgress(String id) async {
    await _db.from('interactions').update(<String, dynamic>{
      'status': 'in_progress',
    }).eq('id', id);
  }

  Future<void> complete(String id, {String? notes}) async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    await _db.from('interactions').update(<String, dynamic>{
      'status': 'completed',
      'completed_at': DateTime.now().toIso8601String(),
      'completed_by': user.id,
      if (notes != null && notes.isNotEmpty) 'completion_notes': notes,
    }).eq('id', id);
  }

  Future<void> cancel(String id, {String? reason}) async {
    final user = _db.auth.currentUser;
    if (user == null) return;
    final row = await _db
        .from('interactions')
        .select('helper_id')
        .eq('id', id)
        .maybeSingle();
    final helperId = row?['helper_id'] as String?;
    final amHelper = helperId == user.id;
    await _db.from('interactions').update(<String, dynamic>{
      'status': amHelper ? 'cancelled_by_helper' : 'cancelled_by_helped',
      if (reason != null && reason.isNotEmpty) 'cancel_reason': reason,
    }).eq('id', id);
  }
}
