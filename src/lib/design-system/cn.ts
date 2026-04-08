// ============================================================
// Mensaena Design System – Class-Name Utility
// Merges Tailwind classes with clsx + tailwind-merge to
// prevent class conflicts (e.g. "px-4" and "px-6").
// ============================================================

import { clsx, type ClassValue } from 'clsx'
import { twMerge } from 'tailwind-merge'

/**
 * Merge multiple class values into a single string.
 * Resolves Tailwind conflicts automatically.
 *
 * @example
 * cn('px-4 py-2', condition && 'bg-primary-500', 'rounded-xl')
 */
export function cn(...inputs: ClassValue[]): string {
  return twMerge(clsx(inputs))
}

export default cn
