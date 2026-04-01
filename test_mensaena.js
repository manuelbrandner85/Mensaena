const { chromium } = require('playwright');

const BASE_URL = 'https://mensaena.manuelbrandner4.workers.dev';
const EMAIL = 'brandy13062@gmail.com';
const PASSWORD = 'Jolene2305';

const results = [];
let page, browser, context;

function log(category, test, status, detail = '') {
  const entry = { category, test, status, detail };
  results.push(entry);
  const icon = status === 'PASS' ? '✅' : status === 'FAIL' ? '❌' : status === 'WARN' ? '⚠️' : 'ℹ️';
  console.log(`${icon} [${category}] ${test}${detail ? ': ' + detail : ''}`);
}

async function wait(ms) {
  return new Promise(r => setTimeout(r, ms));
}

async function goto(url, desc) {
  try {
    await page.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
    await wait(2000);
    return true;
  } catch(e) {
    log(desc, 'Navigation', 'FAIL', e.message.substring(0, 100));
    return false;
  }
}

async function clickAndWait(selector, desc, timeout = 5000) {
  try {
    await page.click(selector, { timeout });
    await wait(1500);
    return true;
  } catch(e) {
    log(desc, 'Click', 'FAIL', e.message.substring(0, 100));
    return false;
  }
}

async function checkVisible(selector, desc, testName) {
  try {
    const el = await page.waitForSelector(selector, { timeout: 5000, state: 'visible' });
    if (el) { log(desc, testName, 'PASS'); return true; }
  } catch(e) {
    log(desc, testName, 'FAIL', `Selector not found: ${selector}`);
    return false;
  }
}

async function getURL() { return page.url(); }
async function getTitle() { return page.title(); }

async function testLogin() {
  console.log('\n=== LOGIN TEST ===');
  await goto(BASE_URL + '/login', 'Login');
  
  // Check page loads
  await checkVisible('input[type="email"]', 'Login', 'Email field visible');
  await checkVisible('input[type="password"]', 'Login', 'Password field visible');
  
  // Fill credentials
  try {
    await page.fill('input[type="email"]', EMAIL);
    await page.fill('input[type="password"]', PASSWORD);
    log('Login', 'Fill credentials', 'PASS');
  } catch(e) {
    log('Login', 'Fill credentials', 'FAIL', e.message);
  }
  
  // Submit
  try {
    await page.click('button[type="submit"]');
    await page.waitForURL('**/dashboard**', { timeout: 15000 });
    const url = await getURL();
    log('Login', 'Redirect to dashboard', url.includes('dashboard') ? 'PASS' : 'FAIL', url);
  } catch(e) {
    log('Login', 'Login submit + redirect', 'FAIL', e.message);
    // Take screenshot
    await page.screenshot({ path: '/tmp/login_fail.png' });
  }
}

async function testDashboard() {
  console.log('\n=== DASHBOARD TEST ===');
  const url = await getURL();
  if (!url.includes('dashboard')) {
    await goto(BASE_URL + '/dashboard', 'Dashboard');
  }
  
  await checkVisible('text=Dashboard', 'Dashboard', 'Dashboard heading visible');
  await checkVisible('nav, aside', 'Dashboard', 'Sidebar visible');
  
  // Check for user greeting
  try {
    const body = await page.textContent('body');
    if (body.includes('Guten') || body.includes('Hallo') || body.includes('Willkommen')) {
      log('Dashboard', 'User greeting', 'PASS');
    } else {
      log('Dashboard', 'User greeting', 'WARN', 'No greeting found');
    }
    
    if (body.includes('Manuel') || body.includes('brandy')) {
      log('Dashboard', 'User name shown', 'PASS');
    } else {
      log('Dashboard', 'User name shown', 'WARN', 'Username not visible');
    }
  } catch(e) {
    log('Dashboard', 'Content check', 'FAIL', e.message);
  }
}

