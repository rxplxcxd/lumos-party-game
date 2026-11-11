// Web-Leistungsmessung: startet das exportierte Web-Build in Chromium (optional mit CPU-Drosselung wie auf einem
// schwachen Laptop), zeichnet Bildintervalle und lange Hauptthread-Aufgaben auf und gibt sie zusammen mit den
// [PERF]-Markern des Spiels aus.
//   node tools/dev/web_perf.js <url> [sekunden] [drosselung]
//   z. B. node tools/dev/web_perf.js "http://localhost:8788/index.html?args=--scene%3Dres://scenes/party/PartyBoard.tscn%20--test-roulette%20--perf-log" 60 4
const { chromium } = require('playwright');

(async () => {
	const url = process.argv[2];
	const secs = Number(process.argv[3] || 60);
	const throttle = Number(process.argv[4] || 1);
	const browser = await chromium.launch({ args: ['--autoplay-policy=no-user-gesture-required', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'] });
	const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });
	const cdp = await page.context().newCDPSession(page);
	if (throttle > 1) await cdp.send('Emulation.setCPUThrottlingRate', { rate: throttle });
	const t0 = Date.now();
	page.on('console', (m) => {
		const t = m.text();
		if (t.includes('[PERF]') || t.includes('ERROR') || t.includes('[Audio]')) console.log(`[${((Date.now() - t0) / 1000).toFixed(1)}s] ${t}`);
	});
	await page.addInitScript(() => {
		window.__frames = [];
		window.__long = [];
		let last = performance.now();
		const tick = (now) => { window.__frames.push([now, now - last]); last = now; requestAnimationFrame(tick); };
		requestAnimationFrame(tick);
		try {
			new PerformanceObserver((list) => { for (const e of list.getEntries()) window.__long.push([e.startTime, e.duration]); }).observe({ entryTypes: ['longtask'] });
		} catch (e) {}
	});
	await page.goto(url);
	await page.waitForTimeout(secs * 1000);
	const data = await page.evaluate(() => ({ frames: window.__frames, long: window.__long, audio: window.__lumosAudioState ? window.__lumosAudioState() : '?' }));
	// Auswertung je 2-s-Fenster: mittlere FPS, schlechtestes Bild, lange Aufgaben
	const win = 2000;
	const buckets = {};
	for (const [t, dt] of data.frames) {
		const b = Math.floor(t / win);
		buckets[b] = buckets[b] || { n: 0, worst: 0 };
		buckets[b].n += 1;
		buckets[b].worst = Math.max(buckets[b].worst, dt);
	}
	const longB = {};
	for (const [t, d] of data.long) {
		const b = Math.floor(t / win);
		longB[b] = (longB[b] || []);
		longB[b].push(Math.round(d));
	}
	console.log('Fenster  FPS  schlechtestes Bild  lange Aufgaben (ms)');
	for (const b of Object.keys(buckets).map(Number).sort((a, c) => a - c)) {
		const fps = (buckets[b].n / (win / 1000)).toFixed(0);
		console.log(`${(b * win / 1000).toString().padStart(5)}s ${fps.padStart(4)} ${buckets[b].worst.toFixed(0).padStart(8)} ms  ${(longB[b] || []).join(' ')}`);
	}
	console.log('AudioContext:', data.audio);
	await browser.close();
})();
