-- Restore missing document-kind instructions on the active return event so
-- the member resubmission RPC can validate the corrected documents.
BEGIN;

WITH current_returns AS (
  SELECT
    app.id AS application_uuid,
    app.application_id AS application_reference,
    returned.id AS event_id,
    returned.request_id,
    returned.details,
    returned.created_at
  FROM public.loan_applications AS app
  JOIN public.application_verifications AS verification
    ON verification.application_id = app.id
   AND verification.stage = 'returned_for_requirements'
  JOIN LATERAL (
    SELECT event.id, event.request_id, event.details, event.created_at
    FROM public.application_workflow_events AS event
    WHERE event.application_id = app.id
      AND event.action = 'return'
    ORDER BY event.created_at DESC, event.id DESC
    LIMIT 1
  ) AS returned ON true
  WHERE lower(btrim(coalesce(app.status::text, ''))) IN ('returned', 'returned_for_requirements')
    AND app.application_id = 'LA-2026-447641'
), recoverable AS (
  SELECT
    returned.event_id,
    COALESCE(
      CASE
        WHEN jsonb_typeof(audit.affected_kinds) = 'array'
         AND jsonb_array_length(audit.affected_kinds) > 0
          THEN audit.affected_kinds
      END,
      (
        SELECT jsonb_agg(latest_review.kind ORDER BY latest_review.kind)
        FROM (
          SELECT DISTINCT ON (review.document_id)
            document.kind,
            review.status
          FROM public.loan_document_reviews AS review
          JOIN public.loan_documents AS document
            ON document.id = review.document_id
          WHERE document.loan_application_id = returned.application_uuid
            AND review.created_at <= returned.created_at
          ORDER BY review.document_id, review.created_at DESC, review.id DESC
        ) AS latest_review
        WHERE latest_review.status = 'needs_replacement'
      ),
      (
        -- This return and its audit both recorded an empty affectedKinds
        -- array. When no replacement review identifies the requested types,
        -- use the document kinds already attached to this active application.
        -- The resubmission RPC still verifies that each latest file exists
        -- and is not awaiting replacement.
        SELECT jsonb_agg(DISTINCT document.kind ORDER BY document.kind)
        FROM public.loan_documents AS document
        WHERE document.loan_application_id = returned.application_uuid
      )
    ) AS affected_kinds
  FROM current_returns AS returned
  LEFT JOIN LATERAL (
    SELECT log.details->'affectedKinds' AS affected_kinds
    FROM public.admin_activity_logs AS log
    WHERE log.action_name = 'application-verification-return'
      AND log.result = 'success'
      AND log.target_id = returned.application_reference
      AND log.details->>'requestId' = returned.request_id::text
    ORDER BY log.created_at DESC
    LIMIT 1
  ) AS audit ON true
  WHERE CASE
    WHEN jsonb_typeof(returned.details->'affectedKinds') = 'array'
      THEN jsonb_array_length(returned.details->'affectedKinds') = 0
    ELSE true
  END
), repaired AS (
  UPDATE public.application_workflow_events AS event
  SET details = coalesce(event.details, '{}'::jsonb)
    || jsonb_build_object('affectedKinds', recoverable.affected_kinds)
  FROM recoverable
  WHERE event.id = recoverable.event_id
    AND jsonb_typeof(recoverable.affected_kinds) = 'array'
    AND jsonb_array_length(recoverable.affected_kinds) > 0
  RETURNING event.application_id, event.details->'affectedKinds' AS affected_kinds
)
SELECT
  application.application_id,
  repaired.affected_kinds
FROM repaired
JOIN public.loan_applications AS application
  ON application.id = repaired.application_id;

COMMIT;
