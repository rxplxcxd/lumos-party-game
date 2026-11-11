# Changelog – Lumos Party & Nitro Dash

Versionierung vor dem Release: **1.1.x** (1.1.1 … 1.1.9), danach **1.2.x** (Release-Reihe, Etappen 1.2.1 …).
Eine Quelle für alle Stellen: `python3 tools/version.py <version>` (bzw. `--next`). Commit-Betreff: `vX.Y.Z: …`.

## 1.2.5 – Generalüberholung des Online-Multiplayers
Grundlage sind Praxistests mit mehreren Spielern. Gilt für alle online spielbaren Modi (Brett, Minispiele,
Rennen); Lumos-Athlon profitiert von der neuen Platzvergabe.

* **Gleiche Figuren und Rollen auf allen Geräten:**
  * Der Host verteilt beim Start eine vollständige Spielerliste: Platz, Figur, Name, Mensch oder CPU, CPU-Stufe
    und Konto. Alle Geräte übernehmen sie, auch für die CPUs. Vorher nahm jedes Gerät für CPUs seine eigenen
    lokalen Einstellungen, deshalb sahen CPUs je Gerät anders aus oder fehlten.
  * Plätze vergibt der Host in der Lobby lückenlos (Host zuerst, dann Beitrittsreihenfolge). Zwei gleichzeitig
    Beitretende landen nicht mehr auf demselben Platz.
  * Figuren sind eindeutig: Doppelte Wahl und eigene 3D-Avatare, die nur auf dem eigenen Gerät existieren,
    werden durch freie Standardfiguren ersetzt. Die Lobby zeigt das vorher an und listet freie Plätze nach
    Platznummer.
  * Ist ein Konto schon von einem anderen Gerät im Raum, wird der Beitritt mit einer Erklärung abgelehnt.
    Vorher überschrieb das zweite Gerät den Eintrag, und beide steuerten denselben Platz.
  * Neben den Namen steht „DU“, „ONLINE“ oder „CPU · Stufe“ – auf allen Geräten aus derselben Liste – dazu
    „AM ZUG“ beim aktiven Spieler.
* **Nur der aktive Spieler bedient:**
  * Würfel, Item- und Wegwahl, Ja/Nein, Spielerwahl, Shop und Glücksrad gibt es nur auf dem Gerät des aktiven
    Menschen.
  * Alle anderen sehen eine Anzeige ohne Knöpfe („X entscheidet …“, „Zuschauen: X ist am Zug“) und live, was
    der aktive Spieler gerade markiert.
  * Behoben: Bei CPU-Entscheidungen waren die Knöpfe auf dem Host anklickbar, man konnte also für die CPU
    entscheiden.
  * Touch-Knöpfe verschwinden, solange ein anderer am Zug ist.
  * Online gibt es keinen Schnellvorlauf mehr.
* **Host-autoritativer Brettzustand:**
  * Zu Beginn jedes Zuges und vor der Minispiel-Wahl verteilt der Host den vollständigen Stand: Felder,
    Münzen, Sterne, Items, Fallen, Partner, Sternfeld, Entscheidungszähler und Zufallsgenerator.
  * Weicht ein Gerät ab, übernimmt es den Host-Stand sofort.
  * Der neue `NetCodec` überträgt Ganzzahl-Schlüssel, Ganzzahlen und Vektoren verlustfrei über JSON und erzeugt
    nie Objekte aus Netzdaten.
* **Tests:**
  * `net_test.sh` kann jetzt mehrere Gäste testen (`CLIENTS=2`), mit einem bedienenden Mensch-Gast (`HUMAN=1`)
    und eigener Figur je Gerät (`HEROES=…`).
  * Das Skript prüft: identische Spielerliste auf allen Geräten, eindeutige Plätze, Bedienelemente nur für den
    eigenen Platz und identischen Brettzustand.
  * `test_systems.gd` prüft zusätzlich Codec, Spielerliste und Host-Korrektur.

## 1.2.4 – System-Update: Items, CPU-Stufen, Routen, Emotes, Touch & Controller
* **Item-Persistenz (Bugfix):** Items gingen verloren, wenn ein Zug durch ein Partner-Feld, ein Minispiel oder
  eine Cutscene unterbrochen wurde. Dabei verfielen Restschritte und Würfeleffekt.
  * Der Zug läuft nach der Unterbrechung mit den Restschritten weiter (`resume_move`).
  * Vor jedem Szenenwechsel wird das Inventar gesichert und bei der Rückkehr abgeglichen (`inv_guard`).
  * Items verschwinden nur noch durch Einsatz oder gewollte Mechaniken (Tausch- und Mopser-Karten).
