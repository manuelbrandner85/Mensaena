-- Referral-Verbesserungen (V3 + V5).
--
-- V3: referral_inviter_name(code) — öffentliche Namens-Auflösung für den
--     "Du wurdest von … eingeladen"-Banner auf dem Registrieren-Screen.
--     SECURITY DEFINER, weil RLS auf referrals/profiles den anonymen Zugriff
--     sonst blockiert. Gibt NUR den Vornamen/Anzeigenamen des Einladenden
--     zurück (kein sensibler Datenzugriff), und nur für noch offene Codes.
--
-- V5: accept_referral vergibt jetzt zusätzlich Karma an den Einladenden
--     (sofortiger Anreiz, nicht erst ab dem 3er-Badge). Rest der Funktion
--     unverändert (Badge ab 3, Notification, neuer pending-Code).

-- ── V3: Namens-Auflösung ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.referral_inviter_name(p_code TEXT)
RETURNS TEXT
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
STABLE
AS $$
  SELECT p.full_name
  FROM public.referrals r
  JOIN public.profiles p ON p.id = r.inviter_id
  WHERE r.invite_code = p_code AND r.status = 'pending'
  LIMIT 1;
$$;

GRANT EXECUTE ON FUNCTION public.referral_inviter_name(TEXT) TO anon, authenticated;

-- ── V5: accept_referral um Karma-Belohnung erweitern ────────────────────────
CREATE OR REPLACE FUNCTION public.accept_referral(
    p_invite_code TEXT,
    p_invitee_id  UUID
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_referral       RECORD;
    v_accepted_count INTEGER;
    v_badge_id       UUID;
    v_has_badge      BOOLEAN;
BEGIN
    SELECT * INTO v_referral
    FROM public.referrals
    WHERE invite_code = p_invite_code AND status = 'pending';

    IF NOT FOUND THEN
        RETURN '{"success":false,"error":"Code ungültig oder bereits verwendet"}'::JSON;
    END IF;

    IF v_referral.inviter_id = p_invitee_id THEN
        RETURN '{"success":false,"error":"Eigener Code"}'::JSON;
    END IF;

    UPDATE public.referrals
    SET invitee_id  = p_invitee_id,
        status      = 'accepted',
        accepted_at = now()
    WHERE invite_code = p_invite_code AND status = 'pending';

    -- V5: Karma für den Einladenden — sofortiger Anreiz je erfolgreiche Einladung.
    INSERT INTO public.karma_log (user_id, delta, reason, reference_type, reference_id)
    VALUES (v_referral.inviter_id, 15, 'referral_accepted', 'referral', v_referral.id);

    SELECT COUNT(*) INTO v_accepted_count
    FROM public.referrals
    WHERE inviter_id = v_referral.inviter_id AND status = 'accepted';

    IF v_accepted_count >= 3 THEN
        SELECT id INTO v_badge_id
        FROM public.badges
        WHERE name = 'Nachbarschafts-Botschafter:in'
        LIMIT 1;

        IF v_badge_id IS NULL THEN
            INSERT INTO public.badges
                (name, description, icon, category, requirement_type, requirement_value, points, rarity)
            VALUES (
                'Nachbarschafts-Botschafter:in',
                'Du hast mindestens 3 Nachbarn erfolgreich eingeladen.',
                '🤝', 'botschafter', 'referrals_accepted', 3, 100, 'rare'
            )
            RETURNING id INTO v_badge_id;
        END IF;

        SELECT EXISTS (
            SELECT 1 FROM public.user_badges
            WHERE user_id = v_referral.inviter_id AND badge_id = v_badge_id
        ) INTO v_has_badge;

        IF NOT v_has_badge THEN
            INSERT INTO public.user_badges (user_id, badge_id)
            VALUES (v_referral.inviter_id, v_badge_id);
        END IF;
    END IF;

    INSERT INTO public.notifications
        (user_id, type, title, body, content)
    VALUES (
        v_referral.inviter_id,
        'referral_accepted',
        'Deine Einladung wurde angenommen!',
        'Deine Einladung wurde angenommen!',
        'Ein neuer Nachbar ist über deinen Einladungslink beigetreten (+15 Karma).'
    );

    INSERT INTO public.referrals (inviter_id, invite_code, status)
    VALUES (v_referral.inviter_id, uuid_generate_v4()::TEXT, 'pending');

    RETURN '{"success":true}'::JSON;
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_referral(TEXT, UUID) TO authenticated;
