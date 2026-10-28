-- Enable Row Level Security on all tables
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loan_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.loan_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.savings_accounts ENABLE ROW LEVEL SECURITY;

-- Members table policies
-- Allow authenticated users to read their own member data
CREATE POLICY "Users can view own member data"
  ON public.members
  FOR SELECT
  USING (auth.uid() = user_id);

-- Allow authenticated users to update their own member data
CREATE POLICY "Users can update own member data"
  ON public.members
  FOR UPDATE
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

-- Allow service role to insert members (for admin operations)
CREATE POLICY "Service role can insert members"
  ON public.members
  FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

-- Allow service role to delete members
CREATE POLICY "Service role can delete members"
  ON public.members
  FOR DELETE
  USING (auth.role() = 'service_role');

-- Loan applications table policies
-- Allow authenticated users to read their own loan applications
CREATE POLICY "Users can view own loan applications"
  ON public.loan_applications
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.members
      WHERE members.id = loan_applications.member_id
      AND members.user_id = auth.uid()
    )
  );

-- Allow authenticated users to insert their own loan applications
CREATE POLICY "Users can insert own loan applications"
  ON public.loan_applications
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.members
      WHERE members.id = loan_applications.member_id
      AND members.user_id = auth.uid()
    )
  );

-- Allow service role to update loan applications (for approval workflow)
CREATE POLICY "Service role can update loan applications"
  ON public.loan_applications
  FOR UPDATE
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Allow service role to delete loan applications
CREATE POLICY "Service role can delete loan applications"
  ON public.loan_applications
  FOR DELETE
  USING (auth.role() = 'service_role');

-- Loan payments table policies
-- Allow authenticated users to read payments for their own loans
CREATE POLICY "Users can view own loan payments"
  ON public.loan_payments
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.loan_applications
      JOIN public.members ON members.id = loan_applications.member_id
      WHERE loan_applications.id = loan_payments.loan_application_id
      AND members.user_id = auth.uid()
    )
  );

-- Allow service role to insert loan payments
CREATE POLICY "Service role can insert loan payments"
  ON public.loan_payments
  FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

-- Allow service role to update loan payments
CREATE POLICY "Service role can update loan payments"
  ON public.loan_payments
  FOR UPDATE
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Allow service role to delete loan payments
CREATE POLICY "Service role can delete loan payments"
  ON public.loan_payments
  FOR DELETE
  USING (auth.role() = 'service_role');

-- Savings accounts table policies
-- Allow authenticated users to read their own savings accounts
CREATE POLICY "Users can view own savings accounts"
  ON public.savings_accounts
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.members
      WHERE members.id = savings_accounts.member_id
      AND members.user_id = auth.uid()
    )
  );

-- Allow service role to insert savings accounts
CREATE POLICY "Service role can insert savings accounts"
  ON public.savings_accounts
  FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

-- Allow service role to update savings accounts
CREATE POLICY "Service role can update savings accounts"
  ON public.savings_accounts
  FOR UPDATE
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

-- Allow service role to delete savings accounts
CREATE POLICY "Service role can delete savings accounts"
  ON public.savings_accounts
  FOR DELETE
  USING (auth.role() = 'service_role');
