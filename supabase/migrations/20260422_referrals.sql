-- Referral-System: Tabelle, Indexes, RLS, accept_referral-Funktion

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── Tabelle ──────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.referrals (
    id            UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    inviter_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    invite_code   TEXT        NOT NULL UNIQUE,
    invitee_id    UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
    invitee_email TEXT,
    status        TEXT        NOT NULL DEFAULT 'pending'
                              CHECK (status IN ('pending', 'accepted', 'expired')),
    created_at    TIMESTAMPTZ DEFAULT now(),
    accepted_at   TIMESTAMPTZ
);

-- ─── Indexes ──────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_referrals_inviter ON public.referrals(inviter_id);
CREATE INDEX IF NOT EXISTS idx_referrals_code    ON public.referrals(invite_code);
CREATE INDEX IF NOT EXISTS idx_referrals_status  ON public.referrals(status);

-- ─── RLS ──────────────────────────────────────────────────────────────────────

ALTER TABLE public.referrals ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Eigene Referrals lesen"
    ON public.referrals FOR SELECT
    TO authenticated
    USING (inviter_id = auth.uid() OR invitee_id = auth.uid());

CREATE POLICY "Referral erstellen"
    ON public.referrals FOR INSERT
    TO authenticated
    WITH CHECK (inviter_id = auth.uid());

-- ─── Funktion accept_referral ─────────────────────────────────────────────────

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
    -- Prüfe ob Code existiert und noch pending ist
    SELECT * INTO v_referral
    FROM public.referrals
    WHERE invite_code = p_invite_code AND status = 'pending';

    IF NOT FOUND THEN
        RETURN '{"success":false,"error":"Code ungültig oder bereits verwendet"}'::JSON;
    END IF;

    -- Eigener Code nicht erlaubt
    IF v_referral.inviter_id = p_invitee_id THEN
        RETURN '{"success":false,"error":"Eigener Code"}'::JSON;
    END IF;

    -- Referral akzeptieren
    UPDATE public.referrals
    SET invitee_id  = p_invitee_id,
        status      = 'accepted',
        accepted_at = now()
    WHERE invite_code = p_invite_code AND status = 'pending';

    -- Anzahl akzeptierter Referrals des Inviters zählen
    SELECT COUNT(*) INTO v_accepted_count
    FROM public.referrals
    WHERE inviter_id = v_referral.inviter_id AND status = 'accepted';

    -- Badge "Nachbarschafts-Botschafter:in" ab 3 akzeptierten Referrals
    IF v_accepted_count >= 3 THEN
        -- Badge-Definition holen (anlegen falls noch nicht vorhanden)
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
                '🤝',
                'botschafter',
                'referrals_accepted',
                3,
                100,
                'rare'
            )
            RETURNING id INTO v_badge_id;
        END IF;

        -- Prüfe ob Nutzer Badge schon besitzt
        SELECT EXISTS (
            SELECT 1 FROM public.user_badges
            WHERE user_id = v_referral.inviter_id AND badge_id = v_badge_id
        ) INTO v_has_badge;

        IF NOT v_has_badge THEN
            INSERT INTO public.user_badges (user_id, badge_id)
            VALUES (v_referral.inviter_id, v_badge_id);
        END IF;
    END IF;

    -- Benachrichtigung für den Inviter
    INSERT INTO public.notifications
        (user_id, type, title, body, content)
    VALUES (
        v_referral.inviter_id,
        'referral_accepted',
        'Deine Einladung wurde angenommen!',
        'Deine Einladung wurde angenommen!',
        'Ein neuer Nachbar ist über deinen Einladungslink beigetreten.'
    );

    -- Neuen pending Referral für den Inviter anlegen
    INSERT INTO public.referrals (inviter_id, invite_code, status)
    VALUES (v_referral.inviter_id, uuid_generate_v4()::TEXT, 'pending');

    RETURN '{"success":true}'::JSON;
END;
$$;

GRANT EXECUTE ON FUNCTION public.accept_referral(TEXT, UUID) TO authenticated;
