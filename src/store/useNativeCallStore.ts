// FIX-125: Native Incoming Call Store.
// Hält den Pending-Call-State zwischen IncomingCallKit-Annahme und LiveRoomModal-Mount.

import { create } from 'zustand'

export interface NativePendingCall {
  callId: string
  token: string
  url: string
  roomName: string
  callType: 'audio' | 'video'
  partnerName: string
  partnerAvatar: string | null
  answeredAt: string
}

interface NativeCallState {
  pendingCall: NativePendingCall | null
  setPendingCall: (call: NativePendingCall) => void
  clearPendingCall: () => void
}

export const useNativeCallStore = create<NativeCallState>((set) => ({
  pendingCall: null,
  setPendingCall: (call) => set({ pendingCall: call }),
  clearPendingCall: () => set({ pendingCall: null }),
}))
