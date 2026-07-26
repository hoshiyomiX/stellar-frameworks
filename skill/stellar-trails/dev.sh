#!/bin/bash
# stellar-trails dev server v9.0.0 — improved from v7.2.2 base
#
# Serves /home/z/my-project/.zscripts/ on port :3000 with Cache-Control: no-store
# headers (bypass browser heuristic caching).
#
# v9.0.0 architecture (improved from v7.2.2, NOT hybrid with v8.0.0):
#   - python3 runs in FOREGROUND (no & background, no wait race condition)
#   - while true infinite loop (no MAX_RETRIES permanent exit)
#   - No exit 0 on clean signal (always restart — proven v7.2.2 behavior)
#   - set -e for setup phase (fail-fast on config errors)
#
# Improvements over v7.2.2 (safe additions only):
#   1. SIGHUP trap in python3 (signal.SIG_IGN) — survive terminal close
#   2. SIGHUP trap in bash (trap '' SIGHUP) — wrapper survives too
#   3. Log to /tmp/st-devsh.log — post-mortem debugging
#   4. PID file (/tmp/st-devsh.pid) — prevent duplicate instances
#   5. Stale PID detection — clean up if process already dead
#   6. Rapid-crash backoff — if python3 exits within 2s, increase sleep
#      (prevents spin loop on persistent failure, but NEVER gives up)
#
# Explicitly REJECTED from v8.0.0 (caused degraded behavior):
#   ❌ Background python3 + wait (race condition on SIGHUP)
#   ❌ exit 0 on clean signal (kills supervisor, no restart)
#   ❌ MAX_RETRIES permanent exit (gives up after 10 failures)
#
# Usage:
#   bash /home/z/my-project/.zscripts/dev.sh
#
# On ZAI platform, /start.sh auto-launches this at session start.

set -e

ZSCRIPTS_DIR="${ZSCRIPTS_DIR:-/home/z/my-project/.zscripts}"
PORT="${PORT:-3000}"
PID_FILE="/tmp/st-devsh.pid"
LOG_FILE="/tmp/st-devsh.log"

mkdir -p "$ZSCRIPTS_DIR"
cd "$ZSCRIPTS_DIR"

# --- Logging (improvement over v7.2.2 silent 2>/dev/null) ---
log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [dev.sh] $*" >> "$LOG_FILE" 2>/dev/null
  echo "[dev.sh] $*"
}

# --- PID file management (improvement: prevent duplicates) ---
# If PID file exists and process alive → exit (already running)
# If PID file exists but process dead → stale, clean up + continue
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
  if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    log "Already running (PID $OLD_PID) — not starting"
    exit 0
  fi
  log "Stale PID file (PID $OLD_PID not running) — cleaning up"
  rm -f "$PID_FILE"
fi
echo $$ > "$PID_FILE"

# Clean PID on exit (any exit path)
trap 'rm -f "$PID_FILE" 2>/dev/null' EXIT

# SIGHUP: terminal closed — DON'T exit, keep serving (improvement over v7.2.2)
trap '' SIGHUP

# --- Port guard (same as v7.2.2) ---
if command -v ss >/dev/null 2>&1 && ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
  log "Port :$PORT already in use — not starting"
  rm -f "$PID_FILE"
  exit 0
fi

log "Serving $ZSCRIPTS_DIR on :$PORT with Cache-Control: no-store (v9.0.0 — improved v7.2.2)"
log "PID: $$ | Log: $LOG_FILE | Mode: foreground + infinite loop + rapid-crash backoff"

# --- Crash recovery loop (v7.2.2 architecture + rapid-crash backoff) ---
# Key difference from v8.0.0:
#   - python3 runs in FOREGROUND (no &, no wait, no race condition)
#   - NO exit 0 on clean signal (always restart — proven v7.2.2 behavior)
#   - NO MAX_RETRIES (infinite loop — never gives up)
#   - Rapid-crash backoff: if python3 exits within 2s, sleep longer
#     (prevents spin loop, but NEVER exits permanently)

BACKOFF=1

while true; do
  START_TIME=$(date +%s)
  log "Starting python3 server (foreground, backoff=${BACKOFF}s)"

  # python3 runs in FOREGROUND — dev.sh blocks here until python3 exits
  # This is the KEY difference from v8.0.0 (which used & + wait)
  python3 -c "
import http.server, socketserver, signal, sys

class ReuseTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

class NoCacheHandler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header('Cache-Control', 'no-store, no-cache, must-revalidate, max-age=0')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')
        super().end_headers()
    def log_message(self, format, *args):
        pass  # suppress access logs

def shutdown(sig, frame):
    sys.exit(0)

signal.signal(signal.SIGTERM, shutdown)
signal.signal(signal.SIGINT, shutdown)
# SIGHUP: keep serving even if terminal closes (improvement over v7.2.2)
signal.signal(signal.SIGHUP, signal.SIG_IGN)

with ReuseTCPServer(('0.0.0.0', $PORT), NoCacheHandler) as httpd:
    httpd.serve_forever()
" 2>>"$LOG_FILE" || true

  # python3 exited — calculate uptime
  END_TIME=$(date +%s)
  UPTIME=$((END_TIME - START_TIME))
  log "python3 exited (uptime: ${UPTIME}s)"

  # Rapid-crash backoff: if python3 ran for <2s, it's a crash (not a signal)
  # Increase sleep to prevent spin loop, but NEVER exit (unlike v8.0.0 MAX_RETRIES)
  if [ "$UPTIME" -lt 2 ]; then
    log "Rapid crash detected (uptime ${UPTIME}s < 2s) — backing off ${BACKOFF}s"
    sleep "$BACKOFF"
    # Exponential backoff: 1→2→4→8→16→30 (capped, but NEVER exits)
    BACKOFF=$((BACKOFF * 2))
    [ "$BACKOFF" -gt 30 ] && BACKOFF=30
  else
    # Normal exit (signal, OOM, etc) — restart immediately with backoff reset
    log "Normal exit — restarting immediately (backoff reset to 1s)"
    BACKOFF=1
    sleep 1
  fi
  # Loop continues — infinite, never gives up (v7.2.2 proven behavior)
done
