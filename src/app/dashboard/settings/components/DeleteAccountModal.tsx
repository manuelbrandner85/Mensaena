'use client'

import { useState, useEffect } from 'react'
import { AlertTriangle, Loader2, X, Trash2, FileText, MessageSquare, Heart, Star, Bell, Users } from 'lucide-react'
import { useTranslations } from 'next-intl'

interface Props {
  userId: string
  open: boolean
  onClose: () => void
  onRequestDeletion: () => Promise<boolean>
  onConfirmDeletion: () => Promise<boolean>
  onCountData: () => Promise<{
    posts: number
    messages: number
    interactions: number
    saved_posts: number
    trust_ratings: number
    conversations: number
    notifications: number
  }>
}

export default function DeleteAccountModal({
  userId, open, onClose, onRequestDeletion, onConfirmDeletion, onCountData,
}: Props) {
  const t = useTranslations('deleteAccountModal')
  const [step, setStep] = useState<1 | 2 | 3>(1)
  const [confirmText, setConfirmText] = useState('')
  const [reason, setReason] = useState('')
  const [deleting, setDeleting] = useState(false)
  const [dataCounts, setDataCounts] = useState<{
    posts: number; messages: number; interactions: number
    saved_posts: number; trust_ratings: number; conversations: number; notifications: number
  } | null>(null)
  const [loadingCounts, setLoadingCounts] = useState(false)

  useEffect(() => {
    if (open && !dataCounts) {
      setLoadingCounts(true)
      onCountData().then(counts => {
        setDataCounts(counts)
        setLoadingCounts(false)
      })
    }
  }, [open, dataCounts, onCountData])

  useEffect(() => {
    if (!open) {
      setStep(1)
      setConfirmText('')
      setReason('')
      setDeleting(false)
    }
  }, [open])

  if (!open) return null

  const confirmWord = t('confirmWord')

  const handleStep1 = async () => {
    const ok = await onRequestDeletion()
    if (ok) setStep(2)
  }

  const handleFinalDelete = async () => {
    if (confirmText !== confirmWord) return

    setDeleting(true)
    await onConfirmDeletion()
    setDeleting(false)
  }

  const totalItems = dataCounts
    ? dataCounts.posts + dataCounts.messages + dataCounts.interactions +
      dataCounts.saved_posts + dataCounts.trust_ratings + dataCounts.conversations + dataCounts.notifications
    : 0

  const REASONS = [
    t('reason1'), t('reason2'), t('reason3'), t('reason4'), t('reason5'),
  ]

  const dataRows = dataCounts ? [
    { icon: <FileText className="w-3.5 h-3.5" />, label: t('labelPosts'), count: dataCounts.posts },
    { icon: <MessageSquare className="w-3.5 h-3.5" />, label: t('labelMessages'), count: dataCounts.messages },
    { icon: <Heart className="w-3.5 h-3.5" />, label: t('labelInteractions'), count: dataCounts.interactions },
    { icon: <Star className="w-3.5 h-3.5" />, label: t('labelRatings'), count: dataCounts.trust_ratings },
    { icon: <Users className="w-3.5 h-3.5" />, label: t('labelConversations'), count: dataCounts.conversations },
    { icon: <Bell className="w-3.5 h-3.5" />, label: t('labelNotifications'), count: dataCounts.notifications },
  ] : []

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-black/50 backdrop-blur-sm" onClick={onClose}>
      <div className="bg-white rounded-2xl shadow-2xl w-full max-w-md max-h-[90vh] overflow-y-auto" onClick={e => e.stopPropagation()}>
        {/* Header */}
        <div className="flex items-center justify-between p-6 border-b border-stone-100 sticky top-0 bg-white rounded-t-2xl">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-red-100 flex items-center justify-center">
              <AlertTriangle className="w-5 h-5 text-red-600" />
            </div>
            <div>
              <h3 className="font-bold text-ink-900">{t('title')}</h3>
              <p className="text-xs text-ink-500">{t('stepOf', { step })}</p>
            </div>
          </div>
          <button onClick={onClose} className="p-2 rounded-lg hover:bg-stone-100 transition-colors">
            <X className="w-5 h-5 text-ink-500" />
          </button>
        </div>

        {/* Body */}
        <div className="p-6">
          {step === 1 && (
            <div className="space-y-4">
              {/* Data overview */}
              <div className="bg-stone-50 border border-stone-200 rounded-xl p-4">
                <p className="text-sm font-medium text-ink-900 mb-3">
                  {t('dataTitleCount', { count: loadingCounts ? '...' : totalItems })}
                </p>
                {loadingCounts ? (
                  <div className="flex justify-center py-3">
                    <Loader2 className="w-5 h-5 text-ink-400 animate-spin" />
                  </div>
                ) : (
                  <div className="grid grid-cols-2 gap-2">
                    {dataRows.map(row => (
                      <div key={row.label} className="flex items-center gap-2 text-xs text-ink-600">
                        <span className="text-ink-400">{row.icon}</span>
                        <span>{row.count} {row.label}</span>
                      </div>
                    ))}
                  </div>
                )}
              </div>

              <div className="bg-red-50 border border-red-200 rounded-xl p-4">
                <p className="text-sm text-red-800 font-medium mb-2">{t('deletionWhat')}</p>
                <ul className="text-xs text-red-700 space-y-1.5">
                  <li>&#x2022; {t('bullet1')}</li>
                  <li>&#x2022; {t('bullet2')}</li>
                  <li>&#x2022; {t('bullet3')}</li>
                  <li>&#x2022; {t('bullet4')}</li>
                  <li>&#x2022; {t('bullet5')}</li>
                  <li>&#x2022; {t('bullet6')}</li>
                </ul>
              </div>

              <div>
                <label className="label">{t('reasonLabel')}</label>
                <select value={reason} onChange={e => setReason(e.target.value)} className="input">
                  <option value="">{t('reasonPlaceholder')}</option>
                  {REASONS.map(r => <option key={r} value={r}>{r}</option>)}
                </select>
              </div>

              <div className="flex items-start gap-2 bg-amber-50 rounded-xl p-3">
                <AlertTriangle className="w-4 h-4 text-amber-600 flex-shrink-0 mt-0.5" />
                <p className="text-xs text-amber-700">{t('gdprNote')}</p>
              </div>
            </div>
          )}

          {step === 2 && (
            <div className="space-y-4">
              <div className="bg-amber-50 border border-amber-200 rounded-xl p-4 text-center">
                <p className="text-sm font-medium text-amber-800">{t('markedTitle')}</p>
                <p className="text-xs text-amber-700 mt-1">{t('markedDesc')}</p>
              </div>

              <button
                onClick={() => setStep(3)}
                className="w-full py-2.5 rounded-xl text-sm font-medium bg-red-600 text-white hover:bg-red-700 transition-colors"
              >
                {t('confirmFinal')}
              </button>
            </div>
          )}

          {step === 3 && (
            <div className="space-y-4">
              <div className="bg-red-50 border border-red-200 rounded-xl p-4 text-center">
                <Trash2 className="w-8 h-8 text-red-600 mx-auto mb-2" />
                <p className="text-sm font-medium text-red-800">{t('sureTitle')}</p>
                <p className="text-xs text-red-600 mt-1">{t('irreversible')}</p>
              </div>

              <div>
                <label className="label">
                  {t('confirmLabelPre')} <strong className="text-red-600">{confirmWord}</strong> {t('confirmLabelPost')}
                </label>
                <input
                  value={confirmText}
                  onChange={e => setConfirmText(e.target.value)}
                  placeholder={confirmWord}
                  className="input border-red-200 focus:ring-red-300"
                  autoFocus
                />
              </div>
            </div>
          )}
        </div>

        {/* Footer */}
        <div className="flex gap-3 p-6 border-t border-stone-100 sticky bottom-0 bg-white rounded-b-2xl">
          <button
            onClick={step === 1 ? onClose : () => setStep((step - 1) as 1 | 2)}
            className="flex-1 py-2.5 rounded-xl text-sm font-medium bg-stone-100 text-ink-700 hover:bg-stone-200 transition-colors"
          >
            {step === 1 ? t('cancel') : t('back')}
          </button>

          {step === 1 && (
            <button
              onClick={handleStep1}
              className="flex-1 py-2.5 rounded-xl text-sm font-medium bg-red-600 text-white hover:bg-red-700 transition-colors"
            >
              {t('requestDeletion')}
            </button>
          )}

          {step === 3 && (
            <button
              onClick={handleFinalDelete}
              disabled={deleting || confirmText !== confirmWord}
              className="flex-1 flex items-center justify-center gap-2 py-2.5 rounded-xl text-sm font-medium bg-red-600 text-white hover:bg-red-700 transition-colors disabled:opacity-50"
            >
              {deleting ? <Loader2 className="w-4 h-4 animate-spin" /> : <Trash2 className="w-4 h-4" />}
              {deleting ? t('deleting') : t('finalDelete')}
            </button>
          )}
        </div>
      </div>
    </div>
  )
}
