# Changelog – Lumos Party & Nitro Dash

Versionierung vor dem Release: **1.1.x** (1.1.1 … 1.1.9), danach **1.2.x** (Release-Reihe, Etappen 1.2.1 …).
Eine Quelle für alle Stellen: `python3 tools/version.py <version>` (bzw. `--next`). Commit-Betreff: `vX.Y.Z: …`.

## 1.3.0 – Trailer filmisch überarbeitet
Alle Änderungen liegen ausschließlich in `trailer/` (dazu Doku und Versionsnummer). Das Spiel ist unverändert.
* **Lebendigere Figuren:**
  * Aufeinanderfolgende Wegstücke gehen ohne Halt ineinander über. Angefahren und ausgerollt wird nur am Anfang
    und Ende einer Bewegung.
  * Der Kopf wandert weich zum Blickziel, statt umzuspringen. Beim Laufen schweift der Blick voraus, bei jedem
    in eigenem Takt.
  * Beim Anhalten sackt die Figur kurz ein, beim Loslaufen streckt sie sich. Jeder läuft seinen eigenen, leicht
    geschwungenen Weg. Der erschöpfte Barbar atmet sichtbar.
* **Nähe zum Zuschauer:** Der Held entdeckt nach der Enthüllung des Waldes die Kamera und winkt uns mit. Am
  Lagerfeuer zeigt eine Nahaufnahme die Keks-Pointe, und zum Schluss schauen Held und Barbar der aufsteigenden
  Kamera nach.
* **Weltenwechsel als zusammenhängende Laufsequenz:**
  * Wald → Wiese: hinter dem Baumstamm im Vordergrund (wie bisher, bildgenau unsichtbar).
  * Wiese → Schnee: Die Kamera fährt hinter einem Wasserfall im Raum hindurch (eigener Wasser-Shader, Gischt).
    Die frühere Überblendung entfällt.
  * Schnee → Strand: Der Träumer springt nach dem Stern. Die Welt wechselt in der Luft (Match Cut), er landet
    im Sand.
  * Die Gruppe läuft dabei durchgehend weiter.
* **Nitro Dash neu:** Gefahren wird auf dem echten Lumos-Ring aus dem Spiel (Streckenbaukasten nur gelesen) mit
  Banden, Tribünen, Zieltor und Horizont. Vier Einstellungen: Start, Drift durch die Kurve, Überholen mit Boost
  und Zieldurchfahrt. Die Kamera fährt in Streckenkoordinaten mit. Die Montage ist dafür einen Takt länger
  (Gesamtlänge 97 s), das Hurry-Thema läuft nahtlos weiter.
* **Kamera:** ein Hauch Handkamera (wenige Zentimeter) statt völlig starrer Fahrten.

## 1.2.9 – Trailer als eigenständige Produktion, fertiges 4K60-Video
* **Vollständig vom Spiel getrennt:** Die Trailer-Produktion liegt jetzt in einem eigenen Ordner `trailer/`
  (Szene, Regie, Render-Skript, Video-Prüfung, Doku in `trailer/README.md`):
  * Der Menüpunkt „Trailer ansehen“ ist wieder entfernt, das Spiel verweist nirgends auf den Trailer.
  * Der Trailer ist nicht mehr im Web- oder Linux-Export enthalten.
  * `trailer/check_isolation.sh` prüft das, auch in der CI.
  * Die Renderqualität (volle Auflösung, 4×MSAA, 8192er-Schatten, keine dynamische Auflösung, kein
    Animations-LOD) setzt der Trailer nur im eigenen Prozess. Die Grafik-Automatik des Spiels hätte beim
    langsamen Movie-Maker-Rendern die Auflösung gesenkt und bei 4K die 3D-Auflösung gedeckelt.
  * 4K entsteht über ein temporäres Render-Projekt mit eigener Fenstergröße. Die `project.godot` des Spiels
    bleibt unverändert.
* **Fertiges Video:** `bash trailer/render.sh` rendert den kompletten Trailer mit Kamerafahrten, Animationen,
  Übergängen, Musik, Effekten und Logo.
  * Ausgabe: 3840×2160 bei 60 fps als H.264/AAC-MP4 mit −14 LUFS, dazu eine 1080p60-Fassung.
  * Danach prüft `trailer/qa.py` das Video Bild für Bild: Format, Schwarzbilder, Bildsprünge gegen die
    Schnittliste der Regie, Standbilder, Tonaussetzer, Stille, Übersteuerung und Lautheit.
