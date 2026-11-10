BEGIN;

-- The co-maker invitation Edge Function uses the service role to create
-- notifications and to remove its own partial notification batch on failure.
GRANT INSERT, DELETE ON TABLE public.notifications TO service_role;
GRANT SELECT (data) ON TABLE public.notifications TO service_role;

COMMIT;
