-- Member resubmission after a returned-for-requirements correction.
-- Run in the Supabase SQL Editor after the returned-document correction migration.
BEGIN;

-- Resubmission is a supported workflow event in the approval workflow.
ALTER TABLE public.application_workflow_events
  DROP CONSTRAINT IF EXISTS application_workflow_events_action_check;
ALTER TABLE public.application_workflow_events
  ADD CONSTRAINT application_workflow_events_action_check
  CHECK (action IN ('start','save_draft','mark_verified','return','resubmit'));

-- Permit only the owning active member's genuine returned-to-pending
-- transition. Other status changes remain subject to committee procedures.
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

  -- This one transition is allowed only for the authenticated owner while
  -- the verification stage is actually returned and no final decision exists.
  IF p_old='returned' AND p_new='pending'
     AND NOT EXISTS (
       SELECT 1 FROM public.application_final_decisions AS final_decision
       WHERE final_decision.application_id=p_application
     ) AND (
       (
         p_caller IN ('postgres','supabase_admin','service_role')
         AND
         public.document_member_active()
         AND EXISTS (
           SELECT 1
           FROM public.loan_applications AS app
           JOIN public.members AS member ON member.id=app.member_id
           JOIN public.application_verifications AS verification ON verification.application_id=app.id
           WHERE app.id=p_application AND member.user_id=auth.uid()
             AND verification.stage='returned_for_requirements'
         )
       ) OR (
         p_caller IN ('postgres','supabase_admin','service_role')
         AND public.document_member_active()
         AND EXISTS (
           SELECT 1
           FROM public.loan_applications AS app
           JOIN public.members AS member ON member.id=app.member_id
           JOIN public.application_verifications AS verification ON verification.application_id=app.id
           JOIN public.application_workflow_events AS prior_event
             ON prior_event.application_id=app.id
            AND prior_event.actor_id=member.user_id
            AND prior_event.action='resubmit'
           WHERE app.id=p_application AND verification.stage='needs_verification'
             AND member.user_id=auth.uid()
         )
       )
     ) THEN
    RETURN true;
  END IF;

  -- All other changes still require a trusted staff/service procedure.
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

