BEGIN;

ALTER TABLE public.co_maker_requests
  ADD COLUMN IF NOT EXISTS rejection_reason text;

ALTER TABLE public.loan_submission_agreements
  ADD COLUMN IF NOT EXISTS promissory_note_accepted boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS promissory_note_version text,
  ADD COLUMN IF NOT EXISTS promissory_note_text text;

DO $migration$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conrelid = 'public.loan_submission_agreements'::regclass
      AND conname = 'loan_submission_promissory_consent_check'
  ) THEN
    ALTER TABLE public.loan_submission_agreements
      ADD CONSTRAINT loan_submission_promissory_consent_check
      CHECK (
        NOT promissory_note_accepted
        OR (promissory_note_version IS NOT NULL AND promissory_note_text IS NOT NULL)
      );
  END IF;
END;
$migration$;

-- The updated app must record a distinct Promissory Note acceptance alongside
-- the existing terms and information certification receipt.
CREATE OR REPLACE FUNCTION public.submit_loan_with_agreements(
  p_application_id text,
  p_loan_type text,
  p_amount numeric,
  p_documents jsonb,
  p_tenure_months integer,
  p_terms_accepted boolean,
  p_information_certified boolean,
  p_promissory_note_accepted boolean,
  p_promissory_note_version text,
  p_promissory_note_text text,
  p_terms_version text,
  p_witness_names jsonb
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  app_id uuid;
  updated_id uuid;
BEGIN
  IF p_promissory_note_accepted IS DISTINCT FROM true THEN
    RAISE EXCEPTION 'Accept the Promissory Note before submitting.';
  END IF;
  IF p_promissory_note_version IS DISTINCT FROM 'csucc-promissory-note-2026-11-14-v1'
     OR p_promissory_note_text IS NULL
     OR length(btrim(p_promissory_note_text)) NOT BETWEEN 20 AND 5000 THEN
    RAISE EXCEPTION 'The Promissory Note changed. Update the app and review it again.';
  END IF;

  app_id := public.submit_loan_with_agreements(
    p_application_id,
    p_loan_type,
    p_amount,
    p_documents,
    p_tenure_months,
    p_terms_accepted,
    p_information_certified,
    p_terms_version,
    p_witness_names
  );

  UPDATE public.loan_submission_agreements AS agreement
  SET promissory_note_accepted = true,
      promissory_note_version = p_promissory_note_version,
      promissory_note_text = p_promissory_note_text
  WHERE agreement.application_id = app_id
    AND agreement.borrower_user_id = auth.uid()
    AND (
      agreement.promissory_note_text IS NULL
      OR (
        agreement.promissory_note_version = p_promissory_note_version
        AND agreement.promissory_note_text = p_promissory_note_text
      )
    )
  RETURNING agreement.application_id INTO updated_id;

  IF updated_id IS NULL THEN
    RAISE EXCEPTION 'The saved application agreement changed. Start a new application reference.'
      USING ERRCODE = '40001';
  END IF;
  RETURN app_id;
END;
$function$;

CREATE OR REPLACE FUNCTION public.application_evidence_details(
  p_application_id text,
  p_packet_hash text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  state jsonb;
  app public.loan_applications%ROWTYPE;
  records jsonb;
BEGIN
  IF NOT public.document_staff_access() THEN
    RAISE EXCEPTION 'Active administrator access is required.' USING ERRCODE = '42501';
  END IF;
  state := public.get_application_verification(p_application_id);
  IF p_packet_hash IS DISTINCT FROM state->>'packetHash' THEN
    RAISE EXCEPTION 'The application changed. Refresh before viewing its evidence.' USING ERRCODE = '40001';
  END IF;
  SELECT * INTO STRICT app
  FROM public.loan_applications
  WHERE id = (state->>'applicationUuid')::uuid;

  SELECT coalesce(jsonb_agg(record ORDER BY occurred DESC), '[]')
  INTO records
  FROM (
    SELECT e.occurred_at AS occurred,
      jsonb_build_object(
        'id', e.id,
        'kind', e.kind,
        'subject_reference', e.subject_reference,
        'subject_name', coalesce(nullif(concat_ws(' ', person.first_name, person.last_name), ''), e.subject_reference),
        'method', e.method,
        'occurred_at', e.occurred_at,
        'evidence_reference', e.evidence_reference,
        'status', 'recorded',
        'source', 'consent_evidence',
        'terms_accepted', agreement.terms_accepted,
        'information_certified', agreement.information_certified,
        'promissory_note_accepted', agreement.promissory_note_accepted,
        'promissory_note_version', agreement.promissory_note_version,
        'promissory_note_text', agreement.promissory_note_text,
        'terms_version', agreement.terms_version,
        'terms_text', agreement.terms_text
      ) AS record
    FROM public.application_consent_evidence AS e
    LEFT JOIN public.loan_submission_agreements AS agreement ON agreement.id = e.id
    LEFT JOIN LATERAL (
      SELECT m.first_name, m.last_name
      FROM public.members AS m
      WHERE (e.subject_user_id IS NOT NULL AND m.user_id = e.subject_user_id)
         OR m.member_id = e.subject_reference
         OR m.id::text = e.subject_reference
         OR m.user_id::text = e.subject_reference
      ORDER BY m.id
      LIMIT 1
    ) AS person ON true
    WHERE e.application_id = app.id
      AND e.packet_hash = p_packet_hash
      AND e.invalidated_at IS NULL
      AND e.occurred_at <= now()
      AND (e.expires_at IS NULL OR e.expires_at > now())
    UNION ALL
    SELECT r.accepted_at,
      jsonb_build_object(
        'id', r.id,
        'kind', 'co_maker',
        'subject_reference', coalesce(m.member_id, r.co_maker_name),
        'subject_name', r.co_maker_name,
        'method', 'member_approval',
        'occurred_at', r.accepted_at,
        'evidence_reference', r.id,
        'status', 'approved',
        'source', 'co_maker_request',
        'relationship', r.relationship,
        'borrower_name', r.borrower_name,
        'amount', r.amount,
        'tenure_months', r.tenure_months,
        'loan_type', r.loan_type
      )
    FROM public.co_maker_requests AS r
    LEFT JOIN public.members AS m ON m.id = r.co_maker_member_id
    WHERE r.id = app.co_maker_request_id
      AND r.application_id = app.application_id
      AND r.co_maker_member_id = app.co_maker_member_id
      AND r.borrower_member_id = app.member_id
      AND r.status = 'accepted'
      AND r.accepted_at IS NOT NULL
      AND r.accepted_at <= now()
    UNION ALL
    SELECT receipt.accepted_at,
      jsonb_build_object(
        'id', receipt.id::text || ':witness:' || w.position,
        'kind', 'witness',
        'subject_reference', w.name,
        'subject_name', w.name,
        'method', 'borrower_declaration',
        'occurred_at', receipt.accepted_at,
        'evidence_reference', 'Loan application witness names',
        'status', 'named',
        'source', 'borrower_witness_names'
      )
    FROM public.loan_submission_agreements AS receipt
    CROSS JOIN LATERAL jsonb_array_elements_text(receipt.witness_names)
      WITH ORDINALITY AS w(name, position)
    WHERE receipt.application_id = app.id
      AND receipt.packet_hash = p_packet_hash
  ) AS proof;

  RETURN jsonb_build_object('records', records);
END;
$function$;

REVOKE ALL ON FUNCTION public.application_evidence_details(text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.application_evidence_details(text, text)
  TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.submit_loan_with_agreements(
  text, text, numeric, jsonb, integer, boolean, boolean, text, jsonb
) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.submit_loan_with_agreements(
  text, text, numeric, jsonb, integer, boolean, boolean, boolean, text, text, text, jsonb
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_loan_with_agreements(
  text, text, numeric, jsonb, integer, boolean, boolean, boolean, text, text, text, jsonb
) TO authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
