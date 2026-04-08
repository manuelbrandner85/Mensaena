import { NextResponse } from 'next/server'
import pg from 'pg'

const DB_PW = 'PDJAOdP8LFkVh3lk'

const STEPS: [string, string][] = [
  // ── board_posts table ──
  [`CREATE TABLE IF NOT EXISTS public.board_posts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 500),
    category TEXT NOT NULL DEFAULT 'general' CHECK (category IN ('general','gesucht','biete','event','info','warnung','verloren','fundbuero')),
    color TEXT NOT NULL DEFAULT 'yellow' CHECK (color IN ('yellow','green','blue','pink','orange','purple')),
    image_url TEXT,
    contact_info TEXT,
    expires_at TIMESTAMPTZ,
    pinned BOOLEAN NOT NULL DEFAULT false,
    pin_count INTEGER NOT NULL DEFAULT 0,
    comment_count INTEGER NOT NULL DEFAULT 0,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    region_id UUID,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active','expired','hidden','deleted')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`, 'CREATE board_posts'],

  [`CREATE INDEX IF NOT EXISTS idx_board_posts_status_created ON public.board_posts (status, created_at DESC)`, 'idx status_created'],
  [`CREATE INDEX IF NOT EXISTS idx_board_posts_category ON public.board_posts (category)`, 'idx category'],
  [`CREATE INDEX IF NOT EXISTS idx_board_posts_author ON public.board_posts (author_id)`, 'idx author'],
  [`CREATE INDEX IF NOT EXISTS idx_board_posts_region ON public.board_posts (region_id)`, 'idx region'],

  [`CREATE OR REPLACE TRIGGER handle_board_posts_updated_at BEFORE UPDATE ON public.board_posts FOR EACH ROW EXECUTE FUNCTION handle_updated_at()`, 'trigger updated_at'],

  [`ALTER TABLE public.board_posts ENABLE ROW LEVEL SECURITY`, 'RLS board_posts'],

  [`DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='board_posts' AND policyname='board_posts_select') THEN CREATE POLICY "board_posts_select" ON public.board_posts FOR SELECT USING (status = 'active' OR author_id = auth.uid()); END IF; END $$`, 'policy board_posts_select'],
  [`DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='board_posts' AND policyname='board_posts_insert') THEN CREATE POLICY "board_posts_insert" ON public.board_posts FOR INSERT WITH CHECK (author_id = auth.uid()); END IF; END $$`, 'policy board_posts_insert'],
  [`DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='board_posts' AND policyname='board_posts_update') THEN CREATE POLICY "board_posts_update" ON public.board_posts FOR UPDATE USING (author_id = auth.uid()); END IF; END $$`, 'policy board_posts_update'],
  [`DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='board_posts' AND policyname='board_posts_delete') THEN CREATE POLICY "board_posts_delete" ON public.board_posts FOR DELETE USING (author_id = auth.uid()); END IF; END $$`, 'policy board_posts_delete'],
  [`DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='board_posts' AND policyname='board_posts_service') THEN CREATE POLICY "board_posts_service" ON public.board_posts FOR ALL USING (auth.role() = 'service_role'); END IF; END $$`, 'policy board_posts_service'],

  // ── board_pins table ──
  [`CREATE TABLE IF NOT EXISTS public.board_pins (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    board_post_id UUID NOT NULL REFERENCES public.board_posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (user_id, board_post_id)
  )`, 'CREATE board_pins'],

  [`ALTER TABLE public.board_pins ENABLE ROW LEVEL SECURITY`, 'RLS board_pins'],
  [`DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='board_pins' AND policyname='board_pins_select') THEN CREATE POLICY "board_pins_select" ON public.board_pins FOR SELECT USING (true); END IF; END $$`, 'policy board_pins_select'],
  [`DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='board_pins' AND policyname='board_pins_insert') THEN CREATE POLICY "board_pins_insert" ON public.board_pins FOR INSERT WITH CHECK (user_id = auth.uid()); END IF; END $$`, 'policy board_pins_insert'],
  [`DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='board_pins' AND policyname='board_pins_delete') THEN CREATE POLICY "board_pins_delete" ON public.board_pins FOR DELETE USING (user_id = auth.uid()); END IF; END $$`, 'policy board_pins_delete'],
  [`DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='board_pins' AND policyname='board_pins_service') THEN CREATE POLICY "board_pins_service" ON public.board_pins FOR ALL USING (auth.role() = 'service_role'); END IF; END $$`, 'policy board_pins_service'],

  // ── board_comments table ──
  [`CREATE TABLE IF NOT EXISTS public.board_comments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    board_post_id UUID NOT NULL REFERENCES public.board_posts(id) ON DELETE CASCADE,
    author_id UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    content TEXT NOT NULL CHECK (char_length(content) BETWEEN 1 AND 300),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
  )`, 'CREATE board_comments'],

  [`CREATE INDEX IF NOT EXISTS idx_board_comments_post_created ON public.board_comments (board_post_id, created_at DESC)`, 'idx comments_post_created'],
  [`CREATE OR REPLACE TRIGGER handle_board_comments_updated_at BEFORE UPDATE ON public.board_comments FOR EACH ROW EXECUTE FUNCTION handle_updated_at()`, 'trigger comments_updated_at'],

  [`ALTER TABLE public.board_comments ENABLE ROW LEVEL SECURITY`, 'RLS board_comments'],
  [`DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='board_comments' AND policyname='board_comments_select') THEN CREATE POLICY "board_comments_select" ON public.board_comments FOR SELECT USING (true); END IF; END $$`, 'policy board_comments_select'],
  [`DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='board_comments' AND policyname='board_comments_insert') THEN CREATE POLICY "board_comments_insert" ON public.board_comments FOR INSERT WITH CHECK (author_id = auth.uid()); END IF; END $$`, 'policy board_comments_insert'],
  [`DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='board_comments' AND policyname='board_comments_update') THEN CREATE POLICY "board_comments_update" ON public.board_comments FOR UPDATE USING (author_id = auth.uid()); END IF; END $$`, 'policy board_comments_update'],
  [`DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='board_comments' AND policyname='board_comments_delete') THEN CREATE POLICY "board_comments_delete" ON public.board_comments FOR DELETE USING (author_id = auth.uid()); END IF; END $$`, 'policy board_comments_delete'],
  [`DO $$ BEGIN IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename='board_comments' AND policyname='board_comments_service') THEN CREATE POLICY "board_comments_service" ON public.board_comments FOR ALL USING (auth.role() = 'service_role'); END IF; END $$`, 'policy board_comments_service'],

  // ── Triggers ──
  [`CREATE OR REPLACE FUNCTION update_board_post_pin_count() RETURNS TRIGGER AS $fn$
  BEGIN
    IF TG_OP = 'INSERT' THEN
      UPDATE public.board_posts SET pin_count = (SELECT count(*) FROM public.board_pins WHERE board_post_id = NEW.board_post_id) WHERE id = NEW.board_post_id;
      RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
      UPDATE public.board_posts SET pin_count = (SELECT count(*) FROM public.board_pins WHERE board_post_id = OLD.board_post_id) WHERE id = OLD.board_post_id;
      RETURN OLD;
    END IF;
    RETURN NULL;
  END;
  $fn$ LANGUAGE plpgsql SECURITY DEFINER`, 'fn update_board_post_pin_count'],

  [`DROP TRIGGER IF EXISTS trg_board_pin_count ON public.board_pins`, 'drop trg pin_count'],
  [`CREATE TRIGGER trg_board_pin_count AFTER INSERT OR DELETE ON public.board_pins FOR EACH ROW EXECUTE FUNCTION update_board_post_pin_count()`, 'trg pin_count'],

  [`CREATE OR REPLACE FUNCTION update_board_post_comment_count() RETURNS TRIGGER AS $fn$
  BEGIN
    IF TG_OP = 'INSERT' THEN
      UPDATE public.board_posts SET comment_count = (SELECT count(*) FROM public.board_comments WHERE board_post_id = NEW.board_post_id) WHERE id = NEW.board_post_id;
      RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
      UPDATE public.board_posts SET comment_count = (SELECT count(*) FROM public.board_comments WHERE board_post_id = OLD.board_post_id) WHERE id = OLD.board_post_id;
      RETURN OLD;
    END IF;
    RETURN NULL;
  END;
  $fn$ LANGUAGE plpgsql SECURITY DEFINER`, 'fn update_board_post_comment_count'],

  [`DROP TRIGGER IF EXISTS trg_board_comment_count ON public.board_comments`, 'drop trg comment_count'],
  [`CREATE TRIGGER trg_board_comment_count AFTER INSERT OR DELETE ON public.board_comments FOR EACH ROW EXECUTE FUNCTION update_board_post_comment_count()`, 'trg comment_count'],

  // ── Expire function ──
  [`CREATE OR REPLACE FUNCTION expire_old_board_posts() RETURNS INTEGER AS $fn$
  DECLARE affected INTEGER;
  BEGIN
    UPDATE public.board_posts SET status = 'expired' WHERE status = 'active' AND expires_at IS NOT NULL AND expires_at < now();
    GET DIAGNOSTICS affected = ROW_COUNT;
    RETURN affected;
  END;
  $fn$ LANGUAGE plpgsql SECURITY DEFINER`, 'fn expire_old_board_posts'],

  // ── Realtime ──
  [`DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.board_posts; EXCEPTION WHEN duplicate_object THEN NULL; END $$`, 'realtime board_posts'],
  [`DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.board_pins; EXCEPTION WHEN duplicate_object THEN NULL; END $$`, 'realtime board_pins'],
  [`DO $$ BEGIN ALTER PUBLICATION supabase_realtime ADD TABLE public.board_comments; EXCEPTION WHEN duplicate_object THEN NULL; END $$`, 'realtime board_comments'],
]

