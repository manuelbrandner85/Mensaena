# Motion-Design-Vorschläge — Flutter-App „immersiv"

> Stand: 2026-06-12 · Basis: `emil-design-eng` + `impeccable` + `taste-skill`
> (global installiert, siehe CLAUDE.md „Design- & Motion-Skills")
> Grundregel bleibt: **elegant, professionell, subtil** — Immersion durch
> Tiefe und Physik, nicht durch Lautstärke. JEDER Vorschlag läuft über das
> EffectsGate (none/reduced/full) und respektiert den Frame-Watchdog.

## Vorhandenes Fundament (nicht neu bauen)
- `AppMotion` (Springs snappy/gentle/bouncy + `springTo()`), `AppTransitions`
  (forward/surface/sheet/immersive/calm), `EffectsGate` + Frame-Watchdog
- `Pressable` (Spring-Scale + Haptik), `AnimatedEntrance` (jetzt mit
  `spring:`-Option), `TiltCard`, `CinematicBackdrop`/`-VideoBackdrop`
- GPU-Shader-Pipeline (`shaders/grain.frag`), `OrbitViewer` (360°-Dreh-Viewer)
- Higgsfield-Asset-Pipeline (Stills + nahtlose Loop-Videos, WebP/H.264)

## Entscheidungsrahmen (aus emil-design-eng, gilt für alles unten)
1. **Häufigkeit:** 100×/Tag gesehen → NICHT animieren (Tab-Wechsel,
   Tastatur-Aktionen). Selten/erstmalig (Onboarding, Erfolge) → Delight erlaubt.
2. **Zweck:** Räumliche Konsistenz, Zustands-Feedback, Erklärung — nie „sieht
   cool aus" bei häufigen Interaktionen.
3. **Easing:** Eintritte ease-out (nie ease-in!), Bewegung auf dem Screen
   ease-in-out, Gesten/Unterbrechbares → Springs (AppMotion).
4. **Dauer:** UI < 300 ms (Press 100–160, Sheets 200–500). Atmosphäre
   (Ken-Burns, Drift) darf langsam sein — sie ist Bühne, nicht UI.

---

## Paket A — Räumliche Kontinuität (höchste Wirkung, OTA-fähig erst nach Bump)
**A1 · Container-Transform („reveal"):** `animations`-Paket einbauen
(⚠️ Dependency → Version-Bump nötig, in TODO bereits als Plan vermerkt).
Karte → Detail wächst aus der Karte heraus statt zu pushen:
PostCard→PostDetail, EventCard→EventDetail, Badge→BadgeDetail,
Story-Avatar→StoryViewer. Das ist DER größte Immersions-Hebel, weil die
App räumlich zusammenhängend wird. `AppTransitions.reveal` ist als Slot
schon vorgesehen.

**A2 · Hero-Bilder konsequent:** `Hero`-Tags auf Post-/Event-/Profil-Bildern
(SDK-only, sofort OTA-fähig). Mit `flightShuttleBuilder` + leichtem Scrim-
Crossfade; auf `reduced` automatisch Fade (über AppTransitions-Mechanik).

**A3 · Geteilte Achse im Create-Wizard:** Die 3 Steps des Create-Flows mit
SharedAxis-X (bzw. bis zum Bump: Slide+Fade via AppMotion.gentle) statt
hartem Umschalten — Fortschritt wird körperlich spürbar.

## Paket B — Mikro-Physik (SDK-only, sofort OTA)
**B1 · Pressable-Sweep:** Pressable (Spring + Haptik) von den 2 Kern-Karten
auf alle Cards ausrollen (EventCard, MarketplaceCard, GroupCard,
KnowledgeCard, StatCard). Regel bleibt: InkWell für Listen-Rows (Ripple),
Pressable für Cards.

**B2 · Spring-Entrance gezielt:** `AnimatedEntrance(spring: true)` NUR für
Hero-Momente (erste Dashboard-Karte, Erfolgs-Karten, Empty-State-CTA) —
lange Listen behalten easeOutCubic (Emil: Häufigkeit!).

**B3 · Overscroll mit Charakter:** `StretchingOverscrollIndicator` global
(Android-12-Stretch statt Glow) + bei Pull-to-Refresh ein kleiner
Mensaena-Puls (Logo-Kreis skaliert mit AppMotion.gentle an der Zuggrenze).

**B4 · Zahlen leben:** `TweenAnimationBuilder`-Count-up für Stats
(Karma, Zeitbank-Saldo, Impact) beim ersten Sichtbarwerden + `AnimatedFlipCounter`-
artiger Ziffern-Roll (selbst gebaut, SDK-only) bei Wertänderung. Auf
`reduced`: sofortiger Wert.

**B5 · Morphende Action-Buttons:** „Helfen"-Button morpht Zustand
(Idle → Spinner → Häkchen) in EINEM Button via `AnimatedSize`+`AnimatedSwitcher`
statt SnackBar-only-Feedback — Zustands-Feedback am Ort der Aktion.

## Paket C — Atmosphäre & Tiefe (Bühne, nicht UI)
**C1 · Parallax-Schichten auf der Karte:** Map-Screen bekommt beim
Sheet-Aufziehen eine subtile Tiefenstaffelung (Map dimmt + skaliert 0.98,
Sheet schwebt mit AppMotion.gentle darüber) — iOS-Modal-Gefühl.

**C2 · Scroll-gekoppelte Hero-Header:** `parallax_image_header` auf alle
Detail-Screens mit Bild ausrollen (Post/Event/Org/Profil): Bild scrollt
mit 0.5×, Titel blendet in die AppBar (SliverPersistentHeader). Vorhandenes
Widget, nur Adoption.

**C3 · Tageszeit-Übergänge:** CinemaOverlay-Phasenwechsel (dawn→day→dusk→night)
mit 8s-Crossfade existiert — Vorschlag: SkyBody-Position zusätzlich entlang
eines Bogens animieren (Sonne/Mond „wandert" beim Phasenwechsel). Nur `full`.

**C4 · Shader Nr. 2 + 3:** Auf der grain.frag-Pipeline aufbauen:
(a) `heat_shimmer.frag` für Krisen-frei-Feiermomente/Sommer-Events (sehr subtil),
(b) `aurora.frag` als Premium-Hintergrund für Badge-/Level-Up-Sheets.
GPU-only, 0 Dart-Arbeit/Frame, Fallback = statischer Gradient.

**C5 · OrbitViewer aktivieren:** Sobald Higgsfield-Turntable-Frames generiert
sind (assets/orbit/, Plan steht in TODO): drehbares Bronze-Abzeichen im
badge_detail_sheet — der erste „greifbare" Gegenstand der App.

## Paket D — Momente des Stolzes (selten = Delight erlaubt)
**D1 · Level-Up-Zeremonie:** Karma-Levelwechsel (Nachbar→Helfer→…) bekommt
ein Vollbild-Moment: CinematicBackdrop + CelebrateBurst + Count-up +
neues Level schwebt mit AppMotion.bouncy ein. 1×/Level — hier darf es groß sein.
**D2 · Erste-Hilfe-Moment:** Erste abgeschlossene Hilfe-Interaktion eines
Users → einmalige Dankes-Sequenz (Higgsfield-Still + Konfetti + Teilen-CTA).
**D3 · Streak-Flamme:** Login-/Hilfe-Streak-Widget mit lebendiger
Mini-Flamme (CustomPainter, 2 Layer, nur `full`; `reduced` = statisches Icon).

## Paket E — Geführte Wahrnehmung
**E1 · Mensa-Pulse (offener TODO-Punkt):** Einmaliger Puls-Hinweis auf dem
Assistant-FAB beim ersten Öffnen komplexer Screens (Karte/Beitrag) —
`flutter_secure_storage`-Flag, AppMotion.gentle-Doppelpuls, dann nie wieder.
**E2 · Skeleton→Content-Choreografie:** Skeletons nicht hart ersetzen,
sondern 150 ms-Crossfade + 4 px-Lift (AnimatedSwitcher mit
FadeUpwardsTransition) — nimmt dem Laden die Härte.
**E3 · Empty-State-Atmung:** EmptyStateCard.moodAsset (Higgsfield-Stills)
bekommt den vorhandenen Ken-Burns-Drift der CinematicBackdrop (16 s) —
Empty-States fühlen sich lebendig statt tot an.

---

## Reihenfolge-Empfehlung
| # | Paket | Aufwand | OTA? | Wirkung |
|---|-------|---------|------|---------|
| 1 | B1+B2+B4 (Mikro-Physik-Sweep) | klein | ✅ | hoch, überall spürbar |
| 2 | C2+E2+E3 (Adoption vorhandener Widgets) | klein | ✅ | mittel-hoch |
| 3 | E1 (Mensa-Pulse, offener TODO-Punkt) | klein | ✅ | mittel |
| 4 | D1–D3 (Stolz-Momente) | mittel | ✅ | hoch (Retention) |
| 5 | A2+A3 (Hero + SharedAxis-Näherung) | mittel | ✅ | hoch |
| 6 | A1 (`animations`-Paket, reveal) | mittel | ❌ Bump | sehr hoch |
| 7 | C4+C5 (Shader 2/3, OrbitViewer-Assets) | mittel | teils | Premium-Feeling |

## Leitplanken (nicht verhandelbar)
- Jeder Effekt: `effectsProfileProvider` prüfen; `none` → statisch/instant.
- Nur Transform+Opacity in Transitions (Impeller-freundlich, kein Blur mid-flight).
- Keine neuen ungezügelten AnimationControllers in Listen (V23-Crash-Historie);
  TweenAnimationBuilder/ImplicitlyAnimated bevorzugen.
- Streams-Regeln (`.limit()`, `.autoDispose`) gelten unverändert.
- Krisen-Bereich bleibt `calm` — dort keine neuen Effekte.
