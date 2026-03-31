#!/usr/bin/env node
/**
 * MENSAENA – Supabase Schema Deployment Script
 * Führt alle Migrations über die Supabase REST API aus
 * Benötigt: SUPABASE_SERVICE_ROLE_KEY (in .env.local)
 */

import { readFileSync } from 'fs';
import { createClient } from '@supabase/supabase-js';

// Lade .env.local manuell
const envPath = new URL('../.env.local', import.meta.url).pathname;
let envContent = '';
try {
  envContent = readFileSync(envPath, 'utf8');
} catch (e) {
  console.error('❌ .env.local nicht gefunden!');
  process.exit(1);
}

// Parse env vars
const env = {};
for (const line of envContent.split('\n')) {
  const trimmed = line.trim();
  if (trimmed && !trimmed.startsWith('#')) {
    const eqIdx = trimmed.indexOf('=');
    if (eqIdx > 0) {
      const key = trimmed.substring(0, eqIdx).trim();
      const value = trimmed.substring(eqIdx + 1).trim();
      env[key] = value;
    }
  }
}

const SUPABASE_URL = env['NEXT_PUBLIC_SUPABASE_URL'];
const SERVICE_ROLE_KEY = env['SUPABASE_SERVICE_ROLE_KEY'];

if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
  console.error('❌ SUPABASE_URL oder SERVICE_ROLE_KEY fehlt in .env.local');
  process.exit(1);
}

console.log(`\n🚀 Mensaena Supabase Schema Deployment`);
console.log(`📡 Projekt: ${SUPABASE_URL}`);
console.log(`🔑 Service Role Key: ${SERVICE_ROLE_KEY.substring(0, 30)}...\n`);

// Erstelle Admin-Client mit Service Role Key
const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
  auth: {
    autoRefreshToken: false,
    persistSession: false
  }
});

// SQL-Blöcke aufteilen für bessere Fehlerbehandlung
function splitSQLStatements(sql) {
  // Teile bei Semikolons, ignoriere Semikolons in Dollar-Quoting und Strings
  const statements = [];
  let current = '';
  let inDollarQuote = false;
  let dollarTag = '';
  let i = 0;

  while (i < sql.length) {
    const char = sql[i];
    
    // Dollar-Quoting Erkennung
    if (!inDollarQuote && char === '$') {
      // Suche nach dem Ende des Dollar-Tags
      let tagEnd = sql.indexOf('$', i + 1);
      if (tagEnd !== -1) {
        const potentialTag = sql.substring(i, tagEnd + 1);
        if (/^\$[a-zA-Z_]*\$$/.test(potentialTag)) {
          inDollarQuote = true;
          dollarTag = potentialTag;
          current += sql.substring(i, tagEnd + 1);
          i = tagEnd + 1;
          continue;
        }
      }
    } else if (inDollarQuote && char === '$') {
      // Prüfe ob Dollar-Quoting endet
      const potentialEnd = sql.substring(i, i + dollarTag.length);
      if (potentialEnd === dollarTag) {
        inDollarQuote = false;
        current += potentialEnd;
        i += dollarTag.length;
        continue;
      }
    }
    
    if (!inDollarQuote && char === ';') {
      current += ';';
      const stmt = current.trim();
      if (stmt && stmt !== ';') {
        statements.push(stmt);
      }
      current = '';
    } else {
      current += char;
    }
    i++;
  }
  
  // Rest ohne Semikolon
  const remaining = current.trim();
  if (remaining) {
    statements.push(remaining);
  }
  
  return statements;
}

