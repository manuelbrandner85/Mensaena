'use client'

import { create } from 'zustand'
import { createClient } from '@/lib/supabase/client'
import toast from 'react-hot-toast'
import type {
  Interaction, InteractionUpdate, InteractionFilter,
  InteractionStats, InteractionCounts, CreateInteractionInput,
  InteractionStatus,
} from '../types'

// ── Helpers to map RPC rows → typed Interaction ─────────────────────
function mapRow(row: any): Interaction {
  return {
    id: row.id,
    post_id: row.post_id,
    match_id: row.match_id,
    helper_id: row.helper_id,
    helped_id: row.helped_id,
    status: row.status as InteractionStatus,
    message: row.message,
    response_message: row.response_message,
    cancel_reason: row.cancel_reason,
    completed_at: row.completed_at,
    completed_by: row.completed_by,
    completion_notes: row.completion_notes,
    helper_rated: row.helper_rated ?? false,
    helped_rated: row.helped_rated ?? false,
    rating_requested: row.rating_requested ?? false,
    conversation_id: row.conversation_id,
    created_at: row.created_at,
    updated_at: row.updated_at,
    post: row.post_title ? { id: row.post_id, title: row.post_title, category: row.post_category, type: row.post_type } : null,
    partner: {
      id: row.partner_id,
      name: row.partner_name,
      avatar_url: row.partner_avatar_url,
      trust_score: row.partner_trust_score,
      trust_count: row.partner_trust_count,
    },
    myRole: row.my_role as 'helper' | 'helped',
    match_score: row.match_score,
  }
}

// ── Store interface ─────────────────────────────────────────────────
interface InteractionState {
  interactions: Interaction[]
  currentInteraction: Interaction | null
  interactionUpdates: InteractionUpdate[]
  stats: InteractionStats | null
  counts: InteractionCounts | null
  loading: boolean
  detailLoading: boolean
  updatesLoading: boolean
  filter: InteractionFilter
  hasMore: boolean

  setFilter: (f: Partial<InteractionFilter>) => void
  loadInteractions: (filter?: InteractionFilter) => Promise<void>
  loadMore: () => Promise<void>
  loadInteractionById: (id: string) => Promise<void>
  loadInteractionUpdates: (id: string) => Promise<void>
  loadStats: () => Promise<void>
  loadCounts: () => Promise<void>
  createInteraction: (input: CreateInteractionInput) => Promise<string | null>
  respondToInteraction: (id: string, accept: boolean, responseMessage?: string) => Promise<void>
  startProgress: (id: string) => Promise<void>
  completeInteraction: (id: string, completionNotes?: string) => Promise<void>
  cancelInteraction: (id: string, reason?: string) => Promise<void>
  disputeInteraction: (id: string, reason: string) => Promise<void>
  addUpdate: (id: string, content: string) => Promise<void>
  subscribeRealtime: (userId: string) => void
  unsubscribeRealtime: () => void
}

const PAGE_SIZE = 20

