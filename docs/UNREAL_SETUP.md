# Unreal Engine Setup — hyperinteraktiver 3D-Hero (Pixel Streaming)

Einfache Schritt-für-Schritt-Anleitung: von „Unreal installieren" bis „Haus im
Browser, Tür öffnet sich beim Scrollen". Ziel-Architektur: **Live Pixel Streaming**
(echtes UE in Echtzeit auf einer GPU, per WebRTC in die Landingpage gestreamt).

> **Aufgabenteilung:** Die Schritte mit 🧑 machst **du** (Installieren, Lizenzen,
> GPU, Assets). Die Schritte mit 🤖 übernehme **ich** automatisch über den
> `unreal`-MCP, sobald er läuft (Szene bauen, Blueprint, Web-Anbindung).

---

## Teil 0 — Voraussetzungen 🧑

- **Windows 10/11** mit **NVIDIA-GPU** (Pixel Streaming braucht NVENC-Hardware-Encoder).
  Ohne NVIDIA-GPU läuft das Streaming nicht flüssig.
- **Epic Games Account** (kostenlos) + **Epic Games Launcher**.
- **~100 GB freier Speicher** (Engine + Projekt + Assets).
- **Node.js 18+** (für den Signalling-Server) — https://nodejs.org
- **Git** (hast du bereits).

---

## Teil 1 — Unreal Engine installieren 🧑

1. Epic Games Launcher öffnen → Reiter **Unreal Engine** → **Library**.
2. Auf **+** klicken, **Version 5.4** installieren (stabil für Pixel Streaming + Megascans).
   *(5.5 geht auch, nutzt aber „Pixel Streaming 2" — sag mir, welche du wählst.)*
3. Installieren, fertig.

---

## Teil 2 — Projekt erstellen 🧑

1. Unreal 5.4 starten → **Games** → Vorlage **Blank** (oder **Archviz**, falls vorhanden).
2. Einstellungen:
   - **Blueprint** (nicht C++)
   - **Quality: Maximum**, **Raytracing: aktiviert** (für Hyperrealismus)
   - **Starter Content: an**
3. Projektname z. B. **`MensaenaCity`**, Speicherort merken (Pfad brauche ich).
4. **Create**. Der Editor öffnet sich.

---

## Teil 3 — Hyperrealistisches Haus / Assets 🧑

Ein fotorealistisches Haus braucht echte Assets. Drei einfache Quellen:

**Option A — Fab / Quixel Megascans (gratis mit Epic-Account, empfohlen):**
1. Im Editor oben rechts: **Fab** öffnen (früher „Quixel Bridge").
2. Suche z. B. „house", „building", „nordic house", „village" → Asset **Add to Project**.
3. Auch Boden/Vegetation/HDRI-Himmel mitnehmen für Stimmung.

**Option B — Marketplace/Fab Archviz-Pack:**
- Such auf fab.com nach einem fertigen „Archviz House"/„Modular House"-Pack
  (manche gratis, viele kostenpflichtig) → **Add to Project**.

**Option C — Du hast schon ein Haus-Asset:** super, sag mir den Namen/Pfad.

> Wichtig für die Tür: Die Tür sollte ein **eigenes, bewegliches Mesh** sein
> (eigene Komponente), damit ich sie animieren kann. Wenn das Haus eine separate
> Tür hat → ideal. Wenn nicht, platziere ich eine separate Tür davor.

---

## Teil 4 — Pixel Streaming aktivieren 🧑

1. **Edit → Plugins** → Suche **„Pixel Streaming"** → Häkchen setzen.
   *(UE 5.5: „Pixel Streaming 2".)*
2. Editor **neu starten**, wenn er fragt.

---

## Teil 5 — Den `unreal`-MCP-Server starten 🧑 → dann übernehme ich 🤖

1. Starte denselben **`unreal`-MCP-Server** wie vorhin (Adresse `127.0.0.1:8000`).
   *(Das ist das Tool, mit dem ich Unreal fernsteuere.)*
2. Lass Unreal + den Server laufen.
3. **Sag mir Bescheid** (oder starte ihn einfach) — mein Wächter erkennt ihn
   automatisch und sondiert, was er kann. **Kein Claude-Neustart nötig.**

Ab hier mache **ich** automatisch (soweit der MCP es zulässt):
- 🤖 Haus + Tür im Level platzieren, Kamera + Licht setzen
- 🤖 **Blueprint**: empfängt das Scroll-Signal aus dem Browser → spielt die
  **Tür-Öffnen-Animation** + zeigt die nächste Info
- 🤖 Pixel-Streaming-Startparameter setzen

---

## Teil 6 — Signalling-Server starten 🧑 (einmalig)

Der vermittelt die WebRTC-Verbindung zwischen UE und Browser.

```bash
git clone https://github.com/EpicGamesExt/PixelStreamingInfrastructure
cd PixelStreamingInfrastructure
# passenden Branch zur UE-Version auschecken, z. B.: git checkout UE5.4
cd SignallingWebServer/platform_scripts/cmd
setup.bat        # einmalig Abhängigkeiten holen
start.bat        # Server starten (lauscht u.a. auf Port 80 + 8888)
```

---

## Teil 7 — Unreal mit Pixel Streaming starten 🧑/🤖

Einfachster Weg direkt im Editor:
1. Im Editor oben das **Pixel-Streaming-Menü** (Stecker-Symbol) öffnen.
2. **Signalling Server URL**: `ws://127.0.0.1:8888` eintragen.
3. **Stream Level Editor / Start Streaming** klicken.

*(Alternativ als gepackte App mit `-PixelStreamingURL=ws://127.0.0.1:8888
-RenderOffScreen` — Details in docs/PIXEL_STREAMING.md.)*

---

## Teil 8 — Mit der Landingpage verbinden 🤖

1. Player-URL des Signalling-Servers (lokal meist `http://127.0.0.1` bzw. der
   angezeigte Port) →
   `.env.local`: `NEXT_PUBLIC_PIXELSTREAM_URL=http://127.0.0.1`
2. Ich rüste die Einbettung auf Epics Frontend-Bibliothek um, damit der
   **Scroll-Fortschritt live an UE** geht (`emitUIInteraction`) → Tür reagiert.
3. Lokal testen: scrollen → Tür öffnet sich im echten UE-Stream. ✅

---

## Teil 9 — Live auf www.mensaena.de 🧑 (später, kostenpflichtig)

Für die öffentliche Live-Schaltung läuft Schritt 6 + 7 nicht lokal, sondern auf
einem **öffentlichen GPU-Server** (z. B. AWS `g4dn`/`g5`, Azure `NV`) unter
`stream.mensaena.de` (mit TLS + TURN). Dann `NEXT_PUBLIC_PIXELSTREAM_URL` in
Cloudflare auf diese URL setzen. Kosten: pro paralleler GPU-Session.

---

## Was ich JETZT von dir brauche
1. **UE-Version** (5.4 oder 5.5?)
2. **Projektpfad** (z. B. `C:\Users\manue\Documents\Unreal Projects\MensaenaCity`)
3. **Haus-Asset** vorhanden? (Name/Pfad) oder soll ich aus Fab/Megascans wählen?
4. **`unreal`-MCP-Server gestartet?** → dann lege ich los.
```