* **Trailer-Feinschliff:** Gewichtsverlagerung und Funkenflug laufen bildratenunabhängig (gleich bei 30 und
  60 fps), und bei Weltenwechseln zucken die Figuren nicht mehr.
* **Trailer-Feinschliff aus der Video-Prüfung:**
  * Der Stamm ist jetzt ein Verdecker, der beide Welten überdauert. Er wird im Wechselbild in der neuen Welt
    nachgeführt, sodass der Wechsel unsichtbar bleibt (gemessen Δ 0,0).
  * Der Boss ist riesig und die Gruppe klein im unteren Drittel.
  * Das Lagerfeuer hat eine flackernde Flamme.
  * Der Wasserfall fällt über eine Felswand, die Wasserwand hat einen Farbverlauf.
* **Ergebnis:** 4K60-Master und 1080p60-Fassung, beide mit „QA OK“:
  * 5731 Bilder, 19 harte Schnitte, alle aus der Schnittliste
  * keine Schwarz- oder Standbilder außerhalb von Auf- und Abblende
  * keine Tonaussetzer, kein Clipping, −14,2 LUFS, True Peak −1,3 dBFS
  * Renderzeit 1 h 48 min mit Software-Rendering
* **Spiel unverändert, geprüft:**
  * alle 69 Minispiele mit 4 CPUs regulär beendet: 0 Skriptfehler, niemand in Geometrie gesteckt oder
    durchgefallen
  * Systemtests, Skriptprüfung und Langzeit-Party bestanden
  * Spielcode gegenüber 1.2.8: nur der entfernte Menüpunkt

## 1.2.8 – Neue Asset-Pakete, Saison-Deko und Trailer
* **Asset-Inventur der hochgeladenen Pakete:**
  * Neu im Projekt (entpackt, in `tools/asset_pipeline.py` eingeordnet, `docs/ASSET_INVENTORY.md` neu erzeugt):
    KayKit Halloween Bits, Furniture Bits, Restaurant Bits, City Builder Bits, Platformer Pack und Skeletons 1.1.
  * Bereits vorhanden und inhaltsgleich, daher nicht doppelt abgelegt: Brettspiel-Teile, Dungeon Pack,
    RPG-Werkzeuge, Raumbasis und Holiday Bits. Character Animations 1.2 bringt keine neuen Clips für unser Rig.
    Seine Beispielfigur nutzt ein anderes Skelett und einen anderen Stil und wurde deshalb nicht übernommen.
  * Die ZIP-Dateien sind entfernt. Exportiert wird nur, was der Katalog wirklich benutzt (`tools/export_list.gd`).
* **Thematischer Einbau:**
  * Friedhof-Brett: Totholz, Grabmale, Gruft-Schrein, Sarg, Bank und Laternen (mit Licht) aus den Halloween Bits.
    Dazu vier Skelett-Zuschauer, die sitzen, wippen, jubeln und sticheln.
  * Geister-Fotograf: Die Villa ist eingerichtet (Regale unter den Fenstern, Schränke, Sessel, Stehlampen,
    Beistelltische mit Büchern). Die Möbel stehen eng an den Wänden, sind fest und lassen die Raummitte frei.
  * Rhythmus-Küche: Statt des Kastens steht dort eine echte Küchenzeile mit Kühlschrank, Theken, zwei Herden mit
    Eintopf-Töpfen und Dunstabzug, Ofen und Spüle. In den Ecken stehen Zutatenkisten.
  * Achsen-Taxi: Jede Blockecke hat jetzt Ampel, Hydrant, Bank und Mülleimer. Die Fahrbahn bleibt frei.