* **Vier CPU-Stufen:** Leicht, Mittel, Profi, **Insane**.
  * Insane macht weniger Patzer, streut weniger und reagiert schneller, aber nie unter menschlichen 0,15 s.
  * Fein abgestimmte Größen (Regler, Sprung-Zeitpunkte, Toleranzen, Rempelraten) bleiben auf Profi-Niveau.
    Ein erster Stufenvergleich hatte gezeigt, dass blindes Hochskalieren Insane schlechter machte.
  * Auf dem Brett plant Insane Items und Wege voraus: Wunschwürfel auf exakten Sternabstand, Dreifachwürfel bei
    weitem Stern, Schlüssel vor dem Tor kaufen, Münz-Mopser für den Sternkauf aufsparen.
  * Kein Mogeln: Würfel und Zufall sind für alle gleich. Insane bleibt schlagbar.
* **Dynamischere Bretter:**
  * Mittel-Express quer übers Brett, auf den meisten Brettern hinter einem Schlüsseltor.
  * Auf Friedhof und Leuchtwald ist der Express ein Geheimgang, der erst nach dem Entdecken auftaucht.
  * Schatz-Umweg mit Risiko (rote Felder) und Belohnung (Schatzfeld „X“ mit Truhe).
  * Die Wegwahl zeigt an, was hinter jeder Abzweigung liegt.
* **Shop-Erweiterung** (bis zu 3 Items):
  * Dreifachwürfel, Wunschwürfel (1–10) und Schneckenwürfel (1–3).
  * Platztausch-Karte, Münz-Mopser und Item-Tausch-Karte.
  * Münzfalle, die man auf das eigene Feld legt.
  * Schlüssel für Abkürzungstore.
  * Das Angebot wechselt jede Runde und ist online auf allen Geräten gleich.
* **Emotes:**
  * Acht selbst gezeichnete Vektor-Emotes, keine Standard-Emojis.
  * Bedienung: Y bzw. Q halten (Emote-Rad) oder Klick/Tipp auf den Emote-Knopf.
  * Sie erscheinen als Sprechblase über der Figur und werden online übertragen. Spam-Bremse beim Senden und
    Empfangen.
* **Hauptmenü:** Die Insel hat ein paar kleine Geheimnisse.
* **Touch:** Listen scrollen per Wischen mit Schwung, ein Wischen löst keinen Knopf aus.
* **Controller in der Spieler-/CPU-Auswahl:**
  * links/rechts springt zwischen Figur, Typ und Stufe, hoch/runter zwischen den Zeilen;
  * A auf einem Pfeil ändert den Wert;
  * „Mensch (Pad)“ kollidiert nicht mehr mit der neuen Stufe Insane.
* **Fehlerbehebungen nebenbei:**
  * Modular-Terrain-Modelle (OBJ) wirkten fast schwarz: Godots OBJ-Import machte aus „Ks 1“ metallic = 1. Sie
    werden jetzt matt dargestellt.
  * Lange Boss-Namen passen ins Minispiel-Intro.
  * Die vier neuen Asset-Pakete sind in der Asset-Pipeline registriert. Ohne Eintrag schloss die CI sie per
    `.gdignore` vom Import aus.
  * Hitstops haben einen Mindestabstand von 0,3 s: Rempel-Serien (Kart-Kegeln mit Turbo) ließen das Spiel
    vorher stocken. Kart-Kegeln stoppt nur noch bei harten Treffern.
  * Fanfaren-Jingles in Mega-Summser, Schalter-Schikane, Steinkopf-Kegeln, Lumos-Athlon und Reise-Modus waren
    stumm (falscher Sound-Kanal).
* **Prüfungen:**
  * `tools/dev/test_systems.gd` (in der CI) prüft CPU-Stufen, Inventar-Schutz, Item-Taktik, Emotes, Stepper-
    Navigation, Touch-Wischen und Menü-Figuren.
  * `SWEEP_ARGS="--levels=…"` vergleicht CPU-Stufen im Sweep.
  * `tools/dev/board_route_shot.gd` erzeugt Kontrollbilder von Schlüsseltor, Geheimgang und Schatz-Umweg.

## 1.2.3 – Neue Low-Poly-Welt, Cozy-UI & 15 neue Minispiele (Etappe 3)
Hinweis: Die Anfrage nannte „Version 1.9.3“. Gemäß der Reihe 1.2.x (Etappe 3 nach 1.2.2) ist dieser Build **1.2.3**.

