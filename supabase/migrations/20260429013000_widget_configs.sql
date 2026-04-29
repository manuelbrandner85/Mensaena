-- Widget-Configs Tabelle für Cross-Device-Sync der Dashboard-Widget-Anordnung.
-- Wird vom Zustand-Store `useWidgetStore` (src/stores/widgetStore.ts) per
-- loadFromSupabase / saveToSupabase angesprochen.

CREATE TABLE IF NOT EXISTS public.widget_configs (
  user_id    UUID PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  config     JSONB NOT NULL DEFAULT '[]'::jsonb,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.widget_configs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own widget config" ON public.widget_configs;
CREATE POLICY "Users can manage own widget config"
  ON public.widget_configs
  FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
