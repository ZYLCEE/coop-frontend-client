-- Database Functions for Business Logic

-- Function to check loan eligibility
CREATE OR REPLACE FUNCTION check_loan_eligibility(
  p_member_id UUID,
  p_loan_type VARCHAR,
  p_amount DECIMAL
)
RETURNS TABLE (
  eligible BOOLEAN,
  max_loan_amount DECIMAL,
  reason TEXT
) AS $$
DECLARE
  v_member_status VARCHAR;
  v_existing_loans INT;
  v_total_outstanding DECIMAL;
  v_savings_balance DECIMAL;
  v_credit_score INT;
  v_income DECIMAL;
  v_max_amount DECIMAL;
BEGIN
  -- Get member information
  SELECT status, credit_score, income INTO v_member_status, v_credit_score, v_income
  FROM public.members
  WHERE id = p_member_id;

  -- Check if member is active
  IF v_member_status != 'active' THEN
    RETURN QUERY SELECT false, 0::DECIMAL, 'Member is not active';
    RETURN;
  END IF;

  -- Count existing active loans
  SELECT COUNT(*), COALESCE(SUM(amount), 0) INTO v_existing_loans, v_total_outstanding
  FROM public.loan_applications
  WHERE member_id = p_member_id
  AND status IN ('approved', 'released', 'overdue');

  -- Get savings balance
  SELECT COALESCE(SUM(balance), 0) INTO v_savings_balance
  FROM public.savings_accounts
  WHERE member_id = p_member_id;

  -- Calculate max loan amount based on credit score and income
  v_max_amount := (v_income * 5)::DECIMAL;

  -- Adjust based on credit score
  IF v_credit_score >= 750 THEN
    v_max_amount := v_max_amount * 1.2;
  ELSIF v_credit_score >= 700 THEN
    v_max_amount := v_max_amount * 1.0;
  ELSIF v_credit_score >= 650 THEN
    v_max_amount := v_max_amount * 0.8;
  ELSE
    v_max_amount := v_max_amount * 0.5;
  END IF;

  -- Adjust based on savings (higher savings = higher loan limit)
  IF v_savings_balance > 50000 THEN
    v_max_amount := v_max_amount + (v_savings_balance * 0.5);
  END IF;

  -- Check if requested amount exceeds maximum
  IF p_amount > v_max_amount THEN
    RETURN QUERY SELECT false, v_max_amount, 'Requested amount exceeds maximum allowed based on credit score and income';
    RETURN;
  END IF;

  -- Check if member has too many active loans
  IF v_existing_loans >= 3 THEN
    RETURN QUERY SELECT false, v_max_amount, 'Maximum number of active loans reached';
    RETURN;
  END IF;

  -- Check for overdue loans
  IF EXISTS (
    SELECT 1 FROM public.loan_applications
    WHERE member_id = p_member_id
    AND status = 'overdue'
  ) THEN
    RETURN QUERY SELECT false, v_max_amount, 'Member has overdue loans';
    RETURN;
  END IF;

  -- All checks passed
  RETURN QUERY SELECT true, v_max_amount, 'Eligible for loan';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to calculate loan payment schedule
CREATE OR REPLACE FUNCTION calculate_payment_schedule(
  p_loan_amount DECIMAL,
  p_interest_rate DECIMAL,
  p_term_months INT
)
RETURNS TABLE (
  payment_number INT,
  payment_amount DECIMAL,
  principal_amount DECIMAL,
  interest_amount DECIMAL,
  remaining_balance DECIMAL,
  payment_date DATE
) AS $$
DECLARE
  v_monthly_rate DECIMAL;
  v_monthly_payment DECIMAL;
  v_remaining_balance DECIMAL;
  v_payment_date DATE;
  i INT;
BEGIN
  v_monthly_rate := p_interest_rate / 12 / 100;
  v_remaining_balance := p_loan_amount;
  v_payment_date := CURRENT_DATE;

  -- Calculate monthly payment using amortization formula
  IF v_monthly_rate = 0 THEN
    v_monthly_payment := p_loan_amount / p_term_months;
  ELSE
    v_monthly_payment := p_loan_amount * (v_monthly_rate * POWER(1 + v_monthly_rate, p_term_months)) / (POWER(1 + v_monthly_rate, p_term_months) - 1);
  END IF;

  FOR i IN 1..p_term_months LOOP
    v_payment_date := v_payment_date + INTERVAL '1 month';

    RETURN QUERY NEXT
    SELECT
      i,
      v_monthly_payment,
      LEAST(v_monthly_payment - (v_remaining_balance * v_monthly_rate), v_remaining_balance),
      v_remaining_balance * v_monthly_rate,
      v_remaining_balance - LEAST(v_monthly_payment - (v_remaining_balance * v_monthly_rate), v_remaining_balance),
      v_payment_date;

    v_remaining_balance := v_remaining_balance - LEAST(v_monthly_payment - (v_remaining_balance * v_monthly_rate), v_remaining_balance);

    IF v_remaining_balance <= 0 THEN
      EXIT;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to process loan approval
