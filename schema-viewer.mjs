#!/usr/bin/env node
/**
 * MENSAENA – Schema Viewer mit direktem Copy-Button
 * Läuft auf Port 3001 – zeigt das fertige SQL zum Kopieren in den Supabase SQL Editor
 */

import { createServer } from 'http';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const __dirname = dirname(fileURLToPath(import.meta.url));
const basePath = __dirname;

function loadSQL() {
  try {
    const schema = readFileSync(join(basePath, 'supabase/migrations/001_schema.sql'), 'utf8');
    const seed = readFileSync(join(basePath, 'supabase/migrations/002_seed.sql'), 'utf8');
    const realtime = readFileSync(join(basePath, 'supabase/migrations/003_realtime.sql'), 'utf8');
    
    const cleanSchema = schema
      .replace(
        'CREATE EXTENSION IF NOT EXISTS "postgis" SCHEMA public;',
        '-- PostGIS optional: CREATE EXTENSION IF NOT EXISTS "postgis" SCHEMA public;'
      );
    
    const cleanSeed = seed.replace(/\/\*[\s\S]*?\*\//g, '-- Demo Posts werden über die App erstellt');

    return `-- ============================================================
-- MENSAENA – Vollständiges Schema Deployment
-- Einfach diesen gesamten Text kopieren und im Supabase SQL Editor ausführen
-- ============================================================

${cleanSchema}

-- ============================================================
-- SEED DATA (Regionen)
-- ============================================================
${cleanSeed}

-- ============================================================  
-- REALTIME KONFIGURATION
-- ============================================================
${realtime}

-- ============================================================
-- FERTIG!
-- ============================================================
SELECT 
  'Mensaena Schema erfolgreich deployed! 🎉' as status,
  NOW() as timestamp,
  current_database() as database;
`;
  } catch(e) {
    return `-- Fehler beim Laden: ${e.message}`;
  }
}

const server = createServer((req, res) => {
  if (req.url === '/sql') {
    // Raw SQL endpoint
    res.writeHead(200, { 
      'Content-Type': 'text/plain; charset=utf-8',
      'Content-Disposition': 'attachment; filename="mensaena_schema.sql"'
    });
    res.end(loadSQL());
    return;
  }
  
  const sql = loadSQL();
  const sqlEscaped = sql
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
  
  const PROJECT_REF = 'huaqldjkgyosefzfhjnf';
  
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
  res.end(`<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Mensaena – Schema Deployment</title>
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body { 
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
      background: #0f172a; color: #e2e8f0; min-height: 100vh;
      padding: 24px;
    }
    .header {
      max-width: 1000px; margin: 0 auto 24px;
      background: linear-gradient(135deg, #1e293b, #0f3460);
      border: 1px solid #334155; border-radius: 16px;
      padding: 28px 32px;
    }
    .header h1 { font-size: 28px; color: #a5d6a7; margin-bottom: 8px; }
    .header p { color: #94a3b8; font-size: 15px; }
    
    .steps {
      max-width: 1000px; margin: 0 auto 24px;
      display: grid; grid-template-columns: repeat(3, 1fr); gap: 16px;
    }
    .step {
      background: #1e293b; border: 1px solid #334155;
      border-radius: 12px; padding: 20px;
      transition: border-color 0.2s;
    }
    .step:hover { border-color: #a5d6a7; }
    .step-num {
      width: 36px; height: 36px; border-radius: 50%;
      background: linear-gradient(135deg, #66bb6a, #a5d6a7);
      color: #0f172a; font-weight: 800; font-size: 16px;
      display: flex; align-items: center; justify-content: center;
      margin-bottom: 12px;
    }
    .step h3 { color: #f1f5f9; font-size: 15px; margin-bottom: 6px; }
    .step p { color: #64748b; font-size: 13px; line-height: 1.5; }
    .step a {
      display: inline-block; margin-top: 10px;
      color: #a5d6a7; text-decoration: none; font-size: 13px;
      border: 1px solid #a5d6a7; border-radius: 6px; padding: 4px 10px;
      transition: all 0.2s;
    }
    .step a:hover { background: #a5d6a7; color: #0f172a; }
    
    .sql-container {
      max-width: 1000px; margin: 0 auto;
      background: #1e293b; border: 1px solid #334155;
      border-radius: 16px; overflow: hidden;
    }
    .sql-header {
      background: #0f3460; padding: 16px 24px;
      display: flex; align-items: center; justify-content: space-between;
      border-bottom: 1px solid #334155;
    }
    .sql-header span { color: #a5d6a7; font-weight: 600; font-size: 15px; }
    .sql-info { color: #64748b; font-size: 13px; }
    
    .btn-copy {
      background: linear-gradient(135deg, #66bb6a, #a5d6a7);
      color: #0f172a; border: none; border-radius: 8px;
      padding: 10px 20px; font-size: 14px; font-weight: 700;
      cursor: pointer; transition: all 0.2s;
      display: flex; align-items: center; gap: 8px;
    }
    .btn-copy:hover { transform: translateY(-1px); box-shadow: 0 4px 12px rgba(165,214,167,0.3); }
    .btn-copy.copied { background: linear-gradient(135deg, #22c55e, #4ade80); }
    
    .sql-code {
      background: #0d1117; padding: 20px 24px;
      max-height: 500px; overflow-y: auto;
      font-family: 'JetBrains Mono', 'Fira Code', 'Courier New', monospace;
      font-size: 12px; line-height: 1.7; color: #c9d1d9;
      white-space: pre; overflow-x: auto;
    }
    .sql-code::-webkit-scrollbar { width: 8px; height: 8px; }
    .sql-code::-webkit-scrollbar-track { background: #1e293b; }
    .sql-code::-webkit-scrollbar-thumb { background: #334155; border-radius: 4px; }
    
    .badge {
      display: inline-flex; align-items: center; gap: 6px;
      background: #0f3460; border: 1px solid #1e40af;
      color: #93c5fd; padding: 4px 10px; border-radius: 20px;
      font-size: 12px; font-weight: 500;
    }
    .badge.green { background: #052e16; border-color: #166534; color: #86efac; }
    .badge.yellow { background: #422006; border-color: #92400e; color: #fcd34d; }
    
    .actions {
      max-width: 1000px; margin: 24px auto;
      display: flex; gap: 12px; flex-wrap: wrap;
    }
    .btn {
      padding: 12px 24px; border-radius: 10px; font-size: 14px;
      font-weight: 600; text-decoration: none; display: inline-flex;
      align-items: center; gap: 8px; border: none; cursor: pointer;
      transition: all 0.2s;
    }
    .btn-primary {
      background: linear-gradient(135deg, #66bb6a, #a5d6a7);
      color: #0f172a;
    }
    .btn-primary:hover { transform: translateY(-1px); box-shadow: 0 4px 16px rgba(165,214,167,0.3); }
    .btn-secondary {
      background: #1e293b; color: #e2e8f0;
      border: 1px solid #334155;
    }
    .btn-secondary:hover { border-color: #a5d6a7; }
    
    .warning {
      max-width: 1000px; margin: 0 auto 20px;
      background: #2d1810; border: 1px solid #92400e;
      border-radius: 12px; padding: 16px 20px;
      color: #fcd34d; font-size: 14px; line-height: 1.5;
    }
  </style>
</head>
<body>
  <div class="header">
    <h1>🌿 Mensaena – Schema Deployment</h1>
    <p>
      <span class="badge green">✅ API aktiv</span>&nbsp;
      <span class="badge">Projekt: ${PROJECT_REF}</span>&nbsp;
      <span class="badge yellow">⏳ Schema noch nicht deployed</span>
    </p>
  </div>
  
  <div class="steps">
    <div class="step">
      <div class="step-num">1</div>
      <h3>SQL Editor öffnen</h3>
      <p>Öffne den Supabase SQL Editor für dein Projekt</p>
      <a href="https://supabase.com/dashboard/project/${PROJECT_REF}/sql/new" target="_blank">
        → SQL Editor öffnen
      </a>
    </div>
    <div class="step">
      <div class="step-num">2</div>
      <h3>SQL kopieren</h3>
      <p>Kopiere das gesamte SQL-Schema über den grünen Button unten</p>
    </div>
    <div class="step">
      <div class="step-num">3</div>
      <h3>Ausführen (Run ▶)</h3>
      <p>Füge das SQL ein und klicke auf <strong>Run</strong> – fertig in ~5 Sekunden!</p>
    </div>
  </div>
  
  <div class="actions">
    <a class="btn btn-primary" href="https://supabase.com/dashboard/project/${PROJECT_REF}/sql/new" target="_blank">
      → Supabase SQL Editor öffnen
    </a>
    <a class="btn btn-secondary" href="/sql" target="_blank">
      ⬇ SQL-Datei herunterladen
    </a>
  </div>
  
  <div class="sql-container">
    <div class="sql-header">
      <div>
        <span>📋 mensaena_schema.sql</span>
        <div class="sql-info" style="margin-top:4px">${sql.split('\n').length} Zeilen · ${sql.length.toLocaleString()} Zeichen · Vollständiges Schema + Seed + Realtime</div>
      </div>
      <button class="btn-copy" id="copyBtn" onclick="copySQL()">
        <span id="copyIcon">📋</span>
        <span id="copyText">Alles kopieren</span>
      </button>
    </div>
    <div class="sql-code" id="sqlCode">${sqlEscaped}</div>
  </div>

  <script>
    const sql = ${JSON.stringify(sql)};
    
    function copySQL() {
      navigator.clipboard.writeText(sql).then(() => {
        const btn = document.getElementById('copyBtn');
        const icon = document.getElementById('copyIcon');
        const text = document.getElementById('copyText');
        btn.classList.add('copied');
        icon.textContent = '✅';
        text.textContent = 'Kopiert! Jetzt in SQL Editor einfügen';
        setTimeout(() => {
          btn.classList.remove('copied');
          icon.textContent = '📋';
          text.textContent = 'Alles kopieren';
        }, 3000);
      }).catch(err => {
        // Fallback
        const textarea = document.createElement('textarea');
        textarea.value = sql;
        document.body.appendChild(textarea);
        textarea.select();
        document.execCommand('copy');
        document.body.removeChild(textarea);
        alert('✅ SQL kopiert! Jetzt in den Supabase SQL Editor einfügen.');
      });
    }
  </script>
</body>
</html>`);
});

server.listen(3001, '0.0.0.0', () => {
  console.log('🌿 Mensaena Schema Viewer läuft auf Port 3001');
});
