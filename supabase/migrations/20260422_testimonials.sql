-- Testimonials: Nutzerstimmen für die Landing Page

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ─── Tabelle ──────────────────────────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS public.testimonials (
    id         UUID        PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id    UUID        NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
    quote      TEXT        NOT NULL
                           CHECK (char_length(quote) >= 10 AND char_length(quote) <= 500),
    approved   BOOLEAN     DEFAULT false,
    featured   BOOLEAN     DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- ─── Index ────────────────────────────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_testimonials_approved
    ON public.testimonials(approved, featured, created_at DESC);

-- ─── RLS ──────────────────────────────────────────────────────────────────────

ALTER TABLE public.testimonials ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Genehmigte Testimonials lesen"
    ON public.testimonials FOR SELECT
    TO anon, authenticated
    USING (approved = true);

CREATE POLICY "Eigenes Testimonial erstellen"
    ON public.testimonials FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Admin kann alles"
    ON public.testimonials FOR ALL
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    )
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE id = auth.uid() AND role = 'admin'
        )
    );
