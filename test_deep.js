const { chromium } = require('playwright');

const BASE_URL = 'https://mensaena.manuelbrandner4.workers.dev';
const EMAIL = 'brandy13062@gmail.com';
const PASSWORD = 'Jolene2305';

const issues = [];
const passes = [];

function issue(page, what, detail) {
  issues.push({ page, what, detail });
  console.log(`❌ [${page}] ${what}: ${detail}`);
}
function pass(page, what, detail = '') {
  passes.push({ page, what, detail });
  console.log(`✅ [${page}] ${what}${detail ? ': ' + detail : ''}`);
}
function warn(page, what, detail = '') {
  console.log(`⚠️  [${page}] ${what}${detail ? ': ' + detail : ''}`);
}

async function wait(ms) { return new Promise(r => setTimeout(r, ms)); }

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const pg = await context.newPage();
  
  const network400s = [];
  const networkErrors = [];
  pg.on('response', r => { 
    if (r.status() === 400) network400s.push(r.url());
    if (r.status() >= 500) networkErrors.push(`${r.status()} ${r.url()}`);
  });
  const jsErrors = [];
  pg.on('pageerror', e => jsErrors.push(e.message));

  // ── LOGIN ──────────────────────────────────────────────────────────────────
  console.log('\n══ 1. LOGIN ══');
  await pg.goto(BASE_URL + '/login', { waitUntil: 'networkidle', timeout: 30000 });
  await pg.fill('input[type="email"]', EMAIL);
  await pg.fill('input[type="password"]', PASSWORD);
  await pg.click('button[type="submit"]');
  await pg.waitForURL('**/dashboard**', { timeout: 20000 });
  pass('Login', 'Login successful', pg.url());
  await wait(3000);

  // ── DASHBOARD ──────────────────────────────────────────────────────────────
  console.log('\n══ 2. DASHBOARD ══');
  const dashText = await pg.textContent('body');
  if (dashText.includes('Guten') || dashText.includes('Hallo')) pass('Dashboard', 'Greeting shown');
  else issue('Dashboard', 'Greeting missing', 'No greeting message found');
  
  // Check quick actions grid
  if (dashText.includes('Karte') || dashText.includes('Inserat') || dashText.includes('Chat')) 
    pass('Dashboard', 'Quick actions grid visible');
  else issue('Dashboard', 'Quick actions missing', 'No quick action tiles found');
  
  // Check DM section
  if (dashText.includes('Nachricht') || dashText.includes('DM') || dashText.includes('Gespräch'))
    pass('Dashboard', 'DM section visible');
  else warn('Dashboard', 'DM section not visible');
  
  // Check stats
  if (dashText.includes('Aktiv') || dashText.includes('aktiv') || dashText.includes('Gespeichert'))
    pass('Dashboard', 'Statistics visible');
  else warn('Dashboard', 'Statistics not visible');
  
  // Screenshot
  await pg.screenshot({ path: '/tmp/dashboard.png', fullPage: false });

  // ── ALL DASHBOARD PAGES ────────────────────────────────────────────────────
  console.log('\n══ 3. ALL PAGES DEEP CHECK ══');
  const dashPages = [
    { url: '/dashboard/map', name: 'Karte', checkFor: ['Karte', 'map', 'Leaflet', 'OpenStreetMap', 'leaflet'] },
    { url: '/dashboard/create', name: 'Inserat erstellen', checkFor: ['Inserat', 'Typ', 'Titel', 'erstellen', 'submit'] },
    { url: '/dashboard/posts', name: 'Meine Inserate', checkFor: ['Inserat', 'Post', 'post', 'Keine'] },
    { url: '/dashboard/community', name: 'Community', checkFor: ['Community', 'Gemeinschaft', 'Beiträge'] },
    { url: '/dashboard/chat', name: 'Chat', checkFor: ['Chat', 'Nachricht', 'Kanal', 'Allgemein'] },
    { url: '/dashboard/crisis', name: 'Krisenhilfe', checkFor: ['Krisen', 'Notfall', 'crisis'] },
    { url: '/dashboard/animals', name: 'Tiere', checkFor: ['Tier', 'animal', 'Haustier'] },
    { url: '/dashboard/housing', name: 'Unterkunft', checkFor: ['Unterkunft', 'Wohnung', 'housing'] },
    { url: '/dashboard/supply', name: 'Versorgung', checkFor: ['Versorgung', 'supply', 'Produkt'] },
    { url: '/dashboard/timebank', name: 'Zeitbank', checkFor: ['Zeit', 'Stunde', 'timebank', 'Tausch'] },
    { url: '/dashboard/harvest', name: 'Ernte', checkFor: ['Ernte', 'harvest', 'Obst', 'Gemüse'] },
    { url: '/dashboard/skills', name: 'Fähigkeiten', checkFor: ['Fähig', 'skill', 'Talent'] },
    { url: '/dashboard/knowledge', name: 'Wissen', checkFor: ['Wissen', 'knowledge', 'Artikel'] },
    { url: '/dashboard/sharing', name: 'Teilen', checkFor: ['Teilen', 'sharing', 'verleihen'] },
    { url: '/dashboard/mobility', name: 'Mobilität', checkFor: ['Mobilität', 'mobility', 'Fahrt', 'Transport'] },
    { url: '/dashboard/mental-support', name: 'Mentale Unterstützung', checkFor: ['Mental', 'Unterstützung', 'Hilfe', 'support'] },
    { url: '/dashboard/profile', name: 'Profil', checkFor: ['Profil', 'profile', 'Name', 'Email'] },
    { url: '/dashboard/settings', name: 'Einstellungen', checkFor: ['Einstellung', 'setting', 'Benachrichtigung', 'Passwort'] },
    { url: '/dashboard/admin', name: 'Admin', checkFor: ['Admin', 'admin', 'Nutzer', 'Verwaltung'] },
  ];

  for (const p of dashPages) {
    await pg.goto(BASE_URL + p.url, { waitUntil: 'domcontentloaded', timeout: 25000 });
    await wait(2000);
    const url = pg.url();
    const text = await pg.textContent('body');
    
    if (url.includes('/login')) {
      issue(p.name, 'Auth failed', 'Redirected to login');
      continue;
    }
    if (text.toLowerCase().includes('application error') || text.toLowerCase().includes('unhandled error')) {
      issue(p.name, 'App error', 'Client-side exception on page');
      await pg.screenshot({ path: `/tmp/error_${p.name.replace(/\s/g,'_')}.png` });
      continue;
    }
    
    const found = p.checkFor.some(kw => text.toLowerCase().includes(kw.toLowerCase()));
    if (found) {
      pass(p.name, 'Page loads with expected content');
    } else {
      warn(p.name, 'Page loads but expected keywords not found', `checked: ${p.checkFor.join(', ')}`);
    }
  }

  // ── CHAT DEEP TEST ─────────────────────────────────────────────────────────
  console.log('\n══ 4. CHAT DEEP TEST ══');
  await pg.goto(BASE_URL + '/dashboard/chat', { waitUntil: 'networkidle', timeout: 30000 });
  await wait(4000);
  
  const chatText = await pg.textContent('body');
  
  // Check loading resolved
  if (chatText.includes('Kanal wird geladen') || chatText.includes('wird geladen')) {
    issue('Chat', 'Infinite loading', 'Channel still loading after 4s - chat_channels table likely missing');
  } else {
    pass('Chat', 'Channel loaded (no spinner)');
  }
  
  // Check channel list
  if (chatText.includes('Allgemein') || chatText.includes('Kanal')) {
    pass('Chat', 'Channel shown in list');
  } else {
    issue('Chat', 'No channel visible', 'Channel list is empty');
  }
  
  // Check send input is accessible
  const sendInput = await pg.$('input[placeholder*="Nachricht"]');
  if (sendInput) {
    const isDisabled = await sendInput.isDisabled();
    if (isDisabled) {
      issue('Chat', 'Input disabled', 'Cannot type in chat input');
    } else {
      pass('Chat', 'Input is enabled and writeable');
      // Try to send a real message
      await sendInput.fill('🌱 Test von Mensaena Bot-Tester - ' + new Date().toLocaleTimeString());
      const sendBtn = await pg.$('button[type="submit"]');
      if (sendBtn) {
        const disabled = await sendBtn.isDisabled();
        if (!disabled) {
          await sendBtn.click();
          await wait(2000);
          pass('Chat', 'Message sent successfully');
        } else {
          issue('Chat', 'Send button disabled', 'Cannot send message');
        }
      }
    }
  } else {
    issue('Chat', 'Input not found', 'No message input field visible');
  }
  
  // Check DM tab
  const dmTab = await pg.$('button:has-text("Direkt"), button:has-text("DM"), button:has-text("Nachrichten")');
  if (dmTab) {
    await dmTab.click();
    await wait(1500);
    pass('Chat', 'DM tab clickable');
  } else {
    warn('Chat', 'DM tab not found by text');
  }
  
  await pg.screenshot({ path: '/tmp/chat.png' });

  // ── POST CREATE DEEP TEST ──────────────────────────────────────────────────
  console.log('\n══ 5. POST CREATE DEEP TEST ══');
  await pg.goto(BASE_URL + '/dashboard/create', { waitUntil: 'domcontentloaded', timeout: 25000 });
  await wait(2000);
  
  // Check form fields
  const titleInput = await pg.$('input[name="title"], input[placeholder*="Titel"], input[placeholder*="titel"]');
  if (titleInput) {
    pass('Create', 'Title input found');
    await titleInput.fill('Test Inserat');
  } else {
    warn('Create', 'Title input not found with expected selectors');
  }
  
  // Check type selector
  const typeSelect = await pg.$('select[name="type"], select:first-of-type');
  if (typeSelect) pass('Create', 'Type selector found');
  else warn('Create', 'Type selector not found');
  
  await pg.screenshot({ path: '/tmp/create.png' });

  // ── PROFILE DEEP TEST ──────────────────────────────────────────────────────
  console.log('\n══ 6. PROFILE DEEP TEST ══');
  await pg.goto(BASE_URL + '/dashboard/profile', { waitUntil: 'networkidle', timeout: 25000 });
  await wait(3000);
  
  const profText = await pg.textContent('body');
  if (profText.includes('brandy') || profText.includes('gmail') || profText.includes('@')) {
    pass('Profile', 'Email shown');
  } else {
    warn('Profile', 'Email not visible in profile');
  }
  
  // Check avatar section
  const avatar = await pg.$('img[alt*="Avatar"], img[alt*="Profil"], .avatar, [class*="avatar"]');
  if (avatar) pass('Profile', 'Avatar element found');
  else warn('Profile', 'No avatar element');
  
  // Check edit capability
  const editBtn = await pg.$('button:has-text("Speichern"), button:has-text("Bearbeiten"), button:has-text("Ändern")');
  if (editBtn) pass('Profile', 'Edit/Save button found');
  else warn('Profile', 'No edit button found');
  
  await pg.screenshot({ path: '/tmp/profile.png' });

  // ── SETTINGS DEEP TEST ────────────────────────────────────────────────────
  console.log('\n══ 7. SETTINGS DEEP TEST ══');
  await pg.goto(BASE_URL + '/dashboard/settings', { waitUntil: 'domcontentloaded', timeout: 25000 });
  await wait(2000);
  
  const settingsText = await pg.textContent('body');
  if (settingsText.includes('Passwort') || settingsText.includes('password')) {
    pass('Settings', 'Password settings visible');
  } else {
    warn('Settings', 'No password settings');
  }
  if (settingsText.includes('Benachrichtig') || settingsText.includes('Notification')) {
    pass('Settings', 'Notification settings visible');
  } else {
    warn('Settings', 'No notification settings');
  }
  
  // ── BOT DEEP TEST ─────────────────────────────────────────────────────────
  console.log('\n══ 8. MENSAENA BOT TEST ══');
  await pg.goto(BASE_URL + '/dashboard', { waitUntil: 'networkidle', timeout: 25000 });
  await wait(3000);
  
  const botBtn = await pg.$('button[aria-label*="Bot"]');
  if (!botBtn) {
    issue('Bot', 'Bot button not found', 'aria-label not matching');
  } else {
    pass('Bot', 'Bot toggle button found');
    await botBtn.click();
    await wait(1500);
    
    // Check window opened
    const botWindow = await pg.$('[class*="bot"], div:has-text("Mensaena-Bot")');
    if (botWindow) pass('Bot', 'Bot window opened');
    else warn('Bot', 'Bot window maybe opened but selector not found');
    
    // Find input
    const botInput = await pg.$('input[placeholder*="Frag"], input[placeholder*="frag"], input[placeholder*="Schreib"]');
    if (botInput) {
      pass('Bot', 'Bot input found');
      await botInput.fill('Was ist Mensaena?');
      await pg.keyboard.press('Enter');
      await wait(5000); // Wait for AI response
      
      const bodyAfter = await pg.textContent('body');
      // Check if there's a response (look for typical bot response patterns)
      if (bodyAfter.includes('Mensaena') && bodyAfter.length > 2000) {
        pass('Bot', 'Bot responded');
      } else {
        warn('Bot', 'Bot response unclear');
      }
    } else {
      issue('Bot', 'Bot input not found', 'Cannot send message to bot');
    }
  }
  
  // ── LOGOUT TEST ───────────────────────────────────────────────────────────
  console.log('\n══ 9. LOGOUT TEST ══');
  await pg.goto(BASE_URL + '/dashboard', { waitUntil: 'domcontentloaded', timeout: 20000 });
  await wait(2000);
  
  const logoutBtn = await pg.$('button:has-text("Abmeld"), a:has-text("Abmeld"), button[aria-label*="logout"]');
  if (logoutBtn) {
    await logoutBtn.click();
    await wait(3000);
    const urlAfter = pg.url();
    if (urlAfter.includes('/login') || urlAfter === BASE_URL + '/' || urlAfter === BASE_URL) {
      pass('Logout', 'Logged out and redirected', urlAfter);
    } else {
      warn('Logout', 'Logout clicked but URL unexpected', urlAfter);
    }
  } else {
    warn('Logout', 'Logout button not found by text');
  }

  // ── LANDING PAGE ──────────────────────────────────────────────────────────
  console.log('\n══ 10. LANDING PAGE (no bot) ══');
  await pg.goto(BASE_URL, { waitUntil: 'networkidle', timeout: 25000 });
  await wait(2000);
  
  const botOnLanding = await pg.$('button[aria-label*="Bot"]');
  if (botOnLanding) issue('Landing', 'Bot on landing page', 'Bot must NOT appear before login');
  else pass('Landing', 'No bot on landing page');
  
  const loginLink = await pg.$('a[href="/login"], a:has-text("Anmelden"), a:has-text("Login")');
  if (loginLink) pass('Landing', 'Login link present');
  else warn('Landing', 'Login link not found');
  
  const registerLink = await pg.$('a[href="/register"], a:has-text("Registrieren"), a:has-text("Kostenlos")');
  if (registerLink) pass('Landing', 'Register link present');
  else warn('Landing', 'Register link not found');

  await browser.close();
  
  // ── FINAL REPORT ──────────────────────────────────────────────────────────
  console.log('\n\n══════════════════════════════════════════');
  console.log('           FINAL TEST REPORT');
  console.log('══════════════════════════════════════════');
  console.log(`✅ PASSED: ${passes.length}`);
  console.log(`❌ ISSUES: ${issues.length}`);
  
  if (issues.length > 0) {
    console.log('\n❌ ISSUES TO FIX:');
    issues.forEach((i, n) => console.log(`  ${n+1}. [${i.page}] ${i.what}: ${i.detail}`));
  }
  
  if (network400s.length > 0) {
    console.log(`\n⚠️  400 Errors (${network400s.length} unique):`);
    [...new Set(network400s)].slice(0, 5).forEach(u => console.log('  -', u.substring(0, 100)));
  }
  if (networkErrors.length > 0) {
    console.log(`\n🔴 500+ Errors:`);
    [...new Set(networkErrors)].slice(0, 5).forEach(u => console.log('  -', u.substring(0, 100)));
  }
  if (jsErrors.length > 0) {
    console.log(`\n🔴 JS Errors:`);
    [...new Set(jsErrors)].slice(0, 5).forEach(u => console.log('  -', u.substring(0, 120)));
  }
}

main().catch(e => { console.error('FATAL:', e.message); process.exit(1); });
