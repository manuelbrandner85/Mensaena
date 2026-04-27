// ============================================================
// Mensaena Design System – Tokens
// Single source of truth for colors, spacing, typography,
// radii, shadows, transitions, and z-index.
// ============================================================

// ── Colors ───────────────────────────────────────────────────

/** Primary teal-green palette (#1EAAA6 → #38a169) */
export const colors = {
  primary: {
    50:  '#effcfb',
    100: '#d0f5f3',
    200: '#a3eae8',
    300: '#6ddad7',
    400: '#38c4c0',
    500: '#1EAAA6',
    600: '#178d8a',
    700: '#147170',
    800: '#135a59',
    900: '#144b4a',
  },
  gray: {
    50:  '#f9fafb',
    100: '#f3f4f6',
    200: '#e5e7eb',
    300: '#d1d5db',
    400: '#9ca3af',
    500: '#6b7280',
    600: '#4b5563',
    700: '#374151',
    800: '#1f2937',
    900: '#111827',
  },
  danger: {
    50:  '#fef2f2',
    100: '#fee2e2',
    200: '#fecaca',
    300: '#fca5a5',
    400: '#f87171',
    500: '#C62828',
    600: '#B71C1C',
    700: '#991b1b',
    800: '#7f1d1d',
    900: '#450a0a',
  },
  warning: {
    50:  '#fffbeb',
    100: '#fef3c7',
    200: '#fde68a',
    300: '#fcd34d',
    400: '#fbbf24',
    500: '#f59e0b',
    600: '#d97706',
    700: '#b45309',
    800: '#92400e',
    900: '#78350f',
  },
  success: {
    50:  '#ecfdf5',
    100: '#d1fae5',
    200: '#a7f3d0',
    300: '#6ee7b7',
    400: '#34d399',
    500: '#10b981',
    600: '#059669',
    700: '#047857',
    800: '#065f46',
    900: '#064e3b',
  },
  info: {
    50:  '#eff6ff',
    100: '#dbeafe',
    200: '#bfdbfe',
    300: '#93c5fd',
    400: '#60a5fa',
    500: '#3b82f6',
    600: '#2563eb',
    700: '#1d4ed8',
    800: '#1e40af',
    900: '#1e3a8a',
  },
  trust: {
    50:  '#EFF4FA',
    100: '#D6E4F0',
    200: '#ADC8E1',
    300: '#7FA8CC',
    400: '#4F6D8A',
    500: '#3D5A73',
    600: '#2C4157',
  },
  background: '#EEF9F9',
  surface:    '#ffffff',
  foreground: '#1a1a1a',
  muted:      '#6b7280',
  border:     '#ccf1f0',
} as const

/** Category-to-color mapping for post types */
export const categoryColors: Record<string, { bg: string; text: string; border: string; dot: string }> = {
  help_needed:  { bg: 'bg-red-100',    text: 'text-red-700',    border: 'border-red-200',    dot: '#ef4444' },
  help_offered: { bg: 'bg-primary-100', text: 'text-primary-700', border: 'border-primary-200', dot: '#10b981' },
  crisis:       { bg: 'bg-red-100',    text: 'text-red-700',    border: 'border-red-200',    dot: '#dc2626' },
  animal:       { bg: 'bg-pink-100',   text: 'text-pink-700',   border: 'border-pink-200',   dot: '#ec4899' },
  housing:      { bg: 'bg-blue-100',   text: 'text-blue-700',   border: 'border-blue-200',   dot: '#3b82f6' },
  supply:       { bg: 'bg-amber-100',  text: 'text-amber-700',  border: 'border-amber-200',  dot: '#f59e0b' },
  mobility:     { bg: 'bg-indigo-100', text: 'text-indigo-700', border: 'border-indigo-200', dot: '#6366f1' },
  sharing:      { bg: 'bg-teal-100',   text: 'text-teal-700',   border: 'border-teal-200',   dot: '#14b8a6' },
  community:    { bg: 'bg-violet-100', text: 'text-violet-700', border: 'border-violet-200', dot: '#8b5cf6' },
  rescue:       { bg: 'bg-orange-100', text: 'text-orange-700', border: 'border-orange-200', dot: '#f97316' },
} as const

// ── Radii ────────────────────────────────────────────────────

export const radii = {
  none: '0',
  sm:   '0.375rem',   // 6px
  md:   '0.5rem',     // 8px
  lg:   '0.75rem',    // 12px
  xl:   '0.875rem',   // 14px
  '2xl': '1.25rem',   // 20px
  '3xl': '1.75rem',   // 28px
  full: '9999px',
} as const

// ── Shadows ──────────────────────────────────────────────────

export const shadows = {
  none: 'none',
  sm:   '0 1px 2px rgba(0,0,0,0.05)',
  soft: '0 2px 15px -3px rgba(0,0,0,0.07), 0 10px 20px -2px rgba(0,0,0,0.04)',
  card: '0 1px 3px rgba(0,0,0,0.06), 0 4px 12px rgba(0,0,0,0.08)',
  hover:'0 4px 20px rgba(0,0,0,0.12)',
  lg:   '0 10px 30px -5px rgba(0,0,0,0.1)',
  xl:   '0 20px 50px -12px rgba(0,0,0,0.12)',
  glow: '0 0 20px rgba(30,170,166,0.40)',
  'glow-sm':   '0 0 10px rgba(30,170,166,0.28)',
  'glow-teal': '0 0 24px rgba(30,170,166,0.50)',
  'glow-red':  '0 0 16px rgba(198,40,40,0.35)',
  'glow-blue': '0 0 16px rgba(79,109,138,0.30)',
} as const