* **Saisonale Feiertags-Deko (`scripts/core/seasonal.gd`):**
  * Weihnachten (1. Dezember – 6. Januar) und Halloween (15. Oktober – 2. November) werden am Gerätedatum erkannt.
  * Es schmücken sich das Hauptmenü (Insel-Deko, Gruß unter dem Logo, an Halloween ein tanzendes Skelett), alle
    Bretter (Deko entlang des Wegs und ein Ensemble hinter dem Start: Weihnachtsbaum mit Geschenken bzw.
    Kürbishaufen mit Kerzen) und die Kulissen der Minispiele.
  * Jede Stelle wird geprüft: fester Boden unter der ganzen Grundfläche (nie Wasser, Lava oder Luft), keine
    Überlappung mit Bäumen, Häusern oder Figuren, nichts auf der Spielfläche und nichts Hohes zwischen Kamera und
    Geschehen. Kürbislaternen leuchten. Innenräume (Villa, Küche) bleiben ohne Außendeko.
  * Der Zufall ist lokal und fest je Ort, online bleibt der gemeinsame Spielzufall unberührt.
  * Neue Einstellung „Saison-Deko“: Automatisch / Aus / Weihnachten / Halloween. Zum Testen: `--season=…`.
* **Trailer „Lumos Party – Best adventures are shared.“:**
  * In der Engine inszeniert (`scenes/trailer/Trailer.tscn`), 95 Sekunden in fünf Akten:
    1. Stern in der Dunkelheit, Lichtwelle und Glühwürmchen-Wald.
    2. Weg mit Glühwürmchen, Stolpern und Wasserfall.
    3. Freunde finden sich: High-Five, Schmetterling auf der Nase, Zusammenstoß, der Träumer auf dem Stein, der
       vergessene Freund wird mitgezogen. Dazu drei Weltenwechsel hinter einem Stamm, durch eine Wasserwand und
       per Sternenblitz.
    4. Strand → Vulkan mit Boss, Stille, BOOM, dann eine Montage auf dem Takt: Minispiel-Start, Münzduell,
       Fotofinish, Wasserplumps, Boss-Ausweichen, Siegerpose, Nitro-Dash-Drift, Überholen, Ziellinie, Jubel.
    5. Lagerfeuer mit Keks-Pointe, aufsteigendem Funken, Logo, Slogan und Plattform-Hinweis.
  * Im Hauptmenü unter „Trailer ansehen“, jede Taste überspringt.
  * Als Video: `xvfb-run ./godot --path . --resolution 1280x720 --write-movie trailer.avi --fixed-fps 30
    res://scenes/trailer/Trailer.tscn -- --trailer-quit`, danach mit ffmpeg nach MP4. `--trailer-from=X` startet
    ab Sekunde X.
* **Credits & Lizenzen:** Die Credits nennen die neuen KayKit-Pakete und Quaternius. `LICENSES.md` führt die
  Soundpakete von lolurio und Nomagician Music (CC BY 4.0, Namensnennung im Spiel) jetzt ausdrücklich auf.
* **Tests:** `tools/dev/test_systems.gd` prüft die Saison-Deko: Datumsgrenzen, Einstellung Aus/erzwingen,
  Platzierung nur auf festem Boden (nie im Wasser) und keine Überlappungen.
* **Kleiner Fix:** Die Schlaf-„Z“ (`FX.zzz`) halten ihr Label nur noch über eine schwache Referenz. Endet eine
  Szene, bevor ihr Timer abläuft (z. B. ein übersprungener Trailer), meldet die Engine keinen Fehler mehr.

## 1.2.7 – Stabilitäts-, Physik- und Release-Update
* **Kein Neuladen mehr in langen Sessions:**
  * Hauptursache: Schrift-Glyphen. Jede Schriftgröße × Konturstärke legt eigene Texturseiten an, und die Engine
    gibt sie nie frei. Gemessen sind es ~3 MB je Größe; 53 Größen belegten 163 MB. Angepasste Labels, schwebende
    Texte und Bossnamen erzeugen über 10–15 Runden hunderte Größen, bis Safari den Tab neu lädt. Die Glyphen-Caches
    werden jetzt bei jedem Szenenwechsel geleert. Danach sind es 8 MB, und der Grafikspeicher wächst nicht mehr
    mit der Zahl der Runden.
  * Der Dreiecks-Cache der Deko-Ausrichtung hielt jedes Mesh jeder Szene fest.
  * Kart-Motoren erzeugten je Kart und Rennen einen neuen Sound, den der Browser nie freigab.
  * Speicher ohne Szene nach 15 Runden: vorher 224–343 MB, jetzt 165–210 MB. Der Rest ist Aufwärmen.
  * Zwei Hänger in Duellen behoben: Der Wolken- und der Portal-Auftritt warteten auf Bank-Spieler, deren Animation
    nie lief (die Partie fror ein), und der Wolken-Auftritt griff auf einen falschen Index zu.
  * Neuer Langzeit-Test `tools/dev/soak.gd`: eine CPU-Party über viele Runden mit Leck- und Hänger-Erkennung. Er
    läuft in der CI über 12 Runden, lokal mit bis zu 20 Runden und auch gerendert für den Grafikspeicher. Dazu
    kommt `tools/dev/web_soak.js` für die Browser-Messung. `--log-scenes` protokolliert jetzt Speicher, Objekte,
    Ressourcen, Texturen und Caches.
