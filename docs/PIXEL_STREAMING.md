# Unreal Engine Pixel Streaming — 3D-Hero für mensaena.de (Web)

Hyperrealistischer 3D-Hero auf der Landing-Page, gerendert von **Unreal Engine**
und per **Pixel Streaming** (WebRTC) in den Browser gestreamt. Nur Web — die
Flutter-App ist nicht betroffen. Der funktionale Teil der Seite (Login, Posts,
Chat, Karte, Marktplatz) bleibt unverändert klassisch und schnell.

> **Wichtig vorab — was Pixel Streaming ist:** Unreal rendert die Szene auf einem
> **GPU-Server**, nicht im Browser. Der Browser zeigt nur einen WebRTC-Videostream
> und schickt Maus/Tastatur zurück. Maximale Foto-Optik, **aber**: pro
> gleichzeitigem Besucher ist eine GPU-Session gebunden → Kosten skalieren mit
> Nutzung. Deshalb startet der Stream in Mensaena **nur auf Klick** ("3D live
> erleben") und endet beim Schließen wieder.

---

## 1. Architektur

```
 Browser (mensaena.de)                GPU-Server (NVIDIA)
 ┌───────────────────────┐            ┌──────────────────────────────────┐
 │ Landing-Hero          │  WebRTC    │  Unreal-App (-PixelStreaming)     │
 │ <iframe src=          │◀──────────▶│  + Signalling-Server (Node)       │
 │  NEXT_PUBLIC_         │  Video/    │  + Web-Frontend (Player)          │
 │  PIXELSTREAM_URL>     │  Input     │  + TURN (coturn) für NAT          │
 └───────────────────────┘            └──────────────────────────────────┘
```

Die Web-Seite bündelt **keine** WebRTC-Bibliothek. Der Player wird vom
Signalling-Server ausgeliefert und per `<iframe>` eingebettet
(`src/app/landing/components/HeroPixelStream.tsx`). Vorteil: kein Cloudflare/
OpenNext-Build-Risiko, keine neue npm-Dependency, klarer Sicherheits-Sandkasten.

---

## 2. Web-Seite aktivieren (bereits implementiert)

1. Player-URL des Signalling-Servers als Env setzen (Cloudflare Pages/Workers →
   Project → Settings → Environment Variables, **und** lokal in `.env.local`):

   ```
   NEXT_PUBLIC_PIXELSTREAM_URL=https://stream.mensaena.de
   ```

2. Deployen. Auf tauglichen Desktops (WebRTC vorhanden, keine reduzierte
   Bewegung, kein Datensparmodus, Breite ≥ 900 px) erscheint im Hero der Button
   **„3D live erleben"**. Auf Mobil/unsupported bleibt automatisch der klassische
   Cinematic-Hero (Fallback).

Ohne gesetzte Variable rendert die Komponente nichts — null Risiko im Bestand.

---

## 3. Unreal-Engine-Projekt vorbereiten

Empfohlen: **UE 5.3+** (Linux- oder Windows-Server).

1. **Plugin aktivieren:** Edit → Plugins → „Pixel Streaming" (+ „Pixel Streaming
   Player" falls vorhanden) → Editor neu starten.
2. **Projekt packen:** Platform → Windows/Linux → **Shipping** oder
   **Development**, „Package Project".
3. **Hyperrealismus-Checkliste (Performance vs. Optik):**
   - Lumen (Global Illumination + Reflections) **oder** Hardware-Raytracing
   - Nanite für Geometrie, Virtual Shadow Maps
   - Post-Processing-Volume: Bloom, Exposure (Auto), DOF, Motion Blur (sparsam),
     Film-Grain, Chromatic Aberration dezent, Color-Grading (LUT) passend zur
     Bronze/Teal-Palette der Seite (`--bronze #c79363`, Hintergrund `#0a1420`)
   - HDRI/Sky-Light für realistische Lichtstimmung (Dusk passend zum Web-Look)
   - Ziel: **stabile 30–60 fps** auf der Ziel-GPU bei 1080p (sonst ruckelt der
     Stream für alle Nutzer dieser Session)

---

## 4. Gepackte App mit Pixel Streaming starten

Die App muss mit Pixel-Streaming-Argumenten laufen und sich beim Signalling-
Server anmelden:

```bash
# Linux-Beispiel (headless GPU-Server)
./Mensaena3D.sh \
  -RenderOffScreen \
  -PixelStreamingURL=ws://localhost:8888 \
  -PixelStreamingEncoderMaxBitrate=20000000 \
  -ResX=1920 -ResY=1080 -ForceRes \
  -Unattended -AudioMixer
```

```powershell
# Windows-Beispiel
.\Mensaena3D.exe -RenderOffScreen -PixelStreamingURL=ws://localhost:8888 ^
  -ResX=1920 -ResY=1080 -ForceRes -Unattended
```

- `-RenderOffScreen` rendert ohne sichtbares Fenster (Server-Betrieb).
- `-PixelStreamingURL` zeigt auf den **Streamer-Endpunkt** des Signalling-Servers.

---

## 5. Signalling-Server + Web-Frontend

Epics offizielle Infrastruktur: **Pixel Streaming Infrastructure**
(`https://github.com/EpicGamesExt/PixelStreamingInfrastructure`).

```bash
git clone https://github.com/EpicGamesExt/PixelStreamingInfrastructure
cd PixelStreamingInfrastructure/SignallingWebServer
# passende Version zum UE-Release auschecken (z. B. UE5.3 / 5.4 / 5.5 Branch)
npm ci
# Start (HTTP 80, Streamer-WS 8888, Player-WS 8080 — Defaults je Version prüfen)
npm start -- --publicIp=<SERVER_IP>
```

Der Server liefert auch das **Player-Web-Frontend** aus — genau dessen URL
kommt in `NEXT_PUBLIC_PIXELSTREAM_URL`. Hinter einen Reverse-Proxy mit TLS legen
(`stream.mensaena.de`), denn der Player im iframe braucht **https** (sonst
blockiert der Browser WebRTC auf einer https-Seite).

### TURN-Server (Pflicht in der Praxis)

Hinter NAT/Firewalls scheitert WebRTC ohne TURN. `coturn` aufsetzen und in der
Signalling-Config (`config.json` / Peer-Connection-Options) als
`iceServers` eintragen.

---

## 6. Einbettung absichern

- **HTTPS erzwingen** auf `stream.mensaena.de` (gültiges Zertifikat).
- **Frame-Embedding einschränken:** Auf dem Stream-Server Header setzen, sodass
  nur `mensaena.de` den Player einbetten darf:
  ```
  Content-Security-Policy: frame-ancestors https://mensaena.de https://www.mensaena.de
  ```
- Der iframe läuft mit `sandbox="allow-scripts allow-same-origin
  allow-pointer-lock allow-fullscreen"` und `allow="autoplay; fullscreen;
  gamepad; xr-spatial-tracking; clipboard-write"`.

---

## 7. Skalierung & Kosten (realistisch einplanen)

- **1 GPU-Session ≈ 1 gleichzeitiger Besucher** im 3D-Modus.
- Für mehr Parallelität: **Matchmaker** (`Matchmaker`-Dienst der Infrastruktur) +
  mehrere Unreal-Instanzen / mehrere GPU-Knoten, idealerweise Autoscaling
  (z. B. AWS `g4dn`/`g5`, Azure `NV`-Serie, GCP `g2`). Scale-to-zero, wenn niemand
  streamt, spart am meisten.
- **Kostenrahmen:** Eine einzelne Cloud-GPU liegt grob bei mehreren hundert
  €/Monat bei Dauerbetrieb; rechne pro paralleler Session mit eigener GPU-Zeit.
  Der Klick-zum-Start-Mechanismus auf der Seite begrenzt das auf interessierte
  Nutzer.

---

## 8. Lokaler End-to-End-Test

1. Unreal-App lokal mit `-PixelStreamingURL=ws://localhost:8888` starten.
2. Signalling-Server lokal starten.
3. `NEXT_PUBLIC_PIXELSTREAM_URL=http://localhost:80` (bzw. der lokale Player-Port)
   in `.env.local`, `npm run dev`.
4. Landing öffnen → „3D live erleben" → der lokale Stream erscheint im Overlay.

> Hinweis: Lokal (http) funktioniert WebRTC; in Produktion **muss** der Player
> über https laufen, weil mensaena.de https ist.

---

## 9. Frame-Sequenz für das Scrollytelling (empfohlen für die Landing)

Der Scroll-Story-Abschnitt (`CinematicScrollStory.tsx`) "scrubbt" beim Scrollen
eine **vorgerenderte UE-Frame-Sequenz** auf ein Canvas — die Technik der
modernsten Websites (Apple-Stil). Das ist günstiger und robuster als Live-
Streaming für jeden Besucher: die Frames liegen statisch im CDN, laufen auf
jedem Gerät, kosten keine GPU-Session.

**Schritt 1 — In Unreal rendern (Movie Render Queue):**
1. Sequencer-Kamerafahrt durch die Szene bauen (z. B. langsamer Flug über das
   Viertel bei Dämmerung, passend zur Bronze/Teal-Palette).
2. Window → Cinematics → **Movie Render Queue**, Output: **PNG/EXR-Sequenz**,
   1920×1080 (oder 2560×1440), 24–30 fps, ~6–8 s ⇒ ~150–240 Frames.
3. Anti-Aliasing/Spatial-Samples hoch für sauberes Foto-Niveau.

**Schritt 2 — Zu WebP konvertieren (klein + scharf):**
```bash
# aus dem Render-Ordner; ergibt 0001.webp, 0002.webp, …
ffmpeg -i frame_%04d.png -vf "scale=1920:-2" -q:v 80 hero-seq/%04d.webp
# (oder cwebp pro Datei). Ziel: pro Frame ~40–120 KB
```

**Schritt 3 — Ablegen + aktivieren:**
- Dateien nach `public/hero-seq/` (→ liegen dann unter `https://www.mensaena.de/hero-seq/0001.webp`).
- Env setzen (Cloudflare + `.env.local`):
  ```
  NEXT_PUBLIC_HERO_SEQ_COUNT=180
  NEXT_PUBLIC_HERO_SEQ_BASE=/hero-seq/
  NEXT_PUBLIC_HERO_SEQ_EXT=webp
  ```
- Deploy. Der Scroll-Story-Abschnitt nutzt ab sofort die echten UE-Frames; ohne
  Frames bleibt der cinematische CSS-Fallback aktiv (kein Bruch).

> Tipp: erstes Frame klein-vorladen (`<link rel="preload">`) wenn die Sequenz
> sehr groß wird; die Komponente lädt sonst progressiv und zeigt bis dahin den
> Fallback.

---

## 10. Alternative (Upgrade-Pfad): native Frontend-Bibliothek

Statt iframe lässt sich Epics `@epicgames-ps/lib-pixelstreamingfrontend(-ui)`
direkt in eine React-Komponente einbauen (mehr UI-Kontrolle, eigene Overlays).
Trade-off: zusätzliche, browser-only Dependency → muss per
`dynamic(() => import(...), { ssr: false })` geladen werden und gegen den
Cloudflare/OpenNext-Build verifiziert werden. Für v1 bewusst der iframe-Weg.
