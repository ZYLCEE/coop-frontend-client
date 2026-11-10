# Finalized borrower UI handoff

The normal app offers Review Updated Application after profile confirmation. This creates a separate session-only draft. The existing Use Existing Application button keeps the legacy borrower-only route. A demo build continues to use the isolated fictional participants, inbox, and OTP routes.

| Screen | Future authorized contract |
|---|---|
| Profile and Loan Details | Resolve the signed-in member. Provide eligibility, approved versioned policy, product mapping, and authoritative calculations. |
| Participants | Provide minimal authorized co-maker lookup and eligibility. Define permitted witness data and verification separately. |
| Documents | Provide approved document requirements and scoped private upload references. Validate type, size and ownership on the server. |
| Agreement Preview | Return one immutable server-issued agreement version with approved wording, amounts, parties and permitted file references. |
| Co-maker inbox and review | Adapt an authenticated recipient-scoped request to the existing notification card, agreement preview and acknowledgment layout. Verify ownership, revision and request status before exposing review or decisions. |
| Readiness and submission | Return server-evaluated requirements, separately recorded consent and formalities, and a committed receipt after an atomic idempotent submit. |

The local checklist grants no submission authority. Readiness opens on a separate route and returns to the same captured agreement. Exiting the updated review clears its session draft. The preview has no OTP, upload or submit action, and keeps selections only in memory. Its document UI uses the existing configured threshold provisionally. See the loan application and co-maker handoffs for policy conflicts, access rules and the deployment checks still needed for the legacy path. The legacy path remains borrower-only. Verify the deployed RPC and grants for direct-write bypasses, agreement-bound consent enforcement, private storage access, and safe retries before connecting the updated flow.