* **Asset-Packs integriert** (Quaternius Nature & Platformer, LowPoly Environment, Modular Terrain, Cozy UI):
  * Prozedurale Platzhalter und ältere Modelle laufen über Upgrade-Pools mit Jahreszeit-Varianten: Schnee,
    Herbst, Moos, Totholz.
  * Berg- und Wolkenhorizont aus Modellen mit gemeinsamem Material.
  * Themen-Deko je Brett: Stege, Muscheln, Loren, Lagerfeuer, Ruinen.
  * Alle Modelle werden auf einheitliche Höhe bzw. Breite normiert und geteilt geladen.
  * Die Archive wurden nach dem Entpacken aus dem Repository entfernt.
* **Cozy-UI-Overhaul:**
  * Holz- und Creme-Buttons, Panels, Karten, Checkboxen, Slider, Pfeile, Herzen und ein eigener Mauszeiger.
  * Warme Palette in HUDs, Menüs, Anzeigen und Ergebnisbildschirmen. Die Schrift bleibt.
* **15 neue, hoch-interaktive Minispiele** (eigene Namen, Figuren und Orte; Stick + A/B, Maus, Tastatur,
  Controller und Touch; online-fähig):
  * 2 gegen 2: Bomben-Entschärfung, Taxi-Koordinaten, Karten-Match, Strand-Volley, Tretboot-Rennen,
    Gemüse-Ernte.
  * Duelle: Schnell-Angler, Klatsch-Karussell, Murmel-Labyrinth, Steinkopf-Kegeln.
  * Jeder gegen jeden: Mega-Summser, Achterbahn-Schießbude, Flitzestein-Wurf, Spukvilla-Sprint.
  * Glück und Münzen: Kullerkasten.
* **CPUs springen voll aus:** Bei variabler Sprunghöhe halten CPUs A jetzt lange genug.

## 1.2.2 – Online-Überarbeitung & 15 neue Minispiele (Etappe 2)
Hinweis: Die Anfrage nannte im Text „Version 1.9.2“, in der Überschrift „1.2.2“. Gemäß der Reihe 1.2.x
(Etappe 2 nach 1.2.1) ist dieser Build **1.2.2**.

* **Online – streng synchron:**
  * Lade-Gate für Brett, Minispiele und Rennen: Start erst, wenn alle Geräte geladen haben; der Host wartet
    automatisch („Warte auf Mitspieler …“).
  * Zug-Gates auf dem Brett: Jeder Zug beginnt erst, wenn alle den vorigen fertig gesehen haben. Würfeln und
    Laufen laufen live und gleichzeitig.
  * Gemeinsame Schranke vor dem Minispiel-Roulette und direkt vor dem Countdown.
  * Startfelder korrekt: Feld-IDs außerhalb des Bretts landen auf dem Start statt auf dem letzten Feld;
    doppelte Startsignale (zwei Datenbank-Ereignisse) setzen die Partie nicht mehr zurück.
  * Klare Abbruch-Hinweise statt stillem Hängen: „Der Host hat das Spiel beendet.“, „Der Host hat den Raum
    geschlossen.“, „Die Verbindung zum Host wurde getrennt.“ (12 s ohne Antwort). Späte Beitritte bekommen
    eine Statusmeldung.
* **Lobby – Minispiel-Auswahl:** Kategorie-Chips, „Alle an/aus“, Häkchen-Liste und ▶ zum direkten Start.
  Die Auswahl wird gespeichert und an alle verteilt; Brett und Zufallsmodus ziehen nur aus aktiven Spielen.
