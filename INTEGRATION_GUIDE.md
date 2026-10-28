# Full Integration Guide - Flutter App, Admin Web, and Supabase

This guide explains how the Flutter app, admin web, and Supabase database are connected.

## Architecture Overview

```
┌─────────────────┐
│  Flutter App    │
│  (Member App)   │
└────────┬────────┘
         │
         │ Supabase SDK (Anon Key + RLS)
         │
         ▼
┌─────────────────────────────────────┐
│         Supabase Database           │
│  (PostgreSQL + Auth + Storage)     │
│                                     │
│  - Members table                    │
│  - Loan applications               │
│  - Loan payments                   │
│  - Savings accounts                │
│  - Notifications                   │
│  - Row Level Security (RLS)        │
│  - Database Functions              │
│  - Edge Functions                  │
└────────┬────────────────────────────┘
         │
         │ Supabase SDK (Publishable Key + Admin Auth + RLS)
         │
         ▼
┌─────────────────┐
│  Admin Web      │
│  (Next.js)      │
└─────────────────┘
```

## Component Details

### 1. Supabase Database

**Location:** https://supabase.com/dashboard/project/jhgsqvxlvwhrwpcekvpq

**Tables:**
- `members` - Member profiles and status
- `loan_applications` - Loan applications with status tracking
- `loan_payments` - Payment history
- `savings_accounts` - Member savings accounts
- `notifications` - User notifications

**Security:**
- Row Level Security (RLS) policies ensure users can only access their own data
- Admin access is controlled by authenticated `app_metadata.role = 'coop_admin'` and RLS

**Business Logic:**
- Database functions for loan eligibility, approval processing, credit score updates
- Edge Functions for sensitive operations (loan approval, release, notifications)

### 2. Flutter App (Member App)

**Location:** `C:\Users\zylcee\Desktop\coop_frontend`

**Authentication:**
- Uses Supabase Auth (email/password, OTP)
- Login screen: `lib/loginscreen.dart`
- OTP verification: `lib/email_otp_verification_screen.dart`
- Sign out: `lib/profile.dart`

**Database Access:**
- Service: `lib/services/database_service.dart`
- Methods for CRUD operations on all tables
- Respects RLS policies (users see only their data)

**Screens with Database Integration:**
- Dashboard (`lib/dashboard.dart`) - Shows user profile, active loans, recent activity
- Loans Screen (`lib/loans_screen.dart`) - Shows user's loan applications
- Profile (`lib/profile.dart`) - Shows member information

**Environment:**
- `.env` file with Supabase URL and anon key
- Initialization in `lib/main.dart`

### 3. Admin Web

**Location:** `C:\Users\zylcee\Desktop\coop_frontend\coop_frontend_admin`

**Framework:** Next.js 16 with TypeScript

**Supabase Integration:**
- Client: `src/lib/supabase.ts`
- API Layer: `src/lib/api.ts`

**Access:**
- Uses the same publishable/anon key as Flutter and an authenticated admin session
- Admin queries are authorized by RLS; the service-role key is never used in the browser

**Features:**
- View all loan applications
- Approve/reject loans
- Manage members
- View reports

**Environment:**
- `.env.local` file with Supabase credentials
- See `SUPABASE_SETUP.md` for details

## Data Flow Examples

### Example 1: Member Creates Loan Application

```
1. User fills loan form in Flutter app
2. Flutter app verifies the applicant and calls `DatabaseService.submitLoanApplication()`
3. Supabase inserts into loan_applications table
4. RLS ensures the user can only see their own application
5. The signed-in admin web sees the new row through RLS and its realtime subscription
```

### Example 2: Admin Approves Loan

```
1. Admin views loan applications in admin web
2. Admin clicks "Approve"
3. Admin web calls updateLoanApplicationStatus()
4. Supabase updates loan status to "approved" after the admin role passes RLS
5. Flutter app sees the updated status on next refresh
6. Optionally: Edge function triggers notification to user
```

### Example 3: User Views Dashboard

```
1. User logs in via Flutter app
2. Supabase authenticates user
3. Flutter app fetches user's member data and loans
4. RLS ensures only user's data is returned
5. Dashboard displays user's profile and active loans
```