// ── Spacing ──────────────────────────────────────────────────

export const spacing = {
  0:   '0',
  0.5: '0.125rem',  // 2px
  1:   '0.25rem',   // 4px
  1.5: '0.375rem',  // 6px
  2:   '0.5rem',    // 8px
  2.5: '0.625rem',  // 10px
  3:   '0.75rem',   // 12px
  4:   '1rem',      // 16px
  5:   '1.25rem',   // 20px
  6:   '1.5rem',    // 24px
  8:   '2rem',      // 32px
  10:  '2.5rem',    // 40px
  12:  '3rem',      // 48px
  16:  '4rem',      // 64px
  20:  '5rem',      // 80px
  24:  '6rem',      // 96px
} as const

// ── Typography ───────────────────────────────────────────────

export const typography = {
  fontFamily: {
    sans: "'Inter', system-ui, -apple-system, sans-serif",
  },
  fontSize: {
    xs:   ['0.75rem',  { lineHeight: '1rem'   }],  // 12px
    sm:   ['0.875rem', { lineHeight: '1.25rem' }], // 14px
    base: ['1rem',     { lineHeight: '1.5rem'  }], // 16px
    lg:   ['1.125rem', { lineHeight: '1.75rem' }], // 18px
    xl:   ['1.25rem',  { lineHeight: '1.75rem' }], // 20px
    '2xl': ['1.5rem',  { lineHeight: '2rem'    }], // 24px
    '3xl': ['1.875rem',{ lineHeight: '2.25rem' }], // 30px
    '4xl': ['2.25rem', { lineHeight: '2.5rem'  }], // 36px
  },
  fontWeight: {
    normal:   '400',
    medium:   '500',
    semibold: '600',
    bold:     '700',
    extrabold:'800',
  },
} as const

// ── Transitions ──────────────────────────────────────────────

export const transitions = {
  fast:    '150ms cubic-bezier(0.4, 0, 0.2, 1)',
  normal:  '200ms cubic-bezier(0.4, 0, 0.2, 1)',
  slow:    '300ms cubic-bezier(0.4, 0, 0.2, 1)',
  spring:  '300ms cubic-bezier(0.34, 1.56, 0.64, 1)',
  bounce:  '300ms cubic-bezier(0.68, -0.55, 0.265, 1.55)',
} as const

// ── Z-Index ──────────────────────────────────────────────────

export const zIndex = {
  hide:      -1,
  base:       0,
  dropdown:  10,
  sticky:    20,
  banner:    30,
  overlay:   40,
  modal:     50,
  popover:   60,
  tooltip:   70,
  toast:     80,
  max:       99,
} as const

// ── Gradient helpers ─────────────────────────────────────────

export const gradients = {
  /** The signature teal→green brand gradient */
  primary: 'linear-gradient(135deg, #1EAAA6 0%, #38a169 100%)',
  /** Light hero background */
  hero:    'linear-gradient(135deg, #EEF9F9 0%, #d0f5f3 40%, #EFF4FA 100%)',
  /** Section alternate */
  section: 'linear-gradient(180deg, #FFFFFF 0%, #e6f9f9 100%)',
} as const

/**
 * Modul-Themes für CreatePostPage / ModulePage.
 *
 * Zentral dokumentiert damit neue Module nicht ihre eigene zufällige
 * Farb-Kombi erfinden, sondern aus der Palette wählen. Jedes Theme stellt
 * Tailwind-Klassen für gradientFrom, gradientTo und ringColor bereit.
 *
 * Verwendung:
 * ```tsx
 * <CreatePostPage {...moduleThemes.harvest} ... />
 * ```
 */
export const moduleThemes = {
  // Versorgung & Lebensmittel (warm-grün)
  harvest:        { gradientFrom: 'from-green-500',   gradientTo: 'to-primary-300', ringColor: 'ring-green-400' },
  animals:        { gradientFrom: 'from-amber-500',   gradientTo: 'to-orange-400',  ringColor: 'ring-amber-400' },
  housing:        { gradientFrom: 'from-blue-500',    gradientTo: 'to-cyan-400',    ringColor: 'ring-blue-400' },

  // Wissen & Skills (kühl-blau)
  knowledge:      { gradientFrom: 'from-indigo-500',  gradientTo: 'to-violet-400',  ringColor: 'ring-indigo-400' },
  skills:         { gradientFrom: 'from-purple-500',  gradientTo: 'to-violet-400',  ringColor: 'ring-purple-400' },

  // Mobilität & Teilen (sky-teal)
  mobility:       { gradientFrom: 'from-sky-500',     gradientTo: 'to-blue-400',    ringColor: 'ring-sky-400' },
  sharing:        { gradientFrom: 'from-teal-500',    gradientTo: 'to-cyan-400',    ringColor: 'ring-teal-400' },

  // Notfall & Rettung (warm-rot)
  rescuer:        { gradientFrom: 'from-orange-500',  gradientTo: 'to-red-400',     ringColor: 'ring-orange-400' },

  // Gemeinschaft & Mental (sanft)
  'mental-support': { gradientFrom: 'from-rose-400', gradientTo: 'to-pink-400',    ringColor: 'ring-rose-400' },
  community:      { gradientFrom: 'from-violet-500',  gradientTo: 'to-purple-400',  ringColor: 'ring-violet-400' },
} as const

export type ModuleThemeKey = keyof typeof moduleThemes

// ── Convenience re-export ────────────────────────────────────

const tokens = {
  colors,
  categoryColors,
  radii,
  shadows,
  spacing,
  typography,
  transitions,
  zIndex,
  gradients,
} as const

export default tokens
