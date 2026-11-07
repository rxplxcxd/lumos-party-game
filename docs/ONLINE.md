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

## Konten

| Umgebung | Anmeldung |
|---|---|
| Lumos OS / Lumos One | Lumos Cloud (`/v1/auth/login|register|refresh`, Profil über `/v1/profile` mit Versionierung) |
| Browser, iOS, Android, PWA | Google (Firebase-Popup bzw. Redirect auf iOS-Homescreen) oder E-Mail/Passwort |
| Native ohne Browser | E-Mail/Passwort über die Firebase-REST-API |
| Gast | nur lokal |

Profile werden beim Anmelden zusammengeführt (Bestzeiten = Minimum, Zähler = Maximum, Freischaltungen = Vereinigung).
