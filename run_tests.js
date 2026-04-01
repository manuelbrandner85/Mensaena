const { chromium } = require('./node_modules/playwright')

const BASE = 'https://mensaena.manuelbrandner4.workers.dev'
const EMAIL = 'brandy13062@gmail.com'
const PASS = 'Jolene2305'

const results = []

function log(status, test, detail = '') {
  const icon = status === 'PASS' ? '✅' : status === 'FAIL' ? '❌' : '⚠️'
  console.log(`${icon} [${status}] ${test}${detail ? ': ' + detail : ''}`)
  results.push({ status, test, detail })
}

;(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] })
  const context = await browser.newContext({ viewport: { width: 1280, height: 800 } })
  const page = await context.newPage()

  const errors = []
  page.on('console', msg => { if (msg.type() === 'error') errors.push(msg.text()) })
  page.on('pageerror', err => errors.push('PAGE ERROR: ' + err.message))

  try {
    // === LOGIN ===
    console.log('\n=== LOGIN TEST ===')
    await page.goto(`${BASE}/login`, { waitUntil: 'networkidle', timeout: 30000 })
    log('PASS', 'Login page loads')
    
    await page.locator('input[type="email"], input[name="email"]').first().fill(EMAIL)
    await page.locator('input[type="password"]').first().fill(PASS)
    await page.screenshot({ path: '/tmp/ss_01_login.png' })
    
    await page.locator('button[type="submit"], button:has-text("Anmelden")').first().click()
    await page.waitForURL(/dashboard/, { timeout: 20000 })
    log('PASS', 'Login successful')
    await page.waitForTimeout(2000)
    await page.screenshot({ path: '/tmp/ss_02_dashboard.png' })

    // === DASHBOARD ===
    console.log('\n=== DASHBOARD ===')
    const h1Count = await page.locator('h1, h2').count()
    log(h1Count > 0 ? 'PASS' : 'FAIL', 'Dashboard headings', `${h1Count} headings`)
    
    const sidebarLinks = await page.locator('a[href*="/dashboard"]').count()
    log(sidebarLinks > 0 ? 'PASS' : 'FAIL', 'Sidebar nav links', `${sidebarLinks} links`)

    // === BOT ===
    console.log('\n=== BOT ===')
    const allBtns = await page.locator('button').all()
    let botBtn = null
    for (const btn of allBtns) {
      const box = await btn.boundingBox().catch(() => null)
      if (box && box.y > 600 && box.x > 1000) { botBtn = btn; break }
    }
    if (botBtn) {
      log('PASS', 'Bot button at bottom-right')
      await botBtn.click()
      await page.waitForTimeout(1500)
      const msgInput = await page.locator('input[placeholder*="Frag"], input[placeholder*="Nach"], textarea[placeholder*="Frag"]').count()
      log(msgInput > 0 ? 'PASS' : 'WARN', 'Bot chat input visible', `${msgInput}`)
      await page.screenshot({ path: '/tmp/ss_03_bot.png' })
      // Send a message
      if (msgInput > 0) {
        await page.locator('input[placeholder*="Frag"], textarea[placeholder*="Frag"]').first().fill('Hallo, was kann Mensaena?')
        await page.keyboard.press('Enter')
        await page.waitForTimeout(3000)
        log('PASS', 'Bot: message sent')
        await page.screenshot({ path: '/tmp/ss_04_bot_response.png' })
      }
      // Close bot
      await botBtn.click()
      await page.waitForTimeout(500)
    } else {
      log('WARN', 'Bot button not found at bottom-right')
    }

    // === ALL PAGES ===
    console.log('\n=== PAGE NAVIGATION ===')
    const pages = [
      { url: '/dashboard', name: 'Dashboard' },
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
      { url: '/dashboard/admin', name: 'Admin' },
    ]
    
    for (const p of pages) {
      try {
        await page.goto(`${BASE}${p.url}`, { waitUntil: 'domcontentloaded', timeout: 20000 })
        await page.waitForTimeout(1500)
        if (page.url().includes('login')) {
          log('FAIL', p.name, 'Redirected to login!')
        } else {
          const h1 = await page.locator('h1').first().textContent({ timeout: 2000 }).catch(() => '(no h1)')
          log('PASS', p.name, h1.trim())
        }
      } catch (e) {
        log('FAIL', p.name, e.message.slice(0, 60))
      }
    }

    // === CREATE POST ===
    console.log('\n=== CREATE POST FLOW ===')
    await page.goto(`${BASE}/dashboard/create`, { waitUntil: 'domcontentloaded', timeout: 20000 })
    await page.waitForTimeout(2000)
    
    const typeBtn = page.locator('button').filter({ hasText: 'Hilfe suchen' }).first()
    if (await typeBtn.count() > 0) {
      await typeBtn.click()
      log('PASS', 'Create: selected type Hilfe suchen')
    }
    
    const weiter = page.locator('button').filter({ hasText: 'Weiter' }).first()
    if (await weiter.count() > 0) {
      await weiter.click()
      await page.waitForTimeout(800)
      log('PASS', 'Create: step 1 → 2')
      
      const titleInput = page.locator('input').filter({ hasNot: page.locator('[type="hidden"]') }).first()
      if (await titleInput.count() > 0) {
        await titleInput.fill('Testinserat Playwright')
        log('PASS', 'Create: title filled')
        const w2 = page.locator('button').filter({ hasText: 'Weiter' }).first()
        if (await w2.count() > 0) {
          await w2.click()
          await page.waitForTimeout(800)
          log('PASS', 'Create: step 2 → 3')
          await page.screenshot({ path: '/tmp/ss_05_create3.png' })
          // Check for phone field on step 3
          const ph = await page.locator('input[placeholder*="+"]').count()
          log(ph > 0 ? 'PASS' : 'WARN', 'Create step 3: phone field', `${ph}`)
        }
      }
    } else {
      log('FAIL', 'Create: Weiter button not found')
    }

    // === PROFILE ===
    console.log('\n=== PROFILE ===')
    await page.goto(`${BASE}/dashboard/profile`, { waitUntil: 'domcontentloaded', timeout: 20000 })
    await page.waitForTimeout(2000)
    
    const avatarEl = await page.locator('[class*="avatar"], [class*="Avatar"], img[alt*="avatar"], .rounded-full').count()
    log(avatarEl > 0 ? 'PASS' : 'WARN', 'Profile: avatar element', `${avatarEl}`)
    
    const editBtn = page.locator('button').filter({ hasText: 'Bearbeiten' }).first()
    if (await editBtn.count() > 0) {
      await editBtn.click()
      await page.waitForTimeout(500)
      log('PASS', 'Profile: edit mode activated')
      const inputs = await page.locator('input:visible').count()
      log(inputs > 0 ? 'PASS' : 'WARN', 'Profile edit: inputs visible', `${inputs}`)
      await page.screenshot({ path: '/tmp/ss_06_profile_edit.png' })
      const cancel = page.locator('button').filter({ hasText: 'Abbrechen' }).first()
      if (await cancel.count() > 0) { await cancel.click(); log('PASS', 'Profile: cancel edit') }
    }

    // === SETTINGS ===
    console.log('\n=== SETTINGS ===')
    await page.goto(`${BASE}/dashboard/settings`, { waitUntil: 'domcontentloaded', timeout: 20000 })
    await page.waitForTimeout(2000)
    
    const cbs = await page.locator('input[type="checkbox"]').count()
    log(cbs > 0 ? 'PASS' : 'WARN', 'Settings: checkboxes', `${cbs}`)
    const saveS = page.locator('button').filter({ hasText: 'Speichern' }).first()
    log(await saveS.count() > 0 ? 'PASS' : 'FAIL', 'Settings: Save button')
    await page.screenshot({ path: '/tmp/ss_07_settings.png' })

    // === CHAT ===
    console.log('\n=== CHAT ===')
    await page.goto(`${BASE}/dashboard/chat`, { waitUntil: 'domcontentloaded', timeout: 20000 })
    await page.waitForTimeout(5000)  // extra wait for async channel load
    
    const loadingText = await page.locator('text=Kanäle laden').count()
    log(loadingText === 0 ? 'PASS' : 'FAIL', 'Chat: channels NOT stuck loading',
      loadingText > 0 ? 'STILL LOADING - BUG!' : 'loaded OK')
    
    const allgemein = await page.locator('text=Allgemein').count()
    log(allgemein > 0 ? 'PASS' : 'WARN', 'Chat: Allgemein channel visible', `${allgemein}`)
    
    const msgInput2 = await page.locator('input[placeholder*="Nachricht"], textarea[placeholder*="Nachricht"]').count()
    log(msgInput2 > 0 ? 'PASS' : 'WARN', 'Chat: message input visible', `${msgInput2}`)
    await page.screenshot({ path: '/tmp/ss_08_chat.png' })

    // === LOGOUT ===
    console.log('\n=== LOGOUT ===')
    await page.goto(`${BASE}/dashboard`, { waitUntil: 'domcontentloaded', timeout: 20000 })
    await page.waitForTimeout(1500)
    
    const logoutBtns = await page.locator('button:has-text("Abmelden")').all()
    log(logoutBtns.length > 0 ? 'PASS' : 'FAIL', 'Logout button exists', `${logoutBtns.length}`)
    
    for (const lb of logoutBtns) {
      const vis = await lb.isVisible().catch(() => false)
      if (vis) {
        await lb.click()
        await page.waitForTimeout(2000)
        const finalUrl = page.url()
        log(finalUrl.includes('login') ? 'PASS' : 'WARN', 'Logout redirected', finalUrl)
        await page.screenshot({ path: '/tmp/ss_09_after_logout.png' })
        break
      }
    }

  } catch (e) {
    console.error('CRITICAL:', e.message)
    log('FAIL', 'CRITICAL ERROR', e.message.slice(0, 100))
    await page.screenshot({ path: '/tmp/ss_error.png' }).catch(() => {})
  }

  await browser.close()

  console.log('\n' + '='.repeat(60))
  console.log('FINAL SUMMARY')
  console.log('='.repeat(60))
  const p = results.filter(r => r.status === 'PASS').length
  const f = results.filter(r => r.status === 'FAIL').length
  const w = results.filter(r => r.status === 'WARN').length
  console.log(`Total: ${results.length} | ✅ PASS: ${p} | ❌ FAIL: ${f} | ⚠️ WARN: ${w}`)
  if (f > 0) { console.log('\n❌ FAILURES:'); results.filter(r=>r.status==='FAIL').forEach(r=>console.log(`   ${r.test}: ${r.detail}`)) }
  if (w > 0) { console.log('\n⚠️ WARNINGS:'); results.filter(r=>r.status==='WARN').forEach(r=>console.log(`   ${r.test}: ${r.detail}`)) }
  if (errors.length > 0) { console.log('\n🔴 CONSOLE ERRORS:'); errors.slice(0,8).forEach(e=>console.log('  ',e.slice(0,150))) }
})()
