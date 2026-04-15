'use client'

import { useState } from 'react'
import { Users, Wrench, Apple, Package, ArrowLeftRight, Plus, Trash2, MapPin, Clock } from 'lucide-react'
import toast from 'react-hot-toast'
import FeatureFlag from './FeatureFlag'
import { FeatureCard, PillButton, useFeatureStorage } from './shared'

/* ───────────────────────────── marketplace: Reservierungs-Queue ───────────────────────────── */

interface Reservation {
  id: string
  item: string
  reserver: string
  at: number
}

function MarketplaceReservationInner() {
  const [queue, setQueue] = useFeatureStorage<Reservation[]>('marketplace_reservation', [])
  const [item, setItem] = useState('')
  const [reserver, setReserver] = useState('')

  const add = () => {
    if (!item.trim() || !reserver.trim()) return
    setQueue(prev => [...prev, { id: crypto.randomUUID(), item: item.trim(), reserver: reserver.trim(), at: Date.now() }].slice(-15))
    setItem('')
    setReserver('')
    toast.success('In Warteschlange eingereiht')
  }

  const remove = (id: string) => setQueue(prev => prev.filter(q => q.id !== id))

  return (
    <FeatureCard icon={<Users className="w-5 h-5" />} title="Reservierungs-Queue" subtitle="Wer zuerst kommt, malt zuerst – faire Warteliste" accent="amber">
      <div className="flex gap-2 mb-3">
        <input value={item} onChange={e => setItem(e.target.value)} placeholder="Artikel" className="input py-2 text-sm flex-1" maxLength={40} />
        <input value={reserver} onChange={e => setReserver(e.target.value)} placeholder="Dein Name" className="input py-2 text-sm flex-1" maxLength={30} />
        <PillButton onClick={add} disabled={!item.trim() || !reserver.trim()}><Plus className="w-3.5 h-3.5" /></PillButton>
      </div>
      {queue.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Noch keine Reservierungen.</p>
      ) : (
        <ol className="space-y-1">
          {queue.map((q, i) => (
            <li key={q.id} className="flex items-center justify-between text-sm bg-amber-50/60 border border-amber-100 rounded-xl px-3 py-1.5">
              <span className="flex items-center gap-2"><span className="text-amber-700 font-bold">#{i + 1}</span> {q.item} — <span className="text-gray-500">{q.reserver}</span></span>
              <button onClick={() => remove(q.id)} className="text-gray-400 hover:text-red-500">
                <Trash2 className="w-3.5 h-3.5" />
              </button>
            </li>
          ))}
        </ol>
      )}
    </FeatureCard>
  )
}

export function MarketplaceReservation() {
  return <FeatureFlag flag="marketplace_reservation"><MarketplaceReservationInner /></FeatureFlag>
}

/* ───────────────────────────── sharing: Leih-Kalender ───────────────────────────── */

interface Lending {
  id: string
  tool: string
  borrower: string
  returnBy: number
  deposit: number
}

function SharingLendingCalendarInner() {
  const [lendings, setLendings] = useFeatureStorage<Lending[]>('sharing_lending_calendar', [])
  const [tool, setTool] = useState('')
  const [borrower, setBorrower] = useState('')
  const [days, setDays] = useState(3)
  const [deposit, setDeposit] = useState(0)

  const add = () => {
    if (!tool.trim() || !borrower.trim()) return
    setLendings(prev => [
      { id: crypto.randomUUID(), tool: tool.trim(), borrower: borrower.trim(), returnBy: Date.now() + days * 86400_000, deposit },
      ...prev,
    ].slice(0, 15))
    setTool('')
    setBorrower('')
    toast.success('Verleih eingetragen')
  }

  return (
    <FeatureCard icon={<Wrench className="w-5 h-5" />} title="Leih-Kalender" subtitle="Werkzeug-Verleih mit Rückgabedatum und optionalem Pfand" accent="sky">
      <div className="grid grid-cols-2 gap-2 mb-2">
        <input value={tool} onChange={e => setTool(e.target.value)} placeholder="Gerät / Werkzeug" className="input py-2 text-sm" maxLength={40} />
        <input value={borrower} onChange={e => setBorrower(e.target.value)} placeholder="Leiher" className="input py-2 text-sm" maxLength={30} />
      </div>
      <div className="flex items-center gap-2 mb-3">
        <label className="text-xs text-gray-500">Tage</label>
        <input type="number" min={1} max={30} value={days} onChange={e => setDays(Number(e.target.value))} className="input py-1.5 text-sm w-16" />
        <label className="text-xs text-gray-500">Pfand €</label>
        <input type="number" min={0} value={deposit} onChange={e => setDeposit(Number(e.target.value))} className="input py-1.5 text-sm w-20" />
        <PillButton onClick={add} disabled={!tool.trim() || !borrower.trim()}>Verleihen</PillButton>
      </div>
      {lendings.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Nichts verliehen.</p>
      ) : (
        <ul className="space-y-1">
          {lendings.map(l => (
            <li key={l.id} className="flex items-center justify-between text-sm bg-sky-50/60 border border-sky-100 rounded-xl px-3 py-1.5">
              <span className="truncate">{l.tool} → {l.borrower}</span>
              <span className="text-xs text-sky-700 font-semibold whitespace-nowrap">
                zurück {new Date(l.returnBy).toLocaleDateString('de-DE')}{l.deposit > 0 && ` · ${l.deposit}€`}
              </span>
            </li>
          ))}
        </ul>
      )}
    </FeatureCard>
  )
}