async function testNavigation() {
  console.log('\n=== NAVIGATION TEST ===');
  
  const pages = [
    { url: '/dashboard', name: 'Übersicht' },
    { url: '/dashboard/map', name: 'Karte' },
    { url: '/dashboard/create', name: 'Inserat erstellen' },
    { url: '/dashboard/posts', name: 'Meine Inserate' },
    { url: '/dashboard/community', name: 'Community' },
    { url: '/dashboard/chat', name: 'Chat' },
    { url: '/dashboard/crisis', name: 'Krisenhilfe' },
    { url: '/dashboard/animals', name: 'Tiere' },
    { url: '/dashboard/housing', name: 'Unterkunft' },
    { url: '/dashboard/supply', name: 'Versorgung' },
    { url: '/dashboard/timebank', name: 'Zeitbank' },
    { url: '/dashboard/harvest', name: 'Ernte' },
    { url: '/dashboard/skills', name: 'Fähigkeiten' },
    { url: '/dashboard/knowledge', name: 'Wissen' },
    { url: '/dashboard/sharing', name: 'Teilen' },
    { url: '/dashboard/mobility', name: 'Mobilität' },
    { url: '/dashboard/mental-support', name: 'Mentale Unterstützung' },
    { url: '/dashboard/profile', name: 'Profil' },
    { url: '/dashboard/settings', name: 'Einstellungen' },
  ];
  
  for (const p of pages) {
    try {
      await page.goto(BASE_URL + p.url, { waitUntil: 'domcontentloaded', timeout: 20000 });
      await wait(1500);
      const currentUrl = await getURL();
      const body = await page.textContent('body');
      
      // Check not redirected to login
      if (currentUrl.includes('/login')) {
        log('Navigation', p.name, 'FAIL', 'Redirected to login!');
      } else if (body.includes('Application error') || body.includes('application error')) {
        log('Navigation', p.name, 'FAIL', 'Application error on page');
      } else if (body.includes('404') && body.includes('not found')) {
        log('Navigation', p.name, 'FAIL', '404 Not Found');
      } else {
        log('Navigation', p.name, 'PASS', currentUrl);
      }
    } catch(e) {
      log('Navigation', p.name, 'FAIL', e.message.substring(0, 80));
    }
  }
}

async function testChatCommunity() {
  console.log('\n=== CHAT COMMUNITY TEST ===');
  await goto(BASE_URL + '/dashboard/chat', 'Chat');
  await wait(3000);
  
  const body = await page.textContent('body');
  
  // Check loading state resolved
  if (body.includes('Kanal wird geladen')) {
    log('Chat', 'Loading state', 'WARN', 'Still loading after 3s');
  } else {
    log('Chat', 'Loading state resolved', 'PASS');
  }
  
  // Check channels visible
  try {
    const channelEl = await page.$('text=Allgemein, text=Kanäle, [class*="channel"]');
    if (channelEl || body.includes('Allgemein') || body.includes('Kanal')) {
      log('Chat', 'Channel visible', 'PASS');
    } else {
      log('Chat', 'Channel visible', 'WARN', 'No channel found in UI');
    }
  } catch(e) {
    log('Chat', 'Channel check', 'WARN', e.message);
  }
  
  // Check input field
  try {
    const input = await page.$('input[placeholder*="Nachricht"], input[placeholder*="nachricht"]');
    if (input) {
      log('Chat', 'Message input visible', 'PASS');
      
      // Try to type a message
      await input.click();
      await input.fill('Test Nachricht ' + Date.now());
      log('Chat', 'Can type in input', 'PASS');
      
      // Clear it
      await input.fill('');
    } else {
      log('Chat', 'Message input', 'WARN', 'Input not found');
    }
  } catch(e) {
    log('Chat', 'Message input', 'FAIL', e.message);
  }
}

async function testPostCreation() {
  console.log('\n=== POST CREATION TEST ===');
  await goto(BASE_URL + '/dashboard/create', 'Post Create');
  await wait(2000);
  
  const body = await page.textContent('body');
  if (body.includes('Inserat') || body.includes('erstellen') || body.includes('Beitrag')) {
    log('Post Create', 'Create page loaded', 'PASS');
  } else {
    log('Post Create', 'Create page loaded', 'WARN', 'Expected content not found');
  }
  
  // Check form elements
  await checkVisible('form, input, select, textarea', 'Post Create', 'Form elements exist');
}

