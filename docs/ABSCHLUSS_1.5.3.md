# Abschlussbericht 1.5.3 – Release-Nachträge, Character-Framework-Stufe „1.6“, Universe Polish

Version **1.5.3** (die Framework-Stufe heißt im Auftrag „1.6“ – das ist der Arbeitstitel, keine Versionsnummer).
Branch `claude/elegant-johnson-2kfiut`, `main` unverändert. Alle Zahlen stammen aus Läufen in dieser Umgebung
(Cloud-Container, CPU ohne GPU); was nicht gemessen werden konnte, steht ausdrücklich dabei.

## A – Git und Pull Request

| Punkt | Stand |
|---|---|
| PR für die 1.5.2-Nachträge | [rxplxcxd/lumos-party-game#4](https://github.com/rxplxcxd/lumos-party-game/pull/4) – `claude/release-1.5.2-nachtraege` → `main` |
| Enthaltene Commits | `7a07d1b5` (Draw-Calls −19 %, Minigolf ohne Ruck), `6164e5ae` (Abschlussbericht präzisiert) |
| CI des PR | Lauf 44147956385 (Ereignis `pull_request`): `build` erfolgreich; `release`/`deploy-pages` übersprungen (laufen nur auf `main`); Vercel-Vorschau erfolgreich |
| Merge | **nicht gemergt – wartet auf Freigabe** |
| 1.5.3-Arbeit | `claude/elegant-johnson-2kfiut`: `e269a412` (Gesicht, Verdeckung, Framework je Bereich, Linse), `01bc5290` (Strecken, Bretter, Linsen-Test, Testplan), Abschluss-Commit mit diesem Bericht |
| Hinweis | Die 1.5.3-Commits setzen auf `6164e5ae` auf. Nach dem Merge von #4 enthält ein PR dieses Branches nur noch die 1.5.3-Commits. |

## B – Bretter: eigenes Leben je Brett

`scripts/party/board_life.gd` (`BoardLife`), eingehängt beim Brettstart neben dem Tierleben am Rand. Jedes Brett hat
eigene Elemente – kein gemeinsamer Effekt für alle:

| Brett | Elemente |
|---|---|
| Wuschel-Wiesen | Pusteblumen-Schirmchen im Wind, Drachen an der Schnur, Schwalben hoch über den Hügeln |
| Sonnige Palmen-Bucht | Möwen über dem Meer, Glitzern auf dem Wasser |
| Dungeon Deep | Staub im Fackellicht, Tropfen von der Decke, Glut über dem Lavasee |
| Sternen-Wolkenland | ziehende Wolkenfetzen, drei Heißluftballons am Horizont |
| Geisterfriedhof | Irrlichter im Außenring, kreisende Krähen, welkes Laub |
| Frostdorf | leiser Schneefall, Polarlicht |
| Sternen-Sternwarte | Sternschnuppen, Funkeln, drei kreisende Planeten |
| Glühwürmchen-Zauberwald | leuchtende Sporen, Feenlichter |
| Zuckerback-Torte | Zuckerstreusel, aufsteigende Luftballons |
| Wolkenturm | Blätter im Aufwind um den Turm, Vögel um die Spitze |

Regeln: rein dekorativ, keine Kollision, kein Netz-Abgleich, eigener Zufall (globaler Zufall unberührt); alles in der
Luft oder im Außenring – nie auf Feldern, Wegen oder vor der Brett-Kamera. Grafikstufe „Niedrig“: nur bewegte
Figuren, keine Partikel. Felder, Wege, Ereignisse, Kamera und Spielablauf sind unverändert.

Leistung (Test-Server, headless, CPU je Bild, 20 s Brett, Framework an; „aus“ = ohne BoardLife):

| Brett | aus | an | | Brett | aus | an |
|---|---|---|---|---|---|---|
| Dungeon | 1,47 | 1,06 | | Sternwarte | 1,37 | 1,47 |
| Bucht | 1,32 | 1,25 | | Zauberwald | 1,04 | 1,64 |
| Wolkenland | 1,01 | 1,22 | | Wiesen | 1,01 | 1,06 |
| Friedhof | 1,08 | 1,31 | | Torte | 1,14 | 1,09 |
| Frostdorf | 0,99 | 1,40 | | Wolkenturm | 1,05 | 1,31 |

Die Unterschiede liegen meist im Rauschen zweier Läufe (±0,1–0,4 ms); spürbar sind Zauberwald (+0,6 ms) und Frostdorf
(+0,4 ms) – dort danach weniger Partikel (Sporen 34 → 24, Schnee 60 → 46). Kein Bild > 33 ms, keine Engine-Fehler.
Draw-Calls: je Element 1–3 (Vögel je 3 Teile), zusammen ≈ +10–30 je Brett bei ≈ 1100 – nicht gesondert gemessen.

Sichtprüfung (Kontrollbilder `tools/dev/board_life_shot.gd`, Spielkamera + Weitsicht): Planeten an der Sternwarte und
Irrlichter am Friedhofszaun sind zu sehen; Vögel, Polarlicht und Sternschnuppen liegen in der Weitsicht oft außerhalb
des Bildes oder sind klein, Schneeflocken vor Weiß kaum sichtbar – **im Spiel mit eigenen Augen prüfen**.

## C – Nitro Dash: längere, abwechslungsreichere Strecken

Je Strecke ein eigener Abschnitt vor dem Rundenschluss (der Baukasten schließt die Runde danach selbst). Varianten
(normal, gespiegelt, flacher, kürzer, Spiral-Brücke) wurden automatisch geprüft; gewählt wurde je Strecke die erste
ohne Selbstüberschneidung, deren Rückgerade samt Schlenkern erhalten bleibt.

| Strecke | neu | Länge | Bestrunde (8 CPU) | Median-Runde |
|---|---|---|---|---|
| Lumos-Ring | Esse-Kombination, Kehre | 1060 → 1269 m (+20 %) | 40,4 → 45,3 s | 41,6 → 49,9 s |
| Korallen-Kanal | zweite Felsinsel mit zwei Routen, Fontänen | 1037 → 1333 m (+29 %) | 38,8 → 52,3 s | 44,1 → 55,2 s |
| Neon-Vulkan | Sprung über den Glutgraben, Lavafontäne | 997 → 1196 m (+20 %) | 37,6 → 43,4 s | 38,7 → 47,6 s |
| Sturmpass | Kehre mit Steilkurve, nass | 1198 → 1407 m (+17 %) | 45,4 → 54,0 s | 47,6 → 55,5 s |
| Frost-Gipfel | Eis-Kehre, Steilkurve, Sprung, Schneeball | 999 → 1367 m (+37 %) | 38,0 → 51,3 s | 39,9 → 54,4 s |
| Orbit-Ring | Sprungkissen, Plasmakugel | 1196 → 1411 m (+18 %) | 44,7 → 53,8 s | 46,2 → 55,9 s |
| City-Rally | Häuserblock, zwei Straßen, Lieferwagen | 1120 → 1436 m (+28 %) | 40,6 → 55,4 s | 44,2 → 58,8 s |
| Wüsten-Canyon | Dünensprung, Steppenläufer | 1015 → 1415 m (+39 %) | 38,8 → 51,9 s | 40,9 → 54,4 s |
| Glühwald | zweiter Baumtunnel, Pilz-Sprungkissen | 1157 → 1422 m (+23 %) | 43,1 → 55,1 s | 46,3 → 57,1 s |
| Zuckerstraße | Looping, Sprungkissen, Kaugummikugeln | 1050 → 1560 m (+49 %) | 39,7 → 57,9 s | 40,6 → 60,4 s |
| Dschungel-Tempel | Spiral-Brücke über den eigenen Anfang | 1136 → 1288 m (+13 %) | 43,3 → 49,6 s | 46,7 → 53,1 s |
| Wasserfall-Schlucht | zweiter Wasserfall, nasse Kehre, Sprung | 1047 → 1395 m (+33 %) | 39,7 → 52,5 s | 41,3 → 54,6 s |

Prüfungen: Strecken-Prüfung 12/12 ohne Überschneidung („TRACKS OK“), Fahrtest 12/12 – alle 8 Karts im Ziel, keine
Skriptfehler, keine Warnung; Item-Regeln OK. Fahrphysik, Drift, Kollisionen, Items und KI sind nicht verändert – nur
die Streckendaten.

Ehrlich: Hängenbleiben (Kart unter 4 m/s ohne Treffer) am Stück höchstens 1,3 s (Lumos-Ring, vorher 0,2 s;
Warnschwelle 3 s) – vermutlich die enge neue Kehre vor dem Rundenschluss, nicht einzeln untersucht. Der Dschungel
gewinnt nur +13 % (jede andere Variante zerstört die Schlenker seiner Rückgeraden). Tunnel gibt es nur als Baumtunnel
(Glühwald); „Brücke“ ist die Spiral-Brücke (Dschungel). Sichtprüfung der neuen Abschnitte im Spiel steht aus.

## D – Split-Screen: Linsentropfen je Ansicht

* Jede Split-Ansicht (`SplitView.lens`) hat eine eigene Linse mit eigenen Tropfen nach ihrem Fahrer und ihrer Kamera
  (Regen, Gischt, Fontänen, Auftauchen); die Vollbild-Linse bleibt im Split-Screen leer.
* Lage und Größe nach dem eigenen Rechteck, Tropfengröße nach der Ansichtshöhe; der Linsen-Shader liest nur das Bild
  der eigenen Ansicht (`view_rect`) – an den Grenzen bricht kein Nachbarbild hinein.
* Test `tools/dev/lens_split_test.gd` (auch in der CI): 4 Ansichten auf dem Sturmpass – jede Linse genau 638 × 358
  an ihrer Stelle, Leserechteck = eigene Ansicht, 12–17 Tropfen je Ansicht, Vollbild-Linse 0. Der Test fand dabei
  einen Fehler: Die Linsen der Ansichten hatten zuerst die Größe 0 (Anker ohne Ränder) – behoben.
* Leistung: ohne Tropfen ist eine Linse unsichtbar und kostet nichts; mit Tropfen eine Bildschirmkopie je
  Zeichenebene (alle Ansichten teilen eine). GPU-Kosten auf echten Geräten **nicht gemessen**.

## E – Character Framework (Stufe „1.6“)

**Mund an der Haut** (`LumosFace`): jeder Mund-Punkt einzeln auf der Haut (Tiefenraster, Normale je Punkt), weiche
Grenzen an Kinn, Nase, Schnurrbart, Wange und Ausrüstung. Messung `--lab-face` (feines Raster aus den echten
Dreiecken, 6 Ausdrücke):

| Held | vorher: vor / in der Haut (Kopfbreiten) | jetzt: senkrecht davor / in der Haut |
|---|---|---|
| Ritter | +0,33 / −0,085 | ≤ +0,017 / ≥ −0,003 |
| Barbar | +0,044 / −0,095 | ≤ +0,026 / ≥ −0,007 |
| Magier | +0,12 / −0,055 | ≤ +0,025 / ≥ −0,009 |
| Waldläufer | +0,146 / −0,134 | ≤ +0,032 / ≥ −0,009 |
| Schurke | +0,45 / −0,055 | ≤ +0,027 / ≥ −0,007 |
| Kapuzen-Schurke | +0,054 / −0,042, Zähne unter der Maske | Mund unter der Maske ausgeblendet |

Vorderansicht, Schrägsicht (35°), Seite (80°) und Kopfdrehungen (links, hoch, runter) als Referenzbilder je Held
(`--lab-face=<ordner>`; auch mit echtem Rendering 6/6 PASS). Vergleich der Seitenansicht beim Lachen, vorher/nachher:
`docs/screenshots/1.5.3_mund_seite_vorher_nachher.jpg`. Blend Shapes: bei keinem der 20 Modelle vorhanden – die
Gesichtsebene bleibt die Lösung.

**Verdeckung** (`LumosAppearance`, neu): Zustände je Bereich (sichtbar · eingeschränkt · teilweise verdeckt ·
ausgeblendet) aus Ausrüstung, gemalten Bärten, Vorgaben. Labortests je Held: eigene Teile aus/ein stellt den Zustand
exakt wieder her; geschlossenes Visier blendet Augen, Brauen, Mund, Wangen aus (0 gezeichnete Punkte); Glasbrille
lässt die Augen sichtbar („teilweise verdeckt“); Maske blendet den Mund aus. Hände an Helm/Hut/Maske: Anteil der
echten Hand-Punkte (CPU-Skinning der Hand) in Ausrüstung bei allen 7 Kopf-Gesten 0 % – **mit und ohne** Ausweichen;
die Messung zeigt also keine Durchdringung, belegt aber auch nicht die Wirkung des Ausweichens. Das Ausweichen selbst
ist an den Zielpunkten geprüft (Ritter Kinn/Wange, Maske vor dem Gesicht: Ziel 0,05–0,16 Kopfbreiten nach außen;
unter der Magier-Krempe 0) – ob es in Bewegung natürlich aussieht, zeigt erst die Sichtprüfung.

**Funde und Fixes:** Wackel-Physik erkannte Zubehör am ganzen Teilnamen – beim Kapuzen-Schurken wippten alle acht
Teile wie ein Hut (seit 1.5.2); das Gesicht folgt jetzt dem Knochen, an dem die Gesichtshaut hängt (alle sechs
Helden: 100 % Kopfknochen).

**Kompatibilität (getestet, nicht angenommen):** Gesicht bei 6 KayKit-Helden (alle PASS); 4 Skelett-Helden,
4 Kenney-Figuren, 4 NPCs, 2 Haustiere ohne Gesicht (keine erkennbaren Augen bzw. kein Kopf-Mesh – Körper, Mikroleben,
Gesten wie bisher); eigene Lumos-Avatare (`custom/…`) ohne Framework, nicht geprüft.

**Sozialverhalten (Punkt 10):** vorhanden und im Verhaltenslabor geprüft (98/98): Reaktionszeiten streuen nach
Persönlichkeit und Abstand (B21: 0,24 s Streuung, nie alle gleichzeitig), Angesprochene reagieren anders als
Zuschauer, beschäftigte Figuren lassen sich nicht ablenken, gleichzeitige Anfragen laufen nacheinander (B23),
Unterbrechungen lösen Interaktionen sauber (B22), Blickkontakt mit Ausweichen bei Schüchternen (B17). In 1.5.3 nicht
neu gebaut – nur nachgemessen.

**Integration je Bereich** (`LumosGame`, eigener Schalter je Bereich, „Lebendige Mimik“ als Grundschalter; Menü-Insel
und Siegerehrung unverändert; Fallback = Original-Animation):

| Bereich | Umfang | CPU je Bild aus → an (headless, 20 s) |
|---|---|---|
| Spielbrett (4 Figuren) | Gesicht, Mikroleben, Körper, Cartoon halb | 0,38 → 1,33 ms (Wiesen) |
| Minispiele (Avatare) | nur Gesicht, Gefühle, Augen | 0,79 → 1,74 ms (Sumo-Schubser) |
| Nitro Dash (Fahrer) | nur Gesicht, Gefühle (Treffer, Zielplatz) | 0,91 → 1,37 ms (Lumos-Ring) |

Spielablauf, Steuerung, Physik und Netz sind unberührt (das Framework nutzt nur eigenen Zufall; online legt das
entscheidende Gerät Würfel und Entscheidungen fest und verschickt sie – das Framework greift nicht ein).

**Leistung gegenüber der Vorversion** (PerfLab, 16 Figuren, derselbe Rechner, nacheinander): Szenario F (alles
zugleich) Gesicht zeichnen 3,21 → 3,19 ms, Framework gesamt 7,59 → 7,65 ms; Szenario A 0,78 → 0,88 ms (im Rauschen
dieses Laufs, dort streuen auch unveränderte Teile um ≈ 10 %).

**Was noch eine Sichtprüfung braucht:** Lesbarkeit der gestauchten Ausdrücke bei sehr kurzem Kinn (Waldläufer:
Mund-Grenze 0,08 halbe Breite), Gesten am Helm in Bewegung (nur geometrisch geprüft), Gesichter auf dem Brett und in
Minispielen aus der echten Spielkamera, Mulden unter der Nase (bis 3 % der Kopfbreite Abstand).

## F – Geräte-Leistung

Testplan: `docs/GERAETE_TESTPLAN.md` (Messgrößen, Geräte-Matrix, Ablauf, Vorlage). **Kein echtes Gerät verfügbar** –
deshalb keine Geräte-FPS. Vorhanden:

* Test-Server headless (CPU): Abschnitte B, C, E dieses Berichts; `docs/PERF_SCENES.md` (1.5.2).
* Simuliert (Web-Export in Chromium, Software-Rendering): siehe unten – nur zum Vergleichen, keine Gerätewerte.

**Simuliert – keine Gerätewerte.** Web-Export dieses Stands (`--export-release "Web"`), lokal ausgeliefert, gemessen
mit `tools/dev/web_perf.js` in Chromium headless mit **Software-Grafik (SwiftShader)** – die GPU-Arbeit läuft dort auf
der CPU, echte Geräte mit GPU liegen deutlich höher. CPU-Drosselung 1× bzw. 4× (wie ein schwaches Gerät). Je Szene
nach dem Laden (eingeschwungen):

| Szene | Drosselung | FPS (je 2-s-Fenster) | schlechtestes Bild je Fenster | Laden bis zum ersten flüssigen Bild |
|---|---|---|---|---|
| Hauptmenü (Figuren-Insel mit Framework) | 1× | 24–29 | 50–83 ms | ≈ 6 s |
| Hauptmenü | 4× | 19–21 | 67–83 ms | ≈ 16 s |
| Spielbrett (Start über `--scene`, mit BoardLife und Framework) | 1× | 33–38 | 33–50 ms | ≈ 6 s |
| Spielbrett | 4× | 26–30 | 50–100 ms | ≈ 18 s |

Lange Hauptthread-Aufgaben (> 50 ms) treten in der Simulation regelmäßig auf (Software-Rasterung); einzelne
Aufgaben von 2,5–11 s fallen in die Ladephase. Eine Aussage über ein bestimmtes Gerät erlaubt das nicht – dafür ist
der Testplan da.

## G – Abschluss

| Abnahme | Stand |
|---|---|
| Sichtprüfung Gesichter (vorn/schräg/seitlich, Kopfdrehungen) | Referenzbilder je Held; Mund liegt an, kein abstehender Mund mehr |
| Geometrie Mund (automatisch) | 6/6 PASS (`--lab-face`) |
| Ausrüstung / Verdeckung | 6/6 PASS inkl. Visier, Glasbrille, Maske, Teile aus/ein |
| Hände nicht durch Ausrüstung | 0 % Hand-Punkte in Ausrüstung (7 Gesten, 4 Helden mit Kopf-Ausrüstung) – auch ohne Ausweichen; Wirkung nur geometrisch geprüft |
| Automatische Tests | Check 261/0, Verhaltenslabor 98/98, Gesichts-Labor 6/6, System-Tests, Item-Regeln, Strecken-Prüfung 12/12, Fahrtest 12/12, Linsen-Test, Langzeit-Test (12 + 4 Runden), Menü-Agent (Tastatur 11/11 Abläufe, Controller, Smartphone 844×390, Tablet 1024×768: keine Probleme), Spieler-Agent (5 Minispiele mit Gesichtern, 32 Läufe, 0 Skriptfehler), Trailer-Trennung |
| Sozialverhalten | nachgemessen (Verhaltenslabor), nicht neu gebaut |
| Leistung gegenüber Vorversion | PerfLab ohne Mehrkosten; Bereiche Brett/Minispiel/Rennen ≈ +0,5–1 ms CPU |
| Integration, Schalter, Fallbacks | je Bereich schaltbar; aus = Original-Animation und Original-Gesicht |
| Kompatibilität dokumentiert | 20 Modelle geprüft (Abschnitt E) |
| CI auf dem Endstand | Workflow „build-web“ auf dem letzten Commit dieses Branches (Lauf-Nummer und Ergebnis in der Abschlussmeldung; neue Schritte: Gesichts-Labor, Linsen-Test) |

Beobachtung ohne Bezug zu 1.5.3: Der Spieler-Agent meldet in Minispielen Bildspitzen von 70–130 ms, wenn ein Klang
zum ersten Mal von der Platte geladen wird (z. B. „splash“ 110 ms) – das Framework spielt dort keine Klänge; ein
Vorwärmen der Effekt-Klänge beim Minispielstart wäre der nächste Schritt (nicht umgesetzt).

Offene Grenzen: keine Geräte-FPS (kein Gerät); GPU-Kosten von Linsentropfen und Brett-Leben nicht gemessen; Strecken
und Brett-Leben nur automatisch und auf Kontrollbildern geprüft, nicht im Spielertest; Dschungel nur +13 %;
Lumos-Ring 1,3 s Hängenbleiben am Stück (unter der Warnschwelle); eigene Avatare ohne Framework.
