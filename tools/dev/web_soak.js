// Web-Langzeittest: startet das exportierte Web-Build in Chromium mit einer reinen CPU-Party und protokolliert
// regelmäßig WASM-Heap, JS-Heap und den Arbeitsspeicher aller Browser-Prozesse – zusammen mit den [SCENE]-Zeilen
// des Spiels. Zeigt, ob eine lange Browser-Session Speicher ansammelt (Ursache für Tab-Neuladen auf Mobilgeräten).
//   node tools/dev/web_soak.js <url> [minuten] [intervall_s]
//   z. B. node tools/dev/web_soak.js "http://localhost:8788/index.html?args=--board%3Dmeadow%20--rounds%3D15%20--cpu%20--scene%3Dres://scenes/party/PartyBoard.tscn%20--log-scenes" 25 30
const { chromium } = require('playwright');
const { execSync } = require('child_process');

function browserRssMB(pid) {
	try {
		// alle Nachfahren des Browser-Prozesses (Renderer, GPU, Audio …)
		const out = execSync(`ps -eo pid,ppid,rss --no-headers`).toString().trim().split('\n').map((l) => l.trim().split(/\s+/).map(Number));
		const kids = new Set([pid]);
		let grew = true;
		while (grew) {
			grew = false;
			for (const [p, pp] of out) if (kids.has(pp) && !kids.has(p)) { kids.add(p); grew = true; }
		}
		let sum = 0;
		for (const [p, , rss] of out) if (kids.has(p)) sum += rss;
		return Math.round(sum / 1024);
	} catch (e) { return -1; }
}

(async () => {
	const url = process.argv[2];
	const mins = Number(process.argv[3] || 25);
	const every = Number(process.argv[4] || 30);
	const browser = await chromium.launch({ args: ['--autoplay-policy=no-user-gesture-required', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist', '--enable-precise-memory-info'] });
	const page = await browser.newPage({ viewport: { width: 800, height: 450 } });
	const pid = browser.process ? browser.process().pid : 0;
	const t0 = Date.now();
	const ts = () => ((Date.now() - t0) / 1000).toFixed(0).padStart(5) + 's';
	page.on('console', (m) => {
		const t = m.text();
		if (t.includes('[SCENE]') || t.includes('ERROR') || t.includes('[PERF]')) console.log(`[${ts()}] ${t.slice(0, 220)}`);
	});
	page.on('crash', () => console.log(`[${ts()}] TAB ABGESTÜRZT`));
	await page.goto(url);
	const samples = [];
	while (Date.now() - t0 < mins * 60000) {
		await page.waitForTimeout(every * 1000);
		const m = await page.evaluate(() => {
			let heap = -1;
			try { heap = engine && engine.rtenv && engine.rtenv.HEAP8 ? engine.rtenv.HEAP8.length : -1; } catch (e) {}
			const js = performance.memory ? performance.memory.usedJSHeapSize : -1;
			return { heap: Math.round(heap / 1048576), js: Math.round(js / 1048576) };
		}).catch(() => ({ heap: -2, js: -2 }));
		const rss = browserRssMB(pid);
		samples.push([m.heap, m.js, rss]);
		console.log(`[${ts()}] [MEM] WASM-Heap ${m.heap} MB · JS-Heap ${m.js} MB · Browser-RAM ${rss} MB`);
	}
	const first = samples.slice(1, 4), last = samples.slice(-3);
	const avg = (a, i) => a.reduce((s, e) => s + e[i], 0) / Math.max(1, a.length);
	console.log(`ERGEBNIS WASM ${avg(first, 0).toFixed(0)} → ${avg(last, 0).toFixed(0)} MB · JS ${avg(first, 1).toFixed(0)} → ${avg(last, 1).toFixed(0)} MB · RAM ${avg(first, 2).toFixed(0)} → ${avg(last, 2).toFixed(0)} MB`);
	await browser.close();
})();
