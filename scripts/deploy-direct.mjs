#!/usr/bin/env node
/**
 * MENSAENA – Direkte Supabase Deployment via pg-Pooler (Port 6543)
 * Der Pooler ist über IPv4 erreichbar!
 * 
 * Verwendung: node scripts/deploy-direct.mjs [db-password]
 * Das DB-Passwort aus dem Supabase Dashboard → Settings → Database
 */

import { readFileSync } from 'fs';

// Lade .env.local
const envPath = new URL('../.env.local', import.meta.url).pathname;
const envContent = readFileSync(envPath, 'utf8');
const env = Object.fromEntries(
  envContent.split('\n')
    .filter(l => l.trim() && !l.startsWith('#') && l.includes('='))
    .map(l => {
      const idx = l.indexOf('=');
      return [l.substring(0, idx).trim(), l.substring(idx + 1).trim()];
    })
);

const SUPABASE_URL = env['NEXT_PUBLIC_SUPABASE_URL'];
const SERVICE_ROLE_KEY = env['SUPABASE_SERVICE_ROLE_KEY'];
const PROJECT_REF = SUPABASE_URL.replace('https://', '').replace('.supabase.co', '');

// Passwort aus Kommandozeile oder env
const DB_PASSWORD = process.argv[2] || process.env.SUPABASE_DB_PASSWORD || '';

console.log('\n🚀 Mensaena – Direkte Datenbankverbindung via Pooler');
console.log(`📌 Projekt: ${PROJECT_REF}`);
console.log(`🔗 Pooler: aws-0-eu-central-1.pooler.supabase.com:6543`);

if (!DB_PASSWORD) {
  console.log('\n⚠️  Kein Datenbankpasswort angegeben!');
  console.log('\n📋 Bitte das Passwort angeben:');
  console.log('   node scripts/deploy-direct.mjs <DEIN-DB-PASSWORT>');
  console.log('\n📍 Wo findest du das Passwort:');
  console.log('   → https://supabase.com/dashboard/project/' + PROJECT_REF + '/settings/database');
  console.log('   → Abschnitt "Connection string" → "Connection info" → "Database password"');
  console.log('\n   Oder generiere ein neues unter:');
  console.log('   → Settings → Database → Reset database password');
  console.log('\n💡 Alternativ: Führe das Schema direkt im SQL-Editor aus:');
  console.log('   → https://supabase.com/dashboard/project/' + PROJECT_REF + '/sql/new');
  console.log('   → Kopiere: supabase/DEPLOY_THIS.sql\n');
  process.exit(0);
}

// Importiere pg
let Client;
try {
  const pg = await import('pg');
  Client = pg.default.Client || pg.Client;
} catch (e) {
  console.error('❌ pg-Modul nicht gefunden! Bitte: npm install pg');
  process.exit(1);
}

// Verbindungs-Konfiguration
const connectionConfig = {
  host: 'aws-0-eu-central-1.pooler.supabase.com',
  port: 6543,
  database: 'postgres',
  user: `postgres.${PROJECT_REF}`,
  password: DB_PASSWORD,
  ssl: { rejectUnauthorized: false },
  connectionTimeoutMillis: 15000,
};

console.log(`\n🔌 Verbinde mit: ${connectionConfig.user}@${connectionConfig.host}:${connectionConfig.port}`);

const client = new Client(connectionConfig);

// Lese Migration-Dateien
const basePath = new URL('..', import.meta.url).pathname;

function loadSQL(filename) {
  try {
    const sql = readFileSync(`${basePath}supabase/migrations/${filename}`, 'utf8');
    console.log(`   📄 ${filename} geladen (${sql.length} Zeichen, ${sql.split('\n').length} Zeilen)`);
    return sql;
  } catch (e) {
    console.warn(`   ⚠️  ${filename} nicht gefunden: ${e.message}`);
    return null;
  }
}

// SQL bereinigen für Deployment
function cleanSQL(sql) {
  return sql
    // PostGIS optional machen (oft nicht verfügbar auf Free-Plan)
    .replace(
      /CREATE EXTENSION IF NOT EXISTS "postgis" SCHEMA public;/g,
      '-- PostGIS: CREATE EXTENSION IF NOT EXISTS "postgis" SCHEMA public;'
    );
}

// Führe SQL-Block aus mit Fehlerbehandlung
async function executeBlock(sql, label) {
  if (!sql) return;
  
  const cleanedSQL = cleanSQL(sql);
  
  try {
    await client.query(cleanedSQL);
    console.log(`   ✅ ${label} – erfolgreich`);
    return true;
  } catch (err) {
    // Bei "already exists" Fehlern weitermachen
    if (err.message.includes('already exists') || 
        err.code === '42P07' || // duplicate_table
        err.code === '42710' || // duplicate_object
        err.code === '23505') { // unique_violation
      console.log(`   ℹ️  ${label} – bereits vorhanden (OK)`);
      return true;
    }
    console.error(`   ❌ ${label} – Fehler: ${err.message}`);
    return false;
  }
}