## Setup Instructions

### Step 1: Apply Database Migrations

Go to your Supabase dashboard SQL Editor and run these in order:

1. `supabase/migrations/001_initial_schema.sql`
2. `supabase/migrations/002_rls_policies.sql`
3. `supabase/migrations/003_database_functions.sql`
4. `supabase/migrations/004_notifications_table.sql`
5. `supabase/migrations/005_shared_admin_and_app_fields.sql`

### Step 2: Deploy Edge Functions

```bash
npm install -g supabase
supabase login
supabase link --project-ref jhgsqvxlvwhrwpcekvpq
supabase secrets set SUPABASE_URL=<your-project-url>
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=<set-this-secret-in-your-terminal>
supabase functions deploy loan-approval
supabase functions deploy loan-eligibility
supabase functions deploy loan-release
supabase functions deploy notifications
```

### Step 3: Set Up Storage Buckets

In Supabase dashboard → Storage:
- Create bucket `documents` for loan documents
- Create bucket `profile-images` for member photos
- Set RLS policies for each bucket

### Step 4: Configure Flutter App

The Flutter app is already configured with:
- `.env` file (add to `.gitignore`)
- Supabase initialization in `main.dart`
- Service classes for authentication and database operations

Run:
```bash
flutter pub get
flutter run
```

### Step 5: Configure Admin Web

Create `.env.local` in `coop_frontend_admin`:
```env
NEXT_PUBLIC_SUPABASE_URL=https://your-project.supabase.co
NEXT_PUBLIC_SUPABASE_ANON_KEY=your-publishable-or-anon-key
```

Create admin users in Supabase Auth and set their server-managed `app_metadata.role` to `coop_admin`. Ensure member Auth emails match `members.email`; migration 005 links matching accounts to member rows.

Run:
```bash
cd coop_frontend_admin
npm install
npm run dev
```

## Testing the Integration

### Test Flutter App

1. Run the Flutter app
2. Sign up/Login with email and password
3. Create a loan application
4. Check that the application appears in the dashboard
5. Sign out

### Test Admin Web

1. Run the admin web
2. Navigate to loan applications
3. You should see the loan application created from the Flutter app
4. Approve/reject the application
5. Check in Flutter app that the status updated

### Test Real-time Updates (Optional)

1. Have Flutter app open on one device
2. Have admin web open in browser
3. Update loan status in admin web
4. Refresh Flutter app to see updated status
5. (Future) Implement real-time subscriptions for instant updates

## Security Considerations

1. **Never commit secrets** - Both `.env` (Flutter) and `.env.local` (Next.js) are in `.gitignore`
2. **RLS Policies** - Ensure RLS is enabled and policies are correct
3. **Service Role Key** - Keep only in Supabase Edge Function secrets; rotate it because an old value was present in repository files
4. **Admin Access** - Add authentication to the admin web itself
5. **API Rate Limiting** - Consider rate limiting on Supabase if needed

## Troubleshooting

### Flutter App Issues

**Problem:** Authentication fails
- Check `.env` file exists and has correct credentials
- Verify Supabase Auth is enabled in dashboard
- Check network connectivity

**Problem:** No data showing
- Verify database migrations were applied
- Check RLS policies allow user access
- Check console for errors

### Admin Web Issues

**Problem:** Cannot fetch data
- Check the root `.env` or admin deployment variables are set
- Verify the publishable/anon key is correct and the admin user's `app_metadata.role` is `coop_admin`
- Check browser console for errors

**Problem:** CORS errors
- Ensure Supabase project allows your domain
- Check Supabase dashboard → Settings → API → CORS

## Remaining Work

1. Apply migration 005 and configure an admin user before using the shared database flow.
2. The loan-application workflow is connected; other admin dashboard areas and file uploads still use placeholder data or need separate integration.
3. Add persistent notification delivery and audit logging if those workflows are required.

## Support

- Supabase Documentation: https://supabase.com/docs
- Flutter Documentation: https://flutter.dev/docs
- Next.js Documentation: https://nextjs.org/docs