* **15 neue, hoch-interaktive Minispiele** (eigene Figuren, Orte und Namen; alles mit Stick + A/B spielbar,
  Maus/Tastatur/Controller/Touch, keine Bewegungs- oder Mikrofon-Pflicht; alle online-fähig):
  * *Kugel-Karambolage* – Kugelphysik-Rempeln auf schrumpfender Bühne, B = Sprint-Stoß (Host-Modell).
  * *Wackelsteg-Wirbel* – über heranrollende Baumstämme springen, der Steg kippt mit.
  * *Funken-Karussell* – drehende Scheibe, Funkenarme und Blitzstreifen, drei Leben.
  * *Sandwich-Sturm* – fallenden Zutaten ausweichen, auf dem Stapel klettern, Deckel-Finale.
  * *Stampf-Wellen* – B stampft Wellenringe los, A springt über fremde Wellen (Host-Modell).
  * *Kullerfels-Flucht* – vor dem rollenden Felsbrocken fliehen, Kisten, Stämme und Zaunlücken, Münzen.
  * *Eisschollen-Sturm* – knackende Sechseck-Schollen, angekündigte Windböen, Schubsen auf Glatteis.
  * *Nagel-Profi* – A halten und im grünen Bereich loslassen, krumme Nägel mit B geradebiegen (Host-Modell).
  * *Raketen-Rucksack-Rallye* – Schub mit Tankanzeige, Sternenringe, Gewitterwolken mit Blitzen (Host-Modell).
  * *Schlitten an der Kante* – drei Abfahrten: anschieben, bremsen, möglichst knapp vor der Klippe halten.
  * *Eislauf-Münzjagd* – Münzmuster auf dem Teich, Schubser lassen Münzen kullern, Eisbär mit Pflug (Host-Modell).
  * *Spitzhacken-Spurt* – A/B im Wechsel hacken, Felsbrocken seitlich umgraben, Edelsteine.
  * *Blockpfad-Poker* – Bluff-Spiel: allein auf einem Brückenfeld punktet, geteilte Felder brechen ein (Host-Modell).
  * *UFO-Kaperung* (1 gegen 3) – Traktorstrahl gegen Zappeln, Festhalten und Konfetti-Raketen (Host-Modell).
  * *Schalter-Schikane* (1 gegen 3) – Solo löst vier Fallen aus, das Trio muss den Pendellauf schaffen
    (Host-Modell).
* **Fehlerbehebungen nebenbei:**
  * Intro: Die Portal-Ringe des Auftritts verschwinden wieder (ein abgelaufener Tween wurde weiterbenutzt).
  * Spielwichtige Objekte (Felsbrocken, UFO, Stampfer, Gewitterwolken) werden vom Intro nicht mehr als
    Sichthindernis ausgeblendet (`keep_visible`).
  * Physik-Körper werden nie skaliert (Jolt-Warnungen); es wird nur die Optik plattgedrückt.
* **Werkzeuge:**
  * `tools/dev/minigame_shot.gd` erstellt Kontrollbilder eines Minispiels.
  * Der Sweep meldet jetzt Punktestände.
  * `net_test.sh` erkennt auch das Ende von Host-Modell-Spielen; `EXTRA=` reicht zusätzliche Argumente durch.

## 1.2.1 – Animationen, Bugs & Steuerungs-Framework (Etappe 1)
* **Weiche Animationen überall** (`CharacterRig`):
  * Überblendzeiten nach Übergangsart: Gesten wie Winken und Jubeln ≥ 0,28 s, Fortbewegung ≥ 0,2 s, Aktionen
    knackig, aber nie unter 0,08 s. Vorher teils 0,03–0,1 s, Arme sprangen in Winken & Co.
  * Hysterese zwischen Stehen, Gehen und Laufen: kein Flackern an Schwellen.
  * Tempowechsel gleiten statt zu springen.
  * Lande-Animation nach Sprüngen.
  * `turn_to()` dreht weich statt umzuschnappen.
  * Einmal-Clips blenden schon vor ihrem Ende zurück.
  * Wer länger steht, verlagert ab und zu das Gewicht (Idle-Variante). Statisten werden bei niedriger Bildrate
    nicht mehr unter ~25 Animationsschritte/s gedrosselt.
* **Spielbrett:**
  * Würfelsprung als echte Abfolge: Ausholen, Absprung, Luftpose, Treffer, Fall, Landung, Stand. Vorher
    hart von „Absprung“ in „Laufen“.
  * Laufen mit Anlauf beim ersten und Abbremsen beim letzten Hüpfer; Kurven werden gedreht statt
    umgeschnappt.
  * Figuren drehen sich in Zwischensequenzen weich zur Kamera.
* **Texte passen immer:** `UI.fit_label` verkleinert Titelkarten, Untertitel („Team Rot: A & B & C“),
  Riesenwörter und Brett-Banner auf 90 % der Bildschirmbreite. Der Aufpopp-Effekt von „LOS!“ ragt nicht mehr
  über den Rand.
* **Seifenblasen-Ballett repariert und überarbeitet:**
  * Die Blasen hatten keine Kollision. Alle fielen schon im Intro aus der Kanone ins Leere, die Spielzeit
    war 0 s.
  * Jetzt: echte Standfläche, die eigene Blase ist steuerbar (Ausweichen, Zurückpaddeln), sichtbarer,
    pulsierender Rand, Hitze-Warnung, klügere CPU.
  * Bei mehreren Überlebenden entscheiden die Windtreffer.
