/// SKILL: mensaena-architektur
/// Repository fuer den Marketing-Admin-Bereich.
/// Liest Stats/Segmente per RPC, listet/erstellt/sendet Kampagnen.
library;

import '../services/supabase_service.dart';

class MarketingDashboardStats {
  const MarketingDashboardStats(this.raw);
  final Map<String, dynamic> raw;
  int get newUsersWeek => (raw['new_users_week'] ?? 0) as int;
  int get newUsers30d => (raw['new_users_30d'] ?? 0) as int;
  int get referralsCompleted30d => (raw['referrals_completed_30d'] ?? 0) as int;
  int get emailOptIn => (raw['email_opt_in'] ?? 0) as int;
  int get marketingOptIn => (raw['marketing_opt_in'] ?? 0) as int;
  int get reactivationOptIn => (raw['reactivation_opt_in'] ?? 0) as int;
  int get emailSent30d => (raw['email_sent_30d'] ?? 0) as int;
  num get emailOpenRate30d => (raw['email_open_rate_30d'] ?? 0) as num;
  num get emailClickRate30d => (raw['email_click_rate_30d'] ?? 0) as num;
  int get pushSent30d => (raw['push_sent_30d'] ?? 0) as int;
  bool get marketingPaused => raw['marketing_paused'] == true;
  List<Map<String, dynamic>> get topRegions =>
      ((raw['top_regions'] as List?) ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
}

class MarketingRepository {
  Future<MarketingDashboardStats> stats() async {
    final dynamic res =
        await SupabaseService.client.rpc<dynamic>('marketing_dashboard_stats');
    return MarketingDashboardStats(
        Map<String, dynamic>.from((res as Map?) ?? const {}));
  }

  Future<Map<String, dynamic>> segmentCounts() async {
    final dynamic res =
        await SupabaseService.client.rpc<dynamic>('marketing_segment_counts');
    return Map<String, dynamic>.from((res as Map?) ?? const {});
  }

  Future<bool> setPaused(bool paused) async {
    final dynamic res = await SupabaseService.client
        .rpc<dynamic>('set_marketing_paused', params: {'p_paused': paused});
    return res == true;
  }

  // ── E-Mail-Kampagnen ────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> listEmailCampaigns({int limit = 50}) async {
    final rows = await SupabaseService.client
        .from('email_campaigns')
        .select('id, subject, status, sent_at, sent_count, open_count, click_count, created_at')
        .order('created_at', ascending: false)
        .limit(limit);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<String?> createEmailCampaign({
    required String subject,
    required String html,
    String? text,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    final ins = await SupabaseService.client.from('email_campaigns').insert({
      'subject': subject,
      'body_html': html,
      'body_text': text,
      'status': 'draft',
      if (uid != null) 'created_by': uid,
    }).select('id').maybeSingle();
    return (ins as Map?)?['id']?.toString();
  }

  Future<Map<String, dynamic>> sendEmailCampaign(String campaignId,
      {String? segmentId, String? testTo}) async {
    final res = await SupabaseService.client.functions.invoke(
      'send-email-campaign',
      body: {
        'campaign_id': campaignId,
        if (segmentId != null) 'segment_id': segmentId,
        if (testTo != null) 'test_to': testTo,
      },
    );
    return Map<String, dynamic>.from((res.data as Map?) ?? const {});
  }

  // ── Push-Kampagnen ──────────────────────────────────────────────────────
  Future<Map<String, dynamic>> sendPushCampaign({
    required String title,
    required String body,
    String? link,
    String? segmentId,
  }) async {
    final res = await SupabaseService.client.functions.invoke(
      'send-push-campaign',
      body: {
        'title': title,
        'body': body,
        if (link != null) 'link': link,
        if (segmentId != null) 'segment_id': segmentId,
      },
    );
    return Map<String, dynamic>.from((res.data as Map?) ?? const {});
  }

  // ── Phase 2: Vorlagen-Editor ────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> listTemplates() async {
    final rows = await SupabaseService.client
        .from('message_templates')
        .select('id, name, kind, subject, body_html, body_text, description, updated_at')
        .order('updated_at', ascending: false)
        .limit(100);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  Future<String?> upsertTemplate({
    String? id,
    required String name,
    required String kind,
    String? subject,
    String? bodyHtml,
    String? bodyText,
    String? description,
  }) async {
    final uid = SupabaseService.currentUser?.id;
    final payload = <String, dynamic>{
      if (id != null) 'id': id,
      'name': name,
      'kind': kind,
      'subject': subject,
      'body_html': bodyHtml,
      'body_text': bodyText,
      'description': description,
      'updated_at': DateTime.now().toIso8601String(),
      if (id == null && uid != null) 'created_by': uid,
    };
    final res = await SupabaseService.client
        .from('message_templates')
        .upsert(payload)
        .select('id')
        .maybeSingle();
    return (res as Map?)?['id']?.toString();
  }

  Future<void> deleteTemplate(String id) async {
    await SupabaseService.client.from('message_templates').delete().eq('id', id);
  }

  // ── Phase 2: Empfehlungs-Übersicht ──────────────────────────────────────
  Future<Map<String, dynamic>> referralsOverview() async {
    final res =
        await SupabaseService.client.rpc('marketing_referrals_overview');
    return Map<String, dynamic>.from((res as Map?) ?? const {});
  }

  // ── Phase 2: Region-Manager ─────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> regionsOverview() async {
    final res = await SupabaseService.client.rpc('marketing_regions_overview');
    if (res is List) {
      return res
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();
    }
    return const [];
  }
}