export async function POST(req: Request) {
  const secret = req.headers.get('x-migration-secret')
  if (secret !== 'mensaena-migrate-2026') {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 })
  }

  // Connect directly to the DB via IPv6 (Cloudflare Workers support IPv6)
  const client = new pg.Client({
    host: 'db.huaqldjkgyosefzfhjnf.supabase.co',
    port: 5432,
    database: 'postgres',
    user: 'postgres',
    password: DB_PW,
    ssl: { rejectUnauthorized: false },
    connectionTimeoutMillis: 15000,
  })

  try {
    await client.connect()
  } catch (err) {
    const msg = err instanceof Error ? err.message : 'unknown'
    return NextResponse.json({ error: 'DB connection failed: ' + msg }, { status: 500 })
  }

  const results: { label: string; status: string; msg: string }[] = []

  for (const [sql, label] of STEPS) {
    try {
      await client.query(sql)
      results.push({ label, status: 'ok', msg: 'ok' })
    } catch (err) {
      const msg = err instanceof Error ? err.message : 'unknown'
      const isOk = msg.includes('already exists') || msg.includes('duplicate')
      results.push({ label, status: isOk ? 'ok' : 'err', msg: isOk ? 'already exists' : msg.slice(0, 200) })
    }
  }

  await client.end()

  const okCount = results.filter(r => r.status === 'ok').length
  const errCount = results.filter(r => r.status === 'err').length

  return NextResponse.json({
    summary: { total: results.length, ok: okCount, errors: errCount },
    results,
  })
}

export async function GET() {
  return NextResponse.json({
    message: 'POST with x-migration-secret header to run board migration',
  })
}