* **Global:** Stürze vor dem Spielstart (Intro, Kanone, Countdown) zählen nicht mehr als Ausscheiden. Bei
  mehreren Überlebenden entscheiden in allen Überlebensspielen die Punkte.
* **Dungeon Drop:**
  * Vorher war das Feld nach ≈10 s zerstört.
  * Jetzt: Platten reißen erst nach kurzem Stehen, kommen glühend zurück (in den letzten 15 s nicht mehr),
    und die CPU meidet Wege über Löcher.
  * Gemessen: Spielzeit 36–55 s statt 7–16 s.
* **Steuerungs-Framework** (`docs/CONTROLS.md`):
  * Jedes Minispiel ist zu 100 % per Tastatur, Maus, Gamepad oder Touch spielbar. Neu: Maus-Links/Rechtsklick
    als A/B während Minispielen (aus auf Touch-Geräten).
  * Sensoren (Gyro, Mikrofon …) sind höchstens optional. Der CI-Check `tools/validate_controls.py` erzwingt
    das für alle 39 Minispiele.
* **Qualitäts-Sweep** `tools/dev/minigame_sweep.sh` spielt alle Minispiele mit 4 CPUs durch und prüft Dauer,
  Ausscheiden vor dem Start, Durchfallen, Clipping in Geometrie, Text-Überläufe und Skriptfehler.

## 1.1.9
* **Fix: Neustart ab Runde 3–5 (zurück zu „Tippen zum Starten“).** Das Spiel selbst springt nie zum Startbildschirm,
  es war der Browser: Er hat den Tab wegen Speichermangels beendet und neu geladen. Ursache war die Musik.
  * Im Web spielt Godot 4.7 Ton standardmäßig als „Sample“: Beim ersten Abspielen wird ein Stück komplett entpackt,
    im Schnitt 32 MB, kurzzeitig das Doppelte im WebAssembly-Speicher. Freigegeben wird es nie, denn
    `unregister_stream_as_sample` ruft die Engine nirgends auf.
  * Jedes Minispiel bringt drei eigene Stücke mit (normal, Hurry-Up, Outro).
  * Gemessen im Web-Export (Chromium, CPU-Party): **878 MB** Audio-Puffer nach zwei Runden, JS-Speicher bis 380 MB,
    WebAssembly-Speicher 232 → 334 MB.
* Jetzt läuft Musik im Web als Stream und wird stückweise dekodiert; kurze Effekte bleiben Samples. Gleicher Test:
  **35 MB** Audio-Puffer, JS-Speicher stabil um 45 MB, WebAssembly 225 MB.
  * Die Beat-Uhr gleicht die Ausgabelatenz des Streams aus, Rhythmus-Spiele bleiben synchron.
  * Vor Szenenwechseln blendet die Musik kurz aus, damit sie während des Ladens nicht knackst.
* **Kräftigere Farben auf hellen Brettern.** Wiese, Bucht, Wolkenland, Frostdorf, Sternwarte, Torte und Zauberwald
  am Tag wirkten milchig: im Mittel 75–83 % Helligkeit bei flachem Kontrast, die Farben liefen im Tonemapper ins Weiß.
  * Für helle Tag-Presets: weniger Belichtung, Umgebungslicht, Himmels-Anteil und Dunst, dafür mehr Kontrast
    und Sättigung.
  * Gemessene Sättigung: Wiese 0,41 → 0,53, Bucht 0,45 → 0,64, Zauberwald 0,52 → 0,65, Torte 0,44 → 0,57,
    Frostdorf 0,20 → 0,28.
  * Nacht- und Höhlen-Bretter waren schon satt und bleiben unverändert. Die Regler Farbsättigung/Farbstärke wirken
    wie bisher zusätzlich.
* Testwerkzeuge: Web-URL-Parameter `rounds`, `party-mode`, `log-scenes` für Langzeittests;
  `tools/dev/look_probe.gd` vergleicht Farb-Varianten eines Bretts im echten Renderer.

## 1.1.8
* **Firebase ist jetzt das einzige Backend** (Konten, Google-Anmeldung, Profil-Sync, Online-Lobbys). Der
  Supabase-Client aus 1.1.7 ist komplett entfernt. Die echten Fixes aus 1.1.7 bleiben erhalten:
  JS-Brücken-Erkennung, Fehlermeldungen, Profil-Fenster.
* **Fix Anmeldung: Tippfehler im Firebase-API-Key.** Im Code stand `…XT0n4K0` (Ziffer 0) statt `…XTOn4K0`
  (Buchstabe O), daher „API key not valid“.
