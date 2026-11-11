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

### Synchronisationspunkte (seit 1.2.2)
`Net.sync_point(tag, timeout)` ist eine gemeinsame Schranke: Clients melden `sp` (alle 1,5 s wiederholt), der Host
gibt mit `sp_go` frei, sobald alle Teilnehmer der Partie da sind. Nach 0,6 s Wartezeit erscheint „Warte auf
Mitspieler …“; nach dem Timeout geht es trotzdem weiter (ein hängendes Gerät blockiert nie alle).
* **Lade-Gate** – `Net.loading_gate()` (Tag `load:<epoch>`, `scene_epoch` zählt je Szene hoch): Brett, Minispiel und
  Rennen starten erst, wenn jedes Gerät die Szene fertig geladen hat. Der Host wartet automatisch.
* **Zug-Gate** – `turn:<Runde>:<Zug>`: Ein Brettzug beginnt erst, wenn alle den vorigen komplett gesehen haben.
  Würfeln und Laufen laufen dadurch auf allen Geräten gleichzeitig.
* **Minispiel-Auswahl** – `mgsel:<Runde>` vor dem Minispiel-Roulette, `mg_go:<epoch>` direkt vor dem Countdown.

### Verbindungsabbrüche
* Host verlässt das Spiel (Pause-Menü, Fenster zu) → sendet `bye`. Clients zeigen „Online-Spiel beendet – Der Host
  hat das Spiel beendet.“ (in der Lobby: „… hat den Raum geschlossen.“), OK führt zur Online-Seite.
* Kein `pong` vom Host seit 12 s → „Die Verbindung zum Host wurde getrennt.“
* Host-Eintrag oder Raum-Meta verschwindet aus der Datenbank → ebenfalls Hinweis statt stillem Hängen.
* Späte Beitritte in eine laufende Partie starten nicht mit, sondern bekommen eine Statusmeldung.

### Minispiel-Auswahl in der Lobby
Der Host öffnet über „Auswahl: X von Y aktiv“ den `MinigamePicker`: Kategorie-Chips (Alle, Jeder gegen jeden,
1 gegen 3, 2 gegen 2, Duell, Glück, Münzen …), „Alle an/aus“, Liste mit Häkchen und ▶ (sofort dieses Spiel). Die
Auswahl wird gespeichert (`settings.online_pool_off`) und als `pool_off` in der Raum-Konfiguration verteilt; Brett
und Zufallsmodus ziehen nur aus aktiven Spielen (mit Rückfall auf alle Online-Spiele, falls die Auswahl leer ist).

### Minispiel-Modelle
* **Owner-Modell** (Standard): Jede Figur wird auf ihrem Gerät simuliert. Gefahren entstehen aus dem gemeinsamen
  Spiel-Zufall (`rng`, Startwert aus der Raum-Konfiguration), Ausscheiden und Punkte entscheidet nur der Besitzer
  (`eliminate`/`add_score` → Meldung `sc`). 1-gegen-3-Solo-Steuerungen (Hammer-Hüpfen, Sternschnuppen-Regen)
  werden zusätzlich vom Solo-Gerät gesendet.
* **Host-Modell** (`net_model = "host"`): Der Host simuliert alles, Clients schicken nur Eingaben (`in`) und
  zeigen den Zustand (`gs`) – für Spiele mit gemeinsamen Objekten (Seilziehen, Korbschlacht, Schatzkisten,
  Kugel-Karambolage, Stampf-Wellen, Nagel-Profi, Raketen-Rucksack, Eislauf-Münzjagd, Blockpfad-Poker,
  UFO-Kaperung, Schalter-Schikane …). Hilfsfunktionen `net_pack`/`net_unpack` übertragen den Spielzustand.
* **Endergebnis** kommt immer vom Host (`end` mit Platzierungen und Punkten) – alle Geräte verbuchen dasselbe.

### Online-Party (Brett)
Alle Geräte führen den Brettablauf identisch aus (`Game.prng`, gleicher Startwert). Jede Spieler-Entscheidung –
Würfel, Wegwahl, Ja/Nein, Glücksrad, Gegnerwahl, Abstimmung – bekommt eine fortlaufende Nummer (`Game.party.dseq`).
Das Gerät des Spielers (CPUs: Host) entscheidet und sendet `{"k": "bd", "n", "v"}`; die anderen zeigen dieselbe
Animation und übernehmen genau diesen Wert. Test: `tools/dev/net_test.sh <ordner> party` vergleicht den
Brettzustand von Host und Client nach jedem Zug; `tools/dev/net_test.sh <ordner> <minispiel-id>` prüft ein
einzelnes Minispiel (beide Geräte melden „Minispiel-Ende“ mit Platzierungen – Owner- und Host-Modell).
`EXTRA=--log-scenes` protokolliert zusätzlich jeden Szenenwechsel.

