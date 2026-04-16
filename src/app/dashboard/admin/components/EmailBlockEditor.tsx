'use client'

import { useState } from 'react'
import {
  Type, Image, MousePointerClick, Minus, ChevronUp, ChevronDown,
  Trash2, Plus, Eye, Code, Heading1,
} from 'lucide-react'

// ── Block-Typen ──────────────────────────────────────────────
interface Block {
  id: string
  type: 'header' | 'text' | 'image' | 'button' | 'divider' | 'spacer'
  content: string
  props: Record<string, string>
}

const BLOCK_TEMPLATES: Array<{ type: Block['type']; label: string; icon: React.ReactNode }> = [
  { type: 'header',  label: 'Überschrift', icon: <Heading1 className="w-4 h-4" /> },
  { type: 'text',    label: 'Text',        icon: <Type className="w-4 h-4" /> },
  { type: 'image',   label: 'Bild',        icon: <Image className="w-4 h-4" /> },
  { type: 'button',  label: 'Button',      icon: <MousePointerClick className="w-4 h-4" /> },
  { type: 'divider', label: 'Trennlinie',  icon: <Minus className="w-4 h-4" /> },
]

function newId() { return Math.random().toString(36).slice(2, 10) }

function defaultBlock(type: Block['type']): Block {
  switch (type) {
    case 'header': return { id: newId(), type, content: 'Deine Überschrift hier', props: { size: '24', color: '#1EAAA6' } }
    case 'text':   return { id: newId(), type, content: 'Hier steht dein Text. Du kannst ihn frei bearbeiten und formatieren.', props: {} }
    case 'image':  return { id: newId(), type, content: '', props: { url: 'https://via.placeholder.com/600x200/1EAAA6/ffffff?text=Mensaena', alt: 'Bild' } }
    case 'button': return { id: newId(), type, content: 'Jetzt entdecken →', props: { url: 'https://www.mensaena.de/dashboard', color: '#1EAAA6' } }
    case 'divider': return { id: newId(), type, content: '', props: {} }
    case 'spacer': return { id: newId(), type, content: '', props: { height: '20' } }
  }
}

// ── Block → HTML ─────────────────────────────────────────────
function blockToHtml(block: Block): string {
  switch (block.type) {
    case 'header':
      return `<h1 style="margin:0 0 16px;color:${block.props.color || '#1EAAA6'};font-size:${block.props.size || '24'}px;font-weight:800;">${block.content}</h1>`
    case 'text':
      return `<p style="margin:0 0 16px;color:#374151;font-size:15px;line-height:1.75;">${block.content}</p>`
    case 'image':
      return `<img src="${block.props.url}" alt="${block.props.alt || ''}" style="width:100%;max-width:600px;border-radius:12px;margin:0 0 16px;" />`
    case 'button':
      return `<div style="text-align:center;margin:24px 0;"><a href="${block.props.url}" style="display:inline-block;background:linear-gradient(135deg,${block.props.color || '#1EAAA6'} 0%,#147170 100%);color:#ffffff;text-decoration:none;padding:15px 40px;border-radius:13px;font-size:15px;font-weight:700;box-shadow:0 5px 18px rgba(30,170,166,0.35);">${block.content}</a></div>`
    case 'divider':
      return '<hr style="border:none;border-top:1px solid #E5F7F7;margin:24px 0;" />'
    case 'spacer':
      return `<div style="height:${block.props.height || '20'}px;"></div>`
  }
}