* Projektdaten stehen zentral in `scripts/net/firebase_config.gd` (GDScript) und `web/lumos_bridge.js` (Web-SDK).
  Neuer CI-Schritt `tools/check_firebase_config.py`: bricht ab, wenn beide abweichen oder Google den Key ablehnt.
* **Online-Lobbys:** Ist die anonyme Anmeldung in Firebase aus, meldet die Lobby das sofort und klar, statt
  10 Sekunden zu warten und „keine Verbindung“ zu zeigen.
* Google-Redirect (iOS-Homescreen) startet nach der Rückkehr Firebase wieder und meldet an.
* Mehr verständliche Meldungen, z. B. Anmeldeweg nicht aktiviert, Domain nicht freigegeben, Konto gesperrt,
  keine Datenbank-Berechtigung.
* **Database-Regeln** (`firebase/database.rules.json`) passen jetzt zum Spiel: Athlon-Räume mit bis zu 20 Plätzen
  (vorher nur 0–3 erlaubt), Relay-Nachrichten bis 64 KB.
* Getestet:
  * nativ und im echten Web-Export (Chromium, Firebase-SDK 10.12.2) gegen das echte Firebase-Projekt;
  * Login landet sauber bei „E-Mail oder Passwort falsch.“;
  * Lobby meldet korrekt, dass die Gast-Anmeldung deaktiviert ist.
  Dabei wurde nichts angelegt, ein Test-Gastkonto wurde sofort wieder gelöscht.

## 1.1.7
* **Fix: Anmeldung im Web-Export („Anmeldung fehlgeschlagen (keine Verbindung)“).** Ursache: Das Spiel prüfte
  die JS-Brücke mit `JavaScriptBridge.eval(…) == true`; der JS-Boolean kam im Export nie als `true` an. Die Brücke
  galt als fehlend, Konten liefen über den nativen REST-Weg ins Leere, und die Startroutine (Sitzung
  wiederherstellen) brach ab. Jetzt wird als Text abgefragt.
* Dazu: Der hinterlegte Firebase-API-Key wird von Google als ungültig abgelehnt („API key not valid“), und im
  Projekt waren keine Supabase-Daten vorhanden.
* **Online-Konten über Supabase** (`scripts/net/supabase.gd`):
  * Registrierung, Login, Token-Refresh, Abmelden, Passwort vergessen mit „Neues Passwort festlegen“ und, im Web,
    Google per Weiterleitung.
  * Cloud-Profil in der Tabelle `profiles` mit RLS (`supabase/schema.sql`).
  * Gleicher Code nativ und im Web-Export, nur über HTTPS und nur mit Headern, die Supabase im CORS-Preflight erlaubt.
  * Die Sitzung bleibt über ein Neuladen erhalten. Tokens aus Bestätigungs- und Google-Links werden aus dem
    `#`-Teil der Adresse gelesen und sofort entfernt.
* Zugangsdaten über die Repo-Variablen `SUPABASE_URL` / `SUPABASE_ANON_KEY`. Die CI setzt sie ein und bricht bei
  einem service_role-Key ab. Ohne Daten zeigt das Profil-Fenster einen klaren Hinweis statt eines Formulars, das
  nicht funktionieren kann.
* Fehlermeldungen benennen jetzt die echte Ursache: falsches Passwort, E-Mail nicht bestätigt, schon registriert,
  ungültiger Key, Server nicht gefunden, Zeitüberschreitung, offline/blockiert. Die letzte Meldung bleibt im
  Profil-Fenster sichtbar, die eingegebene E-Mail bleibt stehen.
* **Fix Profil-Fenster:** Nach dem ersten Neuaufbau blieb es bei „Anmeldung läuft …“ hängen. Die gleichnamige alte
  Seite erzwang einen Ersatznamen, Konto-Updates wurden danach ignoriert.
* Web: Die Lumos-Cloud-Erkennung fragt `127.0.0.1:8787` nur noch auf Lumos-Geräten ab. Sonst gab es einen
  Konsolenfehler und in neuem Chrome eventuell eine Abfrage zum Zugriff aufs lokale Netzwerk.
* Getestet gegen einen strengen lokalen Supabase-Nachbau mit CORS-Prüfung: nativ (`tools/dev/supabase_probe.gd`)
  und im echten Web-Export in Chromium von einer fremden Herkunft (Registrierung, Profil-Sync, Neuladen mit
  automatischer Wiederanmeldung, Rückkehr per Weiterleitung).

