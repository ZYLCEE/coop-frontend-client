# CSUCC loan application backend handoff

## Frontend and deployed dependencies

The Flutter module covers profile confirmation, policy-backed loan calculations, documents, summary and agreement review. With `LOAN_PARTICIPANTS_DEMO=true`, it also covers fictional participant lookup, separate simulated borrower and co-maker challenges, co-maker decline and replacement, and an informational Application Readiness screen. The demo keeps files and decisions in memory and stops before submission. A local review revision identifies the practice snapshot. Editing the draft requires a new review and clears previous confirmations. Witness, employer, notarial, and approved agreement requirements remain pending.

The existing standard build still goes from Loan Details to Documents, Summary, Terms, borrower email OTP and the existing submission. It does not enforce the proposed co-maker and witness workflow. The client reads the signed-in member profile and `loan_policy_settings`. After successful borrower OTP, it calls `DatabaseService.submitLoanApplication`. The upload service checks attachments and the active member, uploads files to `loan-documents`, then calls `submit_loan_with_documents`. It displays success after that call returns or a prior matching write is reconciled. The existing display reference and timestamp are generated on the client.

A busy flag blocks repeat taps on the OTP screen. A retry in the same screen reuses its reference and checks for an existing matching application with required attachment kinds. The client attempts cleanup after a failed write. This is limited to the observed client behavior. Deployed RPC atomicity, storage cleanup policies, and cross-device deduplication still require staging verification.

The live participant screen requires a verified active co-maker and an ID document file before continuing. The borrower uploads the document to the existing `loan-documents` bucket under their application folder. The invitation function validates the borrower-owned path and stores it on `co_maker_requests`; the accepted-request trigger copies both `co_maker_member_code` and `co_maker_id_document_path` onto `loan_applications`. The admin Consent & Witness evidence view must select those application fields and use authorized private-storage access to display the document. That admin view is not included in this Flutter client repository.

## Proposed backend contract

**Lifecycle**

Draft → Awaiting Borrower Confirmation → Awaiting Co-Maker Confirmation → Awaiting Required Attestations → Ready for Submission → Submitted for Cooperative Review.

These are proposed service states. Only an authorized server transition should assign readiness or submitted status. CRECOM and BOD activity follows handoff and is outside this contract.

| Operation | Required server behavior |
|---|---|
| Save or revise draft | Verify borrower ownership and authorized profile fields. Resolve product and New / Renewal policy, eligibility, document requirements, and approved calculator inputs. Validate uploads in private storage and retain scoped references. |
| Finalize agreement | Generate an immutable version ID and content hash over the approved template, applicant and participants, policy, amounts, and document references. Return exactly that version to both actors. Changes invalidate affected challenges, requests, and consent. |
| Select participants and issue requests | Offer authenticated lookup with minimal fields. Verify co-maker eligibility, including any approved outstanding obligation rule. Persist a single request per assignment and version after borrower confirmation. Route notification delivery through an authorized, deduplicated server job. Scope review access to the selected actor. |
| Verify and record decisions | Bind OTP to the authenticated user, role, application, version, and purpose. Enforce expiry, retry and rate limits, replay protection, and role checks. Record accept or decline with a server timestamp and audit reference. Revoke a declined or replaced request and its access. A replacement receives a new request and supplies their own decision. |
| Verify required formalities | Accept employer certification only from authorized personnel or an approved source. Store witness evidence according to the approved procedure. Track notarial acknowledgment separately, including applicability and evidence. OTP alone does not establish that a witness observed a signing or that notarization occurred. |
| Submit and hand off | Recheck ownership, eligibility, authoritative policy, document completeness, version and hash, borrower and co-maker decisions, and all applicable formalities. Atomically transition once using a server-enforced idempotency key and uniqueness constraint. Return the committed server reference, timestamp, version, and status. Repeated requests after a lost response should return the same receipt. Keep files referenced by committed submissions and reconcile orphaned uploads. |

Use row-level security and private storage policies for draft and document access. Validate state transitions and actor identity at the server boundary. Keep OTP secrets server-side and avoid logging codes, document contents, or unnecessary member data. Prevent alternative database write paths from bypassing readiness.

## Policy differences to resolve

- Documents and Summary use the configured `collateral_required_above`. The legacy upload precheck requires collateral strictly above ₱200,000. Retry reconciliation reads the configured threshold again. At exactly ₱200,000, the fixed rule permits a submission without collateral. A higher or lower configured threshold can disagree with the fixed rule. Return one server-authoritative document requirement set and policy version for the application, then reuse it for selection, review, retries, and submission.
- The calculator uses configured interest and service-fee inputs. The existing Terms state 2% monthly interest and a 1% service fee. The approved template and financial policy must agree before issuing a consent challenge.
- The mobile product catalog and the paper categories need an approved mapping. New / Renewal is currently draft-only and needs a persistence and validation contract. Confirm how employment details and the Promissory Note are supplied and validated.

## Integration order and cooperative decisions

1. Confirm the product mapping, fee and collateral policy, approved digital agreement and Promissory Note, and whether OTP is accepted for borrower and co-maker consent.
2. Confirm co-maker eligibility, witness eligibility and identity requirements, whether remote witnessing is acceptable, what witnesses must observe, and how evidence is recorded. Confirm the employer certifier and when certification and notarization apply.
3. Implement and verify policy, private documents, immutable agreements, authorized participant lookup, and scoped access in staging.
4. Implement authenticated challenges, decisions, audit records, replacement and invalidation, notifications, and approved formality checks.
5. Prove readiness and idempotent submission in staging, including concurrent requests and lost responses. Enable the revised live flow only after cooperative approval and end-to-end verification.