* **120 FPS als Standard:**
  * Neue Einstellung „Automatisch“: 120 FPS auf Bildschirmen ab 100 Hz (iPhone/iPad Pro, Gaming-PCs,
    High-Hz-Android), sonst 60. Im Browser wird der Bildschirmtakt gemessen.
  * Schafft ein Gerät die 120 nicht dauerhaft, fällt die Bildrate für die Sitzung auf stabile 60 FPS zurück, statt
    unscharf zu werden.
  * Notebooks und Handhelds im Akkubetrieb laufen mit 60 FPS. Der alte Standard „60“ wird automatisch übernommen.
* **iPhone-Ecken:**
  * HUDs, Boss-Leisten, Emote-Knopf, Cutscene-Hinweis und die FPS-Anzeige liegen innerhalb der sicheren Ränder:
    runde Displayecken, Dynamic Island und Home-Leiste, auf allen vier Seiten gemessen.
  * Die Debug-Anzeigen bleiben vollständig erhalten.
* **Minigolf mit echter Physik:**
  * Höhenfeld mit Hügeln und Senken, Rollwiderstand, saubere Banden- und Eckabpraller, elastische Ball-Stöße und
    ein Lochfang nach Tempo und Trefferlage (Lippe).
  * Statt der pendelnden Kraftanzeige lädt A gleichmäßig auf 100 %, der Stick dreht fein, und Leuchtpunkte zeigen
    den Startweg.
  * Die CPU simuliert ihre Schläge mit derselben Physik. Punkte über drei Läufe: Insane 9,7, Leicht 1,7.
* **Volleyball:**
  * Spieler kommen nicht mehr durchs Netz (feste Feldgrenze direkt in der Bewegung).
  * Der Stick bestimmt das Ziel. Neu sind Zuspiel → Schmetterball, Block am Netz und Abpraller bei schlecht
    angenommenen harten Bällen. Punkte entstehen aus dem Spiel, nicht aus Zufall.
  * CPUs teilen sich das Feld, spielen in Lücken und blocken. Insane gegen Leicht: 27:6.
* **Bosse:**
  * Kompakte, halbtransparente Lebensleiste, die sich ausblendet, sobald der Boss dahinter steht.
  * Neue Kameras zeigen den Boss unterhalb von Timer und Leiste.
  * Der Mega-Summser wird durchscheinend, solange er Spieler verdeckt, und hat jetzt eine sichtbare Leiste.
* **CPUs:**
  * Festgefahrene CPUs weichen seitlich aus, überlappende Figuren halten Abstand, und beim Mega-Summser kommt jede
    CPU von einer eigenen Seite.
  * Betäubungen liefen nach Wanduhr statt Spielzeit, das verfälschte Zeitlupe und niedrige Bildraten.
  * Festfahr-Zeit im Sweep: vorher bis 36 s je Spiel, jetzt meist unter 3 s.
  * Alle 69 Spiele wurden in allen 103 Kategorie-Varianten geprüft: ohne Hänger und ohne Skriptfehler.
* **Online:**
  * Absender werden am Transport geprüft. Bisher konnte sich ein Gerät als Host ausgeben, etwa mit „Spiel beendet“
    an alle. Host-Nachrichten kommen nur noch vom Host. Eingaben und Punkte gelten nur für den eigenen Platz.
  * Hammer-Hüpfen: Der Richtungswechsel kam bei Gästen nie an (Feld-Kollision).
  * Native REST-Zugriffe wiederholen bei Funklöchern.
  * Neue CI-Tests: Rennen bei schlechter Verbindung (300 ms, 5 % Verlust) und Host-Absturz mitten im Brettspiel.
