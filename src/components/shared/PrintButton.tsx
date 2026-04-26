'use client'

import { Printer } from 'lucide-react'
import { cn } from '@/lib/utils'

interface PrintButtonProps {
  contentId?: string
  title?: string
  variant?: 'icon' | 'button'
  className?: string
}

const PRINT_CSS = `
  *, *::before, *::after { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: Inter, system-ui, sans-serif; font-size: 14px; color: #1a1a1a; padding: 32px; }
  h1, h2, h3 { color: #147170; margin: 1em 0 .5em; }
  p, li { line-height: 1.6; margin-bottom: .5em; }
  ul, ol { padding-left: 1.4em; }
  a { color: #1EAAA6; text-decoration: underline; }
  table { width: 100%; border-collapse: collapse; margin: 1em 0; }
  th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
  th { background: #EEF9F9; color: #147170; }
  img { max-width: 100%; }
  .print-header { border-bottom: 2px solid #1EAAA6; margin-bottom: 24px; padding-bottom: 12px; display: flex; justify-content: space-between; align-items: baseline; }
  .print-header h1 { font-size: 18px; margin: 0; color: #147170; }
  .print-header span { font-size: 12px; color: #666; }
  .print-footer { border-top: 1px solid #ddd; margin-top: 32px; padding-top: 12px; font-size: 11px; color: #888; display: flex; justify-content: space-between; }
  @media print { body { padding: 16px; } }
`

export default function PrintButton({
  contentId,
  title = 'Mensaena',
  variant = 'button',
  className,
}: PrintButtonProps) {
  function handlePrint() {
    const date = new Date().toLocaleDateString('de-DE', {
      day: '2-digit',
      month: '2-digit',
      year: 'numeric',
    })

    if (contentId) {
      const element = document.getElementById(contentId)
      if (!element) {
        window.print()
        return
      }

      const printWindow = window.open('', '_blank', 'width=800,height=600')
      if (!printWindow) return

      printWindow.document.write(`<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <title>${title}</title>
  <style>${PRINT_CSS}</style>
</head>
<body>
  <div class="print-header">
    <h1>Mensaena – Nachbarschaftshilfe</h1>
    <span>${date}</span>
  </div>
  ${element.innerHTML}
  <div class="print-footer">
    <span>www.mensaena.de</span>
    <span>Erstellt am ${date}</span>
  </div>
</body>
</html>`)

      printWindow.document.close()
      printWindow.focus()
      printWindow.print()
      printWindow.close()
      return
    }

    window.print()
  }

  if (variant === 'icon') {
    return (
      <button
        onClick={handlePrint}
        title="Drucken"
        aria-label="Drucken"
        className={cn(
          'p-2 rounded-lg text-ink-500 hover:bg-stone-100 hover:text-ink-700 transition-colors',
          className
        )}
      >
        <Printer className="w-4 h-4" />
      </button>
    )
  }

  return (
    <button
      onClick={handlePrint}
      className={cn(
        'inline-flex items-center gap-2 px-4 py-2 rounded-xl text-sm font-medium',
        'text-ink-600 bg-stone-100 hover:bg-stone-200 transition-colors',
        className
      )}
    >
      <Printer className="w-4 h-4" />
      Drucken
    </button>
  )
}
