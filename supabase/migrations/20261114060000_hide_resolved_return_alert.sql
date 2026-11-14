-- Keep the return event in history, but stop exposing it as an active alert
-- after the member has resubmitted and the application left Returned status.
BEGIN;

CREATE OR REPLACE FUNCTION public.get_application_verification(p_application_id text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  app public.loan_applications%ROWTYPE;
  verification public.application_verifications%ROWTYPE;
  member_row public.members%ROWTYPE;
  current_state jsonb;
  workflow_history jsonb;
  last_return jsonb;
  is_stale boolean := false;
  review_stage text;
BEGIN
  IF NOT public.document_staff_access() THEN
    RAISE EXCEPTION 'Active administrator access is required.' USING ERRCODE='42501';
  END IF;

  SELECT * INTO STRICT app
  FROM public.loan_applications
  WHERE application_id=p_application_id;

  SELECT * INTO member_row FROM public.members WHERE id=app.member_id;
  SELECT * INTO verification
  FROM public.application_verifications
  WHERE application_id=app.id;

  current_state := public.private_application_verification_state(app.id);
  review_stage := public.committee_application_stage(app.id);
  is_stale := verification.stage='ready_for_committee'
    AND (verification.verified_state_hash IS DISTINCT FROM current_state->>'stateHash'
      OR jsonb_array_length(current_state->'blockers')>0);

  SELECT coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id',event.id,
        'action',event.action,
        'actor',event.actor_name,
        'createdAt',event.created_at,
        'details',event.details
      ) ORDER BY event.created_at DESC,event.id DESC
    ),'[]'
  ) INTO workflow_history
  FROM public.application_workflow_events AS event
  WHERE event.application_id=app.id;

  SELECT jsonb_build_object(
    'reason',event.details->>'reason',
    'category',event.details->>'category',
    'createdAt',event.created_at
  ) INTO last_return
  FROM public.application_workflow_events AS event
  WHERE event.application_id=app.id AND event.action='return'
  ORDER BY event.created_at DESC,event.id DESC
  LIMIT 1;

  RETURN (current_state-'documents') || jsonb_build_object(
    'documents',(
      SELECT coalesce(jsonb_agg(value-'storagePath'-'size'-'contentType'),'[]')
      FROM jsonb_array_elements(current_state->'documents')
    ),
    'applicationId',app.application_id,
    'applicationUuid',app.id,
    'memberName',coalesce(nullif(btrim(concat_ws(' ',member_row.first_name,member_row.last_name)),''),app.member_name),
    'memberNumber',coalesce(member_row.member_id,'Not recorded'),
    'loanType',app.loan_type,
    'loanStatus',app.status,
    'loanSummary',jsonb_build_object(
      'amount',app.amount,
      'months',app.tenure_months,
      'monthlyPayment',app.monthly_payment,
      'purpose',app.purpose
    ),
    'returnEmailStatus',(
      SELECT outbox.status
      FROM public.application_email_outbox AS outbox
      WHERE outbox.application_id=app.id
      ORDER BY outbox.created_at DESC
      LIMIT 1
    ),
    'stage',coalesce(
      review_stage,
      CASE
        WHEN verification.application_id IS NULL THEN 'not_started'
        WHEN is_stale THEN 'needs_verification'
        ELSE verification.stage
      END
    ),
    'enrolled',verification.application_id IS NOT NULL,
    'revision',coalesce(verification.revision,0),
    'stale',coalesce(is_stale,false),
    'checks',coalesce(verification.checks,'{"identity":false,"eligibility":false,"terms":false}'),
    'notes',coalesce(verification.notes,''),
    'history',workflow_history,
    'lastReturned',CASE
      WHEN app.status='returned' AND verification.stage='returned_for_requirements'
        THEN last_return
      ELSE NULL
    END,
    'canEnroll',app.status IN ('pending','under review')
      AND NOT EXISTS (
        SELECT 1 FROM public.application_review_cycles AS cycle
        WHERE cycle.application_id=app.id AND cycle.status<>'superseded'
      ),
    'permissions',jsonb_build_object(
      'verify',public.document_staff_access('applications.verify'),
      'return',public.document_staff_access('applications.return'),
      'policyManage',public.document_staff_access('workflow.policy.manage')
    )
  );
END;
$function$;

NOTIFY pgrst,'reload schema';
COMMIT;