export const useInteractionStore = create<InteractionState>((set, get) => {
  let realtimeChannel: ReturnType<ReturnType<typeof createClient>['channel']> | null = null

  return {
    interactions: [],
    currentInteraction: null,
    interactionUpdates: [],
    stats: null,
    counts: null,
    loading: false,
    detailLoading: false,
    updatesLoading: false,
    filter: { role: 'all', status: 'all', search: '' },
    hasMore: false,

    setFilter: (f) => {
      set(s => ({ filter: { ...s.filter, ...f } }))
    },

    loadInteractions: async (filter) => {
      const f = filter ?? get().filter
      set({ loading: true })
      const supabase = createClient()
      const { data, error } = await supabase.rpc('get_my_interactions', {
        p_role: f.role,
        p_status: f.status,
        p_limit: PAGE_SIZE,
        p_offset: 0,
      })
      if (error) { set({ loading: false }); return }
      let items = ((data as any[]) ?? []).map(mapRow)
      if (f.search) {
        const q = f.search.toLowerCase()
        items = items.filter(i =>
          (i.post?.title ?? '').toLowerCase().includes(q) ||
          (i.partner.name ?? '').toLowerCase().includes(q)
        )
      }
      set({ interactions: items, hasMore: items.length >= PAGE_SIZE, loading: false })
    },

    loadMore: async () => {
      const { filter, interactions } = get()
      const supabase = createClient()
      const { data } = await supabase.rpc('get_my_interactions', {
        p_role: filter.role,
        p_status: filter.status,
        p_limit: PAGE_SIZE,
        p_offset: interactions.length,
      })
      const items = ((data as any[]) ?? []).map(mapRow)
      set(s => ({
        interactions: [...s.interactions, ...items],
        hasMore: items.length >= PAGE_SIZE,
      }))
    },

    loadInteractionById: async (id) => {
      set({ detailLoading: true })
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) { set({ detailLoading: false }); return }

      const { data, error } = await supabase
        .from('interactions')
        .select('*')
        .eq('id', id)
        .single()
      if (error || !data) { set({ detailLoading: false }); return }

      const myRole = data.helper_id === user.id ? 'helper' : 'helped'
      const partnerId = myRole === 'helper' ? data.helped_id : data.helper_id

      // Fetch partner profile
      const { data: partner } = await supabase
        .from('profiles')
        .select('id, name, avatar_url, trust_score, trust_score_count')
        .eq('id', partnerId)
        .maybeSingle()

      // Fetch post if exists (may have been deleted)
      let post = null
      if (data.post_id) {
        const { data: postData } = await supabase
          .from('posts')
          .select('id, title, category, type')
          .eq('id', data.post_id)
          .maybeSingle()
        if (postData) post = postData
      }

      // Fetch match_score if match exists (may have been deleted)
      let matchScore = null
      if (data.match_id) {
        const { data: matchData } = await supabase
          .from('matches')
          .select('match_score')
          .eq('id', data.match_id)
          .maybeSingle()
        if (matchData) matchScore = matchData.match_score
      }

      const interaction: Interaction = {
        ...data,
        status: data.status as InteractionStatus,
        helper_rated: data.helper_rated ?? false,
        helped_rated: data.helped_rated ?? false,
        rating_requested: data.rating_requested ?? false,
        post: post ? { id: post.id, title: post.title, category: post.category, type: post.type } : null,
        partner: {
          id: partner?.id ?? partnerId,
          name: partner?.name ?? null,
          avatar_url: partner?.avatar_url ?? null,
          trust_score: partner?.trust_score ?? null,
          trust_count: partner?.trust_score_count ?? null,
        },
        myRole,
        match_score: matchScore,
      }

      set({ currentInteraction: interaction, detailLoading: false })
    },

    loadInteractionUpdates: async (id) => {
      set({ updatesLoading: true })
      const supabase = createClient()
      const { data } = await supabase
        .from('interaction_updates')
        .select('*, profiles!interaction_updates_author_id_fkey(name, avatar_url)')
        .eq('interaction_id', id)
        .order('created_at', { ascending: true })

      const updates: InteractionUpdate[] = ((data as any[]) ?? []).map(u => ({
        id: u.id,
        interaction_id: u.interaction_id,
        author_id: u.author_id,
        update_type: u.update_type,
        content: u.content,
        old_status: u.old_status,
        new_status: u.new_status,
        created_at: u.created_at,
        author_name: u.profiles?.name ?? null,
        author_avatar: u.profiles?.avatar_url ?? null,
      }))
      set({ interactionUpdates: updates, updatesLoading: false })
    },

    loadStats: async () => {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      const { data } = await supabase.rpc('get_interaction_stats', { p_user_id: user.id })
      if (data) set({ stats: data as any as InteractionStats })
    },

    loadCounts: async () => {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      const { data } = await supabase.rpc('get_interaction_counts', { p_user_id: user.id })
      if (data) set({ counts: data as any as InteractionCounts })
    },

    createInteraction: async (input) => {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return null

      const helperId = input.i_am_helper ? user.id : input.target_user_id
      const helpedId = input.i_am_helper ? input.target_user_id : user.id

      const { data, error } = await supabase
        .from('interactions')
        .insert({
          post_id: input.post_id,
          helper_id: helperId,
          helped_id: helpedId,
          status: 'requested',
          message: input.message,
        })
        .select('id')
        .single()

      if (error || !data) {
        toast.error('Fehler beim Erstellen der Anfrage')
        return null
      }

      // Create update entry
      await supabase.from('interaction_updates').insert({
        interaction_id: data.id,
        author_id: user.id,
        update_type: 'created',
        content: input.message,
      })

      // Send notification
      const { data: profile } = await supabase
        .from('profiles').select('name').eq('id', user.id).maybeSingle()
      const { data: post } = await supabase
        .from('posts').select('title').eq('id', input.post_id).maybeSingle()

      await supabase.from('notifications').insert({
        user_id: input.target_user_id,
        type: 'interaction_request',
        category: 'interaction',
        title: 'Neue Hilfsanfrage',
        content: (profile?.name ?? 'Jemand') + ' möchte ' + (input.i_am_helper ? 'dir helfen' : 'deine Hilfe') + ': ' + (post?.title ?? '').slice(0, 100),
        link: '/dashboard/interactions',
        actor_id: user.id,
        metadata: { interaction_id: data.id, sender_name: profile?.name, post_title: post?.title, message: input.message.slice(0, 100) },
      }).then(() => {})

      toast.success('Anfrage gesendet!')
      get().loadCounts()
      return data.id
    },

    respondToInteraction: async (id, accept, responseMessage) => {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      const interaction = get().currentInteraction ?? get().interactions.find(i => i.id === id)
      if (!interaction) return
      const myRole = interaction.helper_id === user.id ? 'helper' : 'helped'
      const partnerId = myRole === 'helper' ? interaction.helped_id : interaction.helper_id

      if (accept) {
        // Check if conversation exists, if not create one
        let convId = interaction.conversation_id
        if (!convId) {
          const { data: conv, error: convErr } = await supabase
            .from('conversations')
            .insert({ type: 'direct', title: 'Hilfe-Chat' })
            .select('id')
            .single()
          if (convErr || !conv) {
            console.error('create help-chat conversation failed:', convErr?.message)
            toast.error('Chat konnte nicht erstellt werden')
            return
          }
          convId = conv.id
          const { error: memErr } = await supabase.from('conversation_members').insert([
            { conversation_id: conv.id, user_id: interaction.helper_id },
            { conversation_id: conv.id, user_id: interaction.helped_id },
          ])
          if (memErr) console.error('add conversation members failed:', memErr.message)
        }

        const { error: updErr } = await supabase.from('interactions').update({
          status: 'accepted',
          response_message: responseMessage || null,
          conversation_id: convId,
          updated_at: new Date().toISOString(),
        }).eq('id', id)
        if (updErr) {
          console.error('accept interaction failed:', updErr.message)
          toast.error('Anfrage konnte nicht angenommen werden')
          return
        }

        await supabase.from('interaction_updates').insert({
          interaction_id: id, author_id: user.id,
          update_type: 'accepted', content: responseMessage || 'Anfrage angenommen',
          old_status: 'requested', new_status: 'accepted',
        })

        await supabase.from('notifications').insert({
          user_id: partnerId,
          type: 'interaction_accepted', category: 'interaction',
          title: 'Anfrage angenommen!',
          content: 'Deine Hilfsanfrage wurde angenommen. Ihr koennt jetzt chatten.',
          link: '/dashboard/interactions/' + id,
          actor_id: user.id,
          metadata: { interaction_id: id, conversation_id: convId },
        }).then(() => {})

        toast.success('Anfrage angenommen! Chat wurde erstellt.')
      } else {
        const cancelStatus = myRole === 'helper' ? 'cancelled_by_helper' : 'cancelled_by_helped'
        const { error: declErr } = await supabase.from('interactions').update({
          status: cancelStatus,
          response_message: responseMessage || null,
          updated_at: new Date().toISOString(),
        }).eq('id', id)
        if (declErr) {
          console.error('decline interaction failed:', declErr.message)
          toast.error('Anfrage konnte nicht abgelehnt werden')
          return
        }

        await supabase.from('interaction_updates').insert({
          interaction_id: id, author_id: user.id,
          update_type: 'declined', content: responseMessage || 'Anfrage abgelehnt',
          old_status: 'requested', new_status: cancelStatus,
        })

        await supabase.from('notifications').insert({
          user_id: partnerId,
          type: 'interaction_declined', category: 'interaction',
          title: 'Anfrage abgelehnt',
          content: 'Deine Hilfsanfrage wurde leider abgelehnt.',
          link: '/dashboard/interactions/' + id,
          actor_id: user.id,
          metadata: { interaction_id: id },
        }).then(() => {})

        toast('Anfrage abgelehnt.')
      }

      get().loadInteractionById(id)
      get().loadInteractionUpdates(id)
      get().loadCounts()
    },

    startProgress: async (id) => {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      const interaction = get().currentInteraction ?? get().interactions.find(i => i.id === id)
      const partnerId = interaction ? (interaction.helper_id === user.id ? interaction.helped_id : interaction.helper_id) : null

      const { error: spErr } = await supabase.from('interactions').update({
        status: 'in_progress', updated_at: new Date().toISOString(),
      }).eq('id', id)
      if (spErr) {
        console.error('start progress failed:', spErr.message)
        toast.error('Status konnte nicht aktualisiert werden')
        return
      }

      await supabase.from('interaction_updates').insert({
        interaction_id: id, author_id: user.id,
        update_type: 'in_progress', content: 'Hilfe hat begonnen',
        old_status: 'accepted', new_status: 'in_progress',
      })

      if (partnerId) {
        await supabase.from('notifications').insert({
          user_id: partnerId,
          type: 'interaction_status_change', category: 'interaction',
          title: 'Hilfe gestartet',
          content: 'Die Hilfe wurde als gestartet markiert.',
          link: '/dashboard/interactions/' + id,
          actor_id: user.id,
          metadata: { interaction_id: id, new_status: 'in_progress' },
        }).then(() => {})
      }

      toast.success('Als in Bearbeitung markiert.')
      get().loadInteractionById(id)
      get().loadInteractionUpdates(id)
    },

    completeInteraction: async (id, completionNotes) => {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      const interaction = get().currentInteraction ?? get().interactions.find(i => i.id === id)
      const partnerId = interaction ? (interaction.helper_id === user.id ? interaction.helped_id : interaction.helper_id) : null

      const { error: compErr } = await supabase.from('interactions').update({
        status: 'completed',
        completed_at: new Date().toISOString(),
        completed_by: user.id,
        completion_notes: completionNotes || null,
        updated_at: new Date().toISOString(),
      }).eq('id', id)
      if (compErr) {
        console.error('complete interaction failed:', compErr.message)
        toast.error('Interaktion konnte nicht abgeschlossen werden')
        return
      }

      await supabase.from('interaction_updates').insert({
        interaction_id: id, author_id: user.id,
        update_type: 'completed', content: completionNotes || 'Interaktion abgeschlossen',
        old_status: 'in_progress', new_status: 'completed',
      })

      if (partnerId) {
        await supabase.from('notifications').insert({
          user_id: partnerId,
          type: 'interaction_completed', category: 'interaction',
          title: 'Interaktion abgeschlossen!',
          content: 'Die Interaktion wurde als abgeschlossen markiert.',
          link: '/dashboard/interactions/' + id,
          actor_id: user.id,
          metadata: { interaction_id: id },
        }).then(() => {})
      }

      toast.success('Interaktion abgeschlossen!')
      get().loadInteractionById(id)
      get().loadInteractionUpdates(id)
      get().loadCounts()
    },

    cancelInteraction: async (id, reason) => {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      const interaction = get().currentInteraction ?? get().interactions.find(i => i.id === id)
      if (!interaction) return
      const myRole = interaction.helper_id === user.id ? 'helper' : 'helped'
      const newStatus = myRole === 'helper' ? 'cancelled_by_helper' : 'cancelled_by_helped'
      const partnerId = myRole === 'helper' ? interaction.helped_id : interaction.helper_id

      const { error: cancErr } = await supabase.from('interactions').update({
        status: newStatus, cancel_reason: reason || null,
        updated_at: new Date().toISOString(),
      }).eq('id', id)
      if (cancErr) {
        console.error('cancel interaction failed:', cancErr.message)
        toast.error('Interaktion konnte nicht abgesagt werden')
        return
      }

      await supabase.from('interaction_updates').insert({
        interaction_id: id, author_id: user.id,
        update_type: 'cancelled', content: reason || 'Interaktion abgesagt',
      })

      if (partnerId) {
        await supabase.from('notifications').insert({
          user_id: partnerId,
          type: 'interaction_cancelled', category: 'interaction',
          title: 'Interaktion abgesagt',
          content: 'Die Interaktion wurde abgesagt.',
          link: '/dashboard/interactions/' + id,
          actor_id: user.id, metadata: { interaction_id: id },
        }).then(() => {})
      }

      toast('Interaktion abgesagt.')
      get().loadInteractionById(id)
      get().loadInteractionUpdates(id)
      get().loadCounts()
    },

    disputeInteraction: async (id, reason) => {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return
      const interaction = get().currentInteraction ?? get().interactions.find(i => i.id === id)
      const partnerId = interaction ? (interaction.helper_id === user.id ? interaction.helped_id : interaction.helper_id) : null

      const { error: dispErr } = await supabase.from('interactions').update({
        status: 'disputed', updated_at: new Date().toISOString(),
      }).eq('id', id)
      if (dispErr) {
        console.error('dispute interaction failed:', dispErr.message)
        toast.error('Streitfall konnte nicht gemeldet werden')
        return
      }

      await supabase.from('interaction_updates').insert({
        interaction_id: id, author_id: user.id,
        update_type: 'disputed', content: reason,
      })

      if (partnerId) {
        await supabase.from('notifications').insert({
          user_id: partnerId,
          type: 'interaction_disputed', category: 'interaction',
          title: 'Streitfall gemeldet',
          content: 'Ein Streitfall wurde gemeldet. Ein Admin wird sich darum kuemmern.',
          link: '/dashboard/interactions/' + id,
          actor_id: user.id, metadata: { interaction_id: id },
        }).then(() => {})
      }

      // Notify admins
      const { data: admins } = await supabase
        .from('profiles').select('id').eq('role', 'admin')
      if (admins) {
        const { data: profile } = await supabase.from('profiles').select('name').eq('id', user.id).single()
        for (const admin of admins) {
          await supabase.from('notifications').insert({
            user_id: admin.id,
            type: 'interaction_dispute_admin', category: 'system',
            title: 'Neuer Streitfall',
            content: (profile?.name ?? 'Nutzer') + ' hat einen Streitfall gemeldet: ' + reason.slice(0, 100),
            link: '/dashboard/interactions/' + id,
            actor_id: user.id,
            metadata: { interaction_id: id, reason },
          }).then(() => {})
        }
      }

      toast('Streitfall gemeldet – ein Admin wird sich darum kuemmern.')
      get().loadInteractionById(id)
      get().loadInteractionUpdates(id)
    },

    addUpdate: async (id, content) => {
      const supabase = createClient()
      const { data: { user } } = await supabase.auth.getUser()
      if (!user) return

      const { data } = await supabase.from('interaction_updates').insert({
        interaction_id: id, author_id: user.id,
        update_type: 'message', content,
      }).select('*').single()

      if (data) {
        const { data: profile } = await supabase.from('profiles').select('name, avatar_url').eq('id', user.id).single()
        const update: InteractionUpdate = {
          ...data,
          author_name: profile?.name ?? null,
          author_avatar: profile?.avatar_url ?? null,
        }
        set(s => ({ interactionUpdates: [...s.interactionUpdates, update] }))
      }

      const interaction = get().currentInteraction ?? get().interactions.find(i => i.id === id)
      const partnerId = interaction ? (interaction.helper_id === user.id ? interaction.helped_id : interaction.helper_id) : null
      if (partnerId) {
        await supabase.from('notifications').insert({
          user_id: partnerId,
          type: 'interaction_update', category: 'interaction',
          title: 'Neue Notiz',
          content: content.slice(0, 100),
          link: '/dashboard/interactions/' + id,
          actor_id: user.id, metadata: { interaction_id: id },
        }).then(() => {})
      }
    },

    subscribeRealtime: (userId) => {
      const supabase = createClient()
      realtimeChannel = supabase
        .channel('interactions-' + userId)
        .on('postgres_changes', {
          event: 'UPDATE', schema: 'public', table: 'interactions',
        }, (payload) => {
          const updated = payload.new as any
          if (updated.helper_id !== userId && updated.helped_id !== userId) return
          set(s => ({
            interactions: s.interactions.map(i =>
              i.id === updated.id ? { ...i, status: updated.status, updated_at: updated.updated_at } : i
            ),
          }))
          // Update current if viewing
          if (get().currentInteraction?.id === updated.id) {
            get().loadInteractionById(updated.id)
          }
          get().loadCounts()
        })
        .subscribe()
    },

    unsubscribeRealtime: () => {
      if (realtimeChannel) {
        const supabase = createClient()
        supabase.removeChannel(realtimeChannel)
        realtimeChannel = null
      }
    },
  }
})