## 1.1.6
* **Fix: Unerwarteter Neustart nach Minispielen** (Rücksprung zum Startbildschirm). Ursache war ein Speicherleck:
  Gfx hielt seit 1.1.4 jedes bearbeitete Mesh in einem Dictionary fest (pro Brett-Besuch über tausend Objekte),
  dazu ein unbegrenzter Modell-Cache und 4 verwaiste Nodes pro Szene. Lange Sessions liefen voll, bis der Browser
  den Tab neu geladen hat. Jetzt: Markierung am Mesh selbst, Modell-Cache behält nur die letzten zwei Szenen, die
  alte Szene wird vor dem Laden der neuen freigegeben (keine doppelte Spitzenlast). Gemessen: Objektzahl bleibt
  über viele Brett↔Minispiel-Wechsel konstant (~4.500 statt +1.100 je Wechsel), keine verwaisten Nodes mehr.
  Neue Testoption `--log-scenes` protokolliert jeden Szenenwechsel mit Speicher und Objektzahl.
* **Sattere Farben:** ACES statt Filmic-Tonemapping (Filmic hat helle Flächen entsättigt), weniger Dunstschleier,
  weniger bläuliches Himmelslicht in Schatten, höhere Grund-Sättigung.
* **Neue Regler** unter Einstellungen: *Farbsättigung* und *Farbstärke* – wirken sofort auf alle Szenen.

## 1.1.5
* **Bosskämpfe als freie Echtzeit-Arenakämpfe** statt Würfel-Ring: Alle laufen und springen frei, sammeln
  themenpassende Wurfgeschosse (Wasserbomben, Kokosnüsse, Sternsplitter …) und werfen sie mit B auf den Boss.
  Jede Fähigkeit ist eine sichtbar angekündigte Gefahr: leuchtende Bodenkreise (Lava, Eiszapfen, Kometen,
  Wurzeln, Karamell), Schweif-/Flammen-/Frostbögen und Wellen zum Drüberspringen, Sturmangriffe, zielsuchende
  Blasen/Raketen/Geisterorbs, Wind, Wirbelstürme, Schafherden, Kirsch-Bomben, vertauschte Steuerung, Nebel,
  Glätte. Die Einzigartigkeiten sind Orte in der Arena: brüchiger Boden über Lava, Sandbänke bei Flut,
  Wolkenkanonen in den Rücken des Bosses, Grabsteine als Schild, Riesen-Schneebälle, Uhrwerk-Felder,
  Pilzlicht bei Nacht, Duell-Felder, Kirsch-Lifte und Aufwind-Felder (Höhenbonus ×2).
  Phasen bei 66 %/33 % (kurz benommen, dann schneller; Wut-Phase mit Doppelangriffen), 80 Sekunden Zeit.

## 1.1.4
* **Performance-Notfall (alle Plattformen):** gemessen statt geraten – das Hauptmenü war GPU-gebunden.
  * Wasser deckend statt transparent (zwei bildschirmfüllende, sortierte Alpha-Flächen mit je 18.800
    Dreiecken waren der größte Einzelposten); Unterteilung gedeckelt.
  * Geometrie-Diät für alle prozeduralen Grundkörper, kleine Deko wirft keine Schatten mehr (z. B. 680 → 268
    Schattenwerfer), Sichtweiten-Culling kleiner Deko, Lichter blenden mit Entfernung aus.
  * Browser: eine Schattenkaskade unter „Hoch“, kürzere Schattendistanz, Glow nur auf Ultra, weniger Partikel.
  * Animations-LOD für Statisten (halbe/viertel Rate in der Ferne), Slapstick-Modifier nur nahe der Kamera.
* **Pinguin-Curling neu:** Pinguin liegt beim Zielen direkt vor der Figur und dreht sich in Schussrichtung
  (Stick, Stick-Richtung oder Maus), gepunktete Ziellinie mit Bandenabprall; jede Runde eine neue Bahn aus
  7 Layouts (Geraden, Kurven, S-Kurve, Slalom, Prellbock) mit Banden und Hindernissen.
* **10 Boss-Gegner** (je Brett einer, Kampfsystem ab 1.1.5 in Echtzeit): drei
  Fähigkeiten, drei Phasen (Wut-Phase mit Doppelangriff) und eine Einzigartigkeit pro Boss; vollständig
  prozedurale, animierte Modelle (Atmen, Schweben, Glühen, Rauch, Blasen, Zahnräder …) mit eigenen
  Aktions-Animationen. Münz- und Item-Effekte werden auf dem Brett verrechnet.

