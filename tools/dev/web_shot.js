// Web-Build prüfen (ab 1.5.4): lädt das exportierte Spiel in Chromium (Software-WebGL), wartet, speichert ein Bild und
// listet alle Konsolenfehler – fehlende Ressourcen, Shader-Fehler, Skriptfehler. Exit-Code 1 bei Fehlern.
//   node tools/dev/web_shot.js <url> <bild.png> [sekunden]
//   z. B. node tools/dev/web_shot.js "http://localhost:8788/index.html" /tmp/menu.png 30
const { chromium } = require('playwright');

(async () => {
	const url = process.argv[2];
	const out = process.argv[3] || 'web_shot.png';
	const secs = Number(process.argv[4] || 30);
	const browser = await chromium.launch({ args: ['--autoplay-policy=no-user-gesture-required', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
	const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
	const errors = [];
	const t0 = Date.now();
	page.on('console', (m) => {
		const t = m.text();
		if (m.type() === 'error' || /ERROR|SCRIPT ERROR|Failed loading|Cannot open|shader/i.test(t)) {
			errors.push(`[${((Date.now() - t0) / 1000).toFixed(1)}s] ${t.slice(0, 300)}`);
		}
	});
	page.on('pageerror', (e) => errors.push(`[pageerror] ${String(e).slice(0, 300)}`));
	page.on('requestfailed', (r) => errors.push(`[requestfailed] ${r.url()}`));
	await page.goto(url);
	// Startbildschirm „Tippen oder Taste drücken“ (Audio-Freigabe im Browser): das Laden dauert im Software-WebGL
	// unterschiedlich lange – bis zur Hälfte der Zeit alle 4 s tippen (weitere Tipps im Menü landen neben den Kacheln)
	const half = secs * 500;
	for (let t = 8000; t < half; t += 4000) {
		await page.waitForTimeout(4000);
		await page.mouse.click(1180, 640);
	}
	await page.waitForTimeout(secs * 1000 - half);
	await page.screenshot({ path: out });
	await browser.close();
	console.log(`WEB-SHOT ${out} · Konsolenfehler: ${errors.length}`);
	for (const e of errors) console.log('  ' + e);
	process.exit(errors.length ? 1 : 0);
})();
