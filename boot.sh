#!/bin/bash
# stellar-coding-agent — Install, self-heal, and bootstrap (git-tracked)
# First run: installs skill files. Subsequent runs: auto-updates + self-heals + starts dev server.
# Usage: bash stellar-coding-agent/boot.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DIR="$SCRIPT_DIR/skill/stellar-coding-agent"

# IMPL-002: Detect project root — repo may be a subdirectory of /home/z/my-project/
PROJECT_ROOT="${PROJECT_ROOT:-/home/z/my-project}"
if [ -f "$PROJECT_ROOT/package.json" ] && [ -d "$PROJECT_ROOT/src/app" ]; then
  : # PROJECT_ROOT explicitly set or detected
else
  # Fallback: assume repo is inside project root (one level up)
  PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
fi

# Install skill to the project root's skills/ directory (where Skill system loads from)
INSTALL_DIR="$PROJECT_ROOT/skills/stellar-coding-agent"

# ── 0. Auto-update: pull if remote has newer skill files ──────────
# Non-fatal: any git failure just skips the update and proceeds.
if [ -d "$SCRIPT_DIR/.git" ]; then
  BRANCH="$(git -C "$SCRIPT_DIR" branch --show-current 2>/dev/null || echo "")"
  REMOTE="$(git -C "$SCRIPT_DIR" remote get-url origin 2>/dev/null || echo "")"

  if [ -n "$BRANCH" ] && [ -n "$REMOTE" ]; then
    # Fetch remote refs (network errors are non-fatal)
    if git -C "$SCRIPT_DIR" fetch origin "$BRANCH" --quiet 2>/dev/null; then
      LOCAL="$(git -C "$SCRIPT_DIR" rev-parse HEAD 2>/dev/null)"
      REMOTE_SHA="$(git -C "$SCRIPT_DIR" rev-parse "origin/$BRANCH" 2>/dev/null)"

      if [ "$LOCAL" != "$REMOTE_SHA" ]; then
        # Check if local is behind (fast-forward possible)
        BEHIND="$(git -C "$SCRIPT_DIR" rev-list --count HEAD.."origin/$BRANCH" 2>/dev/null || echo "0")"
        AHEAD="$(git -C "$SCRIPT_DIR" rev-list --count "origin/$BRANCH"..HEAD 2>/dev/null || echo "0")"

        if [ "$AHEAD" = "0" ] && [ "$BEHIND" -gt 0 ]; then
          # We're behind, not diverged — check for dirty working tree
          if [ -z "$(git -C "$SCRIPT_DIR" status --porcelain -- skill/ setup.sh boot.sh README.md 2>/dev/null)" ]; then
            OLD_VER="$(grep -oP 'version:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "?")"
            if git -C "$SCRIPT_DIR" pull --ff-only --quiet origin "$BRANCH" 2>/dev/null; then
              NEW_VER="$(grep -oP 'version:\s*\K[0-9]+\.[0-9]+\.[0-9]+' "$SOURCE_DIR/SKILL.md" 2>/dev/null || echo "?")"
              echo "[boot] Updated ${OLD_VER} → ${NEW_VER} ($BEHIND commits)"
            else
              echo "[boot] WARNING: git pull failed — skipping update"
            fi
          else
            echo "[boot] Skipping update — local changes detected in tracked files"
          fi
        elif [ "$AHEAD" -gt 0 ]; then
          echo "[boot] Skipping update — local commits ahead of remote (diverged)"
        fi
      fi
    # fetch failed (network/offline) — silent, not an error
    fi
  fi
fi

# ── 1. Install / self-heal: copy git-tracked skill/ → platform skills/ ──
NEED_INSTALL=false
if [ ! -f "$INSTALL_DIR/SKILL.md" ] || ! grep -q "Phase State Machine" "$INSTALL_DIR/SKILL.md" 2>/dev/null; then
  NEED_INSTALL=true
fi

if $NEED_INSTALL; then
  if [ ! -d "$SOURCE_DIR" ]; then
    echo "[boot] ERROR: skill/ not found. Is this the repo root?"
    exit 1
  fi
  echo "[boot] Installing skill files → skills/"
  rm -rf "${INSTALL_DIR:?}"
  cp -R "$SOURCE_DIR" "$INSTALL_DIR"

  # Verify critical files
  ERRORS=0
  for f in \
    procedure/phases.md \
    procedure/templates/problem-spec.md \
    procedure/templates/implementation-plan.md \
    procedure/templates/verification-report.md \
    procedure/templates/incident-report.md \
    procedure/decision-trees/error-resolution.md \
    constraints/code-standards.md \
    constraints/type-safety.md \
    knowledge/architecture.md \
    knowledge/conventions.md \
    knowledge/platform-constraints.md \
    knowledge/error-patterns.md \
    memory-template.md; do
    if [ -f "$INSTALL_DIR/$f" ]; then
      : # OK
    else
      echo "[boot] WARNING: $f MISSING"
      ERRORS=$((ERRORS + 1))
    fi
  done

  if [ $ERRORS -eq 0 ]; then
    echo "[boot] Installed successfully"
  else
    echo "[boot] WARNING: installed with $ERRORS missing file(s)"
  fi
else
  echo "[boot] Skill files OK"
fi

# ── 2. Deploy custom splash ──────────────────────────────────────
# Assets are gitignored — only exist if previously bootstrapped
SPLASH="$INSTALL_DIR/assets/page.tsx"
# IMPL-002: TARGET must point to the Next.js project, not the repo dir
TARGET="$PROJECT_ROOT/src/app/page.tsx"
DEV_SCRIPT="$PROJECT_ROOT/.zscripts/dev.sh"

if [ -f "$SPLASH" ]; then
  mkdir -p "$(dirname "$TARGET")"
  cp "$SPLASH" "$TARGET"
  echo "[boot] Splash deployed → src/app/page.tsx"
fi

# ── 3. Dev server ────────────────────────────────────────────────
if curl -s --connect-timeout 2 "http://localhost:3000" >/dev/null 2>&1; then
  echo "[boot] Dev server running on :3000"
  exit 0
fi

if [ -f "$DEV_SCRIPT" ]; then
  echo "[boot] Starting dev server..."
  chmod +x "$DEV_SCRIPT"
  DATABASE_URL="${DATABASE_URL:-file:${PROJECT_ROOT}/db/custom.db}"
  (
    cd "$PROJECT_ROOT"
    nohup bash "$DEV_SCRIPT" >>"$PROJECT_ROOT/.zscripts/dev.log" 2>&1 </dev/null &
    echo "$!" >"$PROJECT_ROOT/.zscripts/dev.pid"
  )
  for i in $(seq 1 30); do
    if curl -s --connect-timeout 2 "http://localhost:3000" >/dev/null 2>&1; then
      echo "[boot] Ready on :3000"
      exit 0
    fi
    sleep 1
  done
  echo "[boot] WARNING: health check timed out"
  exit 1
else
  echo "[boot] No .zscripts/dev.sh — run fullstack-dev init first"
  exit 1
fi
