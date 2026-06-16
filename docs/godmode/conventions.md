# Godmode Codebase-Konventionen & Stolperfallen

**Diese Datei ist die Referenz für den Admin-Dev-Agent.** Sie listet die ECHTEN
Symbole/APIs des Projekts und die wiederkehrenden Fehler, an denen Aufträge rot
geworden sind. **Vor dem Schreiben von Flutter-Code hier nachschlagen, statt
Symbolnamen zu raten.** Im Zweifel mit `grep -rn "SymbolName" flutter_app/lib`
verifizieren.

> Engine ist **Flutter 3.27.4** (gepinnt). APIs aus neueren Flutter-Versionen
> existieren NICHT. Das CI läuft mit `flutter analyze --no-fatal-infos` →
> **error UND warning sind fatal**, nur `info` ist erlaubt.

## ⚠️ Bekannte Stolperfallen (real passiert → rotes CI)

| Falsch (existiert nicht / bricht 3.27) | Richtig |
|---|---|
| `Color.toARGB32()` | `.value` (deprecated→info, ok) oder zwei `Color` direkt vergleichen |
| `ShimmerSkeleton(...)` | `ShimmerBox(...)` aus `widgets/effects/shimmer_skeleton.dart` |
| `AppColors.primary` | `AppColors.primary500` (Teal-Primary) oder `AppColors.teal` |
| `LucideIcons.euroSign` | `LucideIcons.euro` |
| `LucideIcons.triangleAlert` | `LucideIcons.alertTriangle` |
| `const X(... DateTime.utc(...) ...)` | `DateTime.utc()` ist NICHT const → `final` statt `const`, kein `const` am Aufrufer |
| `DashboardScaffold(actions: ...)` | `DashboardScaffold(appBarActions: ...)` |
| rohe `Map`/`List` ohne Typargumente | `Map<String, dynamic>` / `List<Widget>` (strict_raw_type ist warning = fatal) |
| `import 'package:intl/intl.dart'` zusätzlich zu easy_localization | weglassen (unnecessary_import = warning) |

## AppColors (echte Tokens — `config/theme/app_colors.dart`)

Primär/Teal: `primary500` (#1EAAA6), `teal`, `tealSoft`, `tealDeep`, `tealGlow`
Akzent: `amber`, `amberWarm`, `amberSoft`, `amberDeep`, `amberGlow`
Status/Emotion: `herzrot` (+Warm/Deep/Glow), `leben` (+Soft), `trust` (+Soft),
`bronze` (+Soft/Deep)
Flächen (dark): `voidColor`, `deep`, `surface`, `elevated`, `raised`, `overlay`,
`sheetBackground`, `line`, `lineActive`
Text (dark): `ink`, `inkWarm`, `inkSoft`, `mute`, `ghost`
Light-Theme: `lightVoid`, `lightDeep`, `lightSurface`, `lightElevated`,
`lightRaised`, `lightOverlay`, `lightInk`, `lightInkSoft`, `lightMute`,
`lightGhost`, `lightLine`, `lightLineActive`

**KEINE** emerald-Farben verwenden. Es gibt KEIN `AppColors.primary` (nur
`primary500`).

## Häufige gemeinsame Widgets (echte APIs)

- `DashboardScaffold({title, currentRoute, body, fab, onRefresh, appBarActions})`
- `EmptyStateWidget({required icon, required title, subtitle})`
- `ErrorStateWidget({title, onRetry, icon = LucideIcons.wifiOff})`
- `ShimmerBox({height, width, borderRadius})` — Skeleton-Platzhalter
- `Haptics.tap()`, `Haptics.select()` (aus `services/haptics.dart`)
- Typo: `AppTypography.body({size, color, weight})`, `.label({size, color})`,
  `.caption({color})`
- Icons: `lucide_icons` (Paket `^0.257.0`) — Namen per Code-Grep verifizieren.

## Datenzugriff & Regeln

- Datenzugriff NUR über `lib/repositories/*` bzw. `lib/services/*` — KEIN
  direktes `sb.from(...)` in screens/widgets (Guard `check_ui_supabase.py`).
- Supabase-`.stream()` IMMER mit `.limit(N)`; `StreamProvider.family` IMMER
  `.autoDispose` (Guard `check_stream_limits.py`).
- i18n: jeder neue UI-String via `.tr()` in ALLEN 7 Dateien
  `assets/translations/{de,en,it,es,fr,tr,ru}.json`.
- Secrets/Keys NIE in den Code (nur Supabase/GitHub Secrets).
- `pubspec.yaml`-Version NICHT ohne Auftrag ändern. Neue NATIVE Dependency →
  Versions-Bump (kein OTA); reine Dart-Pakete unkritisch.

## Pflege

Der Selbstheilungs-Agent ergänzt hier eine knappe Zeile, wenn er einen NEUEN,
wiederkehrenden Fehlertyp behebt — so wird diese Liste mit der Zeit klüger.
