'use client'

import { useState } from 'react'
import { Mail, Share2 } from 'lucide-react'
import EmailsTab from './EmailsTab'
import SocialMediaSection from './SocialMediaSection'

type MarketingView = 'emails' | 'social'

export default function MarketingTab() {
  const [view, setView] = useState<MarketingView>('emails')

  return (
    <div className="space-y-5">
      {/* Haupt-Navigation */}
      <div className="bg-white rounded-2xl border border-gray-100 shadow-sm overflow-hidden">
        <div className="border-b border-gray-100 px-4 py-3 flex items-center gap-2">
          <button
            onClick={() => setView('emails')}
            className={`flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-medium transition-all ${
              view === 'emails'
                ? 'bg-primary-500 text-white shadow-sm'
                : 'text-gray-600 hover:bg-gray-100'
            }`}
          >
            <Mail className="w-4 h-4" />
            E-Mails
          </button>
          <button
            onClick={() => setView('social')}
            className={`flex items-center gap-2 px-5 py-2.5 rounded-xl text-sm font-medium transition-all ${
              view === 'social'
                ? 'bg-primary-500 text-white shadow-sm'
                : 'text-gray-600 hover:bg-gray-100'
            }`}
          >
            <Share2 className="w-4 h-4" />
            Social Media
          </button>
        </div>

        <div className="p-4 lg:p-5">
          {view === 'emails' && <EmailsTab />}
          {view === 'social' && <SocialMediaSection />}
        </div>
      </div>
    </div>
  )
}