## 1.1.3
* **Performance (vor allem im Browser):**
  * 3D-Pixelbudget: Auf Retina-/4K-Displays (devicePixelRatio 2–3) wurde die Szene bisher in voller
    Geräteauflösung gerendert. Jetzt max. ~1700 px Breite (Ultra 2200) mit Hochskalierung; die UI bleibt scharf.
  * Dynamische Auflösung steigt bei dauerhaft zu niedrigen FPS jetzt auch eine Qualitätsstufe ab, statt an
    der Untergrenze stecken zu bleiben (nur bei Qualität „Auto“).
  * WebGL: MSAA nur noch auf „Ultra“, Glow erst ab „Hoch“, weiche Schattenfilter aus.
  * Physik: höchstens 4 Physik-Schritte pro Bild (keine Verlangsamungs-Spirale auf schwachen Geräten).

## 1.1.2
* **Automatisches Deployment:** Jeder Push auf `main` baut per GitHub Actions den Web-Export, führt das
  PWA-Postprocessing und den Browser-Rauchtest aus und veröffentlicht auf GitHub Pages
  (https://rxplxcxd.github.io/lumos-party-game/). Kein manueller ZIP-Download mehr nötig.
  Einmalig nötig: Settings → Pages → Source „GitHub Actions“ (oder Secret `PAGES_TOKEN`).
* **Fix (Online-Rennen):** Kam ein entfernter Fahrer als letzter Mensch ins Ziel, endete das Rennen auf dem
  Client nie (sein Ziel-Status wurde vor dem Rundenzähler gesetzt, die Ziel-Prüfung lief nicht). Jetzt wird
  jede Physik-Runde geprüft. Das war auch die Ursache des seit Tagen roten CI-Online-Tests.
* **Schlanker Web-Build:** Die Musik (≈ 30 MB) steckt nicht mehr im Start-Paket – `index.pck` schrumpft von
  49,6 auf 19,7 MB. Die Songs liegen als `music/…ogg` neben dem Spiel, werden bei Bedarf sofort und sonst im
  Hintergrund nacheinander geladen (Menü → Minispiele → Bretter). Native Builds behalten alles im PCK.
* **Schlankes Repository:** 34.371 nie importierte Dateien (≈ 685 MB) entfernt – FBX-/OBJ-/DAE-/STL-Duplikate,
  Vorschaubilder, Vektor-/Spritesheet-Varianten und ungenutzte Pakete, die Godot per `.gdignore` ohnehin
  übersprang. Das Spiel nutzt ausschließlich GLB/glTF; Inventar (`docs/ASSET_INVENTORY.md`) neu erzeugt.
  Texturen machen im Build nur 0,24 MB aus, Musik ist bereits effizient kodiert (≈ 108 kbit/s Vorbis) –
  eine erneute verlustbehaftete Kompression hätte hörbar geschadet und wurde bewusst nicht gemacht.

## 1.1.1
* **Fix: Web-Build hing beim Laden („Lädt Spielwelt … 59 %“).** Ursache: Godots Web-Lader reicht einen
  mitten im Download abreißenden Stream nie als Fehler weiter – der Balken friert dann für immer ein.
  Ausgelöst wurde das vor allem durch den Service Worker, der bei jedem neuen Build ~90 MB parallel
  vorgeladen, sich per `skipWaiting`/`clients.claim` mitten im Laden ausgetauscht und die großen Dateien
  durch sich hindurchgestreamt hat.
  * Ladebildschirm lädt `index.wasm`/`index.pck` selbst: Stillstand-Erkennung (15 s), Vollständigkeits-
    Prüfung, bis zu 4 Versuche; Wachhund mit „Neu laden“ (entfernt alte Service Worker & Caches).
  * Service Worker greift online nicht mehr in die großen Dateien ein, wird erst nach dem Spielstart
    registriert und legt sie danach im Hintergrund für den Offline-Start ab.
* **Neuer Ladebildschirm & neues Logo** aus echten Spiel-Assets (Ritter im Kart, Party-Stern, Würfel,
  Münzen) – gerendert mit `tools/brand/render_logo.gd`, Icons aus `tools/brand/make_icons.py`; Spiel-
  Schriften (Lilita One, Fredoka), gestreifter Ladebalken mit Stern, Tipps, Versionsanzeige.
* Neue App-Icons (PWA, Lumos Store, Projekt-Icon).

## 1.1.0
* Wolkenturm, Kolosseum-Turnier, eigene 3D-Avatare, 5 neue Minispiele, Themen-Tierchen, nur hochgeladene
  Soundtracks, Web-Build nicht mehr im Repo (siehe Git-Historie bis 9c2bdfe3).
