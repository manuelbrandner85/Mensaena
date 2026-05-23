#!/usr/bin/env bash
# ════════════════════════════════════════════════════════════════════════
# Patch flutter_webrtc fuer Flutter 3.27+ Kompatibilitaet
#
# flutter_webrtc 0.13.1+hotfix.1 / 0.14.x verwenden den FALSCHEN Methoden-
# namen `onSurfaceCleanup()` in der TextureRegistry.SurfaceProducer.Callback
# anonymous class. Die Flutter-SDK-Methode heisst aber `onSurfaceDestroyed()`.
#
# Fix: rename `onSurfaceCleanup` → `onSurfaceDestroyed` damit die abstrakte
# Methode korrekt implementiert wird. Die Logik bleibt identisch (beide
# rufen surfaceDestroyed() auf).
#
# Idempotent: Patch wird nur einmal angewandt.
# ════════════════════════════════════════════════════════════════════════
set -euo pipefail

PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"

apply_patch() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "  skip: $file (nicht vorhanden)"
    return
  fi
  if grep -q "onSurfaceDestroyed" "$file"; then
    echo "  ✓ patched bereits: $file"
    return
  fi
  python3 - "$file" <<'PY'
import re
import sys
path = sys.argv[1]
with open(path, 'r') as f:
    src = f.read()
# Rename onSurfaceCleanup → onSurfaceDestroyed (1x in anonymous class)
new = re.sub(
    r'\bonSurfaceCleanup\b',
    'onSurfaceDestroyed',
    src,
)
if new != src:
    with open(path, 'w') as f:
        f.write(new)
    print("  ✓ renamed onSurfaceCleanup → onSurfaceDestroyed in", path)
else:
    print("  skip: no occurrence in", path)
PY
}

echo "═══════════════════════════════════════════════════════"
echo " flutter_webrtc Flutter-3.27-Patch"
echo "═══════════════════════════════════════════════════════"
for v in 0.13.1+hotfix.1 0.14.0 0.14.1 0.14.2 0.14.3; do
  apply_patch "$PUB_CACHE/hosted/pub.dev/flutter_webrtc-$v/android/src/main/java/com/cloudwebrtc/webrtc/SurfaceTextureRenderer.java"
done
echo "═══════════════════════════════════════════════════════"
echo " ✓ Fertig. Build erneut: flutter build apk --release"
echo "═══════════════════════════════════════════════════════"
