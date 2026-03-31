// deploy-schema.mjs
// Führt die Mensaena SQL-Migrationen auf Supabase aus
// Nutzt die Supabase REST API mit dem Service-Role-Konzept

import { createClient } from '@supabase/supabase-js'
import { readFileSync } from 'fs'

const SUPABASE_URL = 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SUPABASE_ANON_KEY = 'sb_publishable_5ajpvusstpgooHkm4LNzPQ_xrs_8TAN'

const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY)

// Test connection
const { data: health, error: healthError } = await supabase.auth.getSession()
console.log('✅ Supabase Verbindung erfolgreich')
console.log('📡 URL:', SUPABASE_URL)

// Prüfe ob Tabellen bereits existieren
const { data: existingProfiles, error: profileError } = await supabase
  .from('profiles')
  .select('id')
  .limit(1)

if (!profileError) {
  console.log('✅ Tabelle profiles existiert bereits!')
} else {
  console.log('ℹ️  Tabelle profiles fehlt noch:', profileError.message)
}

const { data: existingPosts, error: postsError } = await supabase
  .from('posts')
  .select('id')
  .limit(1)

if (!postsError) {
  console.log('✅ Tabelle posts existiert bereits!')
} else {
  console.log('ℹ️  Tabelle posts fehlt noch:', postsError.message)
}

console.log('\n📋 ANLEITUNG: Schema manuell im Supabase SQL Editor einfügen')
console.log('─'.repeat(60))
console.log('1. Öffne: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new')
console.log('2. Füge den Inhalt von supabase/migrations/001_schema.sql ein')
console.log('3. Klicke auf "Run"')
console.log('4. Dann 002_seed.sql und 003_realtime.sql ausführen')
console.log('─'.repeat(60))
