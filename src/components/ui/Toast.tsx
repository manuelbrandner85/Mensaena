'use client'

import toast from 'react-hot-toast'
import { CheckCircle, AlertTriangle, Info, XCircle } from 'lucide-react'

/**
 * Typed toast helpers with consistent cinematic styling.
 * Uses react-hot-toast under the hood.
 */

const baseStyle = {
  borderRadius: '1rem',
  fontSize: '0.875rem',
  fontWeight: 500,
  boxShadow:
    '0 0 0 0.5px rgba(15, 23, 42, 0.06), 0 8px 16px rgba(15, 23, 42, 0.08), 0 24px 56px rgba(15, 23, 42, 0.10), inset 0 1px 0 rgba(255, 255, 255, 1)',
  backdropFilter: 'blur(8px) saturate(160%)',
  WebkitBackdropFilter: 'blur(8px) saturate(160%)',
  padding: '0.75rem 1rem',
}

export const showToast = {
  success: (message: string) =>
    toast.success(message, {
      icon: <CheckCircle className="w-5 h-5 text-mn-bronze" />,
      duration: 3000,
      style: {
        ...baseStyle,
        background: 'linear-gradient(150deg, rgba(239,252,251,0.97) 0%, rgba(208,245,243,0.92) 100%)',
        color: '#135a59',
        border: '1px solid rgba(163, 234, 232, 0.7)',
      },
    }),

  error: (message: string) =>
    toast.error(message, {
      icon: <XCircle className="w-5 h-5 text-mn-herzrot" />,
      duration: 4000,
      style: {
        ...baseStyle,
        background: 'linear-gradient(150deg, rgba(254,242,242,0.97) 0%, rgba(254,226,226,0.92) 100%)',
        color: '#7f1d1d',
        border: '1px solid rgba(254, 202, 202, 0.7)',
      },
    }),

  warning: (message: string) =>
    toast(message, {
      icon: <AlertTriangle className="w-5 h-5 text-amber-600" />,
      duration: 4000,
      style: {
        ...baseStyle,
        background: 'linear-gradient(150deg, rgba(255,251,235,0.97) 0%, rgba(254,243,199,0.92) 100%)',
        color: '#92400e',
        border: '1px solid rgba(253, 230, 138, 0.7)',
      },
    }),

  info: (message: string) =>
    toast(message, {
      icon: <Info className="w-5 h-5 text-trust-500" />,
      duration: 3000,
      style: {
        ...baseStyle,
        background: 'linear-gradient(150deg, rgba(239,244,250,0.97) 0%, rgba(214,228,240,0.92) 100%)',
        color: '#2C4157',
        border: '1px solid rgba(173, 200, 225, 0.7)',
      },
    }),
}

export default showToast
