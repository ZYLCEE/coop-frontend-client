BEGIN;

-- Used only by the service-role Edge Function to limit exact-ID directory
-- lookups by the authenticated borrower. Member and loan rows are untouched.
CREATE TABLE IF NOT EXISTS public.co_maker_lookup_limits (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  attempts INTEGER NOT NULL DEFAULT 1 CHECK (attempts >= 1 AND attempts <= 10),
  window_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.co_maker_lookup_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.co_maker_lookup_limits FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.co_maker_lookup_limits TO service_role;

CREATE OR REPLACE FUNCTION public.reserve_co_maker_lookup_attempt(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  reserved UUID;
BEGIN
  IF p_user_id IS NULL THEN
    RETURN FALSE;
  END IF;

  INSERT INTO public.co_maker_lookup_limits AS limits (user_id, attempts)
  VALUES (p_user_id, 1)
  ON CONFLICT (user_id) DO UPDATE
  SET attempts = CASE
        WHEN limits.window_started_at <= pg_catalog.now() - INTERVAL '15 minutes' THEN 1
        ELSE limits.attempts + 1
      END,
      window_started_at = CASE
        WHEN limits.window_started_at <= pg_catalog.now() - INTERVAL '15 minutes'
          THEN pg_catalog.now()
        ELSE limits.window_started_at
      END
  WHERE limits.attempts < 10
    OR limits.window_started_at <= pg_catalog.now() - INTERVAL '15 minutes'
  RETURNING user_id INTO reserved;

  RETURN reserved IS NOT NULL;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.reserve_co_maker_lookup_attempt(UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_co_maker_lookup_attempt(UUID)
  TO service_role;

COMMIT;
