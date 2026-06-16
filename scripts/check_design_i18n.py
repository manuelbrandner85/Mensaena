#!/usr/bin/env python3
"""Design-/i18n-Guard für Mensaena (vom CI in flutter.yml erzwungen).

Drei Prüfungen — alle so gebaut, dass der aktuelle Stand GRÜN ist und nur
NEUE Verstöße rot werden (Ratchet), bzw. ein hartes Verbot mit 0 Treffern:

1. emerald-Verbot: KEINE emerald-Farben (CLAUDE.md). Hartes 0-Limit in lib/.
2. Hardcoded-Color-Ratchet: Anzahl `Color(0x…)` in screens/ + widgets/ darf
   die Baseline nicht ÜBERSTEIGEN (neue Farben gehören in AppColors).
3. i18n-Key-Parität: jeder Key aus de.json MUSS in allen 6 anderen
   Übersetzungs-Dateien existieren (häufigster i18n-Bug: Key nur in de.json).

Exit 1 bei Verstoß, sonst 0.
"""
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "flutter_app", "lib")
TRANS = os.path.join(ROOT, "flutter_app", "assets", "translations")

# Baseline = aktueller Ist-Stand (darf nur sinken, nie steigen).
COLOR_LITERAL_BASELINE = 177

LANGS = ["en", "it", "es", "fr", "tr", "ru"]  # gegen de.json (Quelle)

errors = []


def walk_dart(base):
    for dirpath, _, files in os.walk(base):
        for f in files:
            if f.endswith(".dart"):
                yield os.path.join(dirpath, f)


# ── 1) emerald-Verbot ───────────────────────────────────────────────────────
emerald_hits = []
for path in walk_dart(LIB):
    with open(path, encoding="utf-8") as fh:
        for i, line in enumerate(fh, 1):
            if re.search(r"emerald", line, re.IGNORECASE):
                emerald_hits.append(f"{os.path.relpath(path, ROOT)}:{i}")
if emerald_hits:
    errors.append(
        "emerald-Farben sind verboten (CLAUDE.md → primary/teal verwenden):\n  "
        + "\n  ".join(emerald_hits)
    )

# ── 2) Hardcoded-Color-Ratchet (screens + widgets) ──────────────────────────
color_count = 0
for sub in ("screens", "widgets"):
    for path in walk_dart(os.path.join(LIB, sub)):
        with open(path, encoding="utf-8") as fh:
            color_count += len(re.findall(r"Color\(0x", fh.read()))
if color_count > COLOR_LITERAL_BASELINE:
    errors.append(
        f"Zu viele hartcodierte Color(0x…) in screens/+widgets/: {color_count} "
        f"(Baseline {COLOR_LITERAL_BASELINE}). Neue Farben gehören in AppColors. "
        f"Wenn du bewusst reduziert hast, senke COLOR_LITERAL_BASELINE in "
        f"scripts/check_design_i18n.py."
    )

# ── 3) i18n-Key-Parität ─────────────────────────────────────────────────────
def flatten(d, prefix=""):
    keys = set()
    for k, v in d.items():
        key = f"{prefix}.{k}" if prefix else k
        if isinstance(v, dict):
            keys |= flatten(v, key)
        else:
            keys.add(key)
    return keys


de_path = os.path.join(TRANS, "de.json")
try:
    with open(de_path, encoding="utf-8") as fh:
        de_keys = flatten(json.load(fh))
    for lang in LANGS:
        p = os.path.join(TRANS, f"{lang}.json")
        with open(p, encoding="utf-8") as fh:
            missing = de_keys - flatten(json.load(fh))
        if missing:
            sample = ", ".join(sorted(missing)[:10])
            errors.append(
                f"{lang}.json fehlen {len(missing)} Keys aus de.json: {sample}"
            )
except Exception as e:  # noqa: BLE001
    errors.append(f"i18n-Parität konnte nicht geprüft werden: {e}")


if errors:
    print("❌ Design-/i18n-Guard: Verstöße gefunden:\n")
    for e in errors:
        print("• " + e + "\n")
    sys.exit(1)

print(
    "✅ Design-/i18n-Guard: kein emerald, Color-Literale ≤ Baseline, "
    "i18n-Keys in allen 7 Sprachen vollständig."
)
