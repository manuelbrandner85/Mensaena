import { createServer } from 'http'
import { readFileSync } from 'fs'

const schema = readFileSync('./supabase/migrations/001_schema.sql', 'utf8')
const seed = readFileSync('./supabase/migrations/002_seed.sql', 'utf8')
const realtime = readFileSync('./supabase/migrations/003_realtime.sql', 'utf8')

const html = `<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Mensaena – SQL Schema Deployment</title>
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Inter', sans-serif; background: #F6FBF6; color: #1a1a1a; }
  .header { background: linear-gradient(135deg, #388E3C, #66BB6A); padding: 2rem; color: white; }
  .header h1 { font-size: 1.75rem; font-weight: 800; }
  .header p { opacity: 0.9; margin-top: 0.5rem; font-size: 0.95rem; }
  .container { max-width: 1000px; margin: 0 auto; padding: 2rem; }
  .step { background: white; border-radius: 16px; padding: 1.5rem; margin-bottom: 1.5rem; border: 1px solid #e8f5e9; box-shadow: 0 2px 8px rgba(0,0,0,0.05); }
  .step-header { display: flex; align-items: center; gap: 1rem; margin-bottom: 1rem; }
  .step-num { width: 36px; height: 36px; background: #66BB6A; color: white; border-radius: 50%; display: flex; align-items: center; justify-content: center; font-weight: 800; font-size: 1rem; flex-shrink: 0; }
  .step h2 { font-size: 1.1rem; font-weight: 700; color: #1B5E20; }
  .step p { font-size: 0.875rem; color: #555; margin-bottom: 1rem; line-height: 1.6; }
  .copy-btn { display: inline-flex; align-items: center; gap: 0.5rem; padding: 0.6rem 1.25rem; background: #66BB6A; color: white; border: none; border-radius: 10px; font-size: 0.875rem; font-weight: 600; cursor: pointer; transition: all 0.2s; margin-bottom: 0.75rem; }
  .copy-btn:hover { background: #388E3C; transform: translateY(-1px); }
  .copy-btn.copied { background: #2E7D32; }
  pre { background: #0d1117; color: #e6edf3; border-radius: 10px; padding: 1.25rem; overflow-x: auto; font-size: 0.8rem; line-height: 1.5; max-height: 300px; overflow-y: auto; }
  .link { display: inline-flex; align-items: center; gap: 0.5rem; padding: 0.75rem 1.5rem; background: #4F6D8A; color: white; text-decoration: none; border-radius: 12px; font-weight: 600; font-size: 0.875rem; transition: all 0.2s; }
  .link:hover { background: #3D5A73; transform: translateY(-1px); }
  .info { background: #EFF4FA; border: 1px solid #ADC8E1; border-radius: 12px; padding: 1rem; margin-bottom: 1.5rem; font-size: 0.875rem; color: #2C4157; }
  .success { background: #e8f5e9; border: 1px solid #A5D6A7; border-radius: 12px; padding: 1rem; margin-bottom: 1.5rem; font-size: 0.875rem; color: #1B5E20; }
</style>
</head>
<body>
<div class="header">
  <h1>🌿 Mensaena – SQL Schema Deployment</h1>
  <p>Führe diese 3 Migrationen nacheinander im Supabase SQL Editor aus</p>
</div>
<div class="container">
  <div class="info">
    <strong>📋 Anleitung:</strong> Öffne den Supabase SQL Editor für dein Projekt, 
    kopiere jedes SQL-Script und führe es aus. Beginne mit Script 1, dann 2, dann 3.
  </div>
  
  <div style="margin-bottom: 1.5rem;">
    <a href="https://supabase.com/dashboard/project/huaqldjkgyosefzfhjnf/sql/new" 
       target="_blank" class="link">
      🔗 Supabase SQL Editor öffnen →
    </a>
  </div>

  <div class="step">
    <div class="step-header">
      <div class="step-num">1</div>
      <h2>Schema – Tabellen, Trigger, RLS Policies</h2>
    </div>
    <p>Erstellt alle Tabellen: profiles, posts, interactions, conversations, messages, saved_posts, notifications, trust_ratings, regions. Enthält Trigger für updated_at und auto-Profil-Erstellung, sowie alle Row Level Security Policies.</p>
    <button class="copy-btn" onclick="copySQL('sql1', this)">📋 Script 1 kopieren</button>
    <pre id="sql1">${schema.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</pre>
  </div>

  <div class="step">
    <div class="step-header">
      <div class="step-num">2</div>
      <h2>Seed Data – Regionen</h2>
    </div>
    <p>Fügt Demo-Regionen (München, Berlin, Hamburg, Köln) ein. Testdaten für Posts werden nach der ersten Registrierung über die App erstellt.</p>
    <button class="copy-btn" onclick="copySQL('sql2', this)">📋 Script 2 kopieren</button>
    <pre id="sql2">${seed.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</pre>
  </div>

  <div class="step">
    <div class="step-header">
      <div class="step-num">3</div>
      <h2>Realtime – Live-Updates für Chat und Karte</h2>
    </div>
    <p>Aktiviert Supabase Realtime für: messages (Chat), notifications (Benachrichtigungen), posts (Live-Karten-Updates).</p>
    <button class="copy-btn" onclick="copySQL('sql3', this)">📋 Script 3 kopieren</button>
    <pre id="sql3">${realtime.replace(/</g, '&lt;').replace(/>/g, '&gt;')}</pre>
  </div>

  <div class="success">
    <strong>✅ Nach dem Deployment:</strong> Alle 3 Scripts erfolgreich ausgeführt? 
    Die Mensaena App ist dann vollständig mit deiner Supabase-Datenbank verbunden!
    Registriere dich über <strong>/register</strong> um das erste Profil anzulegen.
  </div>
</div>

<script>
function copySQL(id, btn) {
  const pre = document.getElementById(id);
  const text = pre.innerText;
  navigator.clipboard.writeText(text).then(() => {
    btn.textContent = '✅ Kopiert!';
    btn.classList.add('copied');
    setTimeout(() => {
      btn.textContent = '📋 Script ' + id.replace('sql', '') + ' kopieren';
      btn.classList.remove('copied');
    }, 2000);
  });
}
</script>
</body>
</html>`

const server = createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' })
  res.end(html)
})

server.listen(3001, '0.0.0.0', () => {
  console.log('📋 Schema Viewer läuft auf Port 3001')
})
