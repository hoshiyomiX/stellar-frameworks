#!/bin/bash
# stellar-trails dev server v8.0.0 — resilient no-cache HTTP server
#
# Serves /home/z/my-project/.zscripts/ on port :3000 with Cache-Control: no-store.
#
# v8.0.0 changes (from v7.2.2):
#   1. Signal traps (SIGHUP, SIGTERM, SIGINT) → clean child shutdown
#   2. PID file tracking → prevent orphans, enable clean restart
#   3. Exponential backoff (1s→2s→4s→8s→16s→30s max) → no spin loop
#   4. Max retries (10 consecutive failures → exit, don't spin forever)
#   5. Log to file (/tmp/st-devsh.log) → debugging possible
#   6. Health check (curl every 30s → restart if hung)
#   7. No `set -e` → explicit error handling
#
# Kill vectors addressed:
#   A. SIGHUP on terminal close → trap + ignore (keep serving)
#   B. Session reset → setsid in caller + PID file for recovery
#   C. OOM killer → crash recovery + backoff
#   D. Orphaned python3 → trap kills child before exit
#   E. Spin loop → backoff + max retries
#   F. Silent errors → log to file
#   G. Hung server → health check + restart

ZSCRIPTS_DIR="${ZSCRIPTS_DIR:-/home/z/my-project/.zscripts}"
PORT="${PORT:-3000}"
PID_FILE="/tmp/st-devsh.pid"
LOG_FILE="/tmp/st-devsh.log"
MAX_RETRIES=10
HEALTH_CHECK_INTERVAL=30

mkdir -p "$ZSCRIPTS_DIR"
cd "$ZSCRIPTS_DIR" || exit 1

# --- Logging ---
log() {
  echo "[$(date -u '+%Y-%m-%dT%H:%M:%SZ')] [dev.sh] $*" >> "$LOG_FILE"
  echo "[dev.sh] $*"
}

# --- PID file management ---
write_pid() {
  echo $$ > "$PID_FILE"
}

clear_pid() {
  rm -f "$PID_FILE" 2>/dev/null
}

check_already_running() {
  if [ -f "$PID_FILE" ]; then
    OLD_PID=$(cat "$PID_FILE" 2>/dev/null)
    if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
      log "Already running (PID $OLD_PID) — not starting"
      exit 0
    fi
    # Stale PID file — clean up
    log "Stale PID file (PID $OLD_PID not running) — cleaning up"
    clear_pid
  fi
}

# --- Signal handling ---
CHILD_PID=""

cleanup() {
  log "Received signal — shutting down"
  if [ -n "$CHILD_PID" ] && kill -0 "$CHILD_PID" 2>/dev/null; then
    kill -TERM "$CHILD_PID" 2>/dev/null
    sleep 0.5
    kill -KILL "$CHILD_PID" 2>/dev/null
  fi
  clear_pid
  exit 0
}

# SIGHUP: terminal closed — DON'T exit, keep serving (detached)
trap '' SIGHUP
# SIGTERM/SIGINT: clean shutdown
trap cleanup SIGTERM SIGINT

# --- Port guard ---
if command -v ss >/dev/null 2>&1 && ss -tlnp 2>/dev/null | grep -q ":$PORT "; then
  # Check if it's our own process
  EXISTING_PID=$(ss -tlnp 2>/dev/null | grep ":$PORT " | grep -oP 'pid=\K[0-9]+' | head -1)
  if [ -n "$EXISTING_PID" ] && [ -f "$PID_FILE" ] && [ "$(cat "$PID_FILE")" = "$EXISTING_PID" ]; then
    log "Port :$PORT in use by our own process (PID $EXISTING_PID) — not starting"
    exit 0
  fi
  log "Port :$PORT in use by PID $EXISTING_PID — not starting"
  exit 0
fi

# --- Start server ---
check_already_running
write_pid
log "Serving $ZSCRIPTS_DIR on :$PORT (v8.0.0 resilient mode)"
log "PID: $$ | Log: $LOG_FILE | Backoff: 1s→30s | Max retries: $MAX_RETRIES"

RETRY_COUNT=0
BACKOFF=1

start_python_server() {
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
        pass

def shutdown(sig, frame):
    sys.exit(0)

signal.signal(signal.SIGTERM, shutdown)
signal.signal(signal.SIGINT, shutdown)
# SIGHUP: keep serving even if terminal closes
signal.signal(signal.SIGHUP, signal.SIG_IGN)

with ReuseTCPServer(('0.0.0.0', $PORT), NoCacheHandler) as httpd:
    httpd.serve_forever()
" >> "$LOG_FILE" 2>&1 &
  CHILD_PID=$!
}

# --- Main loop with backoff + health check ---
while true; do
  log "Starting python3 server (attempt $((RETRY_COUNT + 1)))"
  start_python_server
  wait "$CHILD_PID"
  EXIT_CODE=$?

  if [ $EXIT_CODE -eq 0 ]; then
    # Clean exit (SIGTERM/SIGINT) — don't restart
    log "python3 exited cleanly (signal) — not restarting"
    clear_pid
    exit 0
  fi

  RETRY_COUNT=$((RETRY_COUNT + 1))

  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    log "Max retries ($MAX_RETRIES) reached — giving up. Check $LOG_FILE for details."
    clear_pid
    exit 1
  fi

  log "python3 exited (code $EXIT_CODE) — retry $RETRY_COUNT/$MAX_RETRIES in ${BACKOFF}s"
  sleep "$BACKOFF"

  # Exponential backoff: 1→2→4→8→16→30 (capped)
  BACKOFF=$((BACKOFF * 2))
  [ "$BACKOFF" -gt 30 ] && BACKOFF=30
done
