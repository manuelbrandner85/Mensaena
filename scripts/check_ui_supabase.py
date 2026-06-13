#!/usr/bin/env python3
"""UI-Schicht-Guard: verbietet NEUE direkte Supabase-Zugriffe (`sb.from(...)`
oder `Supabase.instance`) in flutter_app/lib/screens und lib/widgets.

Datenzugriff gehört in lib/repositories (bzw. lib/services für Call/Realtime-
Logik) — nur dort werden Stream-Limits, Fehlerbehandlung und Schema-Wissen
zentral erzwungen (siehe CLAUDE.md / check_stream_limits.py).

Ratchet-Prinzip: Die BASELINE unten ist der eingefrorene Altbestand
(2026-06-11, 113 Zugriffe in 61 Dateien). Jede Datei darf nur WENIGER
Zugriffe bekommen, nie mehr; neue Dateien dürfen gar keine haben.
Wenn du eine Datei aufräumst: Zahl hier senken oder Eintrag löschen.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent / "flutter_app"
SCAN_DIRS = ["lib/screens", "lib/widgets"]
PATTERN = re.compile(r"\bsb\s*\.\s*from\s*\(|Supabase\.instance")

# Eingefrorener Altbestand — NICHT erhöhen. Abbau erwünscht.
# 2026-06-13: Altbestand vollständig abgebaut (Start 113/61 → 0/0). Die
# BASELINE ist jetzt LEER = harte Null-Toleranz: JEDER neue direkte
# sb.from()-Zugriff in screens/ oder widgets/ lässt den CI scheitern.
# Datenzugriffe gehören in lib/repositories/ (oder lib/services/).
# Ausnahme bleibt sb.storage (Datei-Upload) — vom PATTERN nicht erfasst.
BASELINE: dict[str, int] = {}


def main() -> int:
    errors: list[str] = []
    improved: list[str] = []
    for scan in SCAN_DIRS:
        for f in sorted((ROOT / scan).rglob("*.dart")):
            rel = f.relative_to(ROOT).as_posix()
            count = len(PATTERN.findall(f.read_text(encoding="utf-8")))
            allowed = BASELINE.get(rel, 0)
            if count > allowed:
                errors.append(
                    f"  {rel}: {count} direkte Supabase-Zugriffe "
                    f"(Baseline erlaubt {allowed})"
                )
            elif count < allowed:
                improved.append(f"  {rel}: {allowed} -> {count}")
    if improved:
        print("ℹ️  Abgebaute Altlasten — bitte BASELINE in "
              "scripts/check_ui_supabase.py entsprechend senken:")
        print("\n".join(improved))
    if errors:
        print("❌ Neue direkte Supabase-Zugriffe in der UI-Schicht "
              "(screens/widgets):")
        print("\n".join(errors))
        print("\nFix: Query in ein Repository (lib/repositories) oder einen "
              "Service (lib/services) verschieben und von dort aufrufen.")
        return 1
    print("✅ Keine neuen direkten Supabase-Zugriffe in der UI-Schicht.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
