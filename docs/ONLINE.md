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

### Spielerliste und Rollen (seit 1.2.5)
Der Host ist die einzige Quelle dafür, wer auf welchem Platz sitzt:
* **Plätze:** In der Lobby vergibt der Host die Plätze lückenlos und eindeutig: 0 = Host, dann nach
  Beitrittszeit. Treten zwei Gäste gleichzeitig bei, landen sie nicht mehr auf demselben Platz.
* **Spielerliste (`cfg.roster`):** Beim Start legt der Host für alle vier Plätze fest: Figur, Name, Mensch oder
  CPU, CPU-Stufe und Konto. Jedes Gerät übernimmt genau diese Liste (`Net.apply_roster`), auch für die CPUs.
  Vorher nahm jedes Gerät für CPUs seine eigenen lokalen Einstellungen.
* **Figuren sind eindeutig:** Wählen zwei Spieler dieselbe Figur, behält sie der niedrigere Platz, der andere
  bekommt eine freie. Eigene 3D-Avatare gibt es nur auf dem eigenen Gerät; online werden sie durch eine freie
  Standardfigur ersetzt, damit alle dasselbe sehen. Die Lobby weist darauf hin („wird beim Start getauscht“).
* **Ein Konto pro Gerät:** Ist ein Konto schon von einem anderen Gerät im Raum (`dev` im Spielereintrag), wird
  der Beitritt mit einer Erklärung abgelehnt. Sonst würden beide Geräte denselben Platz steuern.
* **Anzeige:** Neben jedem Namen steht „DU“ (dieses Gerät), „ONLINE“ (Mitspieler) oder „CPU · Stufe“. Dazu
  kommt „AM ZUG“ beim aktiven Spieler.

### Wer bedient? (seit 1.2.5)
* **Bedienelemente** bekommt nur der Mensch, der am Gerät für den aktiven Platz spielt: Würfel, Item- und
  Wegwahl, Ja/Nein, Spielerwahl, Shop, Glücksrad.
* **Zuschauer:** Alle anderen sehen eine reine Anzeige ohne Knöpfe („X entscheidet …“) und den Hinweis
  „Zuschauen: X ist am Zug“. Was der aktive Spieler gerade markiert, wird live mitgezeigt (`hv`, unzuverlässig).
  Das gilt auch für CPU-Entscheidungen auf dem Host und offline: Niemand kann mehr für eine CPU klicken.
* **Touch:** Auf Touch-Geräten sind die Spielknöpfe ausgeblendet, solange ein anderer am Zug ist
  (Touch-Profil `spectate`).
* **Tempo:** Online gibt es keinen Schnellvorlauf; alle sehen den Ablauf im selben Tempo.
* **Gleichzeitige Eingaben** gibt es nur, wo das Spiel sie vorsieht: Minispiel-Abstimmung und Minispiele.

### Host-Schnappschuss (seit 1.2.5)
Zu Beginn jedes Zuges und vor der Minispiel-Wahl schickt der Host den vollständigen Brettzustand (`bs`):
* **Spieler:** Felder, Münzen, Sterne, Items und Statistik.
* **Brett:** Sternfeld, Fallen, Geheimgänge, Partner und Shop.
* **Abläufe:** Entscheidungszähler und Zufallsgenerator.

Clients warten darauf und übernehmen bei jeder Abweichung den Host-Stand, inklusive Figurenpositionen und
Anzeige. Der Lockstep hält alle Geräte zwischen zwei Zügen synchron; der Schnappschuss korrigiert jede Abweichung
spätestens beim nächsten Zug. Die Kodierung (`NetCodec`) erhält Ganzzahl-Schlüssel, Ganzzahlen und Vektoren über
JSON und erzeugt nie Objekte aus Netzdaten.

### Wartezeiten, Ping und Relay (seit 1.2.6)
* **Wartezeiten:**
  * Pong-Wächter (Gast) 60 s; Zeit, in der das eigene Gerät eine Szene lädt, zählt nicht.
  * Synchronisationspunkte 60 s, Szenen-Laden 120 s, Anmeldung 60 s, HTTP-Anfragen 30 s.
* **Ping:** Er läuft einmal pro Sekunde, über den Direktkanal unzuverlässig (`u: 1`, kein Warten hinter
  Spielereignissen), sonst über Relay. Angezeigt wird ein geglätteter Wert mit Übertragungsweg („direkt“ bzw.
  „über Server“). Werte um 300–400 ms bedeuten Relay; Direktverbindungen liegen typischerweise deutlich
  darunter.
* **Relay bündelt:** Alle Nachrichten eines Bilds an denselben Empfänger gehen als ein Datenbank-Eintrag raus
  (JSON-Liste, höchstens ~60 KB je Eintrag). Empfänger verstehen Einzel- und Sammel-Einträge.
