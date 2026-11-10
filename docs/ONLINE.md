# Online-Mehrspieler & Konten

## Räume (Firebase Realtime Database)

```
rooms/{CODE}/meta            {host, created, state: lobby|playing, cfg}
rooms/{CODE}/players/{uid}   {name, hero, slot 0-3, ready, t}
rooms/{CODE}/signal/{to}/…   {from, type: offer|answer|ice, sdp | mid, idx, cand}
rooms/{CODE}/relay/{to}/…    {from, d}          (Fallback-Transport)
profiles/{uid}               Profil (Bestzeiten, Statistiken, Freischaltungen)
```

* Raumcodes: 5 Zeichen ohne Verwechslungsgefahr (kein 0/O, 1/I). Anlegen per Transaktion (Code frei?).
* Identität: Firebase-UID (Google, E-Mail oder anonym). Lumos-Konten melden sich für Räume zusätzlich anonym an.
* Regeln: `firebase/database.rules.json` (nur eigene Profile, Spieler-Einträge nur vom Spieler selbst oder Host,
  Signaling/Relay nur mit korrektem Absender und nur für den Empfänger lesbar).

## Transport

Stern-Topologie: Jeder Client baut **eine WebRTC-Verbindung zum Host** auf (Angebot vom Client, Antwort vom
Host, ICE-Kandidaten über `signal/`). Zwei ausgehandelte Datenkanäle: `rel` (zuverlässig, geordnet – Items,
Treffer, Start, Ende) und `unrel` (unzuverlässig, ungeordnet – Zustände mit 30 Hz). Der Host leitet Broadcasts
weiter. Im selben WLAN liegt die Laufzeit typischerweise unter 20 ms (Anzeige in der Lobby).

Fallback: Kommt nach 9–10 s keine Direktverbindung zustande oder fehlt WebRTC (native Builds ohne
`webrtc-native`-Erweiterung), laufen alle Nachrichten über `relay/` (Zustände auf 10 Hz gedrosselt,
gebündelt, verarbeitete Einträge werden in einem Request gelöscht).

## Spielsynchronisation

| | Eigene Einheit | Fremde Einheiten | Ereignisse |
|---|---|---|---|
| Nitro Dash | lokal simuliert (sofortige Reaktion = Prediction), Zustand 30 Hz | Snapshot-Puffer, 100 ms Interpolation, bis 250 ms Extrapolation | Items: Werfer sendet, alle simulieren Geschosse; Treffer meldet das Opfer |
| Minispiele (Figuren) | lokal simuliert, Zustand 30 Hz | Interpolation von Position, Blickrichtung, Laufanimation | Schubser gehen an den Besitzer des Opfers, Stürze meldet der Besitzer, Ende/Platzierungen bestimmt der Host |
| CPUs | vom Host simuliert | bei Clients interpoliert | – |

Start: Alle Geräte melden „bereit“, der Host gibt „go“ → gleichzeitiger Countdown.

### Minispiel-Modelle
* **Owner-Modell** (Standard): Jede Figur wird auf ihrem Gerät simuliert. Gefahren entstehen aus dem gemeinsamen
  Spiel-Zufall (`rng`, Startwert aus der Raum-Konfiguration), Ausscheiden und Punkte entscheidet nur der Besitzer
  (`eliminate`/`add_score` → Meldung `sc`). 1-gegen-3-Solo-Steuerungen (Hammer-Hüpfen, Sternschnuppen-Regen)
  werden zusätzlich vom Solo-Gerät gesendet.
* **Host-Modell** (`net_model = "host"`): Der Host simuliert alles, Clients schicken nur Eingaben (`in`) und
  zeigen den Zustand (`gs`) – für Spiele mit gemeinsamen Objekten (Seilziehen, Korbschlacht, Schatzkisten …).
* **Endergebnis** kommt immer vom Host (`end` mit Platzierungen und Punkten) – alle Geräte verbuchen dasselbe.

### Online-Party (Brett)
Alle Geräte führen den Brettablauf identisch aus (`Game.prng`, gleicher Startwert). Jede Spieler-Entscheidung –
Würfel, Wegwahl, Ja/Nein, Glücksrad, Gegnerwahl, Abstimmung – bekommt eine fortlaufende Nummer (`Game.party.dseq`).
Das Gerät des Spielers (CPUs: Host) entscheidet und sendet `{"k": "bd", "n", "v"}`; die anderen zeigen dieselbe
Animation und übernehmen genau diesen Wert. Test: `tools/dev/net_test.sh <ordner> party` vergleicht den
Brettzustand von Host und Client nach jedem Zug.

