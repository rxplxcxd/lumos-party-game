// Rauchtest für den Web-Build: lädt die PWA in Chromium (WebGL2 via SwiftShader),
// wartet auf den Engine-Start und prüft Fehler, Manifest und Service-Worker-Cache.
// node tools/web_smoke_test.js http://localhost:8765/ [screenshot.png]
const { chromium } = require('playwright');

(async () => {
  const url = process.argv[2] || 'http://localhost:8765/';
  const shot = process.argv[3] || '';
  const browser = await chromium.launch({ args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
  const errors = [];
  page.on('pageerror', (e) => errors.push(e.message));
  page.on('console', (m) => { if (m.type() === 'error' && !/favicon/.test(m.text())) errors.push(m.text()); });
  const t0 = Date.now();
  await page.goto(url, { waitUntil: 'load' });
  await page.waitForFunction(() => !document.getElementById('splash'), null, { timeout: 240000 });
  console.log(`Engine gestartet nach ${((Date.now() - t0) / 1000).toFixed(1)} s`);
  await page.waitForTimeout(8000);
  if (shot) await page.screenshot({ path: shot });
  const manifestOk = await page.evaluate(async () => (await fetch('manifest.webmanifest')).ok);
  const swCaches = await page.evaluate(async () => (await caches.keys()).filter((k) => k.startsWith('lumos-party-')));
  await browser.close();
  console.log('Manifest:', manifestOk, 'SW-Caches:', swCaches.join(', ') || '–');
  const fatal = errors.filter((e) => /SCRIPT ERROR|Uncaught|Aborted|RuntimeError/.test(e));
  if (fatal.length || !manifestOk) {
    console.error('Fehler:\n' + fatal.join('\n'));
    process.exit(1);
  }
  console.log('Rauchtest bestanden.');
})().catch((e) => { console.error(e); process.exit(1); });
