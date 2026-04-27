const STORAGE_KEY = 'mensaena_theme'

/**
 * Inline no-flash script for <head>. Pure function, no 'use client' needed.
 * Safe to call from Server Components (e.g. root layout).
 */
export function getThemeScript(): string {
  return `(function(){try{var m=localStorage.getItem('${STORAGE_KEY}');var d=(m==='dark')||(!m&&window.matchMedia('(prefers-color-scheme: dark)').matches);if(d)document.documentElement.classList.add('dark');}catch(e){}})();`
}