export function SharingLendingCalendar() {
  return <FeatureFlag flag="sharing_lending_calendar"><SharingLendingCalendarInner /></FeatureFlag>
}

/* ───────────────────────────── harvest: Obstbaum-Karte ───────────────────────────── */

interface Tree {
  id: string
  kind: string
  location: string
  note: string
}

function HarvestFruitMapInner() {
  const [trees, setTrees] = useFeatureStorage<Tree[]>('harvest_fruit_map', [])
  const [kind, setKind] = useState('Apfel')
  const [location, setLocation] = useState('')
  const [note, setNote] = useState('')

  const add = () => {
    if (!location.trim()) return
    setTrees(prev => [{ id: crypto.randomUUID(), kind, location: location.trim(), note: note.trim() }, ...prev].slice(0, 30))
    setLocation('')
    setNote('')
    toast.success('Baum eingetragen')
  }

  return (
    <FeatureCard icon={<Apple className="w-5 h-5" />} title="Obstbaum-Karte" subtitle="Was reift gerade wo – darf gepflückt werden?" accent="primary">
      <div className="grid grid-cols-2 gap-2 mb-2">
        <select value={kind} onChange={e => setKind(e.target.value)} className="input py-2 text-sm">
          <option>Apfel</option><option>Birne</option><option>Kirsche</option>
          <option>Pflaume</option><option>Walnuss</option><option>Beere</option>
        </select>
        <input value={location} onChange={e => setLocation(e.target.value)} placeholder="Standort" className="input py-2 text-sm" maxLength={50} />
      </div>
      <div className="flex gap-2 mb-3">
        <input value={note} onChange={e => setNote(e.target.value)} placeholder={'Hinweis (z.B. „reif"/„warte noch")'} className="input py-2 text-sm flex-1" maxLength={80} />
        <PillButton onClick={add} disabled={!location.trim()}><Plus className="w-3.5 h-3.5" /></PillButton>
      </div>
      {trees.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Noch keine Bäume gemeldet.</p>
      ) : (
        <ul className="space-y-1">
          {trees.map(t => (
            <li key={t.id} className="flex items-center justify-between text-sm bg-primary-50/50 border border-primary-100 rounded-xl px-3 py-1.5">
              <span className="truncate"><span className="text-primary-700 font-semibold">{t.kind}</span> · <MapPin className="w-3 h-3 inline" /> {t.location}</span>
              {t.note && <span className="text-xs text-gray-500 italic truncate max-w-[40%]">„{t.note}"</span>}
            </li>
          ))}
        </ul>
      )}
    </FeatureCard>
  )
}

export function HarvestFruitMap() {
  return <FeatureFlag flag="harvest_fruit_map"><HarvestFruitMapInner /></FeatureFlag>
}

/* ───────────────────────────── supply: Notvorrats-Tausch ───────────────────────────── */

interface SupplySwap {
  id: string
  offer: string
  want: string
}

