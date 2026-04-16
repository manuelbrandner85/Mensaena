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

// ── Pinterest ───────────────────────────────────────────────────
export async function publishToPinterest(
  channel: ChannelConfig,
  content: string,
  imageUrl?: string,
): Promise<PublishResult> {
  const token = channel.access_token
  const boardId = channel.page_id
  if (!token || !boardId) return { ok: false, error: 'Access Token oder Board ID fehlt' }
  if (!imageUrl) return { ok: false, error: 'Pinterest erfordert ein Bild für Pins' }

  try {
    const res = await fetch('https://api.pinterest.com/v5/pins', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        board_id: boardId,
        title: content.slice(0, 100),
        description: content,
        media_source: { source_type: 'image_url', url: imageUrl },
        link: 'https://www.mensaena.de',
      }),
    })
    const data = await res.json() as { id?: string; message?: string }
    if (!res.ok) return { ok: false, error: data.message || `HTTP ${res.status}` }
    return { ok: true, platformPostId: data.id }
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) }
  }
}

// ── TikTok ──────────────────────────────────────────────────────
export async function publishToTikTok(
  channel: ChannelConfig,
  content: string,
): Promise<PublishResult> {
  const token = channel.access_token
  if (!token) return { ok: false, error: 'Access Token fehlt' }

  try {
    // TikTok Content Posting API — erstellt einen Text-Post
    const res = await fetch('https://open.tiktokapis.com/v2/post/publish/content/init/', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        post_info: { title: content.slice(0, 150), privacy_level: 'PUBLIC_TO_EVERYONE' },
        source_info: { source: 'PULL_FROM_URL' },
      }),
    })
    const data = await res.json() as { data?: { publish_id?: string }; error?: { message?: string } }
    if (!res.ok || data.error) return { ok: false, error: data.error?.message || `HTTP ${res.status}` }
    return { ok: true, platformPostId: data.data?.publish_id }
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) }
  }
}

// ── Threads (Meta) ──────────────────────────────────────────────
export async function publishToThreads(
  channel: ChannelConfig,
  content: string,
): Promise<PublishResult> {
  const token = channel.access_token
  const userId = channel.page_id
  if (!token || !userId) return { ok: false, error: 'Access Token oder User ID fehlt' }

  try {
    // Schritt 1: Container erstellen
    const createRes = await fetch(
      `https://graph.threads.net/v1.0/${userId}/threads`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ media_type: 'TEXT', text: content, access_token: token }),
      },
    )
    const createData = await createRes.json() as { id?: string; error?: { message?: string } }
    if (!createRes.ok || createData.error) return { ok: false, error: createData.error?.message || `HTTP ${createRes.status}` }

    // Schritt 2: Veröffentlichen
    const publishRes = await fetch(
      `https://graph.threads.net/v1.0/${userId}/threads_publish`,
      {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ creation_id: createData.id, access_token: token }),
      },
    )
    const pubData = await publishRes.json() as { id?: string; error?: { message?: string } }
    if (!publishRes.ok || pubData.error) return { ok: false, error: pubData.error?.message || `HTTP ${publishRes.status}` }
    return { ok: true, platformPostId: pubData.id }
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) }
  }
}

// ── Mastodon ────────────────────────────────────────────────────
export async function publishToMastodon(
  channel: ChannelConfig,
  content: string,
): Promise<PublishResult> {
  const token = channel.access_token
  const instance = (channel.config as Record<string, string>)?.instance || channel.page_id || 'mastodon.social'
  if (!token) return { ok: false, error: 'Access Token fehlt' }

  try {
    const baseUrl = instance.startsWith('http') ? instance : `https://${instance}`
    const res = await fetch(`${baseUrl}/api/v1/statuses`, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: content, visibility: 'public' }),
    })
    const data = await res.json() as { id?: string; error?: string }
    if (!res.ok) return { ok: false, error: data.error || `HTTP ${res.status}` }
    return { ok: true, platformPostId: data.id }
  } catch (err) {
    return { ok: false, error: err instanceof Error ? err.message : String(err) }
  }
}

// ── Telegram ────────────────────────────────────────────────────
export async function publishToTelegram(
  channel: ChannelConfig,
  content: string,
): Promise<PublishResult> {
  const botToken = channel.access_token
  const chatId = channel.page_id // @channel_name oder -100xxxxx
  if (!botToken || !chatId) return { ok: false, error: 'Bot Token oder Channel ID fehlt' }

  try {
    const res = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        chat_id: chatId,
        text: content,
        parse_mode: 'HTML',
        disable_web_page_preview: false,
      }),
    })
    const data = await res.json() as { ok?: boolean; result?: { message_id?: number }; description?: string }
    if (!data.ok) return { ok: false, error: data.description || 'Telegram-Fehler' }
    return { ok: true, platformPostId: String(data.result?.message_id) }
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
    case 'pinterest': return publishToPinterest(channel, content, imageUrl)
    case 'tiktok':    return publishToTikTok(channel, content)
    case 'threads':   return publishToThreads(channel, content)
    case 'mastodon':  return publishToMastodon(channel, content)
    case 'telegram':  return publishToTelegram(channel, content)
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
    case 'pinterest': {
      if (!channel.access_token) return { ok: false, error: 'Token fehlt' }
      const res = await fetch('https://api.pinterest.com/v5/user_account', {
        headers: { 'Authorization': `Bearer ${channel.access_token}` },
      })
      const data = await res.json() as { username?: string; message?: string }
      if (!res.ok) return { ok: false, error: data.message || `HTTP ${res.status}` }
      return { ok: true, platformPostId: data.username }
    }
    case 'tiktok': {
      if (!channel.access_token) return { ok: false, error: 'Token fehlt' }
      const res = await fetch('https://open.tiktokapis.com/v2/user/info/?fields=display_name', {
        headers: { 'Authorization': `Bearer ${channel.access_token}` },
      })
      if (!res.ok) return { ok: false, error: `HTTP ${res.status}` }
      return { ok: true }
    }
    case 'threads': {
      if (!channel.access_token || !channel.page_id) return { ok: false, error: 'Token oder User ID fehlt' }
      const res = await fetch(`https://graph.threads.net/v1.0/${channel.page_id}?fields=username&access_token=${channel.access_token}`)
      const data = await res.json() as { username?: string; error?: { message?: string } }
      if (data.error) return { ok: false, error: data.error.message }
      return { ok: true, platformPostId: data.username }
    }
    case 'mastodon': {
      if (!channel.access_token) return { ok: false, error: 'Token fehlt' }
      const instance = (channel.config as Record<string, string>)?.instance || channel.page_id || 'mastodon.social'
      const baseUrl = instance.startsWith('http') ? instance : `https://${instance}`
      const res = await fetch(`${baseUrl}/api/v1/accounts/verify_credentials`, {
        headers: { 'Authorization': `Bearer ${channel.access_token}` },
      })
      const data = await res.json() as { username?: string; error?: string }
      if (!res.ok) return { ok: false, error: data.error || `HTTP ${res.status}` }
      return { ok: true, platformPostId: `@${data.username}@${instance}` }
    }
    case 'telegram': {
      if (!channel.access_token) return { ok: false, error: 'Bot Token fehlt' }
      const res = await fetch(`https://api.telegram.org/bot${channel.access_token}/getMe`)
      const data = await res.json() as { ok?: boolean; result?: { username?: string }; description?: string }
      if (!data.ok) return { ok: false, error: data.description || 'Ungültiger Bot Token' }
      return { ok: true, platformPostId: `@${data.result?.username}` }
    }
    default:
      return { ok: false, error: 'Unbekannte Plattform' }
  }
}
