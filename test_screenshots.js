const { chromium } = require('playwright');
const BASE_URL = 'https://mensaena.manuelbrandner4.workers.dev';
const EMAIL = 'brandy13062@gmail.com';
const PASSWORD = 'Jolene2305';

async function wait(ms) { return new Promise(r => setTimeout(r, ms)); }

async function main() {
  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1280, height: 800 } });
  const pg = await context.newPage();
  
  const issues = [];
  pg.on('pageerror', e => issues.push(e.message));

  // Login
  await pg.goto(BASE_URL + '/login', { waitUntil: 'networkidle', timeout: 30000 });
  await pg.fill('input[type="email"]', EMAIL);
  await pg.fill('input[type="password"]', PASSWORD);
  await pg.click('button[type="submit"]');
  await pg.waitForURL('**/dashboard**', { timeout: 20000 });
  await wait(3000);
  console.log('Logged in!');

  // Take screenshots of each page with issues
  const pagesWithWarnings = [
    { url: '/dashboard/settings', name: 'settings' },
    { url: '/dashboard/chat', name: 'chat_community' },
    { url: '/dashboard/map', name: 'map' },
    { url: '/dashboard/community', name: 'community' },
    { url: '/dashboard/crisis', name: 'crisis' },
    { url: '/dashboard/rescuer', name: 'rescuer' },
    { url: '/dashboard/supply', name: 'supply' },
    { url: '/dashboard/admin', name: 'admin' },
  ];
  
  for (const p of pagesWithWarnings) {
    await pg.goto(BASE_URL + p.url, { waitUntil: 'networkidle', timeout: 25000 });
    await wait(3000);
    await pg.screenshot({ path: `/tmp/${p.name}.png`, fullPage: false });
    console.log(`Screenshot: ${p.name}`);
  }
  
  // Special: Chat community tab
  await pg.goto(BASE_URL + '/dashboard/chat', { waitUntil: 'networkidle', timeout: 25000 });
  await wait(3000);
  // Click community tab
  const commTab = await pg.$('button:has-text("Community")');
  if (commTab) {
    await commTab.click();
    await wait(2000);
    await pg.screenshot({ path: '/tmp/chat_community_tab.png', fullPage: false });
    console.log('Chat community tab screenshot done');
  }
  
  // Get body text of settings page  
  await pg.goto(BASE_URL + '/dashboard/settings', { waitUntil: 'networkidle', timeout: 25000 });
  await wait(2000);
  const settingsText = await pg.textContent('body');
  console.log('Settings page keywords:', settingsText.substring(0, 500));
  
  await browser.close();
  
  if (issues.length > 0) {
    console.log('\nJS Errors:', issues.join('\n'));
  }
}

main().catch(e => { console.error('Fatal:', e.message); });
