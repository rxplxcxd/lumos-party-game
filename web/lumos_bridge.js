/*
 * Lumos Party – JS-Brücke zwischen Godot (JavaScriptBridge) und Browser-Diensten.
 *
 *  - Firebase Auth (Google, E-Mail/Passwort, anonym) + Realtime Database (Profile, Online-Räume)
 *  - Lumos Cloud (Lumos OS): Login/Registrierung/Refresh/Profil über die REST-API von lumos-one-os
 *  - Erkennung, ob das Spiel auf Lumos-Hardware / in Lumos OS läuft
 *
 * Godot ruft Funktionen über JavaScriptBridge.eval("LumosBridge.xyz(...)") auf. Asynchrone
 * Ergebnisse landen als Ereignisse in einer Warteschlange, die Godot jeden Frame mit
 * LumosBridge.poll() abholt (JSON-Array {type, data}). Keine Callbacks über die Engine-Grenze nötig.
 */
(function () {
	'use strict';

	const FIREBASE_CONFIG = {
		apiKey: 'AIzaSyBpCU5im11sq4YQbs5XPQ26cjs2XT0n4K0',
		authDomain: 'lumos-party-game.firebaseapp.com',
		projectId: 'lumos-party-game',
		storageBucket: 'lumos-party-game.firebasestorage.app',
		messagingSenderId: '891917891086',
		appId: '1:891917891086:web:e0243215fecaef954e6e5f',
		measurementId: 'G-YWC316WX1W',
		databaseURL: 'https://lumos-party-game-default-rtdb.europe-west1.firebasedatabase.app',
	};
	const FB_VERSION = '10.12.2';
	const FB_BASE = 'https://www.gstatic.com/firebasejs/' + FB_VERSION + '/';
	const LS_LUMOS = 'lumosparty.lumos.session';
	const LS_CLOUD_URL = 'lumosparty.lumos.url';

	const events = [];
	const listeners = {};
	let fbReady = null;
	let auth = null;
	let db = null;

	function emit(type, data) {
		events.push({ type: type, data: data === undefined ? null : data });
	}

	// ArrayBuffer/Blob → Base64 (in Blöcken, damit große Modelle den Stack nicht sprengen)
	function toB64(data) {
		const p = (typeof Blob !== 'undefined' && data instanceof Blob) ? data.arrayBuffer() : Promise.resolve(data);
		return p.then(function (buf) {
			const bytes = new Uint8Array(buf);
			let bin = '';
			for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
			return btoa(bin);
		});
	}

	function errText(e) {
		const code = (e && e.code) || '';
		const map = {
			'auth/invalid-email': 'Ungültige E-Mail-Adresse.',
			'auth/user-not-found': 'Kein Konto mit dieser E-Mail.',
			'auth/wrong-password': 'Falsches Passwort.',
			'auth/invalid-credential': 'E-Mail oder Passwort falsch.',
			'auth/email-already-in-use': 'Diese E-Mail ist bereits registriert.',
			'auth/weak-password': 'Das Passwort muss mindestens 6 Zeichen haben.',
			'auth/popup-closed-by-user': 'Anmeldefenster wurde geschlossen.',
			'auth/network-request-failed': 'Keine Verbindung zum Server.',
			'auth/too-many-requests': 'Zu viele Versuche – bitte kurz warten.',
		};
		return map[code] || (e && e.message) || String(e);
	}

	function loadScript(src) {
		return new Promise(function (resolve, reject) {
			const s = document.createElement('script');
			s.src = src;
			s.async = true;
			s.onload = resolve;
			s.onerror = function () { reject(new Error('Konnte ' + src + ' nicht laden')); };
			document.head.appendChild(s);
		});
	}

	function ensureFirebase() {
		if (fbReady) return fbReady;
		fbReady = (window.firebase ? Promise.resolve() : loadScript(FB_BASE + 'firebase-app-compat.js'))
			.then(function () { return Promise.all([loadScript(FB_BASE + 'firebase-auth-compat.js'), loadScript(FB_BASE + 'firebase-database-compat.js')]); })
			.then(function () {
				if (!window.firebase.apps.length) window.firebase.initializeApp(FIREBASE_CONFIG);
				auth = window.firebase.auth();
				db = window.firebase.database();
				auth.onAuthStateChanged(function (u) {
					emit('fb_user', u ? userInfo(u) : null);
				});
				return auth.getRedirectResult().catch(function () { return null; });
			})
			.catch(function (e) {
				fbReady = null;
				emit('fb_error', errText(e));
				throw e;
			});
		return fbReady;
	}

	function userInfo(u) {
		const prov = (u.providerData && u.providerData[0] && u.providerData[0].providerId) || (u.isAnonymous ? 'anonymous' : 'password');
		return { uid: u.uid, name: u.displayName || (u.email ? u.email.split('@')[0] : 'Gast'), email: u.email || '', photo: u.photoURL || '', provider: prov, anonymous: !!u.isAnonymous };
	}

	function isIOS() {
		return /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
	}

	function standalone() {
		return (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) || window.navigator.standalone === true;
	}

	// --- Lumos Cloud --------------------------------------------------------------------------------

	function cloudUrl() {
		const q = new URLSearchParams(location.search).get('cloud');
		if (q) {
			localStorage.setItem(LS_CLOUD_URL, q);
			return q.replace(/\/$/, '');
		}
		try {
			const os = JSON.parse(localStorage.getItem('lumos.cloud.config') || 'null');
			if (os && os.url) return String(os.url).replace(/\/$/, '');
		} catch (e) { /* egal */ }
		return (localStorage.getItem(LS_CLOUD_URL) || 'http://127.0.0.1:8787').replace(/\/$/, '');
	}

	function cloudFetch(path, opts) {
		const ctl = new AbortController();
		const t = setTimeout(function () { ctl.abort(); }, (opts && opts.timeout) || 8000);
		const o = Object.assign({ headers: {} }, opts || {}, { signal: ctl.signal });
		o.headers = Object.assign({ 'Content-Type': 'application/json' }, o.headers);
		const sess = lumosSession();
		if (sess && sess.accessToken && !o.noAuth) o.headers.Authorization = 'Bearer ' + sess.accessToken;
		return fetch(cloudUrl() + path, o).then(function (r) {
			clearTimeout(t);
			if (r.status === 204) return null;
			return r.json().catch(function () { return {}; }).then(function (j) {
				if (!r.ok) {
					const e = new Error((j && (j.error || j.message)) || ('HTTP ' + r.status));
					e.status = r.status;
					throw e;
				}
				return j;
			});
		}, function (e) {
			clearTimeout(t);
			throw new Error(e.name === 'AbortError' ? 'Lumos Cloud antwortet nicht.' : 'Keine Verbindung zur Lumos Cloud.');
		});
	}

	function lumosSession() {
		try { return JSON.parse(localStorage.getItem(LS_LUMOS) || 'null'); } catch (e) { return null; }
	}

	function storeSession(r) {
		if (!r || !r.accessToken) return null;
		const s = { accessToken: r.accessToken, refreshToken: r.refreshToken, user: r.user, exp: Date.now() + (r.expiresIn || 900) * 1000 };
		localStorage.setItem(LS_LUMOS, JSON.stringify(s));
		return s;
	}

	function emitLumosUser(s) {
		const u = (s && s.user) || {};
		emit('lumos_user', { uid: u.id, name: u.displayName || (u.email || 'Lumos').split('@')[0], email: u.email || '', friendCode: u.friendCode || '', provider: 'lumos' });
	}

	function withFreshToken() {
		const s = lumosSession();
		if (!s) return Promise.reject(new Error('Nicht angemeldet.'));
		if (s.exp - Date.now() > 60000) return Promise.resolve(s);
		return cloudFetch('/v1/auth/refresh', { method: 'POST', body: JSON.stringify({ refreshToken: s.refreshToken }), noAuth: true })
			.then(storeSession);
	}

	const LumosBridge = {
		version: 1,

		poll: function () {
			if (!events.length) return '';
			const out = JSON.stringify(events);
			events.length = 0;
			return out;
		},

		env: function () {
			const ua = navigator.userAgent || '';
			return JSON.stringify({
				ua: ua,
				lumosUA: /lumos-one-os|LumosOS/i.test(ua),
				electron: !!(window.lumos && window.lumos.isElectron) || /Electron/i.test(ua),
				ios: isIOS(),
				android: /Android/i.test(ua),
				standalone: standalone(),
				online: navigator.onLine !== false,
				cloudUrl: cloudUrl(),
				hasLumosSession: !!lumosSession(),
			});
		},

		// Prüft, ob eine Lumos Cloud (Lumos OS) erreichbar ist: /v1/health → provider "lumos".
		probeLumos: function () {
			cloudFetch('/v1/health', { timeout: 1500, noAuth: true })
				.then(function (j) { emit('lumos_probe', { ok: !!(j && j.provider === 'lumos'), url: cloudUrl(), version: j && j.version }); })
				.catch(function () { emit('lumos_probe', { ok: false, url: cloudUrl() }); });
		},

		// --- Lumos Cloud ---
		lumosLogin: function (email, pw) {
			cloudFetch('/v1/auth/login', { method: 'POST', body: JSON.stringify({ email: email, password: pw }), noAuth: true })
				.then(function (r) { emitLumosUser(storeSession(r)); })
				.catch(function (e) { emit('auth_error', { provider: 'lumos', message: e.message }); });
		},

		lumosRegister: function (email, pw, name) {
			cloudFetch('/v1/auth/register', { method: 'POST', body: JSON.stringify({ email: email, password: pw, displayName: name }), noAuth: true })
				.then(function (r) { emitLumosUser(storeSession(r)); })
				.catch(function (e) { emit('auth_error', { provider: 'lumos', message: e.message }); });
		},

		// Stilles Anmelden: gespeicherte Sitzung erneuern, sonst Lumos-OS-Sitzung (gleicher Ursprung)
		// oder Schlüsselbund-Autofill der Lumos-Shell nutzen.
		lumosResume: function () {
			const s = lumosSession();
			if (s) {
				withFreshToken().then(function (ns) { emitLumosUser(ns); })
					.catch(function () { localStorage.removeItem(LS_LUMOS); emit('lumos_resume_failed', null); });
				return;
			}
			try {
				const os = JSON.parse(localStorage.getItem('lumos.cloud.session') || 'null');
				if (os && os.refreshToken) {
					storeSession({ accessToken: os.accessToken, refreshToken: os.refreshToken, user: os.user, expiresIn: 0 });
					withFreshToken().then(emitLumosUser).catch(function () { emit('lumos_resume_failed', null); });
					return;
				}
			} catch (e) { /* weiter */ }
			if (window.lumos && window.lumos.keychain && window.lumos.keychain.autofill) {
				window.lumos.keychain.autofill(cloudUrl()).then(function (cred) {
					const c = Array.isArray(cred) ? cred[0] : cred;
					if (c && c.username && c.password) LumosBridge.lumosLogin(c.username, c.password);
					else emit('lumos_resume_failed', null);
				}).catch(function () { emit('lumos_resume_failed', null); });
				return;
			}
			emit('lumos_resume_failed', null);
		},

		lumosLogout: function () {
			const s = lumosSession();
			localStorage.removeItem(LS_LUMOS);
			if (s) cloudFetch('/v1/auth/logout', { method: 'POST', body: JSON.stringify({ refreshToken: s.refreshToken }), noAuth: true }).catch(function () {});
			emit('signed_out', { provider: 'lumos' });
		},

		lumosGetProfile: function () {
			withFreshToken().then(function () { return cloudFetch('/v1/profile'); })
				.then(function (j) { emit('profile', { provider: 'lumos', profile: (j && j.profile) || null, version: (j && j.version) || 0 }); })
				.catch(function (e) { emit('profile_error', { provider: 'lumos', message: e.message }); });
		},

		// Eigener 3D-Avatar (GLB). Quelle: 1) Lumos One OS (window.LumosOS.getAvatar), 2) Lumos Cloud
		// GET /v1/profile/avatar → {url, version, forward, name}, 3) URL aus dem Profil. Ergebnis als Base64.
		lumosGetAvatar: function (profileUrl) {
			const os = window.LumosOS || window.lumosOS;
			let metaP;
			if (os && typeof os.getAvatar === 'function') {
				metaP = Promise.resolve(os.getAvatar());
			} else if (lumosSession()) {
				metaP = withFreshToken().then(function () { return cloudFetch('/v1/profile/avatar'); })
					.catch(function (e) { if (e.status === 404 && profileUrl) return { url: profileUrl }; throw e; });
			} else if (profileUrl) {
				metaP = Promise.resolve({ url: profileUrl });
			} else {
				return;
			}
			metaP.then(function (meta) {
				if (!meta || (!meta.url && !meta.data)) return null;
				const info = { name: meta.name || '', version: meta.version || 0, forward: meta.forward || '+z', url: meta.url || '' };
				if (meta.data) return toB64(meta.data).then(function (b) { emit('avatar', { meta: info, b64: b }); });
				let url = String(meta.url);
				if (url.charAt(0) === '/') url = cloudUrl() + url;
				const h = {};
				const s = lumosSession();
				if (s && s.accessToken && url.indexOf(cloudUrl()) === 0) h.Authorization = 'Bearer ' + s.accessToken;
				return fetch(url, { headers: h }).then(function (r) {
					if (!r.ok) { const e = new Error('HTTP ' + r.status); e.status = r.status; throw e; }
					return r.arrayBuffer();
				}).then(toB64).then(function (b) { emit('avatar', { meta: info, b64: b }); });
			}).catch(function (e) {
				if (e && e.status === 404) return;   // kein Avatar hinterlegt → Standardhelden
				emit('avatar_error', { message: errText(e), status: (e && e.status) || 0 });
			});
		},

		lumosPutProfile: function (json, version) {
			let data;
			try { data = JSON.parse(json); } catch (e) { return; }
			withFreshToken().then(function () { return cloudFetch('/v1/profile', { method: 'PUT', body: JSON.stringify({ profile: data, version: version }) }); })
				.then(function (j) { emit('profile_saved', { provider: 'lumos', version: (j && j.version) || version + 1 }); })
				.catch(function (e) { emit('profile_error', { provider: 'lumos', message: e.message, status: e.status || 0 }); });
		},

		// --- Firebase Auth ---
		fbInit: function () {
			ensureFirebase().then(function () { emit('fb_ready', null); }).catch(function () {});
		},

		fbGoogle: function () {
			ensureFirebase().then(function () {
				const p = new window.firebase.auth.GoogleAuthProvider();
				p.setCustomParameters({ prompt: 'select_account' });
				// iOS-Homescreen-Apps blockieren Popups -> Redirect-Flow
				if (isIOS() && standalone()) return auth.signInWithRedirect(p);
				return auth.signInWithPopup(p).catch(function (e) {
					if (e && (e.code === 'auth/popup-blocked' || e.code === 'auth/operation-not-supported-in-this-environment')) return auth.signInWithRedirect(p);
					throw e;
				});
			}).catch(function (e) { emit('auth_error', { provider: 'google', message: errText(e) }); });
		},

		fbEmailLogin: function (email, pw) {
			ensureFirebase().then(function () { return auth.signInWithEmailAndPassword(email, pw); })
				.catch(function (e) { emit('auth_error', { provider: 'password', message: errText(e) }); });
		},

		fbEmailRegister: function (email, pw, name) {
			ensureFirebase().then(function () { return auth.createUserWithEmailAndPassword(email, pw); })
				.then(function (cred) { return name ? cred.user.updateProfile({ displayName: name }).then(function () { emit('fb_user', userInfo(cred.user)); }) : null; })
				.catch(function (e) { emit('auth_error', { provider: 'password', message: errText(e) }); });
		},

		fbResetPassword: function (email) {
			ensureFirebase().then(function () { return auth.sendPasswordResetEmail(email); })
				.then(function () { emit('info', 'E-Mail zum Zurücksetzen wurde gesendet.'); })
				.catch(function (e) { emit('auth_error', { provider: 'password', message: errText(e) }); });
		},

		fbAnonymous: function () {
			ensureFirebase().then(function () { return auth.currentUser ? auth.currentUser : auth.signInAnonymously(); })
				.catch(function (e) { emit('auth_error', { provider: 'anonymous', message: errText(e) }); });
		},

		fbSignOut: function () {
			ensureFirebase().then(function () { return auth.signOut(); }).then(function () { emit('signed_out', { provider: 'firebase' }); });
		},

		fbUid: function () {
			return auth && auth.currentUser ? auth.currentUser.uid : '';
		},

		// --- Realtime Database (Profile + Online-Räume) ---
		dbGet: function (path, tag) {
			ensureFirebase().then(function () { return db.ref(path).get(); })
				.then(function (snap) { emit('db_value', { tag: tag, path: path, value: snap.val() }); })
				.catch(function (e) { emit('db_error', { tag: tag, path: path, message: errText(e) }); });
		},

		dbSet: function (path, json, tag) {
			ensureFirebase().then(function () { return db.ref(path).set(json === '' ? null : JSON.parse(json)); })
				.then(function () { if (tag) emit('db_done', { tag: tag, path: path }); })
				.catch(function (e) { emit('db_error', { tag: tag, path: path, message: errText(e) }); });
		},

		dbUpdate: function (path, json, tag) {
			ensureFirebase().then(function () { return db.ref(path).update(JSON.parse(json)); })
				.then(function () { if (tag) emit('db_done', { tag: tag, path: path }); })
				.catch(function (e) { emit('db_error', { tag: tag, path: path, message: errText(e) }); });
		},

		dbPush: function (path, json) {
			ensureFirebase().then(function () {
				const v = JSON.parse(json);
				v.t = window.firebase.database.ServerValue.TIMESTAMP;
				return db.ref(path).push(v);
			}).catch(function (e) { emit('db_error', { path: path, message: errText(e) }); });
		},

		// Transaktion: Raum nur anlegen, wenn der Code noch frei ist.
		dbCreateIfAbsent: function (path, json, tag) {
			ensureFirebase().then(function () {
				const v = JSON.parse(json);
				return db.ref(path).transaction(function (cur) { return cur === null ? v : undefined; });
			}).then(function (res) { emit('db_created', { tag: tag, path: path, ok: !!res.committed }); })
				.catch(function (e) { emit('db_error', { tag: tag, path: path, message: errText(e) }); });
		},

		dbRemoveOnDisconnect: function (path) {
			ensureFirebase().then(function () { return db.ref(path).onDisconnect().remove(); }).catch(function () {});
		},

		// Abonniert Kinder-Ereignisse (added/changed/removed) eines Pfads unter einem Tag.
		dbListen: function (path, tag) {
			ensureFirebase().then(function () {
				LumosBridge.dbOff(tag);
				const ref = db.ref(path);
				const add = ref.on('child_added', function (s) { emit('db_child', { tag: tag, ev: 'added', key: s.key, value: s.val() }); });
				const chg = ref.on('child_changed', function (s) { emit('db_child', { tag: tag, ev: 'changed', key: s.key, value: s.val() }); });
				const rem = ref.on('child_removed', function (s) { emit('db_child', { tag: tag, ev: 'removed', key: s.key, value: null }); });
				listeners[tag] = function () { ref.off('child_added', add); ref.off('child_changed', chg); ref.off('child_removed', rem); };
			}).catch(function (e) { emit('db_error', { tag: tag, path: path, message: errText(e) }); });
		},

		dbOff: function (tag) {
			if (listeners[tag]) { listeners[tag](); delete listeners[tag]; }
		},

		serverTimeOffset: function () {
			ensureFirebase().then(function () {
				db.ref('.info/serverTimeOffset').once('value', function (s) { emit('time_offset', s.val() || 0); });
			});
		},
	};

	window.LumosBridge = LumosBridge;
	window.addEventListener('online', function () { emit('net', true); });
	window.addEventListener('offline', function () { emit('net', false); });
})();
