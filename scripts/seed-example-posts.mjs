/**
 * Seed script: Creates one example post per type with "[BEISPIEL]" tag.
 * Uses the exact DB schema: id, user_id, type, category, title, description,
 * image_urls, latitude, longitude, urgency (low/medium/high), contact_phone,
 * contact_whatsapp, contact_email, status, is_anonymous, image_url,
 * event_date, event_time, duration_hours, tags
 *
 * Run: node scripts/seed-example-posts.mjs
 */

import { createClient } from '@supabase/supabase-js'

const SUPABASE_URL = 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_KEY  = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

const sb = createClient(SUPABASE_URL, SERVICE_KEY)

// Get first real user from profiles table to use as author
const { data: profiles } = await sb.from('profiles').select('id').limit(1)
const USER_ID = profiles?.[0]?.id

if (!USER_ID) {
  console.error('No user found in profiles table. Please create a user first.')
  process.exit(1)
}
console.log('Using user ID:', USER_ID)

const EXAMPLE_POSTS = [
  {
    type: 'help_request',
    category: 'everyday',
    title: '[BEISPIEL] Hilfe beim Einkaufen gesucht',
    description: 'Dies ist ein Beispielbeitrag. Ich bin älter und komme nicht gut zu Fuß. Würde jemand einmal pro Woche für mich einkaufen gehen können? Ich ersetze natürlich alle Kosten und zahle eine kleine Aufwandsentschädigung.',
    urgency: 'medium',
    contact_phone: '+43 660 000 0001',
    tags: ['beispiel', 'einkaufen', 'hilfe'],
  },
  {
    type: 'help_offer',
    category: 'everyday',
    title: '[BEISPIEL] Biete Hilfe beim Umzug an',
    description: 'Dies ist ein Beispielbeitrag. Ich habe am Wochenende Zeit und einen Transporter zur Verfügung. Wenn jemand Hilfe beim Umzug braucht, helfe ich gerne. Bin körperlich fit und habe Erfahrung mit Möbeln.',
    urgency: 'low',
    contact_phone: '+43 660 000 0002',
    contact_whatsapp: '+43 660 000 0002',
    tags: ['beispiel', 'umzug', 'transporter'],
  },
  {
    type: 'rescue',
    category: 'food',
    title: '[BEISPIEL] Rette Gemüse – bitte abholen!',
    description: 'Dies ist ein Beispielbeitrag. Ich habe zu viel Gemüse aus dem Garten geerntet und kann es nicht alles verwerten. Tomaten, Zucchini und Paprika zu vergeben – alles frisch, bio und kostenlos. Bitte heute noch abholen.',
    urgency: 'medium',
    contact_phone: '+43 660 000 0003',
    tags: ['beispiel', 'lebensmittel', 'bio', 'kostenlos'],
  },
  {
    type: 'animal',
    category: 'animals',
    title: '[BEISPIEL] Katze entlaufen – bitte melden!',
    description: 'Dies ist ein Beispielbeitrag. Unsere Katze "Luna" (weiblich, getigert, ca. 3 Jahre alt, mit Halsband) ist seit gestern Abend verschwunden. Zuletzt gesehen im Bereich Favoriten / Wien 10. Bitte melden wenn gesehen!',
    urgency: 'high',
    contact_phone: '+43 660 000 0004',
    contact_whatsapp: '+43 660 000 0004',
    latitude: 48.1730,
    longitude: 16.3804,
    tags: ['beispiel', 'katze', 'entlaufen', 'wien'],
  },
  {
    type: 'housing',
    category: 'housing',
    title: '[BEISPIEL] Biete Zimmer für 1 Person in WG',
    description: 'Dies ist ein Beispielbeitrag. Wir sind eine 3er-WG in Wien-Neubau und suchen eine ruhige, freundliche Person für ein 14m² Zimmer. Miete inkl. Betriebskosten und Internet: 550€/Monat. Bezug ab sofort möglich.',
    urgency: 'low',
    contact_phone: '+43 660 000 0005',
    contact_email: 'beispiel-wohnen@mensaena.at',
    latitude: 48.2018,
    longitude: 16.3461,
    tags: ['beispiel', 'wg', 'wien', 'zimmer'],
  },
  {
    type: 'supply',
    category: 'food',
    title: '[BEISPIEL] Frische Eier vom Bauernhof zu kaufen',
    description: 'Dies ist ein Beispielbeitrag. Wir haben ca. 80 Freiland-Hühner und täglich frische Eier. 10er-Karton für 3€. Direkt am Hof erhältlich oder Lieferung im Umkreis 20km möglich. Regional und nachhaltig.',
    urgency: 'low',
    contact_phone: '+43 660 000 0006',
    contact_whatsapp: '+43 660 000 0006',
    tags: ['beispiel', 'eier', 'bauernhof', 'regional'],
  },
  {
    type: 'skill',
    category: 'skills',
    title: '[BEISPIEL] Gebe Deutschunterricht für Anfänger',
    description: 'Dies ist ein Beispielbeitrag. Ich bin pensionierter Lehrer und biete kostenlosen Deutschunterricht für Flüchtlinge und Migranten an. Einzel- oder Kleingruppenunterricht möglich. Niveau: A1-B1. Zeitaufwand ca. 2 Stunden/Woche.',
    urgency: 'low',
    contact_phone: '+43 660 000 0007',
    duration_hours: 2,
    tags: ['beispiel', 'deutsch', 'unterricht', 'kostenlos'],
  },
  {
    type: 'mobility',
    category: 'mobility',
    title: '[BEISPIEL] Fahrt Wien → Graz am Samstag – Mitfahrer willkommen',
    description: 'Dies ist ein Beispielbeitrag. Ich fahre am Samstag um 09:00 Uhr von Wien Hauptbahnhof nach Graz. Es gibt noch 2 freie Plätze. Kostenbeteiligung: 15€. Nichtraucher-Fahrzeug, Hund an Bord.',
    urgency: 'low',
    contact_phone: '+43 660 000 0008',
    contact_whatsapp: '+43 660 000 0008',
    event_date: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
    event_time: '09:00',
    tags: ['beispiel', 'wien', 'graz', 'mitfahrt'],
  },
  {
    type: 'sharing',
    category: 'sharing',
    title: '[BEISPIEL] Verleihe Werkzeug kostenlos',
    description: 'Dies ist ein Beispielbeitrag. Ich verleihe mein Werkzeug gerne weiter: Bohrmaschine, Schleifer, Säge, Leiter, und mehr. Ausleihe kostenlos, nur Pfand und sorgsamer Umgang erbeten. Bitte kurz anfragen.',
    urgency: 'low',
    contact_phone: '+43 660 000 0009',
    tags: ['beispiel', 'werkzeug', 'leihen', 'kostenlos'],
  },
  {
    type: 'community',
    category: 'community',
    title: '[BEISPIEL] Idee: Gemeinschaftsgarten im Hof',
    description: 'Dies ist ein Beispielbeitrag. Ich würde gerne einen kleinen Gemeinschaftsgarten im Innenhof unseres Hauses anlegen. Wer hätte Interesse? Wir würden gemeinsam Gemüse, Kräuter und Blumen anbauen. Treffen zur Planung: 15.4. um 18:00.',
    urgency: 'low',
    contact_phone: '+43 660 000 0010',
    event_date: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000).toISOString().split('T')[0],
    event_time: '18:00',
    tags: ['beispiel', 'garten', 'gemeinschaft', 'nachbarschaft'],
  },
  {
    type: 'crisis',
    category: 'emergency',
    title: '[BEISPIEL] NOTFALL: Medikamente dringend gesucht',
    description: 'Dies ist ein Beispielbeitrag für einen Notfall-Beitrag. Insulin dringend benötigt – Vorrat aufgebraucht, Apotheke geschlossen. Bitte sofort melden wenn jemand helfen kann! Dies ist nur ein Demonstrations-Beispiel.',
    urgency: 'high',
    contact_phone: '+43 660 000 0011',
    contact_whatsapp: '+43 660 000 0011',
    tags: ['beispiel', 'notfall', 'medikamente'],
  },
  {
    type: 'knowledge',
    category: 'knowledge',
    title: '[BEISPIEL] Anleitung: Gemüse richtig einkochen',
    description: 'Dies ist ein Beispielbeitrag. Ich teile meine Methode zum Einkochen von Tomaten, Bohnen und Paprika. Nach dieser Anleitung halten die Gläser bis zu 2 Jahre. Ich biete auch einen Workshop an – max. 6 Personen, kostenlos.',
    urgency: 'low',
    contact_phone: '+43 660 000 0012',
    duration_hours: 3,
    tags: ['beispiel', 'einkochen', 'lebensmittel', 'workshop'],
  },
  {
    type: 'mental',
    category: 'mental',
    title: '[BEISPIEL] Suche jemanden zum Reden',
    description: 'Dies ist ein Beispielbeitrag. Nach einem schwierigen Jahr fühle ich mich manchmal allein. Ich suche jemanden für ein offenes, ehrliches Gespräch – ohne Ratschläge, einfach nur zuhören. Bin auch selbst gerne für andere da.',
    urgency: 'low',
    is_anonymous: true,
    tags: ['beispiel', 'gespräch', 'zuhören', 'mental'],
  },
]

let created = 0
let failed = 0

for (const post of EXAMPLE_POSTS) {
  const payload = {
    user_id: USER_ID,
    type: post.type,
    category: post.category,
    title: post.title,
    description: post.description,
    urgency: post.urgency ?? 'low',
    status: 'active',
    is_anonymous: post.is_anonymous ?? false,
    contact_phone: post.is_anonymous ? null : (post.contact_phone ?? null),
    contact_whatsapp: post.is_anonymous ? null : (post.contact_whatsapp ?? null),
    contact_email: post.contact_email ?? null,
    latitude: post.latitude ?? null,
    longitude: post.longitude ?? null,
    event_date: post.event_date ?? null,
    event_time: post.event_time ?? null,
    duration_hours: post.duration_hours ?? null,
    tags: post.tags ?? [],
  }

  const { data, error } = await sb.from('posts').insert(payload).select('id').single()

  if (error) {
    console.error(`❌ FAILED [${post.type}]:`, error.message)
    failed++
  } else {
    console.log(`✅ Created [${post.type}]: "${post.title.substring(0, 50)}" → ID: ${data.id}`)
    created++
  }
}

console.log(`\n✅ Done: ${created} created, ${failed} failed`)
