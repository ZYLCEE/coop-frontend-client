# Co-maker member name lookup

The name-based lookup is deployed to the existing production project `jhgsqvxlvwhrwpcekvpq`. It uses the existing member directory and requires a signed-in member account. No production SQL migration was needed. The app continues to use its original `.env` configuration.

Staging project `cfpziuheilmaujuoiscl` was used for a temporary verification. Its synthetic accounts and Edge Functions have been removed. Migrations `001`–`011` remain applied there. The later `20261112030000_loan_submission_agreements.sql` migration remains unapplied because it references helper functions and tables not defined in the repository migrations. This does not affect the production lookup.

## Endpoint

`POST /functions/v1/co-maker-lookup`

Request body:

```json
{"name":"Juan dela Cruz"}
```

The function requires a signed-in member JWT. It derives the borrower from the JWT, requires exactly one active borrower profile, matches the entered first and last name case-insensitively, and rejects the borrower selecting themselves. Ambiguous names fail closed. It returns only the candidate's Member ID and name. An account without an active linked Auth user is treated as unavailable.

The endpoint enforces a provisional limit of 10 lookups per authenticated member per 15-minute window. It does not log request bodies, member IDs, names, or tokens. The service-role key is read only from the Edge Function environment and must never be added to the Flutter client.

Example response:

```json
{
  "candidate": {"memberId":"CSUCC-1234-5678","name":"Example Member"},
  "eligibilityStatus":"pending_policy",
  "submissionAllowed":false
}
```

## Important limitation

The cooperative's co-maker eligibility rules have not been provided. Active membership and an active Auth account are preliminary account checks, not proof of co-maker eligibility. The response deliberately marks eligibility as pending and blocks submission. Do not present a candidate as eligible or issue consent requests until an approved policy is implemented server-side.

This endpoint only looks up a possible participant. It does not persist an application or co-maker request, send notifications, record consent, or authorize submission.

## Staging prerequisites

1. Review migration `006_member_auth_and_co_maker_lookup.sql` after migrations `001`–`005` on the separate staging project.
2. Configure function JWT verification (enabled in `supabase/config.toml`) and Edge Function secrets in staging only.
3. Create two synthetic staging member/Auth accounts with distinct user IDs.
4. Get the cooperative's written co-maker eligibility rules, then replace the pending-policy response with the approved server-side decision.
5. To repeat staging verification, configure two synthetic staging members with active linked Auth users before testing name lookup.

The production Edge Function deployment changes only the lookup request from Member ID to member name. Production member records are not modified.
