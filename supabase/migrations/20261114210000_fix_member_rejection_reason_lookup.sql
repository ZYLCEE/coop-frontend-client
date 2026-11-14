BEGIN;

-- application_final_decisions is keyed by application_id and does not have
-- an id column. Keep the member lookup compatible with that schema.
CREATE OR REPLACE FUNCTION public.member_application_rejection_reasons()
RETURNS TABLE (
  application_id text,
  rejection_reason text,
  rejected_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
BEGIN
  IF auth.uid() IS NULL OR NOT public.document_member_active() THEN
    RAISE EXCEPTION 'Active member access is required.' USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  SELECT
    loan.application_id::text,
    COALESCE(
      NULLIF(btrim(final_decision.reason), ''),
      NULLIF(btrim(admin_rejection.reason), '')
    )::text,
    COALESCE(final_decision.created_at, admin_rejection.created_at)
  FROM public.loan_applications AS loan
  JOIN public.members AS member
    ON member.id = loan.member_id
   AND member.user_id = auth.uid()
  LEFT JOIN LATERAL (
    SELECT decision.reason, decision.created_at
    FROM public.application_final_decisions AS decision
    WHERE decision.application_id = loan.id
      AND decision.decision = 'reject'
    ORDER BY decision.created_at DESC
    LIMIT 1
  ) AS final_decision ON true
  LEFT JOIN LATERAL (
    SELECT log.details->>'reason' AS reason, log.created_at
    FROM public.admin_activity_logs AS log
    WHERE log.action_name IN ('reject-loan', 'application-final-reject')
      AND log.result = 'success'
      AND log.target_id = loan.application_id
      AND NULLIF(btrim(log.details->>'reason'), '') IS NOT NULL
    ORDER BY log.created_at DESC, log.id DESC
    LIMIT 1
  ) AS admin_rejection ON true
  WHERE lower(btrim(loan.status::text)) = 'rejected'
    AND COALESCE(
      NULLIF(btrim(final_decision.reason), ''),
      NULLIF(btrim(admin_rejection.reason), '')
    ) IS NOT NULL
  ORDER BY loan.date_submitted DESC, loan.created_at DESC;
END;
$function$;

REVOKE ALL ON FUNCTION public.member_application_rejection_reasons()
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.member_application_rejection_reasons()
  TO authenticated, service_role;

NOTIFY pgrst, 'reload schema';
COMMIT;