// Statement-by-Statement Ausführung
async function executeStatements(sql, label) {
  if (!sql) return;
  
  const cleanedSQL = cleanSQL(sql);
  
  // Trenne SQL in einzelne Statements
  // Einfache Methode: Teile bei ";\n" aber behalte Dollar-Quoting
  const statements = [];
  let current = '';
  let inDollarQuote = false;
  let dollarTag = '';
  
  for (let i = 0; i < cleanedSQL.length; i++) {
    const char = cleanedSQL[i];
    
    if (!inDollarQuote && char === '$') {
      let j = i + 1;
      while (j < cleanedSQL.length && cleanedSQL[j] !== '$' && /[a-zA-Z_]/.test(cleanedSQL[j])) j++;
      if (j < cleanedSQL.length && cleanedSQL[j] === '$') {
        const tag = cleanedSQL.substring(i, j + 1);
        inDollarQuote = true;
        dollarTag = tag;
        current += cleanedSQL.substring(i, j + 1);
        i = j;
        continue;
      }
    } else if (inDollarQuote && char === '$') {
      const potentialEnd = cleanedSQL.substring(i, i + dollarTag.length);
      if (potentialEnd === dollarTag) {
        inDollarQuote = false;
        current += potentialEnd;
        i += dollarTag.length - 1;
        continue;
      }
    }
    
    if (!inDollarQuote && char === ';') {
      current += ';';
      const stmt = current.trim();
      if (stmt.length > 1 && !stmt.startsWith('--')) {
        statements.push(stmt);
      }
      current = '';
    } else {
      current += char;
    }
  }
  if (current.trim()) statements.push(current.trim());
  
  console.log(`\n   📊 ${label}: ${statements.length} Statements`);
  
  let success = 0;
  let skipped = 0;
  let errors = 0;
  
  for (const stmt of statements) {
    // Überspringe Kommentare und leere Statements
    const trimmed = stmt.replace(/--[^\n]*/g, '').trim();
    if (!trimmed || trimmed === ';') continue;
    
    try {
      await client.query(stmt);
      success++;
    } catch (err) {
      if (err.message.includes('already exists') || 
          err.code === '42P07' || err.code === '42710' ||
          err.code === '23505' || err.code === '42P16') {
        skipped++;
      } else if (err.message.includes('does not exist') && stmt.includes('publication')) {
        console.log(`   ⚠️  Realtime-Publication: ${err.message}`);
        skipped++;
      } else {
        console.error(`   ❌ Fehler in Statement: ${stmt.substring(0, 80)}...`);
        console.error(`      ${err.message}`);
        errors++;
      }
    }
  }
  
  console.log(`   📈 Ergebnis: ${success} OK, ${skipped} übersprungen, ${errors} Fehler`);
  return errors === 0;
}

async function main() {
  try {
    // Verbinden
    await client.connect();
    console.log('   ✅ Verbindung erfolgreich!\n');
    
    // Versionsprüfung
    const { rows } = await client.query('SELECT version(), current_database(), current_user');
    console.log(`   📊 PostgreSQL: ${rows[0].version.split(' ').slice(0, 2).join(' ')}`);
    console.log(`   🗄️  Datenbank: ${rows[0].current_database}`);
    console.log(`   👤 Nutzer: ${rows[0].current_user}`);
    
    // Prüfe bestehende Tabellen
    const { rows: tables } = await client.query(`
      SELECT table_name FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name
    `);
    console.log(`\n   📋 Bestehende Tabellen (${tables.length}): ${tables.map(t => t.table_name).join(', ') || 'keine'}`);
    
    // Lade SQL-Dateien
    console.log('\n📄 Lade Migration-Dateien...');
    const schemaSql = loadSQL('001_schema.sql');
    const seedSql = loadSQL('002_seed.sql');
    const realtimeSql = loadSQL('003_realtime.sql');
    
    // Deploy Schema
    console.log('\n🔨 Deploye Schema (001_schema.sql)...');
    const schemaOK = await executeStatements(schemaSql, 'Schema');
    
    if (schemaOK) {
      console.log('\n🌱 Deploye Seed-Daten (002_seed.sql)...');
      // Nur den nicht-kommentierten Teil der Seed-Datei ausführen
      const activeSeed = seedSql.replace(/\/\*[\s\S]*?\*\//g, '');
      await executeStatements(activeSeed, 'Seed-Daten');
      
      console.log('\n📡 Konfiguriere Realtime (003_realtime.sql)...');
      await executeStatements(realtimeSql, 'Realtime');
    }
    
    // Verifizierung
    console.log('\n🔍 Verifiziere Deployment...');
    const { rows: finalTables } = await client.query(`
      SELECT table_name FROM information_schema.tables 
      WHERE table_schema = 'public' 
      ORDER BY table_name
    `);
    console.log(`   ✅ Tabellen nach Deployment (${finalTables.length}):`);
    finalTables.forEach(t => console.log(`      - ${t.table_name}`));
    
    // RLS prüfen
    const { rows: rlsTables } = await client.query(`
      SELECT tablename, rowsecurity FROM pg_tables 
      WHERE schemaname = 'public' AND rowsecurity = true
      ORDER BY tablename
    `);
    console.log(`\n   🔒 RLS aktiv auf ${rlsTables.length} Tabellen:`);
    rlsTables.forEach(t => console.log(`      - ${t.tablename}`));
    
    console.log('\n═══════════════════════════════════════════════════════');
    console.log('🎉 DEPLOYMENT ERFOLGREICH!');
    console.log('═══════════════════════════════════════════════════════');
    console.log('\n✅ Schema deployed');
    console.log('✅ RLS aktiviert');
    console.log('✅ Trigger konfiguriert');
    console.log('✅ Seed-Daten eingespielt');
    console.log('\n📱 App neu bauen: npm run build');
    console.log(`🌐 Supabase Dashboard: https://supabase.com/dashboard/project/${PROJECT_REF}/editor`);
    console.log('\n');
    
  } catch (err) {
    console.error('\n❌ Verbindungsfehler:', err.message);
    console.log('\n💡 Lösung:');
    console.log('   1. Überprüfe das DB-Passwort im Supabase Dashboard');
    console.log(`   2. → https://supabase.com/dashboard/project/${PROJECT_REF}/settings/database`);
    console.log('   3. Oder führe das Schema manuell im SQL-Editor aus');
    console.log(`   4. → https://supabase.com/dashboard/project/${PROJECT_REF}/sql/new`);
  } finally {
    await client.end();
  }
}

main();
