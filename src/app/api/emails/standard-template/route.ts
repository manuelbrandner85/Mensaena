import { NextRequest, NextResponse } from 'next/server'
import {
  buildNewFeaturesEmail,
  buildCommunityHighlightEmail,
  buildEventInviteEmail,
  buildInactivityReminderEmail,
  buildSecurityUpdateEmail,
} from '@/lib/email/templates/standard'

const builders: Record<string, (data: { unsubscribeUrl: string }) => { subject: string; html: string }> = {
  new_features: buildNewFeaturesEmail,
  community_highlight: buildCommunityHighlightEmail,
  event_invite: buildEventInviteEmail,
  inactivity_reminder: buildInactivityReminderEmail,
  security_update: buildSecurityUpdateEmail,
}

// GET /api/emails/standard-template?template=new_features
export async function GET(req: NextRequest) {
  const template = req.nextUrl.searchParams.get('template')
  if (!template || !builders[template]) {
    return NextResponse.json({
      error: 'Ungültiges Template. Verfügbar: ' + Object.keys(builders).join(', '),
    }, { status: 400 })
  }

  const { subject, html } = builders[template]({
    unsubscribeUrl: 'UNSUBSCRIBE_URL',
  })

  return NextResponse.json({ subject, html })
}
