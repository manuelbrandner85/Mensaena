'use client'

import toast from 'react-hot-toast'
import { CheckCircle, AlertTriangle, Info, XCircle } from 'lucide-react'

/**
 * Typed toast helpers with consistent styling.
 * Uses react-hot-toast under the hood.
 */
export const showToast = {
  success: (message: string) =>
    toast.success(message, {
      icon: <CheckCircle className="w-5 h-5 text-green-600" />,
      duration: 3000,
      style: {
        borderRadius: '0.875rem',
        background: '#ecfdf5',
        color: '#065f46',
        border: '1px solid #a7f3d0',
        fontSize: '0.875rem',
        fontWeight: 500,
      },
    }),

  error: (message: string) =>
    toast.error(message, {
      icon: <XCircle className="w-5 h-5 text-red-600" />,
      duration: 4000,
      style: {
        borderRadius: '0.875rem',
        background: '#fef2f2',
        color: '#7f1d1d',
        border: '1px solid #fecaca',
        fontSize: '0.875rem',
        fontWeight: 500,
      },
    }),

  warning: (message: string) =>
    toast(message, {
      icon: <AlertTriangle className="w-5 h-5 text-amber-600" />,
      duration: 4000,
      style: {
        borderRadius: '0.875rem',
        background: '#fffbeb',
        color: '#92400e',
        border: '1px solid #fde68a',
        fontSize: '0.875rem',
        fontWeight: 500,
      },
    }),

  info: (message: string) =>
    toast(message, {
      icon: <Info className="w-5 h-5 text-blue-600" />,
      duration: 3000,
      style: {
        borderRadius: '0.875rem',
        background: '#eff6ff',
        color: '#1e40af',
        border: '1px solid #bfdbfe',
        fontSize: '0.875rem',
        fontWeight: 500,
      },
    }),
}

export default showToast
