import type { Config } from 'tailwindcss'

const config: Config = {
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        // Teal-green primary palette
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
        teal: {
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
        sage: {
          50: '#effcfb',
          100: '#d0f5f3',
          200: '#a3eae8',
          300: '#6ddad7',
          400: '#38c4c0',
          500: '#1EAAA6',
        },
        trust: {
          50: '#EFF4FA',
          100: '#D6E4F0',
          200: '#ADC8E1',
          300: '#7FA8CC',
          400: '#4F6D8A',
          500: '#3D5A73',
          600: '#2C4157',
        },
        warm: {
          50:  '#f4fefe',
          100: '#e6f9f9',
          200: '#ccf1f0',
          300: '#a8e5e4',
        },
        emergency: {
          500: '#C62828',
          600: '#B71C1C',
        },
        // Very light teal background
        background: '#EEF9F9',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
      },
      borderRadius: {
        xl: '0.875rem',
        '2xl': '1.25rem',
        '3xl': '1.75rem',
      },
      boxShadow: {
        soft:  '0 2px 15px -3px rgba(0,0,0,0.07), 0 10px 20px -2px rgba(0,0,0,0.04)',
        card:  '0 1px 3px rgba(0,0,0,0.06), 0 4px 12px rgba(0,0,0,0.08)',
        hover: '0 4px 20px rgba(0,0,0,0.12)',
        glow:  '0 0 20px rgba(30,170,166,0.40)',
        'glow-sm': '0 0 10px rgba(30,170,166,0.28)',
        'glow-teal': '0 0 24px rgba(30,170,166,0.50)',
        'glow-red': '0 0 16px rgba(198,40,40,0.35)',
        'glow-blue': '0 0 16px rgba(79,109,138,0.30)',
      },
      animation: {
        /* existing */
        'fade-in':   'fadeIn 0.25s ease-in-out',
        'slide-up':  'slideUp 0.35s ease-out',
        'slide-in':  'slideIn 0.3s ease-out',
        /* new */
        'slide-up-fast':    'slideUp 0.2s ease-out',
        'slide-down':       'slideDown 0.3s ease-out',
        'slide-right':      'slideRight 0.3s ease-out',
        'slide-left-in':    'slideLeftIn 0.3s ease-out',
        'fade-in-slow':     'fadeIn 0.6s ease-in-out',
        'scale-in':         'scaleIn 0.2s cubic-bezier(0.34,1.56,0.64,1)',
        'scale-in-sm':      'scaleInSm 0.15s cubic-bezier(0.34,1.56,0.64,1)',
        'bounce-in':        'bounceIn 0.5s cubic-bezier(0.34,1.56,0.64,1)',
        'pulse-soft':       'pulseSoft 2.5s ease-in-out infinite',
        'pulse-dot':        'pulseDot 1.8s ease-in-out infinite',
        'ping-slow':        'ping 2s cubic-bezier(0,0,0.2,1) infinite',
        'spin-slow':        'spin 3s linear infinite',
        'shimmer':          'shimmer 1.8s linear infinite',
        'wave':             'wave 1.4s ease-in-out infinite',
        'float':            'float 6s ease-in-out infinite',
        'float-slow':       'float 10s ease-in-out infinite',
        'float-delayed':    'float 7s ease-in-out 2s infinite',
        'glow-pulse':       'glowPulse 2s ease-in-out infinite',
        'badge-pop':        'badgePop 0.4s cubic-bezier(0.34,1.56,0.64,1)',
        'ripple':           'ripple 0.6s linear',
        'progress-fill':    'progressFill 0.8s ease-out forwards',
        'count-up':         'countUp 0.5s ease-out forwards',
        'sidebar-glow':     'sidebarGlow 0.3s ease-out forwards',
        'message-in-right': 'messageInRight 0.3s cubic-bezier(0.34,1.2,0.64,1)',
        'message-in-left':  'messageInLeft 0.3s cubic-bezier(0.34,1.2,0.64,1)',
        'typing-dot':       'typingDot 1.2s ease-in-out infinite',
        'heart-burst':      'heartBurst 0.6s cubic-bezier(0.34,1.56,0.64,1)',
        'card-enter':       'cardEnter 0.4s ease-out',
        'stagger-1':        'slideUp 0.35s ease-out 0.05s both',
        'stagger-2':        'slideUp 0.35s ease-out 0.10s both',
        'stagger-3':        'slideUp 0.35s ease-out 0.15s both',
        'stagger-4':        'slideUp 0.35s ease-out 0.20s both',
        'stagger-5':        'slideUp 0.35s ease-out 0.25s both',
        'stagger-6':        'slideUp 0.35s ease-out 0.30s both',
        'rotate-in':        'rotateIn 0.4s cubic-bezier(0.34,1.56,0.64,1)',
        'spotlight':        'spotlight 3s ease-in-out infinite',
        'board-new':        'boardNewPost 2s ease-out forwards',
        'sos-blink':        'sosBlink 2.5s ease-in-out infinite',
      },
      keyframes: {
        fadeIn: {
          '0%':   { opacity: '0' },
          '100%': { opacity: '1' },
        },
        slideUp: {
          '0%':   { transform: 'translateY(14px)', opacity: '0' },
          '100%': { transform: 'translateY(0)',    opacity: '1' },
        },
        slideDown: {
          '0%':   { transform: 'translateY(-14px)', opacity: '0' },
          '100%': { transform: 'translateY(0)',     opacity: '1' },
        },
        slideIn: {
          '0%':   { transform: 'translateX(-12px)', opacity: '0' },
          '100%': { transform: 'translateX(0)',     opacity: '1' },
        },
        slideRight: {
          '0%':   { transform: 'translateX(12px)', opacity: '0' },
          '100%': { transform: 'translateX(0)',    opacity: '1' },
        },
        slideLeftIn: {
          '0%':   { transform: 'translateX(20px)', opacity: '0' },
          '100%': { transform: 'translateX(0)',    opacity: '1' },
        },
        scaleIn: {
          '0%':   { transform: 'scale(0.75)', opacity: '0' },
          '100%': { transform: 'scale(1)',    opacity: '1' },
        },
        scaleInSm: {
          '0%':   { transform: 'scale(0.85)', opacity: '0' },
          '100%': { transform: 'scale(1)',    opacity: '1' },
        },
        bounceIn: {
          '0%':   { transform: 'scale(0.3)',   opacity: '0' },
          '50%':  { transform: 'scale(1.05)',  opacity: '1' },
          '70%':  { transform: 'scale(0.95)' },
          '100%': { transform: 'scale(1)' },
        },
        pulseSoft: {
          '0%, 100%': { opacity: '1',    transform: 'scale(1)'    },
          '50%':      { opacity: '0.75', transform: 'scale(0.97)' },
        },
        pulseDot: {
          '0%, 100%': { transform: 'scale(1)',   opacity: '1'   },
          '50%':      { transform: 'scale(1.35)', opacity: '0.7' },
        },
        shimmer: {
          '0%':   { backgroundPosition: '-400px 0' },
          '100%': { backgroundPosition:  '400px 0' },
        },
        wave: {
          '0%, 100%': { transform: 'translateY(0)'   },
          '25%':      { transform: 'translateY(-6px)' },
          '75%':      { transform: 'translateY(3px)'  },
        },
        float: {
          '0%, 100%': { transform: 'translateY(0px)   rotate(0deg)'   },
          '33%':      { transform: 'translateY(-14px)  rotate(2deg)'  },
          '66%':      { transform: 'translateY(-6px)   rotate(-1.5deg)' },
        },
        glowPulse: {
          '0%, 100%': { boxShadow: '0 0 6px rgba(102,187,106,0.2)'  },
          '50%':      { boxShadow: '0 0 22px rgba(102,187,106,0.55)' },
        },
        badgePop: {
          '0%':   { transform: 'scale(0)',   opacity: '0' },
          '60%':  { transform: 'scale(1.3)', opacity: '1' },
          '100%': { transform: 'scale(1)' },
        },
        ripple: {
          '0%':   { transform: 'scale(0)',   opacity: '0.5' },
          '100%': { transform: 'scale(4)',   opacity: '0'   },
        },
        progressFill: {
          '0%':   { width: '0%' },
          '100%': { width: 'var(--progress-width, 100%)' },
        },
        countUp: {
          '0%':   { transform: 'translateY(8px)',  opacity: '0' },
          '100%': { transform: 'translateY(0)',    opacity: '1' },
        },
        sidebarGlow: {
          '0%':   { boxShadow: 'none' },
          '100%': { boxShadow: 'inset 3px 0 0 #4CAF50, 0 0 16px rgba(102,187,106,0.18)' },
        },
        messageInRight: {
          '0%':   { transform: 'translateX(20px) scale(0.92)', opacity: '0' },
          '100%': { transform: 'translateX(0)    scale(1)',    opacity: '1' },
        },
        messageInLeft: {
          '0%':   { transform: 'translateX(-20px) scale(0.92)', opacity: '0' },
          '100%': { transform: 'translateX(0)     scale(1)',    opacity: '1' },
        },
        typingDot: {
          '0%, 80%, 100%': { transform: 'scale(0)',    opacity: '0.3' },
          '40%':           { transform: 'scale(1.1)',  opacity: '1'   },
        },
        heartBurst: {
          '0%':   { transform: 'scale(1)'   },
          '30%':  { transform: 'scale(1.45)' },
          '60%':  { transform: 'scale(0.9)' },
          '100%': { transform: 'scale(1)'   },
        },
        cardEnter: {
          '0%':   { transform: 'translateY(20px) scale(0.97)', opacity: '0' },
          '100%': { transform: 'translateY(0)    scale(1)',    opacity: '1' },
        },
        rotateIn: {
          '0%':   { transform: 'rotate(-10deg) scale(0.8)', opacity: '0' },
          '100%': { transform: 'rotate(0)      scale(1)',   opacity: '1' },
        },
        spotlight: {
          '0%, 100%': { opacity: '0.03' },
          '50%':      { opacity: '0.09' },
        },
        boardNewPost: {
          '0%':   { transform: 'scale(0.95)', opacity: '0', boxShadow: '0 0 0 0 rgba(251,191,36,0.6)' },
          '30%':  { transform: 'scale(1.02)', opacity: '1', boxShadow: '0 0 20px 4px rgba(251,191,36,0.4)' },
          '60%':  { transform: 'scale(1)',    boxShadow: '0 0 12px 2px rgba(251,191,36,0.2)' },
          '100%': { transform: 'scale(1)',    opacity: '1', boxShadow: '0 0 0 0 rgba(251,191,36,0)' },
        },
        sosBlink: {
          '0%, 100%': { boxShadow: '0 0 0 0 rgba(220,38,38,0.0)', opacity: '1' },
          '50%':      { boxShadow: '0 0 8px 2px rgba(220,38,38,0.35)', opacity: '0.85' },
        },
      },
      transitionTimingFunction: {
        'spring': 'cubic-bezier(0.34, 1.56, 0.64, 1)',
        'bounce': 'cubic-bezier(0.68, -0.55, 0.265, 1.55)',
      },
    },
  },
  plugins: [],
}
export default config