### Lumos-Athlon (bis 20 Geräte)
Athlon-Räume (`max = 20`) laufen host-gesteuert: `ath_round` (Herausforderung), `ath_sc` (Münzen der Clients),
`ath_res` (Rundenergebnis inkl. CPUs). Alle Geräte bewegen die Läufer daraus identisch.

## Konten

| Umgebung | Anmeldung |
|---|---|
| Lumos OS / Lumos One | Lumos Cloud (`/v1/auth/login|register|refresh`, Profil über `/v1/profile` mit Versionierung) |
| Supabase eingerichtet (alle Plattformen) | E-Mail/Passwort über Supabase Auth, im Web zusätzlich Google (Weiterleitung) – `scripts/net/supabase.gd` |
| Browser, iOS, Android, PWA ohne Supabase | Google oder E-Mail/Passwort über Firebase (Alt-Weg; der hinterlegte Firebase-Key ist derzeit ungültig) |
| Native ohne Browser, ohne Supabase | E-Mail/Passwort über die Firebase-REST-API |
| Gast | nur lokal |

Profile werden beim Anmelden zusammengeführt (Bestzeiten = Minimum, Zähler = Maximum, Freischaltungen = Vereinigung).
Ohne eingerichtetes Backend zeigt das Profil-Fenster einen Hinweis statt eines Formulars, das nicht funktionieren kann.

### Supabase einrichten (Online-Konten)

1. **Supabase → Project Settings → API Keys:** *Project URL* (`https://<ref>.supabase.co`) und den
   **anon**- bzw. **publishable**-Key kopieren. **Nie** den `service_role`-/`secret`-Key verwenden – der Client-Key
   ist öffentlich, geschützt wird per Row Level Security. Die CI bricht ab, falls doch ein Service-Key eingetragen ist.
2. **GitHub → Settings → Secrets and variables → Actions → Variables:** `SUPABASE_URL` und `SUPABASE_ANON_KEY`
   anlegen (Secrets mit gleichem Namen gehen auch). Danach *Actions → Build & Deploy → Run workflow* oder ein Push –
   `tools/backend_config.py` setzt die Werte vor dem Export in `scripts/net/backend_config.gd` ein.
   Alternativ die beiden Konstanten direkt in `scripts/net/backend_config.gd` eintragen.
3. **SQL Editor:** `supabase/schema.sql` ausführen (Tabelle `profiles` mit RLS: jeder liest/schreibt nur sich selbst).
4. **Authentication → URL Configuration:** *Site URL* `https://rxplxcxd.github.io/lumos-party-game/` und dieselbe
   Adresse unter *Redirect URLs* eintragen – dorthin führen Bestätigungs-, Passwort-Reset- und Google-Links zurück.
5. **Authentication → Sign In / Providers:** *Email* aktiv. Mit „Confirm email“ meldet das Spiel nach der
   Registrierung „Bitte bestätige deine E-Mail“; der Link meldet direkt im Spiel an. Google optional (Client-ID/Secret
   aus der Google Cloud Console, Callback `https://<ref>.supabase.co/auth/v1/callback`) – der Google-Knopf erscheint
   automatisch, sobald der Provider aktiv ist (`GET /auth/v1/settings`).

Technik im Web-Export: Anfragen laufen über `HTTPRequest` (= `fetch`) mit `apikey`, `Authorization` (nur echte JWTs),
`Content-Type` und `Prefer` – alles Header, die Supabase im CORS-Preflight erlaubt; Nicht-localhost-URLs werden auf
`https://` gezwungen (kein Mixed Content auf GitHub Pages). Die Sitzung (Refresh-Token) liegt in `user://account.cfg`
(im Browser IndexedDB), Tokens aus Weiterleitungen werden aus dem `#`-Fragment gelesen und sofort aus der Adresse entfernt.
Test gegen echten oder nachgebauten Server: `LUMOS_SUPABASE_URL=… LUMOS_SUPABASE_KEY=… godot --headless --path .
res://tools/dev/Run.tscn -- --dev-script=res://tools/dev/supabase_probe.gd`.
