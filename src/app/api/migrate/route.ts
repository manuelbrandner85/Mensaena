import { NextResponse } from 'next/server'
import { createClient } from '@supabase/supabase-js'

// One-time migration endpoint - secured via secret header
export async function GET(req: Request) {
  const secret = new URL(req.url).searchParams.get('secret')
  if (secret !== 'mensaena_migrate_2026') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  const supabase = createClient(
    process.env.NEXT_PUBLIC_SUPABASE_URL!,
    process.env.SUPABASE_SERVICE_ROLE_KEY!,
    { auth: { persistSession: false } }
  )

  const statements = [
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS role TEXT NOT NULL DEFAULT 'user'`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_email BOOLEAN DEFAULT TRUE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_messages BOOLEAN DEFAULT TRUE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_interactions BOOLEAN DEFAULT TRUE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_community BOOLEAN DEFAULT FALSE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS notify_crisis BOOLEAN DEFAULT TRUE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS privacy_location BOOLEAN DEFAULT TRUE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS privacy_email BOOLEAN DEFAULT FALSE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS privacy_phone BOOLEAN DEFAULT FALSE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS privacy_public BOOLEAN DEFAULT TRUE`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_postal_code TEXT`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_city TEXT`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_lat DOUBLE PRECISION`,
    `ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS home_lng DOUBLE PRECISION`,
    `ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS is_anonymous BOOLEAN DEFAULT FALSE`,
    `ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS image_url TEXT`,
    `ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS event_date DATE`,
    `ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS event_time TEXT`,
    `ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS duration_hours NUMERIC(4,1)`,
    `CREATE TABLE IF NOT EXISTS public.post_votes (
      id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
      user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
      vote SMALLINT NOT NULL CHECK (vote IN (1,-1)),
      created_at TIMESTAMPTZ DEFAULT NOW(),
      UNIQUE(post_id, user_id)
    )`,
    `ALTER TABLE public.post_votes ENABLE ROW LEVEL SECURITY`,
    `DO $$ BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='post_votes' AND policyname='votes_read') THEN
        CREATE POLICY "votes_read" ON public.post_votes FOR SELECT USING (TRUE);
      END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='post_votes' AND policyname='votes_write') THEN
        CREATE POLICY "votes_write" ON public.post_votes FOR INSERT WITH CHECK (auth.uid() = user_id);
      END IF;
      IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='post_votes' AND policyname='votes_delete') THEN
        CREATE POLICY "votes_delete" ON public.post_votes FOR DELETE USING (auth.uid() = user_id);
      END IF;
    END $$`,
  ]

  const results: { sql: string; ok: boolean; error?: string }[] = []
  
  for (const sql of statements) {
    const { error } = await supabase.rpc('exec_migration', { sql_statement: sql })
    if (error && !error.message.includes('already exists') && !error.message.includes('duplicate')) {
      results.push({ sql: sql.slice(0, 60), ok: false, error: error.message })
    } else {
      results.push({ sql: sql.slice(0, 60), ok: true })
    }
  }

  return NextResponse.json({ results })
}