CREATE OR REPLACE FUNCTION process_loan_approval(
  p_application_id VARCHAR,
  p_approved_by UUID,
  p_notes TEXT DEFAULT NULL
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT,
  new_status VARCHAR
) AS $$
DECLARE
  v_application RECORD;
  v_eligibility RECORD;
BEGIN
  -- Get loan application details
  SELECT * INTO v_application
  FROM public.loan_applications
  WHERE application_id = p_application_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'Loan application not found', NULL::VARCHAR;
    RETURN;
  END IF;

  -- Check if already processed
  IF v_application.status NOT IN ('pending', 'under review') THEN
    RETURN QUERY SELECT false, 'Loan application already processed', v_application.status;
    RETURN;
  END IF;

  -- Check eligibility
  SELECT * INTO v_eligibility
  FROM check_loan_eligibility(v_application.member_id, v_application.loan_type, v_application.amount);

  IF NOT v_eligibility.eligible THEN
    -- Reject the loan
    UPDATE public.loan_applications
    SET status = 'rejected',
        updated_at = CURRENT_TIMESTAMP
    WHERE application_id = p_application_id;

    RETURN QUERY SELECT false, v_eligibility.reason, 'rejected';
    RETURN;
  END IF;

  -- Approve the loan
  UPDATE public.loan_applications
  SET status = 'approved',
      date_approved = CURRENT_DATE,
      updated_at = CURRENT_TIMESTAMP
  WHERE application_id = p_application_id;

  RETURN QUERY SELECT true, 'Loan approved successfully', 'approved';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to trigger loan release
CREATE OR REPLACE FUNCTION release_loan(
  p_application_id VARCHAR
)
RETURNS TABLE (
  success BOOLEAN,
  message TEXT
) AS $$
DECLARE
  v_application RECORD;
BEGIN
  -- Get loan application details
  SELECT * INTO v_application
  FROM public.loan_applications
  WHERE application_id = p_application_id;

  IF NOT FOUND THEN
    RETURN QUERY SELECT false, 'Loan application not found';
    RETURN;
  END IF;

  -- Check if approved
  IF v_application.status != 'approved' THEN
    RETURN QUERY SELECT false, 'Loan must be approved before release';
    RETURN;
  END IF;

  -- Release the loan
  UPDATE public.loan_applications
  SET status = 'released',
      date_released = CURRENT_DATE,
      updated_at = CURRENT_TIMESTAMP
  WHERE application_id = p_application_id;

  RETURN QUERY SELECT true, 'Loan released successfully';
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update credit score based on payment history
CREATE OR REPLACE FUNCTION update_credit_score(p_member_id UUID)
RETURNS INT AS $$
DECLARE
  v_on_time_payments INT;
  v_late_payments INT;
  v_total_payments INT;
  v_new_score INT;
  v_current_score INT;
BEGIN
  -- Get current credit score
  SELECT credit_score INTO v_current_score
  FROM public.members
  WHERE id = p_member_id;

  -- Count on-time payments (within 5 days of due date)
  SELECT COUNT(*) INTO v_on_time_payments
  FROM public.loan_payments lp
  JOIN public.loan_applications la ON la.id = lp.loan_application_id
  WHERE la.member_id = p_member_id
  AND lp.payment_date <= la.date_released + INTERVAL '30 days' * ROW_NUMBER() OVER (PARTITION BY la.id ORDER BY lp.payment_date)
  AND lp.payment_date >= la.date_released + INTERVAL '30 days' * (ROW_NUMBER() OVER (PARTITION BY la.id ORDER BY lp.payment_date) - 1) - INTERVAL '5 days';

  -- Count late payments
  SELECT COUNT(*) INTO v_late_payments
  FROM public.loan_payments lp
  JOIN public.loan_applications la ON la.id = lp.loan_application_id
  WHERE la.member_id = p_member_id
  AND lp.payment_date > la.date_released + INTERVAL '30 days' * ROW_NUMBER() OVER (PARTITION BY la.id ORDER BY lp.payment_date) - INTERVAL '5 days';

  v_total_payments := v_on_time_payments + v_late_payments;

  IF v_total_payments = 0 THEN
    RETURN v_current_score;
  END IF;

  -- Calculate new score (base 700, +10 for on-time, -20 for late)
  v_new_score := 700 + (v_on_time_payments * 10) - (v_late_payments * 20);

  -- Cap between 300 and 850
  v_new_score := GREATEST(LEAST(v_new_score, 850), 300);

  -- Update member's credit score
  UPDATE public.members
  SET credit_score = v_new_score,
      updated_at = CURRENT_TIMESTAMP
  WHERE id = p_member_id;

  RETURN v_new_score;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
