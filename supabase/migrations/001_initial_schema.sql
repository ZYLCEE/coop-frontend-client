-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Members table
CREATE TABLE IF NOT EXISTS public.members (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  member_id VARCHAR(20) UNIQUE NOT NULL,
  first_name VARCHAR(100) NOT NULL,
  last_name VARCHAR(100) NOT NULL,
  email VARCHAR(100) UNIQUE,
  phone VARCHAR(20),
  address TEXT,
  date_joined DATE DEFAULT CURRENT_DATE,
  status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create index on member_id
CREATE INDEX idx_members_member_id ON public.members(member_id);
CREATE INDEX idx_members_user_id ON public.members(user_id);

-- Loan applications table
CREATE TABLE IF NOT EXISTS public.loan_applications (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  application_id VARCHAR(20) UNIQUE NOT NULL,
  member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  member_name VARCHAR(200) NOT NULL,
  loan_type VARCHAR(50) NOT NULL CHECK (loan_type IN ('Regular', 'Medical', 'Educational', 'Emergency', 'Business')),
  amount DECIMAL(15, 2) NOT NULL,
  purpose TEXT,
  status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'under review', 'approved', 'rejected', 'released', 'completed', 'overdue')),
  income DECIMAL(15, 2),
  credit_score INT,
  date_submitted DATE NOT NULL,
  date_approved DATE,
  date_released DATE,
  date_completed DATE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for loan_applications
CREATE INDEX idx_loan_applications_member_id ON public.loan_applications(member_id);
CREATE INDEX idx_loan_applications_application_id ON public.loan_applications(application_id);
CREATE INDEX idx_loan_applications_status ON public.loan_applications(status);
CREATE INDEX idx_loan_applications_date_submitted ON public.loan_applications(date_submitted);

-- Loan payments table
CREATE TABLE IF NOT EXISTS public.loan_payments (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  loan_application_id UUID NOT NULL REFERENCES public.loan_applications(id) ON DELETE CASCADE,
  payment_amount DECIMAL(15, 2) NOT NULL,
  payment_date DATE NOT NULL,
  payment_method VARCHAR(50) DEFAULT 'cash' CHECK (payment_method IN ('cash', 'bank_transfer', 'check', 'automatic')),
  notes TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for loan_payments
CREATE INDEX idx_loan_payments_loan_application_id ON public.loan_payments(loan_application_id);
CREATE INDEX idx_loan_payments_payment_date ON public.loan_payments(payment_date);

-- Savings accounts table
CREATE TABLE IF NOT EXISTS public.savings_accounts (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  member_id UUID NOT NULL REFERENCES public.members(id) ON DELETE CASCADE,
  account_number VARCHAR(20) UNIQUE NOT NULL,
  balance DECIMAL(15, 2) DEFAULT 0.00,
  account_type VARCHAR(50) DEFAULT 'regular' CHECK (account_type IN ('regular', 'special', 'time_deposit')),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for savings_accounts
CREATE INDEX idx_savings_accounts_member_id ON public.savings_accounts(member_id);
CREATE INDEX idx_savings_accounts_account_number ON public.savings_accounts(account_number);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER update_members_updated_at
  BEFORE UPDATE ON public.members
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_loan_applications_updated_at
  BEFORE UPDATE ON public.loan_applications
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_savings_accounts_updated_at
  BEFORE UPDATE ON public.savings_accounts
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- Insert sample data for testing
INSERT INTO public.members (member_id, first_name, last_name, email, phone, address) VALUES
('M-001', 'Juan', 'dela Cruz', 'juan@example.com', '09171234567', '123 Main St, Manila'),
('M-002', 'Rosa', 'Mendoza', 'rosa@example.com', '09181234567', '456 Oak Ave, Quezon City'),
('M-003', 'Carlo', 'Reyes', 'carlo@example.com', '09191234567', '789 Pine Rd, Makati'),
('M-004', 'Ana', 'Torres', 'ana@example.com', '09201234567', '321 Elm St, Pasig'),
('M-005', 'Pedro', 'Santos', 'pedro@example.com', '09211234567', '654 Maple Dr, Taguig'),
('M-006', 'Luis', 'Garcia', 'luis@example.com', '09221234567', '987 Cedar Ln, Paranaque'),
('M-007', 'Grace', 'Tan', 'grace@example.com', '09231234567', '159 Birch Blvd, Muntinlupa');

INSERT INTO public.loan_applications (application_id, member_id, member_name, loan_type, amount, purpose, status, income, credit_score, date_submitted) VALUES
('LA-2025-0089', (SELECT id FROM public.members WHERE member_id = 'M-001'), 'Juan dela Cruz', 'Regular', 75000.00, 'Business expansion', 'pending', 120000, 750, '2025-07-25'),
('LA-2025-0088', (SELECT id FROM public.members WHERE member_id = 'M-002'), 'Rosa Mendoza', 'Medical', 30000.00, 'Medical emergency', 'under review', 95000, 720, '2025-07-24'),
('LA-2025-0087', (SELECT id FROM public.members WHERE member_id = 'M-003'), 'Carlo Reyes', 'Educational', 50000.00, 'Tuition fee payment', 'approved', 150000, 780, '2025-07-23'),
('LA-2025-0086', (SELECT id FROM public.members WHERE member_id = 'M-004'), 'Ana Torres', 'Emergency', 20000.00, 'Personal emergency', 'rejected', 60000, 650, '2025-07-22'),
('LA-2025-0085', (SELECT id FROM public.members WHERE member_id = 'M-005'), 'Pedro Santos', 'Regular', 80000.00, 'Home renovation', 'released', 180000, 800, '2025-07-21'),
('LA-2025-0084', (SELECT id FROM public.members WHERE member_id = 'M-006'), 'Luis Garcia', 'Medical', 25000.00, 'Medical expenses', 'completed', 85000, 710, '2025-07-20'),
('LA-2025-0083', (SELECT id FROM public.members WHERE member_id = 'M-007'), 'Grace Tan', 'Regular', 60000.00, 'Small business', 'overdue', 110000, 690, '2025-07-19');
