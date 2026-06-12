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
BASELINE: dict[str, int] = {
    "lib/screens/dashboard/admin/admin_chat_moderation_screen.dart": 1,
    "lib/screens/dashboard/admin/admin_crash_logs_screen.dart": 2,
    "lib/screens/dashboard/admin/admin_users_screen.dart": 1,
    "lib/screens/dashboard/call/call_history_screen.dart": 2,
    "lib/screens/dashboard/call/scheduled_calls_screen.dart": 3,
    "lib/screens/dashboard/call/voicemail_screen.dart": 2,
    "lib/screens/dashboard/chat/chat_media_sheet.dart": 1,
    "lib/screens/dashboard/chat/chat_message_bubble.dart": 2,
    "lib/screens/dashboard/chat/chat_screen.dart": 2,
    "lib/screens/dashboard/create/module_create_post_screen.dart": 1,
    "lib/screens/dashboard/crisis/crisis_dashboard_screen.dart": 1,
    "lib/screens/dashboard/crisis/crisis_detail_screen.dart": 1,
    "lib/screens/dashboard/drafts_screen.dart": 2,
    "lib/screens/dashboard/followed_tags_screen.dart": 1,
    "lib/screens/dashboard/interactions_screen.dart": 1,
    "lib/screens/dashboard/knowledge/knowledge_create_screen.dart": 1,
    "lib/screens/dashboard/knowledge/knowledge_screen.dart": 2,
    "lib/screens/dashboard/live/live_room_screen.dart": 2,
    "lib/screens/dashboard/marketplace/marketplace_create_screen.dart": 1,
    "lib/screens/dashboard/marketplace/marketplace_detail_screen.dart": 1,
    "lib/screens/dashboard/mentorship_match_screen.dart": 2,
    "lib/screens/dashboard/mentorship_screen.dart": 1,
    "lib/screens/dashboard/messages_screen.dart": 1,
    "lib/screens/dashboard/module/module_posts_screen.dart": 1,
    "lib/screens/dashboard/skills/skills_screen.dart": 1,
    "lib/widgets/crisis/safe_checkin_button.dart": 3,
    "lib/widgets/dashboard/location_onboarding_modal.dart": 1,
    "lib/widgets/events/event_photos_gallery.dart": 2,
    "lib/widgets/livestream/livestream_chat_resolver.dart": 1,
    "lib/widgets/profile/send_voicemail_sheet.dart": 1,
    "lib/widgets/profile/status_editor_sheet.dart": 3,
}


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
