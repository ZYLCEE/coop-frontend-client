BEGIN;

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS data JSONB NOT NULL DEFAULT '{}'::JSONB;

ALTER TABLE public.notifications
  DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE public.notifications
  ADD CONSTRAINT notifications_type_check CHECK (type IN (
    'info', 'success', 'warning', 'error', 'loan_approval', 'loan_rejection',
    'payment_reminder', 'co_maker_invitation', 'co_maker_response'
  ));

CREATE TABLE IF NOT EXISTS public.co_maker_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  application_id VARCHAR(20) NOT NULL UNIQUE,
  borrower_user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  borrower_member_id UUID NOT NULL REFERENCES public.members(id),
  co_maker_member_id UUID NOT NULL REFERENCES public.members(id),
  co_maker_user_id UUID NOT NULL REFERENCES auth.users(id),
  borrower_name TEXT NOT NULL,
  co_maker_name TEXT NOT NULL,
  relationship TEXT NOT NULL CHECK (length(trim(relationship)) BETWEEN 1 AND 100),
  loan_type VARCHAR(50) NOT NULL,
  amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
  tenure_months INTEGER NOT NULL CHECK (tenure_months BETWEEN 1 AND 360),
  loan_details JSONB NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'otp_pending', 'accepted', 'rejected', 'expired')),
  otp_requested_at TIMESTAMPTZ,
  accepted_at TIMESTAMPTZ,
  rejected_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  CHECK (borrower_member_id <> co_maker_member_id),
  CHECK (borrower_user_id <> co_maker_user_id)
);

CREATE INDEX IF NOT EXISTS co_maker_requests_borrower_idx
  ON public.co_maker_requests (borrower_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS co_maker_requests_recipient_idx
  ON public.co_maker_requests (co_maker_user_id, created_at DESC);

ALTER TABLE public.co_maker_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.co_maker_requests FROM PUBLIC, anon, authenticated;
GRANT SELECT ON TABLE public.co_maker_requests TO authenticated;
GRANT ALL ON TABLE public.co_maker_requests TO service_role;

DROP POLICY IF EXISTS "Involved members can view co-maker requests"
  ON public.co_maker_requests;
CREATE POLICY "Involved members can view co-maker requests"
  ON public.co_maker_requests FOR SELECT TO authenticated
  USING (auth.uid() = borrower_user_id OR auth.uid() = co_maker_user_id);

ALTER TABLE public.loan_applications
  ADD COLUMN IF NOT EXISTS tenure_months INTEGER,
  ADD COLUMN IF NOT EXISTS co_maker_member_id UUID REFERENCES public.members(id),
  ADD COLUMN IF NOT EXISTS co_maker_relationship TEXT,
  ADD COLUMN IF NOT EXISTS co_maker_request_id UUID
    REFERENCES public.co_maker_requests(id);

CREATE OR REPLACE FUNCTION public.attach_accepted_co_maker_request()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $function$
DECLARE
  consent public.co_maker_requests%ROWTYPE;
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

    NEW.co_maker_member_id := consent.co_maker_member_id;
    NEW.co_maker_relationship := consent.relationship;
    NEW.co_maker_request_id := consent.id;
  END IF;

  RETURN NEW;
END;
$function$;

REVOKE EXECUTE ON FUNCTION public.attach_accepted_co_maker_request()
  FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS attach_accepted_co_maker_request
  ON public.loan_applications;
CREATE TRIGGER attach_accepted_co_maker_request
  BEFORE INSERT ON public.loan_applications
  FOR EACH ROW
  EXECUTE FUNCTION public.attach_accepted_co_maker_request();

COMMIT;
