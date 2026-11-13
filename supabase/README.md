# Supabase Setup Guide

This directory contains all the Supabase configuration for the CSUCCERMPC app.

## Database Migrations

Run these SQL migrations in your Supabase dashboard (SQL Editor) in order:

1. **001_initial_schema.sql** - Creates the core database tables (members, loan_applications, loan_payments, savings_accounts)
2. **002_rls_policies.sql** - Sets up Row Level Security policies for data protection
3. **003_database_functions.sql** - Creates database functions for business logic (loan eligibility, approval processing, credit score updates)
4. **004_notifications_table.sql** - Creates the notifications table and RLS policies
5. **005_shared_admin_and_app_fields.sql** - Adds member fields, admin-role RLS policies, account linking, and realtime loan updates

### How to Apply Migrations

1. Go to your Supabase dashboard: https://supabase.com/dashboard/project/jhgsqvxlvwhrwpcekvpq
2. Navigate to SQL Editor
3. Open each migration file and run it in order (001, then 002, then 003, then 004)

## Edge Functions

Edge Functions are serverless functions for sensitive business logic:

- **loan-approval**: Processes loan approval logic
- **loan-eligibility**: Checks if a member is eligible for a loan
- **loan-release**: Releases approved loans
- **notifications**: Sends notifications to users

### How to Deploy Edge Functions

Install Supabase CLI:
```bash
npm install -g supabase
```

Login to Supabase:
```bash
supabase login
```

Link to your project:
```bash
supabase link --project-ref jhgsqvxlvwhrwpcekvpq
```

Deploy all edge functions:
```bash
supabase functions deploy loan-approval
supabase functions deploy loan-eligibility
supabase functions deploy loan-release
supabase functions deploy notifications
```

Set environment variables for edge functions:
```bash
supabase secrets set SUPABASE_URL=<your-project-url>
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<set-this-secret-in-your-terminal>
```

## Database Functions

The following database functions are available for use:

### check_loan_eligibility(p_member_id, p_loan_type, p_amount)
Checks if a member is eligible for a loan based on:
- Member status (must be active)
- Credit score
- Income
- Existing loans
- Savings balance
- Payment history

Returns: eligibility status, max loan amount, and reason

### calculate_payment_schedule(p_loan_amount, p_interest_rate, p_term_months)
Calculates amortization schedule for a loan.

Returns: payment schedule with principal, interest, and remaining balance for each payment

### process_loan_approval(p_application_id, p_approved_by, p_notes)
Processes loan approval by:
- Checking eligibility
- Automatically rejecting if not eligible
- Updating loan status to approved

Returns: success status, message, and new status

### release_loan(p_application_id)
Releases an approved loan by updating status to 'released' and setting release date.

Returns: success status and message

### update_credit_score(p_member_id)
Updates a member's credit score based on payment history.

Returns: new credit score

## Storage Setup

Create storage buckets in Supabase:

1. Go to Storage in your Supabase dashboard
2. Create a bucket named `documents` for loan documents
3. Create a bucket named `profile-images` for member profile pictures
4. Set appropriate RLS policies for each bucket

## Flutter Integration

The Flutter app has been configured with:
- `supabase_flutter` dependency
- Environment variables in `.env` file
- Supabase initialization in `main.dart`
- SupabaseService class for common operations

Set `SUPABASE_URL` and the project's current anon/publishable key in the
Flutter app's local `.env` file. Do not put a service-role key in the app.
Members sign in with their Member ID; cooperative administrators use the
superadmin email sign-in option and must have
`app_metadata.role = 'coop_admin'`, as checked by `is_coop_admin()`. Set that
role only through a trusted server-side admin process, never from the client.

### Usage in Flutter

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import 'services/supabase_service.dart';

// Authentication
await SupabaseService().signIn(email: 'user@example.com', password: 'password');
await SupabaseService().signOut();

// Database operations
final supabase = Supabase.instance.client;
final data = await supabase.from('members').select().eq('user_id', userId);

// Call database functions
final eligibility = await supabase.rpc('check_loan_eligibility', params: {
  'p_member_id': memberId,
  'p_loan_type': 'Regular',
  'p_amount': 50000
});

// Call edge functions
final response = await supabase.functions.invoke('loan-approval', body: {
  'application_id': 'LA-2025-0089',
  'approved_by': userId,
  'notes': 'Approved'
});
```

## Security Notes

- Never commit the `.env` file to version control
- The service role key is for server-side use only (Edge Functions)
- The anon key is safe for client-side use due to RLS policies
- RLS policies ensure users can only access their own data
- Edge Functions use service role key for elevated privileges

## Co-Maker Notification Email

The co-maker invitation Edge Function creates one detailed in-app notification
and sends an email copy for invitation, acceptance, and decline events. Email
delivery uses the Resend API from the Edge Function; the Resend key must never
be added to Flutter or committed to this repository. The recipient must have a
registered email on their Supabase Auth account. Email is informational: the
co-maker must sign in to CSUCC ERMPC and accept or decline in the app, where
acceptance still requires email OTP verification.

Before deploying to a staging project, verify a sending domain with Resend and
set these Edge Function secrets on that project:

```sh
supabase secrets set RESEND_API_KEY=re_your_key COOP_EMAIL_FROM="CSUCC ERMPC <no-reply@your-verified-domain>" --project-ref YOUR_STAGING_PROJECT_REF
```

Then deploy the function to staging and test with two staging member accounts:

```sh
supabase functions deploy co-maker-invitation --project-ref YOUR_STAGING_PROJECT_REF
```

The function reports `email_sent` in its response. The app keeps the in-app
notification available if the email provider is not configured or delivery
fails, and displays that state to the borrower.
