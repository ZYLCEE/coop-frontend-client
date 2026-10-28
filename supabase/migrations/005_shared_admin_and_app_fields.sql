ALTER TABLE public.members
  ADD COLUMN IF NOT EXISTS income DECIMAL(15, 2),
  ADD COLUMN IF NOT EXISTS credit_score INT DEFAULT 700;

UPDATE public.members AS member
SET user_id = auth_user.id
FROM auth.users AS auth_user
WHERE member.user_id IS NULL
  AND member.email IS NOT NULL
  AND lower(member.email) = lower(auth_user.email);

ALTER TABLE public.loan_applications
  DROP CONSTRAINT IF EXISTS loan_applications_loan_type_check;

ALTER TABLE public.loan_applications
  ADD CONSTRAINT loan_applications_loan_type_check
  CHECK (loan_type IN (
    'Regular', 'Medical', 'Educational', 'Emergency', 'Business',
    'Calamity', 'Multi-Purpose', 'Quick', 'Livelihood', 'Appliance',
    'Birthday', 'Anniversary', 'Fiesta', 'Bonus', 'Collateral',
    'Mortuary', 'Subsistence', 'ASSME'
  ));

CREATE OR REPLACE FUNCTION public.is_coop_admin()
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
AS $$
  SELECT COALESCE(auth.jwt() -> 'app_metadata' ->> 'role' = 'coop_admin', false);
$$;

GRANT EXECUTE ON FUNCTION public.is_coop_admin() TO authenticated;

REVOKE EXECUTE ON FUNCTION public.check_loan_eligibility(UUID, VARCHAR, DECIMAL)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_loan_eligibility(UUID, VARCHAR, DECIMAL)
  TO service_role;

REVOKE EXECUTE ON FUNCTION public.process_loan_approval(VARCHAR, UUID, TEXT)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_loan_approval(VARCHAR, UUID, TEXT)
  TO service_role;

REVOKE EXECUTE ON FUNCTION public.release_loan(VARCHAR)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.release_loan(VARCHAR)
  TO service_role;

REVOKE EXECUTE ON FUNCTION public.update_credit_score(UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.update_credit_score(UUID)
  TO service_role;

CREATE POLICY "Coop admins can view all members"
  ON public.members FOR SELECT TO authenticated
  USING (public.is_coop_admin());

CREATE POLICY "Coop admins can update members"
  ON public.members FOR UPDATE TO authenticated
  USING (public.is_coop_admin())
  WITH CHECK (public.is_coop_admin());

CREATE POLICY "Coop admins can view all loan applications"
  ON public.loan_applications FOR SELECT TO authenticated
  USING (public.is_coop_admin());

CREATE POLICY "Coop admins can update loan applications"
  ON public.loan_applications FOR UPDATE TO authenticated
  USING (public.is_coop_admin())
  WITH CHECK (public.is_coop_admin());

CREATE POLICY "Coop admins can view all loan payments"
  ON public.loan_payments FOR SELECT TO authenticated
  USING (public.is_coop_admin());

CREATE POLICY "Coop admins can manage loan payments"
  ON public.loan_payments FOR ALL TO authenticated
  USING (public.is_coop_admin())
  WITH CHECK (public.is_coop_admin());

CREATE POLICY "Coop admins can view all savings accounts"
  ON public.savings_accounts FOR SELECT TO authenticated
  USING (public.is_coop_admin());

CREATE POLICY "Coop admins can view all notifications"
  ON public.notifications FOR SELECT TO authenticated
  USING (public.is_coop_admin());

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM pg_publication WHERE pubname = 'supabase_realtime')
     AND NOT EXISTS (
       SELECT 1 FROM pg_publication_tables
       WHERE pubname = 'supabase_realtime'
         AND schemaname = 'public'
         AND tablename = 'loan_applications'
     ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.loan_applications;
  END IF;
END;
$$;