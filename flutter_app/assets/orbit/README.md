# assets/orbit/ — OrbitViewer-Frames (Bronze-Abzeichen)

Frame-Sequenz für `widgets/effects/orbit_viewer.dart` — ein drehbares
Bronze-Abzeichen im `badge_detail_sheet`. Die Engine ist fertig; hier fehlen
nur noch die Einzelframes (`bronze_00.webp` … `bronze_NN.webp`,
im Uhrzeigersinn 0–360°).

## Quelle (Higgsfield, bereits generiert)

- **Still** (start=end-Frame, nahtloser Loop), nano_banana_2 1024×1024:
  Job `a2f5ec27-a26b-448a-aa93-722e00ef105c`
  → `https://d8j0ntlcm91z4.cloudfront.net/user_3Eufkd7yR265iHqkL4xqSEjJo8x/hf_20260613_001110_a2f5ec27-a26b-448a-aa93-722e00ef105c.png`
- **Turntable-Video** (Seedance 2.0, 720×720, 5 s, std, start=end=Still →
  nahtlose 360°-Drehung), Job `b0cbb243-cc92-437f-88b5-519d8c969213`
  → **VIDEO_URL:**
  `https://d8j0ntlcm91z4.cloudfront.net/user_3Eufkd7yR265iHqkL4xqSEjJo8x/hf_20260613_001146_b0cbb243-cc92-437f-88b5-519d8c969213.mp4`
  (CloudFront-URLs können ablaufen — bei 403 das Video über die Higgsfield-
  History neu beziehen, Job-ID oben.)

## Frame-Pipeline (in einer ffmpeg-fähigen Umgebung ausführen)

> In der Web-Session standen **weder ffmpeg noch cwebp** zur Verfügung —
> darum liegt hier nur das Video, nicht die fertigen Frames.

# Das Quell-Video liegt bereits im Repo: `assets/orbit/_source_turntable.mp4`
# (2,4 MB, NICHT in pubspec → wird nicht in die App gebündelt, dient nur als
# Frame-Quelle). Der `_`-Präfix markiert es als Build-Quelle, kein Asset.

```bash
# 1) Quell-Video (liegt im Repo) — oder per VIDEO_URL neu laden
cp assets/orbit/_source_turntable.mp4 turntable.mp4

# 2) 36 gleichmäßige Frames (alle 10°). 5 s Video → fps = 36/5 = 7.2
mkdir -p frames
ffmpeg -i turntable.mp4 -vf "fps=36/5" -frames:v 36 frames/bronze_%02d.png

# 3) Auf Anzeigegröße skalieren (Viewer rendert ~220 dp → 440 px @2x reicht)
#    und als WebP q80 komprimieren (klein halten — 36 Frames!)
for f in frames/bronze_*.png; do
  n=$(basename "$f" .png)
  cwebp -q 80 -resize 440 440 "$f" -o "assets/orbit/$n.webp"
done

# Richtwert: 36 × ~12 KB ≈ 430 KB gesamt. Bei Bedarf 24 Frames (alle 15°)
# oder q75 nehmen. gaplessPlayback im Viewer kaschiert kleine Sprünge.
```

Qualitätskontrolle: Frame 00 und 35 müssen nahtlos ineinander übergehen
(deshalb start=end-Image im Video). Falls das Video minimal „springt",
das letzte Frame (`bronze_35`) weglassen.

## Einbau in `badge_detail_sheet.dart` (sobald Frames liegen)

`pubspec.yaml` deklariert `assets/orbit/` mit aufnehmen
(`flutter: assets: - assets/orbit/`).

Im Sheet das statische Icon-`Container` (großes Abzeichen, ~Zeile 110–136)
bei `earned == true` durch den Viewer ersetzen — Frames als Konstante:

```dart
import '../effects/orbit_viewer.dart';

const _bronzeOrbitFrames = [
  for (var i = 0; i < 36; i++)
    'assets/orbit/bronze_${i.toString().padLeft(2, '0')}.webp',
];

// statt des Icon-Containers, wenn earned:
earned
  ? OrbitViewer(
      frameAssets: _bronzeOrbitFrames,
      size: 96,
      hintLabel: 'badges.dragToRotate'.tr(), // neuer i18n-Key (7 Sprachen)
    )
  : /* bisheriger statischer Icon-Container (nicht verdient) */,
```

EffectsGate ist bereits im Viewer verdrahtet: full = Drag + Fling-Momentum +
einmaliger Hinweis, reduced = nur Drag, none = statischer Referenz-Frame
(kein Sequenz-Preload). Schwach-Geräte-tauglich (nur Bildwechsel, keine
Game-Engine). Reine Dart-/Asset-Änderung → OTA-Patch.
