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
type MemberRow = {
  id: string
  user_id: string | null
  member_id: string
  first_name: string | null
  last_name: string | null
  status: string
}

const respond = (body: JsonObject, status = 200) =>
  new Response(JSON.stringify(body), { status, headers })

const unavailable = () =>
  respond({ error: 'Co-maker invitation is temporarily unavailable. Please try again.' }, 503)

function activeMemberUser(user: {
  app_metadata?: Record<string, unknown>
  banned_until?: string | null
}): boolean {
  const metadata = user.app_metadata ?? {}
  return metadata.role === 'member' &&
    (metadata.account_status === undefined || metadata.account_status === 'active') &&
    (!user.banned_until || Date.parse(user.banned_until) <= Date.now())
}

function normalizedMemberIds(value: unknown): string[] | null {
  if (typeof value !== 'string') return null
  const normalized = value.trim().toUpperCase()
  if (normalized.length === 0 || normalized.length > 20) return null
  const bare = normalized.replace(/^CSUCC-/, '')
  if (!/^\d{4}-\d{4,}$/.test(bare)) return null
  return [...new Set([normalized, bare, `CSUCC-${bare}`])]
}

function displayName(member: MemberRow): string {
  return [member.first_name, member.last_name]
    .filter((part): part is string => typeof part === 'string' && part.trim().length > 0)
    .map((part) => part.trim())
    .join(' ')
}

function escapeHtml(value: string): string {
  const replacements: Record<string, string> = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#39;',
  }
  return value.replace(/[&<>"']/g, (character) => replacements[character] ?? character)
}

async function sendNotificationEmail(
  email: string | null | undefined,
  title: string,
  message: string,
  idempotencyKey: string,
): Promise<boolean> {
  const apiKey = Deno.env.get('RESEND_API_KEY')
  const sender = Deno.env.get('COOP_EMAIL_FROM')
  if (!apiKey || !sender || !email) return false

  try {
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'Idempotency-Key': idempotencyKey,
      },
      body: JSON.stringify({
        from: sender,
        to: [email],
        subject: title,
        text: `${message}\n\nOpen CSUCC ERMPC and go to Notifications to review or respond. Email delivery does not accept or decline the invitation.`,
        html: `<div style="font-family:Arial,sans-serif;max-width:600px;margin:auto;color:#183a24"><h2>${escapeHtml(title)}</h2><p>${escapeHtml(message).replace(/\n/g, '<br>')}</p><p>Open CSUCC ERMPC and go to Notifications to review or respond. Email delivery does not accept or decline the invitation.</p></div>`,
      }),
    })
    return response.ok
  } catch {
    return false
  }
}

function numeric(value: unknown, min = 0, max = 1_000_000_000): number | null {
  const parsed = typeof value === 'number' ? value : Number(value)
  if (!Number.isFinite(parsed) || parsed < min || parsed > max) return null
  return Math.round(parsed * 100) / 100
}