function SupplyEmergencySwapInner() {
  const [items, setItems] = useFeatureStorage<SupplySwap[]>('supply_emergency_swap', [])
  const [offer, setOffer] = useState('')
  const [want, setWant] = useState('')

  const add = () => {
    if (!offer.trim() || !want.trim()) return
    setItems(prev => [{ id: crypto.randomUUID(), offer: offer.trim(), want: want.trim() }, ...prev].slice(0, 20))
    setOffer('')
    setWant('')
    toast.success('Tausch eingetragen')
  }

  return (
    <FeatureCard icon={<Package className="w-5 h-5" />} title="Notvorrats-Tausch" subtitle="Zucker, Mehl, Batterien – kurzfristig tauschen" accent="amber">
      <div className="flex gap-2 mb-3">
        <input value={offer} onChange={e => setOffer(e.target.value)} placeholder="Ich biete" className="input py-2 text-sm flex-1" maxLength={30} />
        <ArrowLeftRight className="w-4 h-4 text-gray-400 self-center" />
        <input value={want} onChange={e => setWant(e.target.value)} placeholder="Ich suche" className="input py-2 text-sm flex-1" maxLength={30} />
        <PillButton onClick={add} disabled={!offer.trim() || !want.trim()}><Plus className="w-3.5 h-3.5" /></PillButton>
      </div>
      {items.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Keine offenen Tausch-Angebote.</p>
      ) : (
        <ul className="space-y-1">
          {items.map(i => (
            <li key={i.id} className="flex items-center gap-2 text-sm bg-amber-50/60 border border-amber-100 rounded-xl px-3 py-1.5">
              <span className="truncate flex-1 text-primary-700 font-semibold">{i.offer}</span>
              <ArrowLeftRight className="w-3.5 h-3.5 text-gray-400" />
              <span className="truncate flex-1 text-amber-700 font-semibold">{i.want}</span>
            </li>
          ))}
        </ul>
      )}
    </FeatureCard>
  )
}

export function SupplyEmergencySwap() {
  return <FeatureFlag flag="supply_emergency_swap"><SupplyEmergencySwapInner /></FeatureFlag>
}

/* ───────────────────────────── timebank: Stunden-Transfer ───────────────────────────── */

function TimebankTransferInner() {
  const [balances, setBalances] = useFeatureStorage<Record<string, number>>('timebank_transfer_balances', {})
  const [from, setFrom] = useState('')
  const [to, setTo] = useState('')
  const [hours, setHours] = useState(1)

  const transfer = () => {
    if (!from.trim() || !to.trim() || hours <= 0) return
    if (from.trim() === to.trim()) {
      toast.error('Quelle und Ziel müssen verschieden sein')
      return
    }
    setBalances(prev => ({
      ...prev,
      [from.trim()]: (prev[from.trim()] ?? 0) - hours,
      [to.trim()]:   (prev[to.trim()] ?? 0) + hours,
    }))
    toast.success(`${hours}h von ${from.trim()} → ${to.trim()}`)
    setFrom('')
    setTo('')
    setHours(1)
  }

  const entries = Object.entries(balances).sort((a, b) => b[1] - a[1])

  return (
    <FeatureCard icon={<Clock className="w-5 h-5" />} title="Stunden-Transfer" subtitle="Übertrage Zeitbank-Stunden an Nachbarn" accent="primary">
      <div className="flex gap-2 mb-2">
        <input value={from} onChange={e => setFrom(e.target.value)} placeholder="Von" className="input py-2 text-sm flex-1" maxLength={30} />
        <input value={to} onChange={e => setTo(e.target.value)} placeholder="An" className="input py-2 text-sm flex-1" maxLength={30} />
      </div>
      <div className="flex items-center gap-2 mb-3">
        <label className="text-xs text-gray-500">Stunden</label>
        <input type="number" min={1} max={100} value={hours} onChange={e => setHours(Number(e.target.value))} className="input py-1.5 text-sm w-20" />
        <PillButton onClick={transfer}>Übertragen</PillButton>
      </div>
      {entries.length === 0 ? (
        <p className="text-xs text-gray-400 italic">Noch keine Konten.</p>
      ) : (
        <ul className="space-y-1">
          {entries.map(([name, bal]) => (
            <li key={name} className="flex items-center justify-between text-sm bg-primary-50/50 border border-primary-100 rounded-xl px-3 py-1.5">
              <span className="truncate">{name}</span>
              <span className={`text-xs font-bold tabular-nums ${bal >= 0 ? 'text-primary-700' : 'text-red-600'}`}>{bal >= 0 ? '+' : ''}{bal}h</span>
            </li>
          ))}
        </ul>
      )}
    </FeatureCard>
  )
}

export function TimebankTransfer() {
  return <FeatureFlag flag="timebank_transfer"><TimebankTransferInner /></FeatureFlag>
}
