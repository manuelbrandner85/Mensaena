-- Add help_date column to timebank_entries
-- Allows users to specify the actual date help was given (vs. entry creation date)

ALTER TABLE public.timebank_entries
  ADD COLUMN IF NOT EXISTS help_date DATE;

-- Backfill existing rows from created_at
UPDATE public.timebank_entries
  SET help_date = created_at::date
  WHERE help_date IS NULL;
