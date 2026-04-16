// ============================================================
// Social Media Platform Publishers
// Jede Plattform hat eine publish()-Funktion
// ============================================================

export interface PublishResult {
  ok: boolean
  platformPostId?: string
  error?: string
}

interface ChannelConfig {
  platform: string
  access_token?: string | null
  api_key?: string | null
  api_secret?: string | null
  page_id?: string | null
  config?: Record<string, unknown>
}

// ── Facebook ────────────────────────────────────────────────────
export async function publishToFacebook(
  channel: ChannelConfig,
  content: string,
): Promise<PublishResult> {
  const pageId = channel.page_id
  const token = channel.access_token
  if (!pageId || !token) {
    return { ok: false, error: 'Page ID oder Access Token fehlt' }
  }

  try {
    const res = await fetch(
      `https://graph.facebook.com/v19.0/${pageId}/feed`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: content,
          access_token: token,
        }),
      },
    )
    const data = await res.json() as { id?: string; error?: { message?: string } }
    if (!res.ok || data.error) {
      return { ok: false, error: data.error?.message || `HTTP ${res.status}` }
    }
    return { ok: true, platformPostId: data.id }
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) }
  }
}

// ── Instagram ───────────────────────────────────────────────────
// Instagram Graph API erfordert 2 Schritte:
// 1. Media-Container erstellen
// 2. Container veröffentlichen
// Für reine Text-Posts (Carousel/Reels) braucht man ein Bild.
// Wir posten als Text-only Story oder überspringen wenn kein Bild.
export async function publishToInstagram(
  channel: ChannelConfig,
  content: string,
  imageUrl?: string,
): Promise<PublishResult> {
  const pageId = channel.page_id // Instagram Business Account ID
  const token = channel.access_token
  if (!pageId || !token) {
    return { ok: false, error: 'Instagram Account ID oder Access Token fehlt' }
  }

  if (!imageUrl) {
    return { ok: false, error: 'Instagram erfordert ein Bild für Posts. Bitte füge eine Bild-URL hinzu.' }
  }

  try {
    // Schritt 1: Media-Container erstellen
    const createRes = await fetch(
      `https://graph.facebook.com/v19.0/${pageId}/media`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          image_url: imageUrl,
          caption: content,
          access_token: token,
        }),
      },
    )
    const createData = await createRes.json() as { id?: string; error?: { message?: string } }
    if (!createRes.ok || createData.error) {
      return { ok: false, error: createData.error?.message || `HTTP ${createRes.status}` }
    }

    // Schritt 2: Veröffentlichen
    const publishRes = await fetch(
      `https://graph.facebook.com/v19.0/${pageId}/media_publish`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          creation_id: createData.id,
          access_token: token,
        }),
      },
    )
    const publishData = await publishRes.json() as { id?: string; error?: { message?: string } }
    if (!publishRes.ok || publishData.error) {
      return { ok: false, error: publishData.error?.message || `HTTP ${publishRes.status}` }
    }
    return { ok: true, platformPostId: publishData.id }
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) }
  }
}

// ── X / Twitter ─────────────────────────────────────────────────
export async function publishToX(
  channel: ChannelConfig,
  content: string,
): Promise<PublishResult> {
  const token = channel.access_token // OAuth 2.0 Bearer Token
  if (!token) {
    return { ok: false, error: 'X Bearer Token fehlt' }
  }

  // Text auf 280 Zeichen kürzen
  const text = content.length > 280 ? content.slice(0, 277) + '...' : content

  try {
    const res = await fetch('https://api.twitter.com/2/tweets', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ text }),
    })
    const data = await res.json() as { data?: { id?: string }; errors?: Array<{ message?: string }> }
    if (!res.ok || data.errors?.length) {
      return { ok: false, error: data.errors?.[0]?.message || `HTTP ${res.status}` }
    }
    return { ok: true, platformPostId: data.data?.id }
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) }
  }
}