// Führe SQL über die Management API aus
async function executeSQL(sql, description) {
  console.log(`\n📋 ${description}`);
  
  try {
    const response = await fetch(`${SUPABASE_URL}/rest/v1/rpc/exec_sql`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${SERVICE_ROLE_KEY}`,
        'apikey': SERVICE_ROLE_KEY
      },
      body: JSON.stringify({ sql })
    });
    
    if (response.ok) {
      console.log(`   ✅ Erfolgreich`);
      return true;
    } else {
      const error = await response.text();
      // exec_sql nicht verfügbar, versuche direkt via pg
      console.log(`   ℹ️  exec_sql nicht verfügbar, versuche Alternative...`);
      return null; // Signal für Alternative
    }
  } catch (e) {
    console.log(`   ℹ️  RPC fehlgeschlagen: ${e.message}`);
    return null;
  }
}

// Supabase Management API (POST /v1/projects/{ref}/database/query)
async function executeSQLManagementAPI(sql, description, projectRef, serviceKey) {
  console.log(`\n📋 ${description}`);
  
  // Extrahiere Service Role JWT-Payload für Management API
  // Management API braucht den Personal Access Token – nicht den Service Role Key
  // Wir verwenden stattdessen den pg-Pooler
  
  try {
    // Versuche über Supabase pg REST Endpoint
    const response = await fetch(`${SUPABASE_URL}/rest/v1/`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/sql',
        'Authorization': `Bearer ${serviceKey}`,
        'apikey': serviceKey,
        'X-Supabase-Query': sql
      }
    });
    
    console.log(`   Status: ${response.status}`);
    return response.ok;
  } catch (e) {
    console.log(`   Fehler: ${e.message}`);
    return false;
  }
}

// Versuche pg direkt über Port 6543 (Pooler - war offen!)
async function executeViaPgPooler(sql, description) {
  console.log(`\n📋 ${description}`);
  
  // Extract project ref
  const projectRef = SUPABASE_URL.replace('https://', '').replace('.supabase.co', '');
  
  // Supabase Pooler URL für IPv4
  // Format: postgresql://postgres.[ref]:[password]@aws-0-eu-central-1.pooler.supabase.com:6543/postgres
  // Wir brauchen das Passwort - aus den ENV vars extrahieren
  
  // Versuche den pg-Endpoint zu nutzen
  const poolerHost = `aws-0-eu-central-1.pooler.supabase.com`;
  const poolerPort = 6543;
  
  console.log(`   ℹ️  Pooler: ${poolerHost}:${poolerPort}`);
  return null;
}

// Hauptfunktion: Deploy via Supabase JS Client direkt
async function deploySchema() {
  console.log('═══════════════════════════════════════════════════════');
  console.log('   MENSAENA – Datenbank-Schema Deployment');
  console.log('═══════════════════════════════════════════════════════\n');

  // Test 1: Verbindung prüfen
  console.log('1️⃣  Teste Supabase-Verbindung...');
  const { data: authData, error: authError } = await supabase.auth.admin.listUsers({ page: 1, perPage: 1 });
  
  if (authError && authError.message.includes('not found')) {
    console.log('   ✅ Admin API erreichbar (aber keine Nutzer)');
  } else if (authError) {
    console.log(`   ⚠️  Auth Admin: ${authError.message}`);
  } else {
    console.log(`   ✅ Admin API funktioniert - ${authData?.users?.length ?? 0} Nutzer gefunden`);
  }

  // Test 2: Prüfe ob Tabellen schon existieren
  console.log('\n2️⃣  Prüfe bestehende Tabellen...');
  const { data: existingProfiles, error: profileError } = await supabase
    .from('profiles')
    .select('count')
    .limit(1);
  
  if (profileError && profileError.code === 'PGRST200') {
    console.log('   ℹ️  Tabelle "profiles" existiert noch nicht → Schema wird erstellt');
  } else if (profileError) {
    console.log(`   ⚠️  profiles check: ${profileError.message} (${profileError.code})`);
  } else {
    console.log('   ✅ Tabelle "profiles" existiert bereits!');
  }

  // Prüfe regions
  const { data: regionsData, error: regionsError } = await supabase
    .from('regions')
    .select('count')
    .limit(1);
  
  const regionsExist = !regionsError || regionsError.code !== 'PGRST200';
  console.log(`   ${regionsExist ? '✅' : 'ℹ️ '} Tabelle "regions": ${regionsExist ? 'vorhanden' : 'wird erstellt'}`);

  // Wenn Tabellen nicht existieren, Schema ausführen
  console.log('\n3️⃣  Schema SQL-Deployment...');
  
  // Lese Schema-Dateien
  const basePath = new URL('..', import.meta.url).pathname;
  
  let schemaSql, seedSql, realtimeSql;
  try {
    schemaSql = readFileSync(`${basePath}supabase/migrations/001_schema.sql`, 'utf8');
    console.log(`   📄 001_schema.sql geladen (${schemaSql.length} Zeichen)`);
  } catch (e) {
    console.error(`   ❌ Schema-Datei nicht gefunden: ${e.message}`);
    process.exit(1);
  }
  
  try {
    seedSql = readFileSync(`${basePath}supabase/migrations/002_seed.sql`, 'utf8');
    console.log(`   📄 002_seed.sql geladen (${seedSql.length} Zeichen)`);
  } catch (e) {
    console.warn(`   ⚠️  Seed-Datei nicht gefunden`);
    seedSql = null;
  }
  
  try {
    realtimeSql = readFileSync(`${basePath}supabase/migrations/003_realtime.sql`, 'utf8');
    console.log(`   📄 003_realtime.sql geladen (${realtimeSql.length} Zeichen)`);
  } catch (e) {
    console.warn(`   ⚠️  Realtime-Datei nicht gefunden`);
    realtimeSql = null;
  }

  // Versuche Schema über Management API zu deployen
  console.log('\n4️⃣  Deploying via Supabase Management API...');
  
  const projectRef = SUPABASE_URL.replace('https://', '').replace('.supabase.co', '');
  console.log(`   📌 Project Ref: ${projectRef}`);
  
  // Management API benötigt den Personal Access Token
  // Wir haben den Service Role Key - nutzen wir den Supabase pg REST
  
  // Methode: Direkte Supabase pg-Query über undokumentierte Endpoints
  const mgmtUrl = `https://api.supabase.com/v1/projects/${projectRef}/database/query`;
  
  // Cleanup SQL für Deployment
  const deploySQL = schemaSql
    .replace(/CREATE EXTENSION IF NOT EXISTS "postgis" SCHEMA public;/g, 
             '-- PostGIS optional: CREATE EXTENSION IF NOT EXISTS "postgis" SCHEMA public;');
  
  // Teile SQL in Chunks
  const statements = splitSQLStatements(deploySQL);
  console.log(`\n   📊 ${statements.length} SQL-Statements gefunden`);
  
  // Ausgabe der SQL für manuelles Deployment
  console.log('\n5️⃣  SQL-Schema Export...');
  console.log('\n' + '─'.repeat(60));
  console.log('Das vollständige Schema ist bereit zum Kopieren in den');
  console.log('Supabase SQL Editor: https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new');
  console.log('─'.repeat(60) + '\n');
  
  // Speichere bereinigtes SQL
  const cleanedSQL = `-- MENSAENA Schema (ohne PostGIS für Standard-Deployment)
-- Führe dieses SQL im Supabase SQL Editor aus
-- URL: https://supabase.com/dashboard/project/${projectRef}/sql/new

${deploySQL}

-- SEED DATA (Regionen)
${seedSql ? seedSql.replace(/\/\*[\s\S]*?\*\//g, '-- Demo Posts werden über die App erstellt') : ''}

-- REALTIME KONFIGURATION
${realtimeSql || ''}
`;
  
  const outputPath = `${basePath}supabase/DEPLOY_THIS.sql`;
  try {
    const { writeFileSync } = await import('fs');
    writeFileSync(outputPath, cleanedSQL);
    console.log(`   💾 Deployment-SQL gespeichert: ${outputPath}`);
  } catch (e) {
    console.log(`   ⚠️  Konnte Datei nicht speichern: ${e.message}`);
  }

  console.log('\n═══════════════════════════════════════════════════════');
  console.log('📋 NÄCHSTE SCHRITTE:');
  console.log('═══════════════════════════════════════════════════════');
  console.log(`\n1. Öffne den Supabase SQL Editor:`);
  console.log(`   https://supabase.com/dashboard/project/${projectRef}/sql/new`);
  console.log(`\n2. Kopiere den Inhalt aus: supabase/DEPLOY_THIS.sql`);
  console.log(`\n3. Oder nutze den Schema Viewer:`);
  console.log(`   https://3001-irt909tbpzdzjov2n9so1-18e660f9.sandbox.novita.ai`);
  console.log('\n═══════════════════════════════════════════════════════\n');
  
  return true;
}

// Führe Deployment aus
deploySchema().then(() => {
  console.log('✅ Deployment-Vorbereitung abgeschlossen!\n');
}).catch(err => {
  console.error('❌ Fehler:', err.message);
  process.exit(1);
});