CREATE OR REPLACE FUNCTION public.resubmit_returned_loan(
  p_application_id text,
  p_request_id uuid,
  p_updates jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  app_id uuid;
  app_status text;
  app_purpose text;
  member_first_name text;
  member_last_name text;
  verification_stage text;
  verification_revision integer;
  affected_kinds jsonb;
  v_kind text;
  v_document_id uuid;
  latest_version_id uuid;
  latest_review_status text;
  current_packet_hash text;
  existing_event public.application_workflow_events%ROWTYPE;
  request_hash text;
  result_payload jsonb;
BEGIN
  IF auth.uid() IS NULL OR NOT public.document_member_active() THEN
    RAISE EXCEPTION 'An active member account is required.' USING ERRCODE='42501';
  END IF;

  IF p_application_id IS NULL OR length(btrim(p_application_id)) NOT BETWEEN 1 AND 50
     OR p_request_id IS NULL
     OR p_updates IS NULL OR jsonb_typeof(p_updates) IS DISTINCT FROM 'object' THEN
    RAISE EXCEPTION 'The resubmission request is invalid.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM jsonb_object_keys(p_updates) AS update_key(key)
    WHERE key <> 'purpose'
  ) OR (
    p_updates ? 'purpose'
    AND (
      jsonb_typeof(p_updates->'purpose') IS DISTINCT FROM 'string'
      OR length(btrim(p_updates->>'purpose')) > 2000
    )
  ) THEN
    RAISE EXCEPTION 'Only the loan purpose may be corrected, up to 2,000 characters.';
  END IF;

  SELECT a.id,a.status::text,a.purpose,m.first_name,m.last_name
    INTO app_id,app_status,app_purpose,member_first_name,member_last_name
  FROM public.loan_applications a
  JOIN public.members m ON m.id=a.member_id
  WHERE a.application_id=p_application_id AND m.user_id=auth.uid()
  FOR UPDATE OF a;

  IF app_id IS NULL THEN
    RAISE EXCEPTION 'The application was not found for this member.' USING ERRCODE='42501';
  END IF;

  request_hash := md5(jsonb_build_object(
    'applicationId',p_application_id,
    'updates',p_updates
  )::text);

  -- Return the original result when a client retries after a lost response.
  SELECT * INTO existing_event
  FROM public.application_workflow_events
  WHERE request_id=p_request_id
  FOR UPDATE;

  IF FOUND THEN
    IF existing_event.application_id=app_id
       AND existing_event.actor_id=auth.uid()
       AND existing_event.action='resubmit'
       AND existing_event.request_hash=request_hash THEN
      RETURN existing_event.result;
    END IF;
    RAISE EXCEPTION 'This resubmission request ID has already been used.' USING ERRCODE='40001';
  END IF;

  SELECT stage,revision INTO verification_stage,verification_revision
  FROM public.application_verifications
  WHERE application_id=app_id
  FOR UPDATE;

  IF lower(btrim(coalesce(app_status,''))) NOT IN ('returned','returned_for_requirements')
     OR NOT (
       verification_stage='returned_for_requirements'
       OR (
         verification_stage='needs_verification'
         AND EXISTS (
           SELECT 1 FROM public.application_workflow_events AS prior_event
           WHERE prior_event.application_id=app_id
             AND prior_event.actor_id=auth.uid()
             AND prior_event.action='resubmit'
         )
       )
     ) THEN
    RAISE EXCEPTION 'This application is no longer returned for requirements. Refresh your applications.';
  END IF;

  SELECT e.details->'affectedKinds' INTO affected_kinds
  FROM public.application_workflow_events e
  WHERE e.application_id=app_id AND e.action='return'
  ORDER BY e.created_at DESC,e.id DESC
  LIMIT 1;

  IF jsonb_typeof(affected_kinds) IS DISTINCT FROM 'array'
     OR jsonb_array_length(affected_kinds)=0 THEN
    RAISE EXCEPTION 'The return instructions are unavailable. Contact the cooperative before resubmitting.';
  END IF;

  -- Every requested kind must now have a file, and none may still be marked
  -- needs_replacement at its latest uploaded version.
  FOR v_kind IN
    SELECT DISTINCT requested.kind
    FROM jsonb_array_elements_text(affected_kinds) AS requested(kind)
  LOOP
    SELECT d.id INTO v_document_id
    FROM public.loan_documents d
    WHERE d.loan_application_id=app_id
      AND d.user_id=auth.uid()
      AND d.kind=v_kind
    ORDER BY d.created_at DESC,d.id DESC
    LIMIT 1;

    IF v_document_id IS NULL THEN
      RAISE EXCEPTION 'Upload the requested % document before resubmitting.',v_kind;
    END IF;

    SELECT v.id INTO latest_version_id
    FROM public.loan_document_versions v
    WHERE v.document_id=v_document_id
    ORDER BY v.version DESC,v.created_at DESC,v.id DESC
    LIMIT 1;

    SELECT r.status INTO latest_review_status
    FROM public.loan_document_reviews r
    WHERE r.document_id=v_document_id
      AND r.version_id IS NOT DISTINCT FROM latest_version_id
    ORDER BY r.created_at DESC,r.id DESC
    LIMIT 1;

    IF latest_review_status='needs_replacement' THEN
      RAISE EXCEPTION 'Replace the requested % document before resubmitting.',v_kind;
    END IF;

    v_document_id := NULL;
    latest_version_id := NULL;
    latest_review_status := NULL;
  END LOOP;

  -- Keep the loan application status under the authorized committee,
  -- final-decision and servicing procedures, except for the narrowly
  -- authorized member resubmission transition defined above.
  UPDATE public.loan_applications
  SET status='pending',
      purpose=CASE WHEN p_updates ? 'purpose' THEN btrim(p_updates->>'purpose') ELSE purpose END,
      updated_at=clock_timestamp()
  WHERE id=app_id;

  -- A document replacement changes the packet hash, but does not change the
  -- borrower's agreement to the same loan terms. Keep its signed agreement
  -- and declared witness names attached to the refreshed document packet
  -- when the purpose is unchanged. A changed purpose requires fresh consent.
  IF NOT (p_updates ? 'purpose')
     OR btrim(p_updates->>'purpose') IS NOT DISTINCT FROM app_purpose THEN
    current_packet_hash := public.private_application_verification_state(app_id)->>'packetHash';

    -- Keep the saved agreement and its witness-name source on the corrected
    -- document packet too. The admin evidence view reads witness names from
    -- this agreement row by packet hash.
    UPDATE public.loan_submission_agreements AS agreement
    SET packet_hash=current_packet_hash
    WHERE agreement.application_id=app_id
      AND agreement.borrower_user_id=auth.uid()
      AND agreement.packet_hash IS DISTINCT FROM current_packet_hash;

    -- Older applications may not have a loan_submission_agreements row.
    -- Preserve their already-recorded OTP evidence across document-only
    -- corrections as long as the purpose (and therefore the loan terms) did
    -- not change.
    UPDATE public.application_consent_evidence AS evidence
    SET packet_hash=current_packet_hash
    WHERE evidence.application_id=app_id
      AND evidence.invalidated_at IS NULL
      AND evidence.occurred_at<=now()
      AND (evidence.expires_at IS NULL OR evidence.expires_at>now())
      AND evidence.method='otp'
      AND (
        (evidence.kind='borrower' AND evidence.subject_user_id=auth.uid())
        OR (evidence.kind='witness' AND evidence.subject_user_id IS NULL)
      );

    UPDATE public.application_consent_evidence AS evidence
    SET packet_hash=current_packet_hash
    WHERE evidence.application_id=app_id
      AND evidence.kind='borrower'
      AND evidence.subject_user_id=auth.uid()
      AND evidence.invalidated_at IS NULL
      AND EXISTS (
        SELECT 1 FROM public.loan_submission_agreements AS agreement
        WHERE agreement.application_id=app_id
          AND agreement.borrower_user_id=auth.uid()
          AND agreement.id=evidence.id
      );

    INSERT INTO public.application_consent_evidence(
      application_id,kind,subject_reference,subject_user_id,method,
      evidence_reference,packet_hash,occurred_at
    )
    SELECT app_id,'witness',btrim(witness.name),NULL,'otp',
      'Borrower-declared witness name from OTP-confirmed loan agreement '||agreement.id::text,
      current_packet_hash,agreement.accepted_at
    FROM public.loan_submission_agreements AS agreement
    CROSS JOIN LATERAL jsonb_array_elements_text(agreement.witness_names) AS witness(name)
    WHERE agreement.application_id=app_id
      AND agreement.borrower_user_id=auth.uid()
      AND NOT EXISTS (
        SELECT 1 FROM public.application_consent_evidence AS existing_witness
        WHERE existing_witness.application_id=app_id
          AND existing_witness.kind='witness'
          AND existing_witness.packet_hash=current_packet_hash
          AND lower(existing_witness.subject_reference)=lower(btrim(witness.name))
          AND existing_witness.invalidated_at IS NULL
      );
  END IF;

  UPDATE public.application_verifications
  SET stage='needs_verification',
      revision=verification_revision+1,
      checks='{"terms":false,"identity":false,"eligibility":false}'::jsonb,
      notes='',
      policy_id=NULL,
      verified_state_hash=NULL,
      verified_snapshot=NULL,
      verified_by=NULL,
      verified_at=NULL,
      updated_by=auth.uid(),
      updated_at=clock_timestamp()
  WHERE application_id=app_id;

  result_payload := jsonb_build_object(
    'applicationId',p_application_id,
    'status','pending',
    'stage','needs_verification',
    'revision',verification_revision+1
  );

  INSERT INTO public.application_workflow_events(
    application_id,request_id,request_hash,actor_id,actor_name,action,details,result
  ) VALUES (
    app_id,p_request_id,request_hash,auth.uid(),
    coalesce(nullif(btrim(concat_ws(' ',member_first_name,member_last_name)),''),'Member'),
    'resubmit',
    jsonb_build_object(
      'affectedKinds',affected_kinds,
      'purposeUpdated',p_updates ? 'purpose'
    ),
    result_payload
  );

  RETURN result_payload;
END;
$function$;

REVOKE ALL ON FUNCTION public.resubmit_returned_loan(text,uuid,jsonb) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.resubmit_returned_loan(text,uuid,jsonb) TO authenticated,service_role;

NOTIFY pgrst,'reload schema';
COMMIT;
