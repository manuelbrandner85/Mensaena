// deploy-schema-service.mjs
// Mensaena – Schema Deployment via Supabase Service Role Key
// Nutzt die Supabase REST API mit Service Role Permissions

import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'

const __dirname = dirname(fileURLToPath(import.meta.url))

const SUPABASE_URL = 'https://huaqldjkgyosefzfhjnf.supabase.co'
const SERVICE_ROLE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh1YXFsZGprZ3lvc2VmemZoam5mIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NDk4NzExOCwiZXhwIjoyMDkwNTYzMTE4fQ.t09nG5IbpDPAuBuTLuOedep9ZEmi1dcNjD0xsPzFZVQ'

const headers = {
  'apikey': SERVICE_ROLE_KEY,
  'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
  'Content-Type': 'application/json',
  'Prefer': 'return=minimal'
}

// Supabase v2 Management API für direktes SQL
async function execSQL(sql, label) {
  console.log(`\n⚡ ${label}...`)
  try {
    const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/query`, {
      method: 'POST',
      headers,
      body: JSON.stringify({ query: sql })
    })

    if (!res.ok) {
      const body = await res.text()
      // Try Management API
      const res2 = await fetch(`https://api.supabase.com/v1/projects/huaqldjkgyosefzfhjnf/database/query`, {
        method: 'POST',
        headers: {
          'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({ query: sql })
      })
      if (!res2.ok) {
        console.log(`  ℹ️  ${label}: ${body.substring(0, 100)}`)
        return false
      }
    }
    console.log(`  ✅ ${label} – OK`)
    return true
  } catch (err) {
    console.log(`  ⚠️  ${label}: ${err.message}`)
    return false
  }
}

// Statements einzeln via pg Verbindung ausführen  
async function deployViaPooler() {
  const { default: pg } = await import('pg')
  const { Client } = pg

  // Supabase Session Pooler (Port 5432, IPv4)
  // Wir nutzen den Service Role als Passwort-Äquivalent
  // Der echte DB-Zugang braucht das DB-Passwort
  // Alternativ: Direct Connection via API
  
  console.log('\n🔄 Versuche Verbindung via Supabase Transaction Pooler...')
  
  // Supabase CLI Access Token (sb_secret_...)
  const ACCESS_TOKEN = 'SUPABASE_SECRET_REMOVED'
  
  // Supabase Management API – SQL ausführen
  // Endpoint: POST /v1/projects/{ref}/database/query
  const schemaSQL = readFileSync(join(__dirname, 'supabase/migrations/001_schema.sql'), 'utf8')
  const seedSQL = readFileSync(join(__dirname, 'supabase/migrations/002_seed.sql'), 'utf8')
  const realtimeSQL = readFileSync(join(__dirname, 'supabase/migrations/003_realtime.sql'), 'utf8')

  const mgmtHeaders = {
    'Authorization': `Bearer ${ACCESS_TOKEN}`,
    'Content-Type': 'application/json'
  }

  async function runQuery(sql, label) {
    console.log(`\n📄 Deploying: ${label}`)
    try {
      const res = await fetch(
        `https://api.supabase.com/v1/projects/huaqldjkgyosefzfhjnf/database/query`,
        {
          method: 'POST',
          headers: mgmtHeaders,
          body: JSON.stringify({ query: sql })
        }
      )
      const body = await res.text()
      if (res.ok) {
        console.log(`  ✅ ${label} – Erfolgreich`)
        return true
      } else {
        console.log(`  ℹ️  ${label} Status: ${res.status}`)
        console.log(`  ${body.substring(0, 200)}`)
        return false
      }
    } catch (err) {
      console.log(`  ❌ Fehler: ${err.message}`)
      return false
    }
  }

  const ok1 = await runQuery(schemaSQL, '001_schema.sql')
  if (ok1) await runQuery(seedSQL, '002_seed.sql')
  if (ok1) await runQuery(realtimeSQL, '003_realtime.sql')
  
  return ok1
}

async function main() {
  console.log('🌿 Mensaena – Schema Deployment')
  console.log('='.repeat(50))
  console.log('🔑 Service Role Key: aktiv')
  console.log('📡 Projekt: huaqldjkgyosefzfhjnf')

  const success = await deployViaPooler()

  if (!success) {
    console.log('\n⚠️  Management API nicht verfügbar mit diesem Token-Typ.')
    console.log('📋 Bitte Schema manuell einfügen:')
    console.log('🔗 https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new')
  }
}

main().catch(console.error)
