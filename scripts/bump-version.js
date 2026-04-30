#!/usr/bin/env node
// UPDATE-SYSTEM: Bumpt version.json beim Mobile-Build automatisch
const fs = require('fs')
const { execSync } = require('child_process')
const pkg = require('../package.json')

const webVersion = pkg.version || '1.0.0'
const apkVersion = pkg.apkVersion || '1.0.0'

let webBuildId = 'local'
try { webBuildId = execSync('git rev-parse --short HEAD').toString().trim() } catch {}

const [ma, mi, pa] = apkVersion.split('.').map(Number)
const apkBuildCode = ma * 10000 + mi * 100 + pa

let existing = {}
try { existing = JSON.parse(fs.readFileSync('./public/version.json', 'utf-8')) } catch {}

const data = {
  webVersion,
  webBuildId,
  apkVersion,
  apkBuildCode,
  apkUrl: existing.apkUrl || 'https://github.com/manuelbrandner85/Mensaena/releases/latest/download/mensaena-release.apk',
  apkSize: existing.apkSize || '~15 MB',
  apkRequired: existing.apkRequired ?? false,
  apkMinVersion: existing.apkMinVersion || '1.0.0',
  releasedAt: new Date().toISOString(),
  releaseNotes: existing.releaseNotes || { headline: 'Update', subtitle: '', features: [], footer: '' },
  apkReleaseNotes: existing.apkReleaseNotes || { headline: 'App-Update', subtitle: '', reason: '', steps: [], footer: '' },
}

fs.writeFileSync('./public/version.json', JSON.stringify(data, null, 2))
console.log(`✅ version.json: web=${webVersion} apk=${apkVersion} build=${webBuildId}`)