async function testProfile() {
  console.log('\n=== PROFILE TEST ===');
  await goto(BASE_URL + '/dashboard/profile', 'Profile');
  await wait(2000);
  
  const body = await page.textContent('body');
  if (body.includes('Profil') || body.includes('profile')) {
    log('Profile', 'Profile page loaded', 'PASS');
  } else {
    log('Profile', 'Profile page loaded', 'WARN');
  }
  
  if (body.includes('brandy') || body.includes('Manuel') || body.includes('gmail')) {
    log('Profile', 'User data shown', 'PASS');
  } else {
    log('Profile', 'User data shown', 'WARN', 'No user data visible');
  }
}

async function testBot() {
  console.log('\n=== BOT TEST ===');
  await goto(BASE_URL + '/dashboard', 'Dashboard for bot test');
  await wait(2000);
  
  // Check bot button exists
  try {
    const botBtn = await page.$('button[aria-label*="Bot"], button[aria-label*="bot"]');
    if (botBtn) {
      log('Bot', 'Bot button visible', 'PASS');
      await botBtn.click();
      await wait(1000);
      
      const body = await page.textContent('body');
      if (body.includes('Mensaena-Bot') || body.includes('Bot')) {
        log('Bot', 'Bot window opens', 'PASS');
      } else {
        log('Bot', 'Bot window opens', 'WARN');
      }
      
      // Try send a message
      const input = await page.$('input[placeholder*="Frag"]');
      if (input) {
        await input.fill('Hallo, was kannst du?');
        await page.keyboard.press('Enter');
        await wait(3000);
        log('Bot', 'Bot message sent', 'PASS');
      }
    } else {
      log('Bot', 'Bot button', 'WARN', 'Not found - might be inside shadow DOM or different selector');
    }
  } catch(e) {
    log('Bot', 'Bot test', 'FAIL', e.message);
  }
}

async function testLandingPageNoBot() {
  console.log('\n=== LANDING PAGE BOT CHECK ===');
  await goto(BASE_URL, 'Landing page');
  await wait(2000);
  
  try {
    const botBtn = await page.$('button[aria-label*="Bot"], button[aria-label*="bot"]');
    if (botBtn) {
      log('Landing', 'Bot on landing page', 'FAIL', 'Bot button found on landing page - should NOT be here!');
    } else {
      log('Landing', 'No bot on landing page', 'PASS', 'Bot correctly hidden on landing page');
    }
  } catch(e) {
    log('Landing', 'Bot check', 'PASS', 'No bot button found');
  }
}

async function main() {
  browser = await chromium.launch({ headless: true });
  context = await browser.newContext({ 
    viewport: { width: 1280, height: 800 },
    userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 Chrome/120 Safari/537.36'
  });
  page = await context.newPage();
  
  // Capture console errors
  const consoleErrors = [];
  page.on('console', msg => {
    if (msg.type() === 'error') consoleErrors.push(msg.text());
  });
  
  try {
    await testLogin();
    await testDashboard();
    await testNavigation();
    await testChatCommunity();
    await testPostCreation();
    await testProfile();
    await testBot();
    await testLandingPageNoBot();
  } finally {
    await browser.close();
  }
  
  console.log('\n\n======= SUMMARY =======');
  const passed = results.filter(r => r.status === 'PASS').length;
  const failed = results.filter(r => r.status === 'FAIL').length;
  const warned = results.filter(r => r.status === 'WARN').length;
  console.log(`✅ PASS: ${passed} | ❌ FAIL: ${failed} | ⚠️ WARN: ${warned}`);
  
  if (failed > 0) {
    console.log('\n❌ FAILURES:');
    results.filter(r => r.status === 'FAIL').forEach(r => {
      console.log(`  - [${r.category}] ${r.test}: ${r.detail}`);
    });
  }
  if (warned > 0) {
    console.log('\n⚠️  WARNINGS:');
    results.filter(r => r.status === 'WARN').forEach(r => {
      console.log(`  - [${r.category}] ${r.test}: ${r.detail}`);
    });
  }
  
  if (consoleErrors.length > 0) {
    console.log('\n🔴 JS CONSOLE ERRORS:');
    consoleErrors.slice(0, 10).forEach(e => console.log('  -', e));
  }
}

main().catch(e => { console.error('Fatal:', e); process.exit(1); });
