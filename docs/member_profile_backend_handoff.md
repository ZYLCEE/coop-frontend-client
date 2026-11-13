# Read-only member Profile backend handoff

The mobile Profile displays the signed-in member record and directs members to the CSUCC cooperative office for corrections. The frontend removed its member self-update action.

The repository's Supabase migration 002 allows updates to a member's own row through an RLS policy. Where authenticated users also have UPDATE privileges, a member can still send a direct update to the members API. Migration 005 adds a separate cooperative admin update policy. That policy does not revoke the earlier self-update policy. Repository inspection found no separate member profile update Edge Function. The deployed grants and policies have not been verified.

The backend team should verify deployed grants, policies, and API routes, then restrict protected profile writes to authorized cooperative staff under CSUCC's approved workflow. Keep members' own-record read access and verify on staging that a direct write by an ordinary member is rejected while authorized staff can make approved corrections.