### Lumos-Athlon (bis 20 Geräte)
Athlon-Räume (`max = 20`) laufen host-gesteuert: `ath_round` (Herausforderung), `ath_sc` (Münzen der Clients),
`ath_res` (Rundenergebnis inkl. CPUs). Alle Geräte bewegen die Läufer daraus identisch.

## Konten (Firebase – einziges Backend)

| Umgebung | Anmeldung |
|---|---|
| Lumos OS / Lumos One | Lumos Cloud (`/v1/auth/login|register|refresh`, Profil über `/v1/profile` mit Versionierung) |
| Browser, iOS, Android, PWA | Firebase-Web-SDK über `web/lumos_bridge.js`: Google (Popup, auf dem iOS-Homescreen Redirect) oder E-Mail/Passwort |
| Native ohne Browser | E-Mail/Passwort über die Firebase-REST-API |
| Online-Lobby ohne Konto | anonyme Firebase-Anmeldung (Gast) |
| Gast | nur lokal |

Profile liegen unter `profiles/{uid}` in der Realtime Database und werden beim Anmelden zusammengeführt
(Bestzeiten = Minimum, Zähler = Maximum, Freischaltungen = Vereinigung).

Projektdaten stehen an genau zwei Stellen: `scripts/net/firebase_config.gd` (GDScript: REST, Datenbank-URL) und
`FIREBASE_CONFIG` in `web/lumos_bridge.js` (Web-SDK). Die CI (`tools/check_firebase_config.py`) bricht ab, wenn
beide voneinander abweichen oder Google den API-Key ablehnt. Ein Tippfehler im Key (0 statt O) hat die Anmeldung
bis 1.1.7 lahmgelegt. Nativer Schnelltest ohne Spuren: `godot --headless --path . res://tools/dev/Run.tscn --
--dev-script=res://tools/dev/firebase_probe.gd [--anon]`.

**Google im Browser nur per Popup:** `signInWithRedirect` funktioniert auf GitHub Pages nicht zuverlässig. Nach
der Rückkehr liest das SDK das Ergebnis über ein iframe von `lumos-party-game.firebaseapp.com`. Für
`rxplxcxd.github.io` ist das Drittanbieter-Speicher, und der ist in Chrome 115+, Firefox 109+ und Safari 16.1+
partitioniert. Folge: Der Google-Login klappt, aber man kommt nicht angemeldet zurück. Das Popup wird beim Drücken
des Knopfes scharf geschaltet (`LumosBridge.fbGoogleArm`) und beim Loslassen direkt im Browser-Ereignis geöffnet.
Godot verarbeitet Klicks erst einen Frame später, und Popup-Blocker lassen nur Popups aus einer echten Geste zu.
Das SDK wird beim Öffnen des Profil-Fensters vorgeladen (`fbWarm`). Ist ein Popup trotzdem blockiert, gibt es eine
Meldung statt eines Redirects.

### Firebase-Konsole: Checkliste

1. **Authentication, Anmeldemethode:** *E-Mail/Passwort* (aktiv), *Google* (aktivieren) und *Anonym* (aktivieren,
   für Online-Lobbys ohne Konto). Ohne Anonym zeigt die Lobby „Gast-Anmeldung (anonym) ist im Firebase-Projekt
   nicht aktiviert“, und nur angemeldete Spieler können online spielen.
2. **Authentication, Einstellungen, Autorisierte Domains:** `rxplxcxd.github.io` hinzufügen (für Google-Popup bzw.
   -Redirect). `localhost` steht dort standardmäßig.
3. **Realtime Database, Regeln:** Inhalt von `firebase/database.rules.json` einfügen und veröffentlichen
   (ersetzt die ablaufende Testmodus-Regel). Grundsatz: nichts ohne Anmeldung. Profile darf nur der Besitzer
   lesen und schreiben. Raum-Metadaten ändert nur der Host. Spieler schreiben nur ihren eigenen Eintrag (Platz
   0–19). Signal- und Relay-Nachrichten müssen den eigenen Absender tragen. Raumcodes: 4–6 Zeichen aus A–Z/2–9.