* **Bereit-Abfrage vor Minispielen:** `{"k": "mgr", "e": <Szene>, "s": [Plätze]}`. Start, sobald alle Menschen
  bereit sind, spätestens nach 15 s; danach das bekannte `mg_go`-Gate.
* **Glücksrad:** Das Ergebnisfeld ist eine `bd`-Entscheidung. Die Animation endet bei jeder Bildrate exakt auf
  diesem Feld.

### Absender-Prüfung & schlechte Verbindungen (seit 1.2.7)
* **Wer etwas sendet, prüft der Empfänger am Transport**, nicht am Inhalt: Datenbank-Regeln erzwingen
  `from == Konto` (Relay), Direktverbindungen sind je Gerät. Das Feld `f` gilt nur, wenn der Host eine Nachricht
  weiterleitet; der Host setzt es selbst. Vorher hätte sich ein Gerät als Host ausgeben können.
* **Nur der Host** darf `bye`, `sp_go`, `bs`, `end`, `gs` und die Athlon-Steuernachrichten erzeugen
  (`Net.HOST_ONLY`); alles andere wird verworfen und unter `debug_counts.abgelehnt` gezählt.
* **Eigener Platz:** Eingaben (`in`) und Punktemeldungen (`sc`) gelten nur für den Platz des sendenden Geräts
  (`Net.may_speak_for`, der Host zusätzlich für CPU-Plätze). Eingabewerte werden begrenzt.
* **Wiederholung:** Native REST-Schreibzugriffe wiederholen bei Funklöchern/5xx/429 bis zu dreimal (0,4/0,8/1,6 s);
  im Browser übernimmt das das Firebase-SDK.
* **Test mit schlechter Verbindung:** `MOCK_DELAY_MS=300 MOCK_FAIL_PCT=5 tools/dev/net_test.sh …` – der
  RTDB-Ersatz verzögert jede Anfrage zufällig und lässt 5 % scheitern; Brett/Rennen müssen trotzdem auf allen
  Geräten identisch enden (Teil der CI).

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
* Kein `pong` vom Host seit 60 s (Ladepausen ausgenommen) → „Die Verbindung zum Host wurde getrennt.“ – auch bei
  einem harten Host-Absturz ohne `bye` (geprüft in der CI: `HOST_CRASH=60 tools/dev/net_test.sh … party`).
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
* **Endergebnis:** Es kommt immer vom Host (`end` mit Platzierungen, Punkten und seit 1.2.5 auch Zusatzergebnissen
  `x`, z. B. Boss-Schaden). Alle Geräte verbuchen dasselbe. Gäste warten bis zu 15 s darauf („Warte auf das
  Ergebnis des Hosts …“); kommt es nicht, gleicht der Host-Schnappschuss beim nächsten Zug ab.

### Online-Party (Brett)
Alle Geräte führen den Brettablauf identisch aus (`Game.prng`, gleicher Startwert). Jede Spieler-Entscheidung –
Würfel, Wegwahl, Ja/Nein, Glücksrad, Gegnerwahl, Abstimmung – bekommt eine fortlaufende Nummer (`Game.party.dseq`).
Das Gerät des Spielers (CPUs: Host) entscheidet und sendet `{"k": "bd", "n", "v"}`; die anderen zeigen dieselbe
Animation und übernehmen genau diesen Wert. Test: `tools/dev/net_test.sh <ordner> party` vergleicht den
Brettzustand von Host und Gästen nach jedem Zug; mit `CLIENTS=2 HUMAN=1 HEROES="knight ranger mage"` laufen drei
Geräte mit verschiedenen Figuren, der erste Gast bedient als Mensch. Das Skript prüft zusätzlich: gleiche
Spielerliste auf allen Geräten, eindeutige Plätze und Bedienelemente nur für den eigenen Platz; `tools/dev/net_test.sh <ordner> <minispiel-id>` prüft ein
einzelnes Minispiel (beide Geräte melden „Minispiel-Ende“ mit Platzierungen – Owner- und Host-Modell).
`EXTRA=--log-scenes` protokolliert zusätzlich jeden Szenenwechsel.

Seit 1.2.4 laufen auch Item-Einsatz, Wunschzahl, Kartenziel, Shop-Kauf, Fallen und Wegwahl an Schlüsseltor,
Geheimgang und Schatz-Umweg über dieselben `bd`-Entscheidungen (`_choose_option`). Das Shop-Angebot einer Runde
wird aus Brett, Runde und Partie-Startwert berechnet und ist damit auf allen Geräten gleich. Entdeckte Geheimgänge
und gelegte Fallen liegen im Partie-Zustand (`Game.party`).

**Emotes:** `{"k": "emo", "s": <slot>, "e": <id>}` – jedes Gerät zeigt das Emote über der Figur des Spielers;
unbekannte IDs werden ignoriert, die Abklingzeit gilt auch für empfangene Emotes.

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
