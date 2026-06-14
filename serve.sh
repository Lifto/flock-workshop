#!/usr/bin/env bash
# Workshop file server — run this at the venue
# Serves models/ directory on port 8080

set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
PORT=8080

# Get local IP
IP=$(ipconfig getifaddr en0 2>/dev/null || hostname -I 2>/dev/null | awk '{print $1}')

echo "============================================"
echo "  Workshop File Server"
echo "============================================"
echo ""
echo "  URL:  http://${IP}:${PORT}"
echo ""
echo "  Files available:"
for f in "$DIR/models"/*; do
  SIZE=$(du -h "$f" | cut -f1)
  echo "    $(basename "$f")  ($SIZE)"
done
echo ""
echo "  Tell attendees to open:"
echo "    http://${IP}:${PORT}"
echo "============================================"
echo ""

cd "$DIR/models"
python3 -m http.server "$PORT"
