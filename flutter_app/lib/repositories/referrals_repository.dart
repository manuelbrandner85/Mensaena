/// SKILL: supabase + mensaena-features
/// ReferralsRepository — Einladungs-Codes + Empfehlungs-Statistik
/// (referrals-Tabelle). Vorher 4 Queries direkt im invite_screen.
library;

import '../services/supabase_service.dart';

class ReferralsRepository {
  const ReferralsRepository._();

  /// Liefert den bestehenden pending-Invite-Code des Users oder legt
  /// einen neuen an (DB generiert invite_code). Plus accepted/pending-Zaehler.
  static Future<({String? code, int accepted, int pending})> myInviteState(
      String userId) async {
    final pending = await sb
        .from('referrals')
        .select('invite_code')
        .eq('inviter_id', userId)
        .eq('status', 'pending')
        .limit(1)
        .maybeSingle();
    var code = pending?['invite_code'] as String?;
    if (code == null) {
      final inserted = await sb
          .from('referrals')
          .insert({'inviter_id': userId, 'status': 'pending'})
          .select('invite_code')
          .maybeSingle();
      code = inserted?['invite_code'] as String?;
    }
    final acceptedRes = await sb
        .from('referrals')
        .select('id')
        .eq('inviter_id', userId)
        .eq('status', 'accepted');
    final pendingRes = await sb
        .from('referrals')
        .select('id')
        .eq('inviter_id', userId)
        .eq('status', 'pending');
    return (
      code: code,
      accepted: (acceptedRes as List).length,
      pending: (pendingRes as List).length,
    );
  }
}
