-- v_my_matches: Supabase .stream() unterstützt kein .or()-Filter.
-- Diese View vereint beide Rollen (offer/request) und exponiert user_id,
-- damit .stream().eq('user_id', uid).limit(100) serverseitig filtert.
CREATE OR REPLACE VIEW v_my_matches
  WITH (security_invoker = true)
AS
  SELECT
    id, offer_post_id, request_post_id, offer_user_id, request_user_id,
    match_score, score_breakdown, status, distance_km,
    offer_responded, request_responded, offer_accepted, request_accepted,
    conversation_id, seen_by_offer, seen_by_request,
    declined_by, decline_reason, expires_at, completed_at,
    created_at, updated_at,
    offer_user_id AS user_id
  FROM matches
  UNION ALL
  SELECT
    id, offer_post_id, request_post_id, offer_user_id, request_user_id,
    match_score, score_breakdown, status, distance_km,
    offer_responded, request_responded, offer_accepted, request_accepted,
    conversation_id, seen_by_offer, seen_by_request,
    declined_by, decline_reason, expires_at, completed_at,
    created_at, updated_at,
    request_user_id AS user_id
  FROM matches;

GRANT SELECT ON v_my_matches TO authenticated;

-- Realtime-Publikation: matches (Basistabelle) ist bereits enthalten;
-- Supabase leitet Änderungen der Basistabelle an Stream-Subscriber weiter.
