#!/usr/bin/env python3
"""Guard gegen doppelte Migrations-Timestamps (CI).

Supabase nutzt den numerischen Versions-Prefix einer Migrationsdatei
(`<version>_name.sql`) als Primary Key in `supabase_migrations.schema_migrations`.
Teilen sich ZWEI Dateien denselben Prefix, schlägt `supabase db push` mit
`SQLSTATE 23505 duplicate key` rot fehl — der Deploy bricht.

Genau das ist am 2026-06-24 passiert (zwei Dateien auf `20260624120000`).
Dieser Guard fängt die Kollision früh im PR, BEVOR sie gemergt wird und den
Main-Deploy rot macht.

Exit 0 = alle Versions-Prefixe eindeutig. Exit 1 = Kollision gefunden.
"""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path

MIGRATIONS_DIR = Path(__file__).resolve().parent.parent / "supabase" / "migrations"
# Führender numerischer Prefix vor dem ersten Unterstrich (14-stellige
# Timestamps wie 20260624120000, aber auch Legacy-Versionen wie 001).
VERSION_RE = re.compile(r"^(\d+)_")


def main() -> int:
    if not MIGRATIONS_DIR.is_dir():
        print(f"::warning::Migrations-Ordner nicht gefunden: {MIGRATIONS_DIR}")
        return 0

    by_version: dict[str, list[str]] = defaultdict(list)
    skipped: list[str] = []
    for path in sorted(MIGRATIONS_DIR.glob("*.sql")):
        m = VERSION_RE.match(path.name)
        if not m:
            skipped.append(path.name)
            continue
        by_version[m.group(1)].append(path.name)

    duplicates = {v: files for v, files in by_version.items() if len(files) > 1}

    if skipped:
        print(
            "::warning title=Migration ohne Versions-Prefix::"
            + ", ".join(skipped)
        )

    if duplicates:
        for version, files in sorted(duplicates.items()):
            joined = ", ".join(sorted(files))
            print(
                f"::error title=Doppelter Migrations-Timestamp::"
                f"Version {version} wird von mehreren Dateien benutzt: {joined}. "
                f"`supabase db push` schlaegt sonst mit SQLSTATE 23505 fehl. "
                f"Eine der Dateien auf einen eindeutigen, spaeteren Timestamp "
                f"umbenennen."
            )
        print(
            f"\n{len(duplicates)} doppelte Versions-Prefix(e) gefunden. "
            f"Bitte umbenennen, damit der Supabase-Deploy gruen bleibt."
        )
        return 1

    print(
        f"OK - {sum(len(f) for f in by_version.values())} Migrationen, "
        f"alle Versions-Prefixe eindeutig."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