// ── LinkedIn ────────────────────────────────────────────────────
export async function publishToLinkedIn(
  channel: ChannelConfig,
  content: string,
): Promise<PublishResult> {
  const token = channel.access_token
  const orgId = channel.page_id // LinkedIn Organization URN
  if (!token || !orgId) {
    return { ok: false, error: 'LinkedIn Access Token oder Organization ID fehlt' }
  }

  const urn = orgId.startsWith('urn:') ? orgId : `urn:li:organization:${orgId}`

  try {
    const res = await fetch('https://api.linkedin.com/v2/ugcPosts', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${token}`,
        'Content-Type': 'application/json',
        'X-Restli-Protocol-Version': '2.0.0',
      },
      body: JSON.stringify({
        author: urn,
        lifecycleState: 'PUBLISHED',
        specificContent: {
          'com.linkedin.ugc.ShareContent': {
            shareCommentary: { text: content },
            shareMediaCategory: 'NONE',
          },
        },
        visibility: { 'com.linkedin.ugc.MemberNetworkVisibility': 'PUBLIC' },
      }),
    })
    const data = await res.json() as { id?: string; message?: string }
    if (!res.ok) {
      return { ok: false, error: data.message || `HTTP ${res.status}` }
    }
    return { ok: true, platformPostId: data.id }
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) }
  }
}

// ── Dispatcher ──────────────────────────────────────────────────
export async function publishToChannel(
  channel: ChannelConfig,
  content: string,
  imageUrl?: string,
): Promise<PublishResult> {
  switch (channel.platform) {
    case 'facebook':  return publishToFacebook(channel, content)
    case 'instagram': return publishToInstagram(channel, content, imageUrl)
    case 'x':         return publishToX(channel, content)
    case 'linkedin':  return publishToLinkedIn(channel, content)
    default:          return { ok: false, error: `Unbekannte Plattform: ${channel.platform}` }
  }
}

// ── Token-Verifikation ──────────────────────────────────────────
export async function verifyChannel(channel: ChannelConfig): Promise<PublishResult> {
  switch (channel.platform) {
    case 'facebook': {
      if (!channel.access_token) return { ok: false, error: 'Token fehlt' }
      const res = await fetch(`https://graph.facebook.com/v19.0/me?access_token=${channel.access_token}`)
      const data = await res.json() as { name?: string; error?: { message?: string } }
      if (data.error) return { ok: false, error: data.error.message }
      return { ok: true, platformPostId: data.name }
    }
    case 'instagram': {
      if (!channel.access_token || !channel.page_id) return { ok: false, error: 'Token oder Account ID fehlt' }
      const res = await fetch(`https://graph.facebook.com/v19.0/${channel.page_id}?fields=name,username&access_token=${channel.access_token}`)
      const data = await res.json() as { username?: string; error?: { message?: string } }
      if (data.error) return { ok: false, error: data.error.message }
      return { ok: true, platformPostId: data.username }
    }
    case 'x': {
      if (!channel.access_token) return { ok: false, error: 'Token fehlt' }
      const res = await fetch('https://api.twitter.com/2/users/me', {
        headers: { 'Authorization': `Bearer ${channel.access_token}` },
      })
      const data = await res.json() as { data?: { username?: string }; errors?: Array<{ message?: string }> }
      if (data.errors?.length) return { ok: false, error: data.errors[0].message }
      return { ok: true, platformPostId: data.data?.username }
    }
    case 'linkedin': {
      if (!channel.access_token) return { ok: false, error: 'Token fehlt' }
      const res = await fetch('https://api.linkedin.com/v2/me', {
        headers: { 'Authorization': `Bearer ${channel.access_token}` },
      })
      if (!res.ok) return { ok: false, error: `HTTP ${res.status}` }
      return { ok: true }
    }
    default:
      return { ok: false, error: 'Unbekannte Plattform' }
  }
}
