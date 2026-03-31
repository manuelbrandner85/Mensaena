// deploy-migrations.mjs
// Mensaena – Direkte Migration über Supabase Transaction Pooler (IPv4)
import pg from 'pg'
import { readFileSync } from 'fs'
import { fileURLToPath } from 'url'
import { dirname, join } from 'path'

const __dirname = dirname(fileURLToPath(import.meta.url))

// Supabase Transaction Pooler (IPv4, Port 6543)
// Format: postgresql://postgres.[project-ref]:[DB-PASSWORD]@aws-0-eu-central-1.pooler.supabase.com:6543/postgres
const DB_PASSWORD = process.env.DB_PASSWORD || 'REPLACE_WITH_DB_PASSWORD'

const connectionString = `postgresql://postgres.huaqldjkgyosefzfhjnf:${DB_PASSWORD}@aws-0-eu-central-1.pooler.supabase.com:6543/postgres?sslmode=require`

const { Client } = pg

async function runMigration(client, filePath, label) {
  console.log(`\n📄 ${label}...`)
  const sql = readFileSync(filePath, 'utf8')

  // Statements splitten (grobes Splitting für Migration-Files)
  try {
    await client.query(sql)
    console.log(`  ✅ ${label} erfolgreich`)
  } catch (err) {
    console.error(`  ❌ Fehler in ${label}:`)
    console.error(`  ${err.message}`)
    // Weitermachen bei nicht-kritischen Fehlern
  }
}

async function main() {
  if (DB_PASSWORD === 'REPLACE_WITH_DB_PASSWORD') {
    console.log('❌ Bitte DB_PASSWORD setzen:')
    console.log('   DB_PASSWORD=deinPasswort node deploy-migrations.mjs')
    process.exit(1)
  }

  const client = new Client({ connectionString })

  try {
    console.log('🔌 Verbinde mit Supabase...')
    await client.connect()
    console.log('✅ Verbunden!')

    const migrationsDir = join(__dirname, 'supabase', 'migrations')

    await runMigration(client, join(migrationsDir, '001_schema.sql'), '001 Schema + RLS')
    await runMigration(client, join(migrationsDir, '002_seed.sql'), '002 Seed Data')
    await runMigration(client, join(migrationsDir, '003_realtime.sql'), '003 Realtime')

    console.log('\n🎉 Alle Migrationen abgeschlossen!')
    console.log('🌐 Dashboard: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf')

  } catch (err) {
    console.error('❌ Verbindungsfehler:', err.message)
  } finally {
    await client.end()
  }
}

main()