* **Performance:** Kulisse weit außerhalb der Arena wirft keine Schatten mehr.
* **Release:**
  * Neue `LICENSES.md` mit allen Paketen und ihrer Herkunft.
  * README mit eigenem Nitro-Dash-Abschnitt und aktuellen Zahlen; Markennamen entfernt.
  * Doku zu Speicher/Stabilität, Online-Sicherheit, Bildrate und den überarbeiteten Minispielen.

## 1.2.6 – Polishing-, Performance- und Fix-Update
* **Glücksrad deterministisch:**
  * Das Rad bremste Bild für Bild ab und meldete am Ende das Feld unter dem Zeiger. Bei unterschiedlicher
    Bildrate (Host flüssig, Gast-Laptop ~15 FPS) landeten die Geräte auf verschiedenen Feldern und wandten
    verschiedene Effekte an.
  * Jetzt legt der Entscheider das Feld fest. Die Bremskurve ist eine exakte Funktion der Zeit und endet bei
    jeder Bildrate genau dort. Angewendet wird immer das verteilte Ergebnis.
  * Das Minispiel-Roulette lädt ebenfalls den festgelegten Eintrag.
  * Glücks-Glöckchen zeigt Symbole und Gewinn fremder Automaten exakt wie beim Besitzer. Vorher stand dort
    immer „+1“, und die fremden Walzen drehten nicht.
* **Minispiele:**
  * Hammer-Hüpfen: Der obere Balken kreiste starr gegenüber (180°) und war so keine echte Gefahr. Jetzt wandert
    sein Abstand zum unteren ständig, er rückt bei niedrigem Tempo deutlich näher heran. Zwischen beiden
    bleibt immer mindestens ~1 s, damit es fair bleibt.
  * Tauziehen: Das Seil endet exakt an den Händen der äußersten Figur jeder Seite. Vorher ragte es rund 6 m
    nach hinten durch die Figuren.
  * Flitzestein-Wurf: keine versteckte Kante mehr (20,4° = 88 m, 20,6° = sofort versunken). Der Absprung hängt
    stetig vom Aufprallwinkel ab, das Optimum liegt bei ~25°.
  * Pinguin-Curling: Die Wurf-Reihenfolge wird ausgelost, damit der Vorteil des letzten Wurfs nicht am Platz
    hängt.
  * Faire Startplätze: In 18 Jeder-gegen-jeden-Spielen werden die Startplätze jede Runde aus dem gemeinsamen
    Zufall verteilt. Bei fester Aufstellung in einer Reihe gewannen die Außenplätze messbar öfter (15,7 und 12,2
    gegen 8,2 und 4,0 Siege in 40 Spielen).
  * Jede Erklärkarte nennt jetzt in einer eigenen Zeile das **Ziel**, abgeleitet aus Spielart und Kategorie. Für
    22 Spiele steht dort eine genaue Wertung, z. B. „Gold +3, Kiste +1, Bombe −2“.
  * Schienen-Express erklärt die Steuerung für eine allein besetzte Lore.
* **Erklärbildschirme:**
  * Lokal bleibt die Anleitung stehen, bis jemand bestätigt (A, Leertaste, Klick oder Tippen); Sicherheitsgrenze
    10 Minuten. Nur mit CPUs geht es nach 2 s weiter.
  * Online gibt es eine Bereit-Abfrage: Jeder Mensch bestätigt, alle sehen „Bereit: 2 / 3 · Warte auf …“. Los
    geht es, sobald alle bereit sind, spätestens nach 15 s.
* **Welt-Begrenzung:**
  * Viele Arenen sind erhöhte Inseln über einem tieferen Fernboden. Daneben platzierte Deko schwebte in der Luft
    oder ragte über Kanten; eine Prüfung fand 448 solche Modelle in 34 Spielen.
  * `PropSettler` setzt jetzt nach dem Aufbau jedes Deko-Modell sauber auf: Kanten-Objekte rücken auf die
    Fläche, Schwebendes wird auf den Boden darunter abgesenkt, Deko im Nichts ausgeblendet.
  * Spielelemente bleiben unberührt: alles mit Kollision und alles, was das Spielskript selbst hält.
  * Danach bleibt in allen 69 Spielen ein einziger Stein als Grenzfall.
