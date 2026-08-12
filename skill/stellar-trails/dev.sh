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
#   4. PID file (.zscripts/st-devsh.pid, moved from /tmp/ in v9.11.4) — prevent duplicate instances
#   5. Stale PID detection — clean up if process already dead (v9.11.6: verify /proc/cmdline)
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
# PID file moved from /tmp/ to .zscripts/ (v9.11.4) — /tmp/ is shared across shells
# and race-prone if multiple dev.sh start simultaneously. .zscripts/ is in repo.tar
# so survives session reset, and is owned by the same user.
PID_FILE="$ZSCRIPTS_DIR/st-devsh.pid"
LOG_FILE="/tmp/st-devsh.log"

mkdir -p "$ZSCRIPTS_DIR"
cd "$ZSCRIPTS_DIR"

# --- Logging (improvement over v7.2.2 silent 2>/dev/null) ---
log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [dev.sh] $*" >> "$LOG_FILE" 2>/dev/null
  echo "[dev.sh] $*"
}

# --- PID file management (v9.11.6: verify process identity, not just PID alive) ---
# Bug 1 fix: kill -0 only checks if PID is alive, not whether it's dev.sh.
# After container reboot, PID file persists (in .zscripts/ which survives reset),
# but the PID number may be reused by a different process (boot service, etc).
# dev.sh would false-positive "Already running" and exit without serving → 9-min outage.
# Fix: verify /proc/$PID/cmdline contains 'dev.sh' before trusting it.
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
  if [ -n "$OLD_PID" ] && [ -d "/proc/$OLD_PID" ]; then
    OLD_CMDLINE=$(tr '\0' ' ' < "/proc/$OLD_PID/cmdline" 2>/dev/null)
    if echo "$OLD_CMDLINE" | grep -q 'dev\.sh'; then
      log "Already running (PID $OLD_PID, cmdline: $OLD_CMDLINE) — not starting"
      exit 0
    fi
    log "PID $OLD_PID is not dev.sh (cmdline: $OLD_CMDLINE) — stale PID file, cleaning up"
    rm -f "$PID_FILE"
  else
    log "Stale PID file (PID $OLD_PID not running) — cleaning up"
    rm -f "$PID_FILE"
  fi
fi
echo $$ > "$PID_FILE"

# Bug 2 fix: EXIT trap must only delete PID file if it contains our own PID ($$).
# Original trap 'rm -f "$PID_FILE"' would delete the PID file on ANY exit,
# including the "Already running" exit path above — a second dev.sh invocation
# would delete the first one's PID file, breaking duplicate-detection.
trap 'if [ -f "$PID_FILE" ] && [ "$(cat "$PID_FILE" 2>/dev/null)" = "$$" ]; then rm -f "$PID_FILE"; fi' EXIT

# SIGHUP: terminal closed — DON'T exit, keep serving (improvement over v7.2.2)
trap '' SIGHUP

# --- Port guard (same as v7.2.2, but v9.11.6: respect PID ownership) ---
if command -v ss >/dev/null 2>&1 && ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
  log "Port :$PORT already in use — not starting"
  # Only delete PID file if it's ours (Bug 2 fix — same as EXIT trap)
  if [ "$(cat "$PID_FILE" 2>/dev/null)" = "$$" ]; then rm -f "$PID_FILE"; fi
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