function blocksToFullHtml(blocks: Block[]): string {
  const bodyHtml = blocks.map(blockToHtml).join('\n')
  return `<!DOCTYPE html>
<html lang="de">
<head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0"></head>
<body style="margin:0;padding:0;background:#EEF9F9;font-family:Arial,Helvetica,sans-serif;">
<table width="100%" cellpadding="0" cellspacing="0" style="background:#EEF9F9;padding:40px 16px;">
<tr><td align="center">
<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#ffffff;border-radius:20px;overflow:hidden;box-shadow:0 6px 30px rgba(30,170,166,0.12);">
  <tr><td>
    <div style="background:linear-gradient(135deg,#1EAAA6 0%,#147170 100%);padding:36px 48px;text-align:center;">
      <div style="display:inline-block;background:rgba(255,255,255,0.15);border-radius:16px;padding:10px 20px;">
        <span style="color:#fff;font-size:28px;font-weight:800;letter-spacing:-1px;">Mensaena</span>
      </div>
    </div>
  </td></tr>
  <tr><td style="padding:40px 48px;">
    ${bodyHtml}
  </td></tr>
  <tr><td style="padding:0 48px;"><hr style="border:none;border-top:1px solid #E5F7F7;margin:0;"></td></tr>
  <tr><td style="background:#f8fffe;padding:24px 48px;border-radius:0 0 20px 20px;text-align:center;">
    <p style="margin:0;color:#9CA3AF;font-size:11px;">
      <a href="UNSUBSCRIBE_URL" style="color:#6B7280;text-decoration:underline;">E-Mails abbestellen</a>
      &nbsp;·&nbsp;
      <a href="https://www.mensaena.de/impressum" style="color:#6B7280;text-decoration:none;">Impressum</a>
      &nbsp;·&nbsp;
      <a href="https://www.mensaena.de/datenschutz" style="color:#6B7280;text-decoration:none;">Datenschutz</a>
    </p>
  </td></tr>
</table>
</td></tr></table>
</body></html>`
}

