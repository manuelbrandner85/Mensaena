-- ============================================================
-- DSGVO Speicherbegrenzung (Art. 5 Abs. 1 lit. e): automatische Löschung
-- alter personenbezogener Log-/Engagement-Daten per pg_cron.
--
-- HINWEIS: Die Fristen sind konservative Defaults und sollten mit der/dem
-- Datenschutz-Anwält:in final festgelegt werden. cron.schedule mit gleichem
-- Job-Namen ersetzt eine bestehende Definition (idempotent). Läuft nur, wenn
-- pg_cron aktiv ist (nicht auf Preview-Branches).
-- ============================================================
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN

    -- E-Mail-Versandprotokolle: 12 Monate
    PERFORM cron.schedule(
      'gdpr-retention-email-logs',
      '5 3 * * *',
      'DELETE FROM public.email_logs WHERE sent_at < NOW() - INTERVAL ''12 months'''
    );

    -- E-Mail-Engagement (Öffnungen/Klicks): 12 Monate
    PERFORM cron.schedule(
      'gdpr-retention-email-opens',
      '8 3 * * *',
      'DELETE FROM public.email_opens WHERE created_at < NOW() - INTERVAL ''12 months'''
    );
    PERFORM cron.schedule(
      'gdpr-retention-email-clicks',
      '11 3 * * *',
      'DELETE FROM public.email_clicks WHERE created_at < NOW() - INTERVAL ''12 months'''
    );

    -- Kampagnen-Events (Sent/Open/Click): 12 Monate
    PERFORM cron.schedule(
      'gdpr-retention-campaign-events',
      '14 3 * * *',
      'DELETE FROM public.campaign_events WHERE created_at < NOW() - INTERVAL ''12 months'''
    );

    -- KI-Feedback (Klartext Frage/Antwort): 12 Monate
    PERFORM cron.schedule(
      'gdpr-retention-ai-chat-feedback',
      '17 3 * * *',
      'DELETE FROM public.ai_chat_feedback WHERE created_at < NOW() - INTERVAL ''12 months'''
    );

    -- KI-Analytics (nur Metadaten): 14 Monate
    PERFORM cron.schedule(
      'gdpr-retention-ai-chat-analytics',
      '20 3 * * *',
      'DELETE FROM public.ai_chat_analytics WHERE created_at < NOW() - INTERVAL ''14 months'''
    );

    -- Audit-Logs (Moderation): 24 Monate
    PERFORM cron.schedule(
      'gdpr-retention-audit-logs',
      '23 3 * * *',
      'DELETE FROM public.audit_logs WHERE created_at < NOW() - INTERVAL ''24 months'''
    );

  END IF;
END;
$$;
