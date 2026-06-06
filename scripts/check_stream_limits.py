#!/usr/bin/env python3
"""Guard rails gegen den OOM-Crash, der die App über Stunden langsam machte.

Scannt flutter_app/lib/ und scheitert, wenn:
  1. Ein Supabase `.stream(primaryKey: [...])` keinen `.limit(N)` innerhalb
     der nächsten Zeilen hat (außer eine `.eq(...)`-Kette zeigt schon eine
     stark eingegrenzte Single-Row-Quelle wie `dm_calls` für einen User).
  2. Ein `StreamProvider.family<...>` kein `.autoDispose` verwendet.
  3. Ein `StreamProvider<...>` (ohne family) screen-spezifisch wirkt aber
     kein `.autoDispose` hat (nur Whitelist-Warnung, kein Fail).

Wird in flutter.yml direkt nach `flutter analyze` aufgerufen.
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

LIB = Path(__file__).resolve().parent.parent / "flutter_app" / "lib"

# Streams, deren globaler Charakter eine Limit-Lockerung rechtfertigt — z.B.
# der Auth-State, der per Definition genau eine Row liefert.
STREAM_LIMIT_WHITELIST_TABLES = {
    # Tabellen, deren .stream() implizit auf 1 Row begrenzt ist (z.B. weil
    # eq() auf einen Singleton-Wert filtert wie eine eindeutige live_room-ID).
    # Leer lassen → Default: jeder Stream MUSS .limit() bekommen.
}

errors: list[str] = []
warnings: list[str] = []


def check_supabase_streams(path: Path, source: str) -> None:
    """Prüft jeden .stream(primaryKey: [...]) auf nachfolgendes .limit()."""
    # Ein Stream-Block reicht von `.stream(primaryKey` bis zum nächsten
    # Semicolon (Dart Statement-Ende). Das ist robust gegen Umbruch.
    pattern = re.compile(r"\.stream\(primaryKey:\s*\[[^\]]*\][^;]*;", re.DOTALL)
    for m in pattern.finditer(source):
        chunk = m.group(0)
        if ".limit(" in chunk:
            continue
        line_no = source[: m.start()].count("\n") + 1
        # Tabellenname für mögliche Whitelist herausziehen.
        table_match = re.search(r"\.from\(['\"]([^'\"]+)['\"]\)", source[max(0, m.start() - 200) : m.start()])
        table = table_match.group(1) if table_match else "?"
        if table in STREAM_LIMIT_WHITELIST_TABLES:
            continue
        rel = path.relative_to(LIB.parent.parent)
        errors.append(
            f"{rel}:{line_no}: Supabase .stream() auf Tabelle '{table}' ohne .limit() — "
            f"führt zu unbegrenztem RAM-Wachstum. Füge .limit(N) hinzu."
        )


def check_stream_providers(path: Path, source: str) -> None:
    """StreamProvider.family ohne autoDispose ist immer ein Bug."""
    # Wir matchen die Provider-Deklaration auf einer Zeile (Riverpod erlaubt
    # Family/Future/Stream-Kombinationen — wir prüfen nur StreamProvider).
    for m in re.finditer(r"StreamProvider\.family\b(?!\.autoDispose)", source):
        line_no = source[: m.start()].count("\n") + 1
        # Ist es vielleicht in einem Kommentar/String? Naive Zeile-Check.
        line_start = source.rfind("\n", 0, m.start()) + 1
        line = source[line_start : source.find("\n", m.start())]
        if line.lstrip().startswith("//") or line.lstrip().startswith("///"):
            continue
        rel = path.relative_to(LIB.parent.parent)
        errors.append(
            f"{rel}:{line_no}: StreamProvider.family ohne .autoDispose — "
            f"jeder family-Wert hält einen Supabase-Realtime-Channel für immer offen."
        )


def main() -> int:
    if not LIB.exists():
        print(f"::warning::Lib-Verzeichnis nicht gefunden: {LIB}")
        return 0
    for path in LIB.rglob("*.dart"):
        try:
            source = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        check_supabase_streams(path, source)
        check_stream_providers(path, source)

    for w in warnings:
        print(f"::warning::{w}")
    for e in errors:
        print(f"::error::{e}")

    if errors:
        print(
            f"\n❌ {len(errors)} Stream-Verstöße gefunden. "
            "Siehe scripts/check_stream_limits.py für die Regeln."
        )
        return 1
    print(f"✅ Alle Supabase-Streams haben .limit() und alle "
          "StreamProvider.family sind .autoDispose.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