* **Netzwerk:**
  * Wartezeiten großzügig: Der Pong-Wächter wartet 60 s statt 12 s, und eigenes Laden zählt nicht mit.
    Synchronisationspunkte warten 60 s, das Szenen-Laden 120 s, die Anmeldung 60 s, HTTP-Anfragen 30 s.
    Langsame Laptops fliegen nicht mehr heraus.
  * Ping-Analyse: Werte von 300–400 ms sind die Server-Weiterleitung (Relay). Die Anzeige nennt jetzt den Weg
    („85 ms · direkt“ bzw. „über Server“) und glättet Ausreißer.
  * Ping läuft über den Direktkanal unzuverlässig, also ohne Warten hinter Spielereignissen.
  * Relay-Nachrichten werden pro Bild und Empfänger gebündelt, statt jede einzeln zu schreiben.
* **Performance & Audio:**
  * Minispiel-Roulette: Die Walze zeichnet alle Zeilen in einer Schriftgröße und skaliert sie per
    Transformation. Vorher musste jede Größe erst neu gerastert werden.
  * Schrift, Effekt-Klänge und Partikel-Shader werden vorab hinter dem Ladebildschirm vorbereitet, auch in
    Minispielen.
  * Audio auf schwachen Geräten: Im Web wird die Musik auf dem Hauptthread nachgemischt; bei ~15 FPS lief der
    50-ms-Puffer leer und es stotterte. Der Puffer hat jetzt 160 ms; Effekte laufen weiter verzögerungsfrei
    als Samples.
  * Die Beat-Uhr folgt der echten Zeit statt der Spielzeit, die bei Hitstops und unter 15 FPS gebremst wird.
  * Neue Einstellung **Bildrate**: 60 (Standard), 120 (High-Hz) und Maximal (Bildschirmtakt). Die Physik rechnet
    im gleichen Takt, damit 120 FPS wirklich flüssig sind. CPU-Zeitgeber rechnen mit der echten Bildzeit statt
    fester 1/60 s.
* **Robustheit:** Wird eine Minispiel-Szene während der Anleitung verlassen, bricht der Ablauf sauber ab statt
  mit einem Fehler.
* **Werkzeuge:**
  * `tools/dev/deco_audit.gd`: Deko-Prüfung aller Minispiele.
  * `tools/dev/arena_overview.gd`: Übersichtsbilder.
  * `tools/dev/frame_probe.gd`: Bildzeit-Sonde.
  * `tools/dev/web_perf.js`: Web-Messung mit CPU-Drosselung.
  * `tools/dev/decision_shot.gd`: Kontrollbilder der Entscheidungs-Dialoge.
  * Web-Seite: `?args=` für Test-Startparameter.
  * `test_systems.gd` prüft zusätzlich Glücksrad, Deko-Absicherung und Bildrate.

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
* **Minispiel-Übergänge:**
  * Das Endergebnis enthält jetzt auch Zusatzergebnisse (z. B. Boss-Schaden).
  * Gäste warten bis zu 15 s statt 5 s darauf und zeigen dabei einen Hinweis. Vorher rechneten sie bei
    langsamer Verbindung eigene Platzierungen.
* **Tests:**
  * `net_test.sh` kann jetzt mehrere Gäste testen (`CLIENTS=2`), mit einem bedienenden Mensch-Gast (`HUMAN=1`)
    und eigener Figur je Gerät (`HEROES=…`).
  * Das Skript prüft: identische Spielerliste auf allen Geräten, eindeutige Plätze, Bedienelemente nur für den
    eigenen Platz und identischen Brettzustand.
  * `test_systems.gd` prüft zusätzlich Codec, Spielerliste und Host-Korrektur.
  * Die CI spielt jetzt zusätzlich ein Online-Brett mit drei Geräten (zwei Gäste, einer davon bedient als
    Mensch).
  * Testhilfe `--test-partner` (nur Debug-Builds) lässt Partner früh erscheinen und erzwingt so unterbrochene
    Züge.

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