// ── Editor Komponente ────────────────────────────────────────
export default function EmailBlockEditor({
  onSave,
  initialHtml,
}: {
  onSave: (html: string) => void
  initialHtml?: string
}) {
  const [blocks, setBlocks] = useState<Block[]>([
    defaultBlock('header'),
    defaultBlock('text'),
    defaultBlock('button'),
  ])
  const [mode, setMode] = useState<'edit' | 'preview' | 'code'>('edit')
  const [selectedBlock, setSelectedBlock] = useState<string | null>(null)

  const addBlock = (type: Block['type']) => {
    setBlocks(prev => [...prev, defaultBlock(type)])
  }

  const moveBlock = (id: string, direction: 'up' | 'down') => {
    setBlocks(prev => {
      const idx = prev.findIndex(b => b.id === id)
      if (idx === -1) return prev
      const newIdx = direction === 'up' ? idx - 1 : idx + 1
      if (newIdx < 0 || newIdx >= prev.length) return prev
      const copy = [...prev]
      ;[copy[idx], copy[newIdx]] = [copy[newIdx], copy[idx]]
      return copy
    })
  }

  const removeBlock = (id: string) => {
    setBlocks(prev => prev.filter(b => b.id !== id))
    if (selectedBlock === id) setSelectedBlock(null)
  }

  const updateBlock = (id: string, updates: Partial<Block>) => {
    setBlocks(prev => prev.map(b => b.id === id ? { ...b, ...updates } : b))
  }

  const fullHtml = blocksToFullHtml(blocks)

  return (
    <div className="space-y-3">
      {/* Toolbar */}
      <div className="flex items-center justify-between flex-wrap gap-2">
        <div className="flex items-center gap-1.5">
          <span className="text-xs font-bold text-gray-700 mr-1">Block hinzufügen:</span>
          {BLOCK_TEMPLATES.map(t => (
            <button
              key={t.type}
              onClick={() => addBlock(t.type)}
              className="flex items-center gap-1 px-2.5 py-1.5 bg-gray-50 hover:bg-primary-50 border border-gray-200 hover:border-primary-200 rounded-lg text-xs text-gray-700 hover:text-primary-700 transition-all"
            >
              {t.icon} {t.label}
            </button>
          ))}
        </div>
        <div className="flex items-center gap-1">
          <button onClick={() => setMode('edit')} className={`px-3 py-1.5 rounded-lg text-xs font-medium ${mode === 'edit' ? 'bg-primary-500 text-white' : 'bg-gray-100 text-gray-600'}`}>
            <Plus className="w-3 h-3 inline mr-1" />Editor
          </button>
          <button onClick={() => setMode('preview')} className={`px-3 py-1.5 rounded-lg text-xs font-medium ${mode === 'preview' ? 'bg-primary-500 text-white' : 'bg-gray-100 text-gray-600'}`}>
            <Eye className="w-3 h-3 inline mr-1" />Vorschau
          </button>
          <button onClick={() => setMode('code')} className={`px-3 py-1.5 rounded-lg text-xs font-medium ${mode === 'code' ? 'bg-primary-500 text-white' : 'bg-gray-100 text-gray-600'}`}>
            <Code className="w-3 h-3 inline mr-1" />HTML
          </button>
        </div>
      </div>

      {/* Editor */}
      {mode === 'edit' && (
        <div className="space-y-2 bg-gray-50 rounded-xl p-3 min-h-[300px]">
          {blocks.length === 0 && (
            <p className="text-xs text-gray-400 text-center py-8 italic">Klicke oben auf einen Block-Typ um zu starten.</p>
          )}
          {blocks.map((block, idx) => (
            <div
              key={block.id}
              onClick={() => setSelectedBlock(block.id)}
              className={`bg-white rounded-xl border p-3 transition-all cursor-pointer ${
                selectedBlock === block.id ? 'border-primary-400 ring-2 ring-primary-100' : 'border-gray-200 hover:border-gray-300'
              }`}
            >
              <div className="flex items-center justify-between mb-2">
                <span className="text-xs text-gray-400 font-medium uppercase">{block.type}</span>
                <div className="flex items-center gap-1">
                  <button onClick={e => { e.stopPropagation(); moveBlock(block.id, 'up') }} disabled={idx === 0} className="p-1 text-gray-400 hover:text-gray-700 disabled:opacity-30"><ChevronUp className="w-3.5 h-3.5" /></button>
                  <button onClick={e => { e.stopPropagation(); moveBlock(block.id, 'down') }} disabled={idx === blocks.length - 1} className="p-1 text-gray-400 hover:text-gray-700 disabled:opacity-30"><ChevronDown className="w-3.5 h-3.5" /></button>
                  <button onClick={e => { e.stopPropagation(); removeBlock(block.id) }} className="p-1 text-gray-400 hover:text-red-500"><Trash2 className="w-3.5 h-3.5" /></button>
                </div>
              </div>

              {block.type === 'header' && (
                <input
                  type="text" value={block.content}
                  onChange={e => updateBlock(block.id, { content: e.target.value })}
                  className="w-full text-xl font-bold text-primary-700 bg-transparent border-none outline-none"
                  placeholder="Überschrift..."
                />
              )}
              {block.type === 'text' && (
                <textarea
                  value={block.content}
                  onChange={e => updateBlock(block.id, { content: e.target.value })}
                  className="w-full text-sm text-gray-700 bg-transparent border-none outline-none resize-none"
                  rows={3}
                  placeholder="Text eingeben..."
                />
              )}
              {block.type === 'image' && (
                <input
                  type="url" value={block.props.url}
                  onChange={e => updateBlock(block.id, { props: { ...block.props, url: e.target.value } })}
                  className="w-full text-xs text-gray-600 bg-gray-50 rounded-lg px-2 py-1.5 border border-gray-200"
                  placeholder="Bild-URL..."
                />
              )}
              {block.type === 'button' && (
                <div className="flex gap-2">
                  <input
                    type="text" value={block.content}
                    onChange={e => updateBlock(block.id, { content: e.target.value })}
                    className="flex-1 text-sm bg-gray-50 rounded-lg px-2 py-1.5 border border-gray-200"
                    placeholder="Button-Text..."
                  />
                  <input
                    type="url" value={block.props.url}
                    onChange={e => updateBlock(block.id, { props: { ...block.props, url: e.target.value } })}
                    className="flex-1 text-xs bg-gray-50 rounded-lg px-2 py-1.5 border border-gray-200"
                    placeholder="Link-URL..."
                  />
                </div>
              )}
              {block.type === 'divider' && (
                <hr className="border-t border-gray-200 my-1" />
              )}
            </div>
          ))}
        </div>
      )}

      {/* Vorschau */}
      {mode === 'preview' && (
        <div className="border border-gray-200 rounded-xl overflow-hidden bg-gray-50">
          <iframe srcDoc={fullHtml} className="w-full h-[500px] bg-white" />
        </div>
      )}

      {/* HTML Code */}
      {mode === 'code' && (
        <textarea
          value={fullHtml}
          readOnly
          className="w-full px-3 py-2 border border-gray-200 rounded-xl text-xs font-mono bg-gray-50 focus:outline-none"
          rows={15}
        />
      )}

      {/* Speichern */}
      <div className="flex justify-end">
        <button
          onClick={() => onSave(fullHtml)}
          className="px-5 py-2 bg-primary-500 hover:bg-primary-600 text-white rounded-xl text-sm font-medium shadow-sm transition-colors"
        >
          Als Kampagne übernehmen
        </button>
      </div>
    </div>
  )
}
