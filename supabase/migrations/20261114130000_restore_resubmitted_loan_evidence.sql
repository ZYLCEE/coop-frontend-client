-- Reattach the saved borrower agreement and witness names to the corrected
-- document packet after a member resubmits LA-2026-447641.
-- Run only when the borrower did not change the loan purpose during correction.
BEGIN;

DO $repair$
DECLARE
  application_row record;
  agreement_row public.loan_submission_agreements%ROWTYPE;
  v_packet_hash text;
  witness_name text;
  has_agreement boolean := false;
BEGIN
  SELECT app.id, app.application_id, app.status::text AS status,
         verification.stage, member.user_id AS borrower_user_id
    INTO application_row
  FROM public.loan_applications AS app
  JOIN public.application_verifications AS verification
    ON verification.application_id = app.id
  JOIN public.members AS member ON member.id = app.member_id
  WHERE app.application_id = 'LA-2026-447641'
  FOR UPDATE OF app;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Application LA-2026-447641 or its verification row was not found.';
  END IF;

  IF lower(btrim(application_row.status)) NOT IN ('pending', 'under review')
     OR application_row.stage <> 'needs_verification'
     OR NOT EXISTS (
       SELECT 1
       FROM public.application_workflow_events AS event
       WHERE event.application_id = application_row.id
         AND event.action = 'resubmit'
     ) THEN
    RAISE EXCEPTION 'LA-2026-447641 is not currently in the resubmitted review stage.';
  END IF;

  SELECT agreement.* INTO agreement_row
  FROM public.loan_submission_agreements AS agreement
  JOIN public.members AS member ON member.user_id = agreement.borrower_user_id
  WHERE agreement.application_id = application_row.id
    AND member.id = (SELECT app.member_id FROM public.loan_applications AS app WHERE app.id = application_row.id);
  has_agreement := FOUND;

  v_packet_hash := public.private_application_verification_state(application_row.id)->>'packetHash';

  -- Relink existing, valid OTP evidence. This also supports older loans that
  -- have no saved agreement row; it never fabricates consent or witness names.
  UPDATE public.application_consent_evidence AS evidence
  SET packet_hash = v_packet_hash
  WHERE evidence.application_id = application_row.id
    AND evidence.invalidated_at IS NULL
    AND evidence.occurred_at <= now()
    AND (evidence.expires_at IS NULL OR evidence.expires_at > now())
    AND evidence.method = 'otp'
    AND (
      (evidence.kind = 'borrower'
        AND evidence.subject_user_id = application_row.borrower_user_id)
      OR (evidence.kind = 'witness' AND evidence.subject_user_id IS NULL)
    );

  IF has_agreement THEN
    UPDATE public.loan_submission_agreements
    SET packet_hash = v_packet_hash
    WHERE id = agreement_row.id;

    INSERT INTO public.application_consent_evidence(
      id, application_id, kind, subject_reference, subject_user_id, method,
      evidence_reference, packet_hash, occurred_at
    )
    SELECT agreement_row.id, application_row.id, 'borrower', member.member_id,
           agreement_row.borrower_user_id, 'otp',
           'Borrower agreement receipt: ' || agreement_row.id::text,
           v_packet_hash, agreement_row.accepted_at
    FROM public.members AS member
    WHERE member.user_id = agreement_row.borrower_user_id
    ON CONFLICT (id) DO UPDATE
      SET packet_hash = EXCLUDED.packet_hash
      WHERE application_consent_evidence.invalidated_at IS NULL;

    FOR witness_name IN
      SELECT btrim(names.name)
      FROM jsonb_array_elements_text(agreement_row.witness_names) AS names(name)
    LOOP
      IF NOT EXISTS (
        SELECT 1
        FROM public.application_consent_evidence AS evidence
        WHERE evidence.application_id = application_row.id
          AND evidence.kind = 'witness'
          AND lower(evidence.subject_reference) = lower(witness_name)
          AND evidence.packet_hash = v_packet_hash
          AND evidence.invalidated_at IS NULL
      ) THEN
        INSERT INTO public.application_consent_evidence(
          application_id, kind, subject_reference, subject_user_id, method,
          evidence_reference, packet_hash, occurred_at
        ) VALUES (
          application_row.id, 'witness', witness_name, NULL, 'otp',
          'Borrower-declared witness name from OTP-confirmed loan agreement '
            || agreement_row.id::text,
          v_packet_hash, agreement_row.accepted_at
        );
      END IF;
    END LOOP;
  END IF;
END;
$repair$;

WITH target AS (
  SELECT app.id, app.application_id,
         public.private_application_verification_state(app.id)->>'packetHash' AS packet_hash,
         agreement.witness_names
  FROM public.loan_applications AS app
  LEFT JOIN public.loan_submission_agreements AS agreement
    ON agreement.application_id = app.id
  WHERE app.application_id = 'LA-2026-447641'
)
SELECT
  target.application_id,
  (SELECT count(*)
   FROM public.application_consent_evidence AS evidence
   WHERE evidence.application_id = target.id
     AND evidence.kind = 'borrower'
     AND evidence.packet_hash = target.packet_hash
     AND evidence.invalidated_at IS NULL) AS borrower_consent_current_packet,
  (SELECT count(DISTINCT lower(evidence.subject_reference))
   FROM public.application_consent_evidence AS evidence
   WHERE evidence.application_id = target.id
     AND evidence.kind = 'witness'
     AND evidence.packet_hash = target.packet_hash
     AND evidence.invalidated_at IS NULL) AS witness_names_current_packet,
  coalesce(jsonb_array_length(target.witness_names), 0) AS saved_witness_name_count
FROM target;

COMMIT;
