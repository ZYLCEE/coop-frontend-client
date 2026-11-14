-- Restore both narrowly authorized status transitions in the application
-- guard: staff return for requirements and member resubmission after fixes.
-- This migration changes only committee_transition_allowed.
BEGIN;

CREATE OR REPLACE FUNCTION public.committee_transition_allowed(
  p_application uuid,
  p_old text,
  p_new text,
  p_caller name
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  decision_row public.application_final_decisions%ROWTYPE;
BEGIN
  IF auth.uid() IS NOT NULL
     AND NOT public.document_staff_access()
     AND NOT EXISTS (
       SELECT 1
       FROM public.loan_applications AS app
       JOIN public.members AS member ON member.id=app.member_id
       WHERE app.id=p_application AND member.user_id=auth.uid()
     ) THEN
    RETURN false;
  END IF;

  IF p_old IS NOT DISTINCT FROM p_new
     OR NOT EXISTS (
       SELECT 1 FROM public.application_verifications AS verification
       WHERE verification.application_id=p_application
     ) THEN
    RETURN true;
  END IF;

  -- Authorized staff may return an active application for requirements only
  -- after the verification procedure recorded that return stage.
  IF p_old IN ('pending','under review')
     AND p_new='returned'
     AND p_caller IN ('postgres','supabase_admin','service_role')
     AND auth.uid() IS NOT NULL
     AND public.document_staff_access('applications.return')
     AND NOT EXISTS (
       SELECT 1 FROM public.application_final_decisions AS final_decision
       WHERE final_decision.application_id=p_application
     )
     AND EXISTS (
       SELECT 1 FROM public.application_verifications AS verification
       WHERE verification.application_id=p_application
         AND verification.stage='returned_for_requirements'
     ) THEN
    RETURN true;
  END IF;

  -- The owning active member may resubmit only while the application is
  -- returned for requirements and no final decision has been recorded.
  IF p_old='returned'
     AND p_new='pending'
     AND p_caller IN ('postgres','supabase_admin','service_role')
     AND NOT EXISTS (
       SELECT 1 FROM public.application_final_decisions AS final_decision
       WHERE final_decision.application_id=p_application
     )
     AND public.document_member_active()
     AND EXISTS (
       SELECT 1
       FROM public.loan_applications AS app
       JOIN public.members AS member ON member.id=app.member_id
       JOIN public.application_verifications AS verification
         ON verification.application_id=app.id
       WHERE app.id=p_application
         AND member.user_id=auth.uid()
         AND verification.stage='returned_for_requirements'
     ) THEN
    RETURN true;
  END IF;

  -- Keep retry compatibility for a resubmit event already committed by the
  -- same member before the verification stage was refreshed.
  IF p_old='returned'
     AND p_new='pending'
     AND p_caller IN ('postgres','supabase_admin','service_role')
     AND NOT EXISTS (
       SELECT 1 FROM public.application_final_decisions AS final_decision
       WHERE final_decision.application_id=p_application
     )
     AND public.document_member_active()
     AND EXISTS (
       SELECT 1
       FROM public.loan_applications AS app
       JOIN public.members AS member ON member.id=app.member_id
       JOIN public.application_verifications AS verification
         ON verification.application_id=app.id
       JOIN public.application_workflow_events AS prior_event
         ON prior_event.application_id=app.id
        AND prior_event.actor_id=member.user_id
        AND prior_event.action='resubmit'
       WHERE app.id=p_application
         AND member.user_id=auth.uid()
         AND verification.stage='needs_verification'
     ) THEN
    RETURN true;
  END IF;

  -- Every other change still follows existing final-decision and servicing
  -- procedure requirements.
  IF p_caller NOT IN ('postgres','supabase_admin','service_role') THEN
    RETURN false;
  END IF;

  SELECT * INTO decision_row
  FROM public.application_final_decisions
  WHERE application_id=p_application;

  RETURN decision_row.application_id IS NOT NULL
    AND public.document_staff_access()
    AND (
      (p_old IN ('pending','under review')
        AND p_new=CASE WHEN decision_row.decision='approve' THEN 'approved' ELSE 'rejected' END)
      OR (decision_row.decision='approve'
        AND ((p_old='approved' AND p_new='released')
          OR (p_old IN ('released','overdue') AND p_new IN ('overdue','completed'))))
    );
END;
$function$;

REVOKE ALL ON FUNCTION public.committee_transition_allowed(uuid,text,text,name) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.committee_transition_allowed(uubrroid,text,text,name) TO authenticated,service_role;

NOTIFY pgrst,'reload schema';
COMMIT;
