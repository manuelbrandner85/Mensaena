-- Speichert das verwendete KI-Modell pro Godmode-Auftrag (z. B. claude-opus-4-8).
-- Standard ist Opus 4.8; nur wenn der Admin bewusst Haiku/Sonnet wählt, weicht es
-- ab. Wird im Dashboard als Badge angezeigt ("Modell pro Auftrag sichtbar").
alter table public.admin_dev_tasks
  add column if not exists model text;
