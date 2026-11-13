BEGIN;

-- Keep the cooperative's human-readable member number alongside the internal
-- members.id foreign key so application evidence can display it directly.
ALTER TABLE public.loan_applications
  ADD COLUMN IF NOT EXISTS co_maker_member_code VARCHAR(20);

UPDATE public.loan_applications AS application
SET co_maker_member_code = member.member_id
FROM public.members AS member
WHERE application.co_maker_member_id = member.id
  AND application.co_maker_member_code IS NULL;

CREATE OR REPLACE FUNCTION public.attach_accepted_co_maker_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  consent public.co_maker_requests%ROWTYPE;
  member_code TEXT;
BEGIN
  SELECT * INTO consent
  FROM public.co_maker_requests
  WHERE application_id = NEW.application_id
  FOR UPDATE;

  IF FOUND THEN
    IF consent.status <> 'accepted' THEN
      RAISE EXCEPTION 'Co-maker consent has not been confirmed.';
    END IF;
    IF consent.loan_type <> NEW.loan_type
       OR consent.amount <> NEW.amount
       OR consent.tenure_months <> NEW.tenure_months THEN
      RAISE EXCEPTION 'Loan details changed after co-maker consent.';
    END IF;

    SELECT member.member_id INTO member_code
    FROM public.members AS member
    WHERE member.id = consent.co_maker_member_id
      AND member.status = 'active';

    IF member_code IS NULL THEN
      RAISE EXCEPTION 'The verified co-maker is no longer an active member.';
    END IF;

    NEW.co_maker_member_id := consent.co_maker_member_id;
    NEW.co_maker_member_code := member_code;
    NEW.co_maker_relationship := consent.relationship;
    NEW.co_maker_request_id := consent.id;
  END IF;

  RETURN NEW;
END;
$function$;

COMMIT;
