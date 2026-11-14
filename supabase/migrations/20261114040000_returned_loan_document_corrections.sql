-- Allow member document corrections for applications explicitly returned
-- for requirements. Run in the Supabase SQL Editor as one script.
BEGIN;

CREATE OR REPLACE FUNCTION public.submit_document_replacement(
  p_document_id uuid,
  p_expected_version_id uuid,
  p_storage_path text,
  p_name text,
  p_content_type text,
  p_size_bytes bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  d public.loan_documents%ROWTYPE;
  current_version uuid;
  current_number integer;
  review_status text;
  app_status text;
  returned_for_requirements boolean;
  object_metadata jsonb;
  created_id uuid;
BEGIN
  IF NOT public.document_member_active() THEN
    RAISE EXCEPTION 'Sign in with an active member account.' USING ERRCODE='42501';
  END IF;

  SELECT * INTO STRICT d
  FROM public.loan_documents
  WHERE id=p_document_id
  FOR UPDATE;

  IF d.user_id IS DISTINCT FROM auth.uid() THEN
    RAISE EXCEPTION 'This document belongs to another member.' USING ERRCODE='42501';
  END IF;

  -- Make retries safe when the upload committed but the client lost its response.
  SELECT id INTO created_id
  FROM public.loan_document_versions
  WHERE document_id=d.id AND storage_path=p_storage_path;
  IF created_id IS NOT NULL THEN
    RETURN jsonb_build_object('id',created_id);
  END IF;

  SELECT id,version INTO current_version,current_number
  FROM public.loan_document_versions
  WHERE document_id=d.id
  ORDER BY version DESC
  LIMIT 1;

  IF current_version IS DISTINCT FROM p_expected_version_id THEN
    RAISE EXCEPTION 'A newer replacement already exists. Refresh your documents.' USING ERRCODE='40001';
  END IF;

  SELECT status INTO review_status
  FROM public.loan_document_reviews
  WHERE document_id=d.id AND version_id IS NOT DISTINCT FROM current_version
  ORDER BY created_at DESC,id DESC
  LIMIT 1;

  SELECT status::text INTO app_status
  FROM public.loan_applications
  WHERE id=d.loan_application_id;

  SELECT EXISTS (
    SELECT 1
    FROM public.application_verifications v
    WHERE v.application_id=d.loan_application_id
      AND v.stage='returned_for_requirements'
  ) INTO returned_for_requirements;

  -- The specific current file must have been requested for replacement. A
  -- returned application is eligible only while its requirements return is active.
  IF review_status IS DISTINCT FROM 'needs_replacement'
     OR app_status IS NULL
     OR (
       app_status NOT IN ('pending','under review')
       AND NOT (
         app_status IN ('returned','returned_for_requirements')
         AND returned_for_requirements
       )
     ) THEN
    RAISE EXCEPTION 'A replacement can be submitted only for a requested file while the application is Pending, Under Review, or Returned for requirements.';
  END IF;

  IF p_storage_path IS NULL
     OR left(p_storage_path,length(auth.uid()::text)+1)<>auth.uid()::text||'/'
     OR p_name IS NULL OR length(p_name) NOT BETWEEN 1 AND 255
     OR p_size_bytes IS NULL OR p_size_bytes NOT BETWEEN 1 AND 10485760
     OR p_content_type IS NULL
     OR p_content_type NOT IN ('application/pdf','image/jpeg','image/png','image/webp','image/heic','image/heif') THEN
    RAISE EXCEPTION 'Choose a supported file of up to 10 MB.';
  END IF;

  SELECT metadata INTO object_metadata
  FROM storage.objects
  WHERE bucket_id='loan-documents' AND name=p_storage_path;

  IF object_metadata IS NULL
     OR (object_metadata->>'size')::bigint IS DISTINCT FROM p_size_bytes
     OR object_metadata->>'mimetype' IS DISTINCT FROM p_content_type THEN
    RAISE EXCEPTION 'The uploaded file could not be verified. Please retry.';
  END IF;

  IF EXISTS(SELECT 1 FROM public.loan_documents WHERE storage_path=p_storage_path)
     OR EXISTS(SELECT 1 FROM public.loan_document_versions WHERE storage_path=p_storage_path) THEN
    RAISE EXCEPTION 'This file is already registered.';
  END IF;

  INSERT INTO public.loan_document_versions(
    document_id,version,storage_path,original_name,content_type,size_bytes,uploaded_by,uploaded_by_name
  ) VALUES (
    d.id,coalesce(current_number,1)+1,p_storage_path,p_name,p_content_type,
    p_size_bytes,auth.uid(),public.document_actor_label()
  ) RETURNING id INTO created_id;

  -- Deliberately do not copy the old review onto this version; it starts To review.
  RETURN jsonb_build_object('id',created_id,'version',coalesce(current_number,1)+1);
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_document_replacement(uuid,uuid,text,text,text,bigint) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.submit_document_replacement(uuid,uuid,text,text,text,bigint) TO authenticated,service_role;

CREATE OR REPLACE FUNCTION public.submit_missing_application_document(
  p_application_id text,
  p_content_type text,
  p_kind text,
  p_name text,
  p_size_bytes bigint,
  p_storage_path text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO ''
AS $function$
DECLARE
  app_id uuid;
  app_status text;
  verification_stage text;
  requested_kinds jsonb;
  object_metadata jsonb;
  existing_id uuid;
  created_id uuid;
BEGIN
  IF auth.uid() IS NULL OR NOT public.document_member_active() THEN
    RAISE EXCEPTION 'An active member account is required.' USING ERRCODE='42501';
  END IF;

  IF p_application_id IS NULL OR length(btrim(p_application_id)) NOT BETWEEN 1 AND 50
     OR p_kind IS NULL OR p_kind NOT IN ('payslip','validId','collateral','employerCertification','supporting')
     OR p_name IS NULL OR length(p_name) NOT BETWEEN 1 AND 255
     OR p_size_bytes IS NULL OR p_size_bytes NOT BETWEEN 1 AND 10485760
     OR p_content_type IS NULL
     OR p_content_type NOT IN ('application/pdf','image/jpeg','image/png','image/webp','image/heic','image/heif') THEN
    RAISE EXCEPTION 'Choose a valid requested document no larger than 10 MB.';
  END IF;

  SELECT a.id,a.status::text,v.stage
    INTO app_id,app_status,verification_stage
  FROM public.loan_applications a
  JOIN public.members m ON m.id=a.member_id
  LEFT JOIN public.application_verifications v ON v.application_id=a.id
  WHERE a.application_id=p_application_id AND m.user_id=auth.uid()
  FOR UPDATE OF a;

  IF app_id IS NULL THEN
    RAISE EXCEPTION 'The application was not found for this member.' USING ERRCODE='42501';
  END IF;

  IF app_status NOT IN ('returned','returned_for_requirements')
     OR verification_stage IS DISTINCT FROM 'returned_for_requirements' THEN
    RAISE EXCEPTION 'Documents can be added only to an application returned for requirements.';
  END IF;

  SELECT e.details->'affectedKinds' INTO requested_kinds
  FROM public.application_workflow_events e
  WHERE e.application_id=app_id AND e.action='return'
  ORDER BY e.created_at DESC,e.id DESC
  LIMIT 1;

  IF jsonb_typeof(requested_kinds) IS DISTINCT FROM 'array'
     OR NOT EXISTS (
       SELECT 1 FROM jsonb_array_elements_text(
         CASE WHEN jsonb_typeof(requested_kinds)='array'
              THEN requested_kinds ELSE '[]'::jsonb END
       ) k(kind)
       WHERE k.kind=p_kind
     ) THEN
    RAISE EXCEPTION 'This document type was not requested in the latest return instructions.';
  END IF;

  IF p_storage_path IS NULL
     OR left(p_storage_path,length(auth.uid()::text||'/'||p_application_id||'/'))
        <> auth.uid()::text||'/'||p_application_id||'/' THEN
    RAISE EXCEPTION 'The uploaded file path does not match this member and application.' USING ERRCODE='42501';
  END IF;

  -- A file already present for this kind must use the replacement RPC so its
  -- version and review history stay attached to the original document record.
  SELECT id INTO existing_id
  FROM public.loan_documents
  WHERE loan_application_id=app_id AND user_id=auth.uid() AND kind=p_kind
  ORDER BY created_at DESC,id DESC
  LIMIT 1
  FOR UPDATE;

  IF existing_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.loan_documents
      WHERE id=existing_id AND storage_path=p_storage_path
    ) THEN
      RETURN jsonb_build_object('id',existing_id);
    END IF;
    RAISE EXCEPTION 'This document already exists. Use Upload replacement on its document card.';
  END IF;

  SELECT metadata INTO object_metadata
  FROM storage.objects
  WHERE bucket_id='loan-documents' AND name=p_storage_path;

  IF object_metadata IS NULL
     OR (object_metadata->>'size')::bigint IS DISTINCT FROM p_size_bytes
     OR object_metadata->>'mimetype' IS DISTINCT FROM p_content_type THEN
    RAISE EXCEPTION 'The uploaded file could not be verified. Please retry.';
  END IF;

  IF EXISTS(SELECT 1 FROM public.loan_documents WHERE storage_path=p_storage_path)
     OR EXISTS(SELECT 1 FROM public.loan_document_versions WHERE storage_path=p_storage_path) THEN
    RAISE EXCEPTION 'This file is already registered.';
  END IF;

  INSERT INTO public.loan_documents(
    loan_application_id,user_id,kind,storage_path,original_name,content_type,size_bytes
  ) VALUES (
    app_id,auth.uid(),p_kind,p_storage_path,p_name,p_content_type,p_size_bytes
  ) RETURNING id INTO created_id;

  RETURN jsonb_build_object('id',created_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.submit_missing_application_document(text,text,text,text,bigint,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.submit_missing_application_document(text,text,text,text,bigint,text) TO authenticated,service_role;

NOTIFY pgrst,'reload schema';
COMMIT;