async function readActor(admin: ReturnType<typeof createClient>, token: string) {
  const { data, error } = await admin.auth.getUser(token)
  if (error || !data.user || !activeMemberUser(data.user)) return null
  const { data: rows, error: memberError } = await admin
    .from('members')
    .select('id, user_id, member_id, first_name, last_name, status')
    .eq('user_id', data.user.id)
    .limit(2)
  if (memberError || !rows || rows.length !== 1 || rows[0].status !== 'active') return null
  return { user: data.user, member: rows[0] as MemberRow }
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

  const admin = createClient(url, serviceKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  })

  try {
    const actor = await readActor(admin, token)
    if (!actor) return respond({ error: 'An active member account is required.' }, 403)
    const input = body as JsonObject
    const action = input.action

    if (action === 'create') {
      const applicationId = typeof input.application_id === 'string' ? input.application_id.trim() : ''
      const variants = normalizedMemberIds(input.co_maker_member_id)
      const relationship = typeof input.relationship === 'string' ? input.relationship.trim() : ''
      const loanType = typeof input.loan_type === 'string'
        ? input.loan_type.trim().replace(/\s+Loan$/i, '')
        : ''
      const tenure = Number(input.tenure_months)
      const amount = numeric(input.amount, 0.01)
      const details = input.loan_details
      const allowedLoanTypes = new Set([
        'Regular', 'Medical', 'Educational', 'Emergency', 'Business', 'Calamity',
        'Multi-Purpose', 'Quick', 'Livelihood', 'Appliance', 'Birthday',
        'Anniversary', 'Fiesta', 'Bonus', 'Collateral', 'Mortuary', 'Subsistence', 'ASSME',
      ])
      if (!/^LA-\d{4}-\d{6}$/.test(applicationId) || !variants ||
          relationship.length < 1 || relationship.length > 100 ||
          !allowedLoanTypes.has(loanType) || amount === null ||
          !Number.isInteger(tenure) || tenure < 1 || tenure > 360 ||
          !details || typeof details !== 'object' || Array.isArray(details)) {
        return respond({ error: 'Complete the loan and co-maker details before inviting.' }, 400)
      }

      const { data: existing, error: existingError } = await admin
        .from('co_maker_requests')
        .select('id, status, borrower_user_id, co_maker_member_id, loan_type, amount, tenure_months')
        .eq('application_id', applicationId)
        .maybeSingle()
      if (existingError) return unavailable()
      if (existing) {
        const { data: linkedMembers, error: linkedMemberError } = await admin
          .from('members')
          .select('id')
          .in('member_id', variants)
          .limit(2)
        if (existing.borrower_user_id !== actor.user.id ||
            linkedMemberError || !linkedMembers || linkedMembers.length !== 1 ||
            linkedMembers[0].id !== existing.co_maker_member_id ||
            existing.loan_type !== loanType || Number(existing.amount) !== amount ||
            existing.tenure_months !== tenure) {
          return respond({ error: 'This application reference is already in use.' }, 409)
        }
        return respond({ request_id: existing.id, status: existing.status })
      }

      const { data: allowed, error: limitError } = await admin.rpc(
        'reserve_co_maker_lookup_attempt',
        { p_user_id: actor.user.id },
      )
      if (limitError) return unavailable()
      if (allowed !== true) return respond({ error: 'Too many invitations. Please wait 15 minutes.' }, 429)

      const { data: candidates, error: candidateError } = await admin
        .from('members')
        .select('id, user_id, member_id, first_name, last_name, status')
        .in('member_id', variants)
        .limit(2)
      if (candidateError || !candidates || candidates.length !== 1) {
        return candidateError ? unavailable() : respond({ error: 'Active co-maker member not found.' }, 404)
      }
      const candidate = candidates[0] as MemberRow
      if (candidate.id === actor.member.id || candidate.user_id === actor.user.id ||
          candidate.status !== 'active' || !candidate.user_id) {
        return respond({ error: 'Choose a different active member as co-maker.' }, 400)
      }
      const { data: candidateAuth, error: candidateAuthError } =
        await admin.auth.admin.getUserById(candidate.user_id)
      if (candidateAuthError || !candidateAuth.user || !activeMemberUser(candidateAuth.user)) {
        return respond({ error: 'Active co-maker member not found.' }, 404)
      }

      const borrowerName = displayName(actor.member)
      const coMakerName = displayName(candidate)
      const { data: created, error: createError } = await admin
        .from('co_maker_requests')
        .insert({
          application_id: applicationId,
          borrower_user_id: actor.user.id,
          borrower_member_id: actor.member.id,
          co_maker_member_id: candidate.id,
          co_maker_user_id: candidate.user_id,
          borrower_name: borrowerName,
          co_maker_name: coMakerName,
          relationship,
          loan_type: loanType,
          amount,
          tenure_months: tenure,
          loan_details: details,
        })
        .select('id, status')
        .single()
      if (createError || !created) return unavailable()

      const requestId = created.id as string
      const loanLabel = `${loanType} Loan`
      const amountLabel = `PHP ${amount.toFixed(2)}`
      const detailsText = [
        `Borrower: ${borrowerName}`,
        `Loan: ${loanLabel}`,
        `Requested amount: ${amountLabel}`,
        `Repayment term: ${tenure} months`,
        `Relationship: ${relationship}`,
        `Monthly amortization: ${String((details as JsonObject).monthly_amortization ?? 'Pending calculation')}`,
        `Interest rate: ${String((details as JsonObject).interest_rate ?? 'Pending confirmation')}`,
        `Processing fee: ${String((details as JsonObject).processing_fee ?? 'Pending confirmation')}`,
        `Notarial fee: ${String((details as JsonObject).notarial_fee ?? 'Pending confirmation')}`,
        `Retention fee: ${String((details as JsonObject).retention_fee ?? 'Pending confirmation')}`,
        `Estimated net take-home: ${String((details as JsonObject).net_take_home ?? 'Pending calculation')}`,
        '',
        'Review the proposed terms carefully. Accepting confirms your consent to be recorded as co-maker for this application; the cooperative still reviews the loan.',
        'To respond, open CSUCC ERMPC, go to Notifications, and review this invitation. Acceptance or rejection must be completed in the app.',
      ].join('\n')
      const payload = { request_id: requestId }
      const notificationTitle = `You are invited to be a Co-Maker of ${borrowerName} for the ${loanLabel}.`
      const { error: notifyError } = await admin.from('notifications').insert({
        user_id: candidate.user_id,
        title: notificationTitle,
        message: detailsText,
        type: 'co_maker_invitation',
        data: payload,
      })
      if (notifyError) {
        await admin.from('notifications').delete().contains('data', payload)
        await admin.from('co_maker_requests').delete().eq('id', requestId)
        return unavailable()
      }

      const emailSent = await sendNotificationEmail(
        candidateAuth.user.email,
        notificationTitle,
        detailsText,
        `co-maker-invitation/${requestId}`,
      )
      return respond({ request_id: requestId, status: created.status, email_sent: emailSent })
    }

    const requestId = typeof input.request_id === 'string' ? input.request_id : ''
    if (!/^[0-9a-f-]{36}$/i.test(requestId)) return respond({ error: 'Invalid invitation.' }, 400)
    const { data: invite, error: inviteError } = await admin
      .from('co_maker_requests')
      .select('*')
      .eq('id', requestId)
      .maybeSingle()
    if (inviteError || !invite) return respond({ error: 'Invitation not found.' }, 404)

    if (action === 'reject') {
      if (invite.co_maker_user_id !== actor.user.id) return respond({ error: 'Invitation not found.' }, 404)
      if (!['pending', 'otp_pending'].includes(invite.status)) {
        return respond({ error: 'This invitation has already been answered.' }, 409)
      }
      const { data: updated, error: updateError } = await admin
        .from('co_maker_requests')
        .update({ status: 'rejected', rejected_at: new Date().toISOString(), updated_at: new Date().toISOString() })
        .eq('id', requestId)
        .in('status', ['pending', 'otp_pending'])
        .select('id')
        .maybeSingle()
      if (updateError || !updated) return respond({ error: 'This invitation has already been answered.' }, 409)
      const { error: notifyError } = await admin.from('notifications').insert({
        user_id: invite.borrower_user_id,
        title: `${invite.co_maker_name} declined the co-maker invitation.`,
        message: `Your ${invite.loan_type} Loan request for ${invite.borrower_name} was declined. You can choose another co-maker.`,
        type: 'co_maker_response',
        data: { request_id: requestId, status: 'rejected' },
      })
      if (notifyError) console.error('Could not create borrower response notification.')
      const { data: borrowerAuth } = await admin.auth.admin.getUserById(invite.borrower_user_id)
      const emailSent = await sendNotificationEmail(
        borrowerAuth.user?.email,
        `${invite.co_maker_name} declined the co-maker invitation.`,
        `Your ${invite.loan_type} Loan invitation for ${invite.borrower_name} was declined. You can choose another co-maker.`,
        `co-maker-response/${requestId}/rejected`,
      )
      return respond({ status: 'rejected', email_sent: emailSent })
    }

    if (action === 'begin_accept') {
      if (invite.co_maker_user_id !== actor.user.id) return respond({ error: 'Invitation not found.' }, 404)
      if (!['pending', 'otp_pending'].includes(invite.status)) {
        return respond({ error: 'This invitation has already been answered.' }, 409)
      }
      const requestedAt = new Date().toISOString()
      const { error: updateError } = await admin
        .from('co_maker_requests')
        .update({ status: 'otp_pending', otp_requested_at: requestedAt, updated_at: requestedAt })
        .eq('id', requestId)
        .in('status', ['pending', 'otp_pending'])
      if (updateError) return unavailable()
      return respond({ status: 'otp_pending' })
    }

    if (action === 'confirm_accept') {
      if (invite.co_maker_user_id !== actor.user.id) return respond({ error: 'Invitation not found.' }, 404)
      if (invite.status === 'accepted') return respond({ status: 'accepted' })
      if (invite.status !== 'otp_pending' || !invite.otp_requested_at) {
        return respond({ error: 'Request an email verification code before accepting.' }, 409)
      }
      const { data: currentAuth, error: currentAuthError } =
        await admin.auth.admin.getUserById(actor.user.id)
      const lastSignIn = currentAuth.user?.last_sign_in_at
        ? Date.parse(currentAuth.user.last_sign_in_at)
        : Number.NaN
      const otpRequestedAt = Date.parse(invite.otp_requested_at)
      if (currentAuthError || !Number.isFinite(lastSignIn) ||
          !Number.isFinite(otpRequestedAt) || lastSignIn < otpRequestedAt - 1_000) {
        return respond({ error: 'Verify the code sent to your registered email before accepting.' }, 403)
      }
      const acceptedAt = new Date().toISOString()
      const { data: updated, error: updateError } = await admin
        .from('co_maker_requests')
        .update({ status: 'accepted', accepted_at: acceptedAt, updated_at: acceptedAt })
        .eq('id', requestId)
        .eq('status', 'otp_pending')
        .select('id')
        .maybeSingle()
      if (updateError || !updated) return respond({ error: 'This invitation has already been answered.' }, 409)
      const { error: notifyError } = await admin.from('notifications').insert({
        user_id: invite.borrower_user_id,
        title: `${invite.co_maker_name} accepted the co-maker invitation.`,
        message: `${invite.co_maker_name} verified their email and accepted the ${invite.loan_type} Loan co-maker invitation. The loan is still subject to cooperative review.`,
        type: 'co_maker_response',
        data: { request_id: requestId, status: 'accepted' },
      })
      if (notifyError) console.error('Could not create borrower response notification.')
      const { data: borrowerAuth } = await admin.auth.admin.getUserById(invite.borrower_user_id)
      const responseTitle = `${invite.co_maker_name} accepted the co-maker invitation.`
      const responseMessage = `${invite.co_maker_name} verified their email and accepted the ${invite.loan_type} Loan co-maker invitation. The loan is still subject to cooperative review.`
      const emailSent = await sendNotificationEmail(
        borrowerAuth.user?.email,
        responseTitle,
        responseMessage,
        `co-maker-response/${requestId}/accepted`,
      )
      return respond({ status: 'accepted', email_sent: emailSent })
    }

    return respond({ error: 'Unsupported action.' }, 400)
  } catch {
    // Never log tokens, member IDs, names, loan details, or raw database errors.
    return unavailable()
  }
})
