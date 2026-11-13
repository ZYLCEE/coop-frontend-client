BEGIN;

-- member-auth reads and updates this flag after password reset.
ALTER TABLE public.members
  ADD COLUMN IF NOT EXISTS must_change_password BOOLEAN NOT NULL DEFAULT FALSE;

-- Login-attempt state used by the existing member-auth Edge Function.
CREATE TABLE IF NOT EXISTS public.member_login_limits (
  identifier_hash TEXT PRIMARY KEY,
  attempts INTEGER NOT NULL CHECK (attempts >= 1 AND attempts <= 5),
  window_started_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE public.member_login_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.member_login_limits FROM PUBLIC, anon, authenticated;
GRANT ALL ON TABLE public.member_login_limits TO service_role;

CREATE OR REPLACE FUNCTION public.reserve_member_login_attempt(p_identifier_hash TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  reserved TEXT;
BEGIN
  IF p_identifier_hash IS NULL OR p_identifier_hash !~ '^[0-9a-f]{64}$' THEN
    RETURN FALSE;
  END IF;

  INSERT INTO public.member_login_limits AS limits (identifier_hash, attempts)
  VALUES (p_identifier_hash, 1)
  ON CONFLICT (identifier_hash) DO UPDATE
  SET attempts = CASE
        WHEN limits.window_started_at <= pg_catalog.now() - INTERVAL '15 minutes' THEN 1
        ELSE limits.attempts + 1
      END,
      window_started_at = CASE
        WHEN limits.window_started_at <= pg_catalog.now() - INTERVAL '15 minutes'
          THEN pg_catalog.now()
        ELSE limits.window_started_at
      END
  WHERE limits.attempts < 5
    OR limits.window_started_at <= pg_catalog.now() - INTERVAL '15 minutes'
  RETURNING identifier_hash INTO reserved;

  RETURN reserved IS NOT NULL;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.reserve_member_login_attempt(TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.reserve_member_login_attempt(TEXT)
  TO service_role;

-- Lookup-attempt state prevents one signed-in account from enumerating the
-- membership directory. The Edge Function derives user_id from the JWT.
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
