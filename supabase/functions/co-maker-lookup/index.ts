import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const headers = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, apikey, content-type, x-client-info',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Max-Age': '86400',
  'Cache-Control': 'no-store',
  'Content-Type': 'application/json',
}

type JsonObject = Record<string, unknown>

const respond = (body: JsonObject, status = 200) =>
  new Response(JSON.stringify(body), { status, headers })

const unavailable = () =>
  respond({ error: 'Member lookup is temporarily unavailable. Please try again.' }, 503)

const notFound = () =>
  respond({ error: 'Member not found or unavailable.' }, 404)

function normalizeMemberId(value: unknown): string[] | null {
  if (typeof value !== 'string') return null

  const normalized = value.trim().toUpperCase()
  if (normalized.length === 0 || normalized.length > 20) return null

  const bareId = normalized.replace(/^CSUCC-/, '')
  if (!/^\d{4}-\d{4,}$/.test(bareId)) return null

  return [...new Set([normalized, bareId, `CSUCC-${bareId}`])]
}

function isActiveMemberUser(user: {
  app_metadata?: Record<string, unknown>
  banned_until?: string | null
}): boolean {
  const metadata = user.app_metadata ?? {}
  const bannedUntil = user.banned_until

  return metadata.role === 'member' &&
    (metadata.account_status === undefined || metadata.account_status === 'active') &&
    (!bannedUntil || Date.parse(bannedUntil) <= Date.now())
}

serve(async (request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers })
  if (request.method !== 'POST') return respond({ error: 'Method not allowed.' }, 405)

  const url = Deno.env.get('SUPABASE_URL')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  if (!url || !serviceKey) return unavailable()

  const token = request.headers.get('Authorization')?.match(/^Bearer\s+(.+)$/i)?.[1]
  if (!token) return respond({ error: 'Authentication required.' }, 401)

  let body: unknown
  try {
    body = await request.json()
  } catch {
    return respond({ error: 'Invalid request.' }, 400)
  }
  if (!body || typeof body !== 'object' || Array.isArray(body)) {
    return respond({ error: 'Invalid request.' }, 400)
  }

  const memberIdVariants = normalizeMemberId((body as JsonObject).member_id)
  if (!memberIdVariants) return respond({ error: 'Enter a valid Member ID.' }, 400)

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  try {
    const { data: authData, error: authError } = await admin.auth.getUser(token)
    const borrowerUser = authData.user
    if (authError || !borrowerUser) {
      return respond({ error: 'Your session expired. Please sign in again.' }, 401)
    }
    if (!isActiveMemberUser(borrowerUser)) {
      return respond({ error: 'An active member account is required.' }, 403)
    }

    const { data: borrowerRows, error: borrowerError } = await admin
      .from('members')
      .select('id, status')
      .eq('user_id', borrowerUser.id)
      .limit(2)

    if (borrowerError) return unavailable()
    if (!borrowerRows || borrowerRows.length !== 1 || borrowerRows[0].status !== 'active') {
      return respond({ error: 'Unable to verify an active member profile.' }, 403)
    }
    const borrower = borrowerRows[0]

    // Ten exact-ID lookups per authenticated member per 15-minute window.
    // This limits directory enumeration; it is not an eligibility decision.
    const { data: lookupAllowed, error: limitError } = await admin.rpc(
      'reserve_co_maker_lookup_attempt',
      { p_user_id: borrowerUser.id },
    )
    if (limitError) return unavailable()
    if (lookupAllowed !== true) {
      return respond({ error: 'Too many member lookups. Please try again in 15 minutes.' }, 429)
    }

    const { data: candidates, error: candidateError } = await admin
      .from('members')
      .select('id, user_id, member_id, first_name, last_name, status')
      .in('member_id', memberIdVariants)
      .limit(2)

    if (candidateError) return unavailable()
    if (!candidates || candidates.length === 0) return notFound()
    if (candidates.length !== 1) return unavailable()

    const candidate = candidates[0]
    if (
      candidate.id === borrower.id ||
      candidate.user_id === borrowerUser.id ||
      candidate.status !== 'active' ||
      typeof candidate.user_id !== 'string'
    ) {
      return notFound()
    }

    const { data: candidateAuthData, error: candidateAuthError } =
      await admin.auth.admin.getUserById(candidate.user_id)
    const candidateUser = candidateAuthData.user
    if (
      candidateAuthError ||
      !candidateUser ||
      !isActiveMemberUser(candidateUser)
    ) {
      return notFound()
    }

    const displayName = [candidate.first_name, candidate.last_name]
      .filter((part): part is string => typeof part === 'string' && part.trim().length > 0)
      .map((part) => part.trim())
      .join(' ')

    return respond({
      candidate: {
        memberId: candidate.member_id,
        name: displayName,
      },
      // Cooperative co-maker rules are not yet defined in this repository.
      // A client may hold this candidate in a draft, but must block submission.
      eligibilityStatus: 'pending_policy',
      submissionAllowed: false,
    })
  } catch {
    // Do not log tokens, member IDs, names, or raw database errors.
    return unavailable()
  }
})
