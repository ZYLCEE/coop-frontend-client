# Profile actions backend handoff

## Notification Preferences

The repository defines per-user notification records and read-state operations. The admin notification function inserts records into Supabase. The app has no member preference API or delivery integration that reads preferences. Phone delivery may exist outside this repository.

The backend team needs to confirm which categories and channels members can control, provide authenticated per-member preference reads and writes, and enforce them in each relevant delivery channel. Essential security and transactional messages need a separate policy that general preferences cannot override.

## Download Loan Statement

The app can read member loan applications and payment history. Loan History derives its displayed balance from scheduled installments and recorded payments. An official statement needs authoritative ledger balances and an approved statement format.

The backend team needs to define the statement period, reconciliation rules, required loan and repayment fields, and CSUCC-approved content. Provide a member-authorized endpoint or private document download that verifies loan ownership and handles missing statements. Use the official values for principal, disbursements, payments, interest, fees, and outstanding balance.
