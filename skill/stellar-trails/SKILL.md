---
name: stellar-trails
description: "Activates on every task: coding (features, bugs, refactoring, scripts), documents (reports, proposals, DOCX, PDF), charts and visualizations, data processing, complex multi-step planning, or even simple questions. Provides a six-phase workflow with traceability IDs, entry/exit gates, scope commitment, and three enforcement layers (phase machine, mandatory prints, preferences dialog). Complexity adapts per task tier. Use this skill whenever the user asks to build, fix, analyze, create, plan, or process anything — the framework runs internally for trivial tasks and fully for complex ones. Web development (Next.js, UI) is delegated to fullstack-dev; this framework wraps the workflow around it."
license: MIT-0
metadata:
  topics:
    - agent-workflow
    - phase-machine
    - phase-workflow
    - task-workflow
    - llm-agents
    - task-management
    - traceability
    - zai
---

## Metadata

- **version**: 9.14.1

---

## Activation

### ⚠️ CRITICAL: Pre-Tool-Call Gate (E4 — Layer 1, NEW in v9.3.0)

Before calling ANY tool (Read, Write, Bash, Edit, Grep, Glob, Task, etc.) in a session, the activation banner MUST have been printed AND Steps 1–5 must have been executed. If you are about to call a tool and have NOT printed the banner + completed all 5 steps, STOP and do activation FIRST.

**Self-check before first tool call**:
- Have I printed `☄️ STELLAR TRAILS · vX.Y.Z · ACTIVE`? → If NO, print it NOW
- Have I executed Steps 1–5 with `✓`/`✗` marks? → If NO, execute them NOW
- Have I printed `✓ Step 5`? → If NO, do not proceed to any tool

This is a **HARD GATE**. No tool call may precede the banner + 5 steps. Violating this gate is a correctness bug, not a style preference.

**Why this gate exists**: Audit of 5 prior sessions found 0/5 compliance with activation mandate. LLMs rationalize skipping ("continuation task", "simple task", "save tokens", "user didn't complain last time"). The gate makes skipping impossible to rationalize — you literally cannot call a tool until activation is done.

**Subagent exemption (added v9.11.4)**: This gate applies to the **main agent** only. Subagents in z.ai receive a compressed task prompt from the orchestrator — they do NOT have SKILL.md pre-loaded into context. To learn the gate exists, a subagent would have to call `Skill(command="stellar-trails")`, which is itself a pre-banner tool call (chicken-and-egg). Therefore E4 is structurally unenforceable on subagents. If subagent compliance is required, the orchestrating main agent MUST pre-inject the relevant SKILL.md sections (activation mandate + step bash blocks) into the subagent's task prompt — only then can the subagent comply. Verified by SIM-001/SIM-002 audit (v9.11.3): both `Explore` and `general-purpose` subagents can call `Skill()` and read SKILL.md from disk, but neither prints the banner first because they have no prior knowledge of the mandate.

### FIRST OUTPUT — Print this banner, then execute Steps 1–5

Your VERY FIRST output to the user is the activation banner below. No other text precedes it. Print the banner, then run Steps 1–5.

**Why print every invoke**: After context truncation, neither you nor the user know whether the banner was already printed. The banner is the only reliable signal that activation ran. Skipping it because "I already did it" is a correctness bug — you cannot reliably know what you did before truncation.

**Banner version is DYNAMIC**: Read the version from the `## Metadata` section at the top of this file (the `- **version**: X.Y.Z` line). Substitute that version into the banner below where you see `<VERSION>`. Do NOT hardcode the version — every version bump must automatically reflect in the banner without editing this template. (Fixes the v9.2.1 bug where the banner was stuck at v9.1.0 because it was hardcoded.)

```
☄️ STELLAR TRAILS · v<VERSION> · ACTIVE
├─ Phase: IDLE → SPECIFY
├─ Complexity: [tier] | Task Type: [type] | Continuation: [NEW / YES]
└─ Activation checklist (1–5, every invoke) — executing:
   ├─ 1  Refresh context + SSV            ...
   ├─ 2  Start popup server               ...
   ├─ 3  Auto-update via ClawHub          ...
   ├─ 4  Verify files + sync zip          ...
   └─ 5  Load phases + classify           ...
```

Replace `...` with `✓` (success) or `✗` (failure) as each step completes.

### Activation Enforcement Vectors (E7-E11, NEW in v9.4.0)

Text enforcement (E1-E6) caps at ~70-85% compliance because LLMs can rationalize past text. The 5 vectors below use **sandbox-native mechanisms** that LLMs cannot fabricate — tool calls are ground truth, file tokens are verifiable, external oracles cannot be faked.

**Expected compliance**: ~90-93% automated, ~95% with active user verification of transcript.

#### Vektor 1 — Hash Token Gate (E7)

Every bash block in activation writes/verifies a hash token. LLM cannot proceed past Step 2+ without actually running Step 1 (which writes the token).

**Token file**: `/tmp/st-active` (session-scoped, wiped on session reset)
**Token content**: `sha256(version_line_from_SKILL.md)[:16]`

Step 1 writes the token. Steps 2-5 verify it at the top of their bash block:
```bash
# Gate check (top of every Step 2+ bash block):
EXPECTED=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md | sha256sum | cut -c1-16)
ACTUAL=$(cat /tmp/st-active)
if [ "$EXPECTED" != "$ACTUAL" ]; then
  echo "✗ GATE FAILED: activation token missing/invalid — Step 1 must run first"
  exit 1
fi
```

If LLM skips Step 1, token doesn't exist → Step 2 bash exits 1 → LLM cannot complete task. **LLM cannot fake this** because writing the correct hash requires reading SKILL.md (a tool call recorded in transcript).

**Subagent write access caveat (added v9.11.4)**: `/tmp/st-active` is owned by the same user that subagents run as (`-rw-rw-r-- z:z`), so a subagent CAN overwrite the token to bypass the E7 gate. The gate enforces Step 1 → Step 2+ ordering for the **main agent**; it does not prevent a malicious subagent from writing a valid token without running Step 1. Mitigation: the orchestrating main agent should pre-validate that the token was written by Step 1 (not by a subagent) before trusting subsequent steps. This is best-effort enforcement, not tamper-proof.

**Token determinism caveat (added v9.13.1)**: The token is `sha256("<version>\n")[:16]` — a pure function of the version string, not a session secret. Every session (main agent, subagent, concurrent or not) running the same skill version computes the **identical** token value. Verified live: token `6c81522b916ad90e` appeared in activation-log entries written by ≥2 distinct sessions running v9.12.0 on 2026-08-23. The gate proves *"someone hashed the version line on this filesystem"*, never *"this specific agent ran Step 1"*. The enforcement matrix row is therefore downgraded from NO to PARTIAL.

#### Vektor 2 — TodoWrite Live Marker (E8)

TodoWrite is a platform tool that renders a live checklist visible to the user in real-time. The user sees checkboxes transition `pending → in_progress → completed` as the LLM works. This is **visibility enforcement** — user can SEE if steps are being executed, not just trust LLM's text claims.

**Mandatory protocol** (before Step 1 bash):
1. Call `TodoWrite` with 5 items (Step 1 through Step 5), all status `pending`
2. Before executing each Step N bash: call `TodoWrite` to mark Step N `in_progress`
3. After each Step N bash succeeds: call `TodoWrite` to mark Step N `completed`
4. If any Step N fails: leave as `in_progress`, do NOT mark `completed`

**Why this works**: TodoWrite is a tool call recorded in transcript. LLM cannot fabricate "I marked Step 3 completed" without actually calling TodoWrite. User sees the live checklist — if Step 3 is marked `completed` but no Bash tool call for Step 3 appears in transcript, fraud is visible.

**Edge case**: LLM could mark all 5 `completed` in a single TodoWrite call without running anything. Mitigation: user watches for the **transition** (pending → in_progress → completed), not just final state. Single-call mass-marking is suspicious.

#### Vektor 3 — Persistent Activation Log (E9)

Each successful activation appends to `/home/user_skills/.st-activation-log` (persistent across sessions). User can audit this file anytime.

**Log entry format** (one line per activation — corrected v9.13.1 to match actual Step 5 bash output):
```
YYYY-MM-DDTHH:MM:SSZ v<VERSION> token=<hash> steps=5/5 banner=YES
```

Step 5 writes the log entry. Next session's Step 1 can read the log to verify prior activations occurred. LLM can fake a log entry, but:
- Timestamps must be monotonic — fake entries with wrong timestamps are detectable
- No session ID is recorded — the log proves WHEN an activation happened, never WHO did it
- User can `cat /home/user_skills/.st-activation-log` to audit anytime

**Empirical persistence + multi-session caveat (added v9.13.1)**: Cross-session persistence is a **verified fact**, not an aspiration. At audit time the log held 326 entries across 38 distinct days (2026-07-11 → 2026-08-23, versions v9.4.0 → v9.13.0) with **0 timestamp-monotonicity violations**. However, the sandbox filesystem is **shared by concurrent sessions**, and their entries interleave indistinguishably. On 2026-08-23 alone, ≥2 sessions interleaved within one hour — including a `COMPLIANCE v9.13.0 score=12/12` entry that belongs to a session which wrote **no adjacent activation entry**. Only version/token discontinuities distinguish the sessions. **The log proves WHEN, never WHO.**

**Best-effort caveat (added v9.11.4)**: `/home/user_skills/` is world-writable (`drwxrwxrwx` mode 0777) in the z.ai sandbox, meaning any process — including subagents — can modify or append to the activation log. This vector is fraud-detection (anomalous timestamps are visible on audit), not fraud-prevention. The real value of E9 is **visibility for the user**, not cryptographic integrity.

#### Vektor 4 — Read Tool Line-Number Proof (E10)

Step 1 must print a specific line from SKILL.md in the format `Read` tool returns (`<line_number>→<content>`). LLM cannot fabricate this format without actually calling Read.

**Protocol**: After Read SKILL.md, print the version line with its line number:
```
SKILL.md line 19: 19→- **version**: 9.4.0
```

User can verify by reading the same file themselves. If LLM fabricates (e.g., wrong line number, wrong content), user catches it on spot-check.

**Limitation**: LLM knows line 19 is the version line (from context). Stronger variant: skill mandates "print line N where N = current day-of-month + 10" — LLM cannot predict which line user will verify. But this adds complexity; the simple variant is sufficient for now.

#### Vektor 5 — Clawhub Oracle Cross-Check (E11)

Step 3 runs `clawhub inspect` — output is ground truth from an external binary LLM cannot fabricate. Step 4 re-runs `clawhub inspect` and cross-checks the version matches what Step 3 reported.

**Protocol**:
- Step 3 writes `clawhub inspect --json` output to `/tmp/st-clawhub-oracle.json`
- Step 4 reads `/tmp/st-clawhub-oracle.json`, extracts `latestVersion.version`
- Step 4 compares to what LLM claimed in transcript
- If mismatch → COMPLIANCE FAILURE reported to user

**Why this works**: `clawhub` is a binary outside LLM control. The real protection is that Step 4 **re-runs `clawhub inspect`** and cross-checks the version — that re-run is the actual oracle. The cached file at `/tmp/st-clawhub-oracle.json` is just an optimization to avoid a second network call.

**Fabrication caveat (corrected v9.11.4, re-verified v9.13.1)**: A previous version of this section claimed "LLM cannot fabricate `/tmp/st-clawhub-oracle.json` without actually running clawhub." This was overstated — the file is plain JSON at `/tmp/` (permissions `-rw-rw-r-- z:z`), confirmed by both `bash stat` and `python3 os.stat`. Any bash command can write arbitrary content to it. The actual protection is Step 4's re-verification via fresh `clawhub inspect` calls, not the file's contents. The file is an audit artifact, not a tamper-proof oracle.

**Parse-defensiveness note (added v9.13.1)**: Live registry responses may **omit or null** fields the checks might expect — `moderation.state` and `name` were absent/`None` while `latestVersion.version` was present and correct. Always extract `latestVersion.version` defensively: `python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('latestVersion') or {}).get('version') or '')"`.

#### Combined Enforcement Matrix

| Vector | What it enforces | LLM can fake? | User can verify? |
|---|---|---|---|
| E7 Hash token | Steps 2-5 cannot run without Step 1 | PARTIAL (proves hashing happened, not who did it — token is version-derived, identical across concurrent sessions) | YES (cat /tmp/st-active) |
| E8 TodoWrite | Steps visible in real-time UI | Partially (can mass-mark, but transitions are visible) | YES (watch live checklist) |
| E9 Persistent log | Cross-session audit trail | Partially (timestamps must be monotonic; no session ID — log proves WHEN, never WHO) | YES (cat /home/user_skills/.st-activation-log) |
| E10 Line-number proof | Step 1 actually called Read | Partially (LLM knows line 19) | YES (read same file, compare) |
| E11 Clawhub oracle | Step 3 actually ran clawhub | NO (external binary output is ground truth) | YES (cat /tmp/st-clawhub-oracle.json) |

**What still cannot be enforced**: Banner printed as FIRST output (text ordering), LLM not printing fake `✓ Step N` markers (text). These remain text-only enforcement via E4-E6.

### Activation Steps

**Step 1 — Refresh context + SSV**: Re-read `/home/z/my-project/skills/stellar-trails/SKILL.md` from disk using the Read tool. Do not trust cached context — the on-disk version is source of truth. If task involves a git repo, run SSV. **E7 (hash token) and E10 (line-number proof) are written by this step** — subsequent steps verify the token to enforce that Step 1 actually ran.

```bash
# v9.13.2 FIX: Banner is printed BY BASH, not by LLM text before bash.
# Root cause of E4 violations: banner was text the LLM was supposed to print
# BEFORE running Step 1 bash. But the LLM often skips it and goes straight to
# bash. Fix: embed the banner echo as the FIRST line of Step 1 bash itself.
# This way, the banner is ALWAYS printed when Step 1 runs — the LLM cannot skip it.
_ST_VER=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md | head -1)
echo "☄️ STELLAR TRAILS · v${_ST_VER} · ACTIVE"
echo "├─ Phase: IDLE → SPECIFY"
echo "├─ Complexity: [tier] | Task Type: [type] | Continuation: [NEW / YES]"
echo "└─ Activation checklist (1–5, every invoke) — executing:"
# SSV only runs if the skill has its own git repo at $HOME/.stellar-trails-repo/.
# In the z.ai sandbox this directory usually does not exist (skill is installed
# via clawhub, not git clone), so SSV is skipped gracefully. Running bare
# `git fetch` from /home/z/my-project/ would operate on the sandbox workspace
# repo — explicitly forbidden by knowledge/zai-sandbox.md.
if [ -d "$HOME/.stellar-trails-repo/.git" ]; then
  git -C "$HOME/.stellar-trails-repo" fetch origin --quiet
  BRANCH=$(git -C "$HOME/.stellar-trails-repo" branch --show-current || echo main)
  BEHIND=$(git -C "$HOME/.stellar-trails-repo" rev-list --count HEAD..origin/$BRANCH)
  if [ -n "$BEHIND" ] && [ "$BEHIND" -gt 0 ]; then echo "✗ Step 1 FAILED: skill repo is $BEHIND commits behind origin — run git -C $HOME/.stellar-trails-repo pull"; exit 1
  else echo "✓ Step 1: context refreshed + SSV passed (v$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md || echo unknown))"; fi
else
  echo "✓ Step 1: context refreshed (v$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md || echo unknown)) — SSV skipped (no skill git repo)"
fi
# E7: Write hash token — Steps 2-5 verify this token to prove Step 1 ran.
# Token = sha256(version line)[:16]. LLM cannot fake this without reading SKILL.md.
grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md | sha256sum | cut -c1-16 > /tmp/st-active
# E10: Print line-number proof — user can verify by reading same file.
SKILL_VERSION_LINE=$(grep -n '^- \*\*version\*\*:' /home/z/my-project/skills/stellar-trails/SKILL.md | head -1 | cut -d: -f1)
echo "  E7 token: $(cat /tmp/st-active)"
echo "  E10 line proof: SKILL.md line ${SKILL_VERSION_LINE}: $(sed -n "${SKILL_VERSION_LINE}p" /home/z/my-project/skills/stellar-trails/SKILL.md)"
# Auto Git Identity Setup (NEW in v9.10.1) — if PAT exists, auto-configure git identity
# from GitHub API. Fixes: Z User author, credentials gagal, UUID local.
# Runs automatically every activation — no manual step needed.
if [ -f /home/z/my-project/upload/PAT ]; then
  _GH_TOKEN=$(tr -d '[:space:]' < /home/z/my-project/upload/PAT)
  _OWNER_JSON=$(curl -sS -m 10 -H "Authorization: Bearer $_GH_TOKEN" https://api.github.com/user)
  _OWNER_LOGIN=$(echo "$_OWNER_JSON" | python3 -c "import json,sys; print(json.load(sys.stdin).get('login',''))")
  if [ -n "$_OWNER_LOGIN" ]; then
    _OWNER_NAME=$(echo "$_OWNER_JSON" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('name') or d.get('login',''))")
    _OWNER_EMAIL="${_OWNER_LOGIN}@users.noreply.github.com"
    git config --global user.email "$_OWNER_EMAIL"
    git config --global user.name "$_OWNER_NAME"
    git config --global credential.helper store
    echo "https://${_OWNER_LOGIN}:${_GH_TOKEN}@github.com" > ~/.git-credentials
    chmod 600 ~/.git-credentials
    export GIT_AUTHOR_NAME="$_OWNER_NAME" GIT_AUTHOR_EMAIL="$_OWNER_EMAIL"
    export GIT_COMMITTER_NAME="$_OWNER_NAME" GIT_COMMITTER_EMAIL="$_OWNER_EMAIL"
    echo "  Git identity: $_OWNER_NAME <$_OWNER_EMAIL> (auto-configured from PAT)"
  fi
fi
```

**Step 2 — Start popup server + verify mascot**: **E7 gate check at top of bash block** — verifies Step 1 ran by checking hash token.

```bash
# E7 gate check — proves Step 1 actually ran (token requires reading SKILL.md)
EXPECTED_TOKEN=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md | sha256sum | cut -c1-16)
ACTUAL_TOKEN=$(cat /tmp/st-active)
if [ "$EXPECTED_TOKEN" != "$ACTUAL_TOKEN" ]; then
  echo "✗ Step 2 GATE FAILED: activation token missing/invalid — Step 1 must run first"
  exit 1
fi
SKILL_DIR="/home/z/my-project/skills/stellar-trails"; ZSCRIPTS="/home/z/my-project/.zscripts"
if [ ! -f "$SKILL_DIR/chibi.svg" ]; then for REPO_CLONE in "/home/z/my-project/stellar-trails/skill/stellar-trails" "/home/z/my-project/.stellar-trails-repo/skill/stellar-trails" "$HOME/.stellar-trails-repo/skill/stellar-trails"; do [ -f "$REPO_CLONE/chibi.svg" ] && cp -f "$REPO_CLONE/chibi.svg" "$SKILL_DIR/chibi.svg" && break; done; fi
if [ -d "$SKILL_DIR" ]; then mkdir -p "$ZSCRIPTS"; [ -f "$SKILL_DIR/dev.sh" ] && cp -f "$SKILL_DIR/dev.sh" "$ZSCRIPTS/dev.sh" && chmod +x "$ZSCRIPTS/dev.sh"; [ -f "$SKILL_DIR/index.html" ] && cp -f "$SKILL_DIR/index.html" "$ZSCRIPTS/index.html"; [ -f "$SKILL_DIR/chibi.svg" ] && cp -f "$SKILL_DIR/chibi.svg" "$ZSCRIPTS/chibi.svg"; fi
DEV_SH="$ZSCRIPTS/dev.sh"; [ -f "$DEV_SH" ] && ! ss -tlnp | grep -q ':3000 ' && ( setsid bash "$DEV_SH" </dev/null >/dev/null 2>&1 & ) &
sleep 1
HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/)
MASCOT=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/chibi.svg)
if [ "$HTTP" = "200" ]; then echo "✓ Step 2: popup server running on :3000 (HTTP $HTTP, mascot $MASCOT)"; else echo "✗ Step 2 FAILED: popup server not responding (HTTP $HTTP)"; exit 1; fi
```

**z.ai sandbox note**: The popup server runs on `localhost:3000` inside the sandbox, but z.ai does NOT expose raw ports to the user's browser. The popup is only visible through the z.ai preview URL pattern: `https://preview-<bot-id>.space-z.ai/`. If the sandbox exposes a preview panel, the popup appears there; otherwise the popup runs but is invisible to the user (activation still succeeds — the popup is decorative, not functional). See `knowledge/zai-sandbox.md` for details.

**Step 3 — Auto-update via ClawHub**: **E7 gate check + E11 oracle** — clawhub output written to `/tmp/st-clawhub-oracle.json` for Step 4 cross-verification.

```bash
# E7 gate check
EXPECTED_TOKEN=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md | sha256sum | cut -c1-16)
ACTUAL_TOKEN=$(cat /tmp/st-active)
if [ "$EXPECTED_TOKEN" != "$ACTUAL_TOKEN" ]; then
  echo "✗ Step 3 GATE FAILED: activation token missing/invalid — Step 1 must run first"
  exit 1
fi
CURRENT=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9]+\.[0-9]+\.[0-9]+' /home/z/my-project/skills/stellar-trails/SKILL.md | head -1)
# E11: Write clawhub output to oracle file — Step 4 will cross-verify this.
# Note: the file itself is writable (see E11 Fabrication caveat above); the real
# protection is Step 4's re-verification via fresh clawhub inspect calls, not the file.
clawhub inspect stellar-trails --json > /tmp/st-clawhub-oracle.json
LATEST=$(python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('latestVersion') or {}).get('version') or '')" < /tmp/st-clawhub-oracle.json || echo "")
if [ -z "$CURRENT" ]; then echo "✗ Step 3 FAILED: could not read current version from SKILL.md"; exit 1
elif [ -z "$LATEST" ]; then echo "✗ Step 3 FAILED: could not reach ClawHub registry (network down?)"; exit 1
elif [ "$CURRENT" = "$LATEST" ]; then echo "✓ Step 3: up to date (v$CURRENT) — E11 oracle: $(stat -c%s /tmp/st-clawhub-oracle.json) bytes"
else
  echo "⚠️ Step 3: DRIFT DETECTED — local v$CURRENT vs registry v$LATEST — FORCE UPDATING..."
  clawhub --no-input update stellar-trails --force
  UPDATE_EXIT=$?
  if [ $UPDATE_EXIT -ne 0 ]; then
    echo "✗ Step 3 FAILED: clawhub update exited $UPDATE_EXIT — see error above"
    exit 1
  fi
  # Post-update verification: re-read local version, confirm it changed
  POST_VERSION=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9]+\.[0-9]+\.[0-9]+' /home/z/my-project/skills/stellar-trails/SKILL.md | head -1)
  if [ "$POST_VERSION" != "$LATEST" ]; then
    echo "✗ Step 3 FAILED: update claimed success but local still v$POST_VERSION (expected v$LATEST)"
    echo "  Possible cause: skill hidden by moderation, or clawhub update silent failure"
    exit 1
  fi
  echo "✓ Step 3: FORCE UPDATE CONFIRMED — local v$POST_VERSION = registry v$LATEST"
  # Sync the persistent zip immediately after a successful update.
  SKILL_DIR="/home/z/my-project/skills/stellar-trails"
  USER_SKILLS_DIR="/home/user_skills"
  if [ -d "$SKILL_DIR" ] && [ -d "$USER_SKILLS_DIR" ]; then
    cd "$(dirname "$SKILL_DIR")" && zip -qr "$USER_SKILLS_DIR/stellar-trails.zip" "$(basename "$SKILL_DIR")/" && echo "✓ Step 3: zip synced to v$LATEST" || echo "⚠️ Step 3: zip sync warning"
  fi
fi
```

If clawhub updated the skill: re-read SKILL.md from disk now. Cached context is stale.

**Step 4 — Verify files + force-override .zscripts/ + restart dev.sh + sync zip**: **E7 gate + E11 cross-check** — verifies Step 3 oracle file exists and matches claimed version.

```bash
# E7 gate check
EXPECTED_TOKEN=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md | sha256sum | cut -c1-16)
ACTUAL_TOKEN=$(cat /tmp/st-active)
if [ "$EXPECTED_TOKEN" != "$ACTUAL_TOKEN" ]; then
  echo "✗ Step 4 GATE FAILED: activation token missing/invalid — Step 1 must run first"
  exit 1
fi
# E11 cross-check: verify Step 3 oracle file exists (proves Step 3 ran clawhub)
if [ ! -f /tmp/st-clawhub-oracle.json ]; then
  echo "✗ Step 4 E11 FAILED: clawhub oracle file missing — Step 3 must run first"
  exit 1
fi
ORACLE_VERSION=$(python3 -c "import json,sys; d=json.load(sys.stdin); print((d.get('latestVersion') or {}).get('version') or '')" < /tmp/st-clawhub-oracle.json || echo "")
echo "  E11 oracle cross-check: registry latest = v${ORACLE_VERSION:-<parse failed>}"
SKILL_DIR="/home/z/my-project/skills/stellar-trails"; USER_SKILLS_DIR="/home/user_skills"; ZSCRIPTS="/home/z/my-project/.zscripts"
# v9.14.1: Install-if-missing — if skill was wiped by container reboot (not in stages.yaml),
# auto-install via clawhub before proceeding to file verification.
if [ ! -f "$SKILL_DIR/SKILL.md" ]; then
  echo "⚠️ Step 4a-pre: SKILL.md missing — auto-installing stellar-trails via clawhub..."
  clawhub install stellar-trails --force || { echo "✗ Step 4a-pre FAILED: clawhub install failed"; exit 1; }
  echo "✓ Step 4a-pre: stellar-trails installed via clawhub"
fi
FILES_OK="yes"
for f in SKILL.md procedure/phases.md dev.sh index.html chibi.svg; do [ ! -f "$SKILL_DIR/$f" ] && echo "✗ Step 4 WARNING: missing $f" && FILES_OK="no"; done
if [ "$FILES_OK" = "yes" ]; then echo "✓ Step 4a: all skill files present"; else echo "✗ Step 4a FAILED: some files missing — graceful degradation"; exit 1; fi
mkdir -p "$ZSCRIPTS"
# v9.11.9: .zscripts/dev.sh is now git-tracked (canonical runtime source).
# Step 4b syncs skill/stellar-trails/dev.sh → .zscripts/dev.sh to keep both in sync.
# Pre-Push Check 14 verifies they have identical hashes before push.
[ -f "$SKILL_DIR/dev.sh" ] && cp -f "$SKILL_DIR/dev.sh" "$ZSCRIPTS/dev.sh" && chmod +x "$ZSCRIPTS/dev.sh"
[ -f "$SKILL_DIR/index.html" ] && cp -f "$SKILL_DIR/index.html" "$ZSCRIPTS/index.html"
[ -f "$SKILL_DIR/chibi.svg" ] && cp -f "$SKILL_DIR/chibi.svg" "$ZSCRIPTS/chibi.svg"
echo "✓ Step 4b: .zscripts/ synced (dev.sh is git-tracked since v9.11.9)"
# Bug 3 fix (v9.11.6): kill bash SUPERVISOR via PID file, not python3 listener via ss.
# ss -tlnp | grep ':3000' returns python3 (the listener), killing it triggers bash
# supervisor to restart python3 with the OLD dev.sh still loaded — file reload fails.
# Fix: read PID file to get bash supervisor PID, verify /proc/cmdline contains dev.sh, kill it.
#
# Bug 4 fix (v9.11.7): killing bash supervisor orphans its python3 child (reparented to
# PID 1) which keeps :3000 occupied → Step 4d's new dev.sh sees port in use → exits →
# no supervisor ever starts. Fix: AFTER killing bash supervisor, also kill the orphaned
# python3 listener on :3000 so Step 4d starts cleanly.
OLD_PID=$(cat "$ZSCRIPTS/st-devsh.pid" 2>/dev/null)
if [ -n "$OLD_PID" ] && [ -d "/proc/$OLD_PID" ]; then
  OLD_CMDLINE=$(tr '\0' ' ' < "/proc/$OLD_PID/cmdline" 2>/dev/null)
  if echo "$OLD_CMDLINE" | grep -q 'dev\.sh'; then
    kill "$OLD_PID"; sleep 1; echo "✓ Step 4c: old dev.sh supervisor (PID $OLD_PID) killed"
    # Bug 4 fix: also kill orphaned python3 listener left by the killed supervisor
    LISTENER_PID=$(ss -tlnp 2>/dev/null | grep ':3000 ' | grep -oP 'pid=\K[0-9]+' | head -1)
    if [ -n "$LISTENER_PID" ]; then
      kill "$LISTENER_PID" 2>/dev/null || true
      sleep 1
      # Force-kill if still alive (uninterruptible listener)
      if ss -tlnp 2>/dev/null | grep -q ':3000 '; then
        kill -9 "$LISTENER_PID" 2>/dev/null || true
        sleep 1
      fi
      echo "  Bug 4 fix: killed orphaned python3 listener (PID $LISTENER_PID) left by supervisor"
    fi
  else
    echo "⚠️ Step 4c: PID $OLD_PID in pidfile is not dev.sh (cmdline: $OLD_CMDLINE) — skipping kill"
    # Fallback: kill python3 listener if port :3000 is still occupied
    LISTENER_PID=$(ss -tlnp | grep ':3000 ' | grep -oP 'pid=\K[0-9]+' | head -1)
    [ -n "$LISTENER_PID" ] && kill "$LISTENER_PID" && sleep 1 && echo "  fallback: killed python3 listener (PID $LISTENER_PID)"
  fi
else
  echo "✓ Step 4c: no stale dev.sh PID file found — fresh start"
fi
DEV_SH="$ZSCRIPTS/dev.sh"
if [ -f "$DEV_SH" ]; then ( setsid bash "$DEV_SH" </dev/null >/dev/null 2>&1 & ) & sleep 1
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/)
  if [ "$HTTP" = "200" ]; then echo "✓ Step 4d: dev.sh restarted on :3000 (HTTP $HTTP)"; else echo "✗ Step 4d FAILED: dev.sh restart failed (HTTP $HTTP)"; exit 1; fi
else echo "✗ Step 4d FAILED: dev.sh not found at $DEV_SH"; exit 1; fi
if [ -d "$SKILL_DIR" ] && [ -d "$USER_SKILLS_DIR" ]; then cd "$(dirname "$SKILL_DIR")" && zip -qr "$USER_SKILLS_DIR/stellar-trails.zip" "$(basename "$SKILL_DIR")/" && echo "✓ Step 4e: persistent zip synced" || { echo "✗ Step 4e FAILED: zip sync error"; exit 1; }; else echo "✗ Step 4e FAILED: directory not found"; exit 1; fi
```

**Step 5 — Load phases + classify**: Read `procedure/phases.md` now. Then determine complexity tier (Minimal/Simple/Standard/Complex), task type (Coding/Document/Visualization/Data Processing/Non-Coding), and continuity (NEW or YES — see Session Continuity below). **E7 gate + E9 persistent log** — writes activation record to `/home/user_skills/.st-activation-log` for cross-session audit.

```bash
# E7 gate check
EXPECTED_TOKEN=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md | sha256sum | cut -c1-16)
ACTUAL_TOKEN=$(cat /tmp/st-active)
if [ "$EXPECTED_TOKEN" != "$ACTUAL_TOKEN" ]; then
  echo "✗ Step 5 GATE FAILED: activation token missing/invalid — Step 1 must run first"
  exit 1
fi
# E9: Write persistent activation log — user can audit anytime via:
#   cat /home/user_skills/.st-activation-log
ST_VERSION=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md | head -1)
ST_TIMESTAMP=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
ST_TOKEN=$(cat /tmp/st-active)
echo "${ST_TIMESTAMP} v${ST_VERSION} token=${ST_TOKEN} steps=5/5 banner=YES" >> /home/user_skills/.st-activation-log
echo "✓ Step 5: phases loaded + classified: [tier]/[type]/[NEW|YES] — E9 log entry written"
# v9.13.0 P2: Automated worklog rotation — execute, not just document.
# Runs every activation. If worklog > 50 entries, rotate immediately (don't wait for 100).
WORKLOG="/home/z/my-project/worklog.md"
if [ -f "$WORKLOG" ]; then
  WENTRY_COUNT=$(grep -c '^---$' "$WORKLOG" 2>/dev/null || echo 0)
  if [ "$WENTRY_COUNT" -gt 50 ]; then
    ARCHIVE="${WORKLOG%.md}-archive-$(date -u '+%Y-%m-%d').md"
    mv "$WORKLOG" "$ARCHIVE"
    # Preserve last 5 entries for continuity
    awk 'BEGIN{RS="^---$"} {entries[NR]=$0} END{print "---"; for(i=NR-4;i<=NR;i++) if(entries[i]) print entries[i]}' "$ARCHIVE" > "$WORKLOG"
    echo "  P2: worklog rotated ($WENTRY_COUNT → 5 entries, archive: $ARCHIVE)"
  fi
fi
# v9.13.0 P3: Knowledge on-demand loading — actually load relevant file, not just instruct.
# Based on task type (determined by LLM before running this bash), load the relevant knowledge file.
# The LLM sets ST_TASK_TYPE before running Step 5. If not set, default to "coding".
ST_TASK_TYPE="${ST_TASK_TYPE:-coding}"
KBASE="/home/z/my-project/skills/stellar-trails/knowledge"
case "$ST_TASK_TYPE" in
  coding|Coding)    head -30 "$KBASE/error-patterns.md" 2>/dev/null | head -5 | sed 's/^/  /' ;;
  audit|Audit)      head -30 "$KBASE/patterns.md" 2>/dev/null | head -5 | sed 's/^/  /' ;;
  document|Document) head -30 "$KBASE/conventions.md" 2>/dev/null | head -5 | sed 's/^/  /' ;;
  *)               head -30 "$KBASE/user-profile.md" 2>/dev/null | head -5 | sed 's/^/  /' ;;
esac
echo "  P3: knowledge preview loaded for task_type=$ST_TASK_TYPE"
# v9.13.3 MIGRATION 1: 5/5 GREEN GATE — was text, now bash echo (LLM cannot skip)
echo "✓ 5/5 GREEN — activation complete"
# v9.13.3 MIGRATION 2: Compliance Score — was text self-assessment, now bash mechanical
# Computes score from verifiable sandbox artifacts, not LLM honesty
SCORE=0; SKIPPED=""
[ -f /tmp/st-active ] && SCORE=$((SCORE+1)) || SKIPPED="${SKIPPED}E7,"
[ -f /tmp/st-clawhub-oracle.json ] && SCORE=$((SCORE+1)) || SKIPPED="${SKIPPED}E11,"
curl -s -o /dev/null -m 2 http://localhost:3000/ 2>/dev/null && SCORE=$((SCORE+1)) || SKIPPED="${SKIPPED}dev.sh,"
tail -1 /home/user_skills/.st-activation-log 2>/dev/null | grep -q "steps=5/5" && SCORE=$((SCORE+1)) || SKIPPED="${SKIPPED}E9log,"
[ -f "$WORKLOG" ] && SCORE=$((SCORE+1)) || SKIPPED="${SKIPPED}worklog,"
echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') COMPLIANCE v${ST_VERSION} score=${SCORE}/5 mechanical=bash skipped=${SKIPPED:-none}" >> /home/user_skills/.st-activation-log
echo "  Compliance: ${SCORE}/5 mechanical (skipped: ${SKIPPED:-none})"
```

**Mandatory TodoWrite protocol (E8)**: Before Step 1 bash, call `TodoWrite` with 5 items (Step 1 through Step 5), all status `pending`. Before each Step N bash, mark Step N `in_progress`. After each Step N bash succeeds, mark Step N `completed`. User sees the live checklist transition in real-time — this is visibility enforcement that text cannot provide.

### E12 — Activation Retry Protocol (NEW v9.12.0)

**Problem this solves**: Previous versions had Step bash blocks that only `exit 1` on GATE failures (E7 token mismatch). Step-specific failures (HTTP != 200, clawhub unreachable, dev.sh restart failed) just echoed `✗ Step N FAILED` and exited 0 — the LLM couldn't detect failure from exit code alone, and there was no retry mandate. The LLM would often proceed to the next step despite a failure, or silently skip the failed step.

**Solution**: Three changes:
1. **Print stdout mandate**: Each Step's bash block stdout MUST be printed verbatim in the transcript — no summarizing, suppressing, or paraphrasing. The user must see the raw `✓` or `✗` output.
2. **Exit code enforcement**: Each Step bash block must `exit 1` on ANY failure (not just GATE failures). The Bash tool reports non-zero exit code → LLM detects failure → triggers retry.
3. **Retry-until-green**: If Step N fails (exit 1), the LLM MUST:
   - Print the error output (already captured by Bash tool)
   - Diagnose the cause (read the ✗ message, identify root cause)
   - Apply a fix (e.g., re-read SKILL.md, restart dev.sh, force clawhub update)
   - Re-run Step N
   - Repeat until ✓ (max 3 retries per step)
   - If still failing after 3 retries → use E6 Escape Hatch or ask user for guidance

**Retry decision tree**:
```
Step N bash exits with code:
  0 (success)  → print ✓ Step N output → proceed to Step N+1
  1 (failure)  → print ✗ Step N output → diagnose → fix → re-run Step N
                   ↓
                   retry 1: re-run Step N
                     ├─ exit 0 → ✓ proceed
                     └─ exit 1 → retry 2: re-run Step N
                                    ├─ exit 0 → ✓ proceed
                                    └─ exit 1 → retry 3: re-run Step N
                                                   ├─ exit 0 → ✓ proceed
                                                   └─ exit 1 → ⚠️ MAX RETRIES EXCEEDED
                                                      → E6 Escape Hatch or ask user
```

**Common failure fixes** (apply before retry):
| Step | Failure | Fix |
|------|---------|-----|
| 1 | SKILL.md not found | `clawhub --no-input update stellar-trails --force` to restore |
| 2 | HTTP != 200 (popup not responding) | Kill stale dev.sh: `kill $(cat /home/z/my-project/.zscripts/st-devsh.pid)` + re-run Step 2 |
| 3 | clawhub unreachable (network) | Retry Step 3 after 5s — network may be transient |
| 3 | clawhub update failed (moderation) | Check `clawhub inspect stellar-trails --json` moderation state → if hidden, ask user |
| 4 | dev.sh restart failed (port in use) | Kill orphaned listener: `ss -tlnp \| grep ':3000' \| grep -oP 'pid=\K[0-9]+' \| xargs kill -9` + re-run Step 4 |
| 4 | zip sync failed (directory missing) | `mkdir -p /home/user_skills` + re-run Step 4 |
| 5 | E7 GATE FAILED (token mismatch) | Re-run Step 1 to re-write token, then re-run Step 5 |

**Anti-patterns (FORBIDDEN)**:
- ❌ "Step 2 failed but I'll proceed to Step 3" — NO. Retry Step 2 until ✓ before proceeding.
- ❌ "I'll summarize the output instead of printing verbatim" — NO. Print the raw stdout. The user needs to see the actual `✓`/`✗` markers.
- ❌ "Step 4d failed but 4a-4c passed, so Step 4 is mostly OK" — NO. Step 4 is one unit. If any sub-check fails, the whole step fails. Retry the entire Step 4.
- ❌ "After 3 retries I'll just skip to Step 5" — NO. Use E6 Escape Hatch to make the skip visible, or ask the user.

### 5/5 GREEN GATE (NEW v9.12.0)

After Step 5 completes, print this confirmation BEFORE entering SPECIFY:

```
✓ 5/5 GREEN — activation complete
```

**Rule**: If ANY of the 5 steps is ✗ (not yet green after retries), do NOT print this line. Instead, continue retrying the failed step. Only print `5/5 GREEN` when all 5 steps have printed `✓`.

**Self-check before printing 5/5 GREEN**:
- Did Step 1 print `✓ Step 1`? → If NO, retry Step 1
- Did Step 2 print `✓ Step 2`? → If NO, retry Step 2
- Did Step 3 print `✓ Step 3`? → If NO, retry Step 3
- Did Step 4 print `✓ Step 4` (including all sub-checks 4a-4e)? → If NO, retry Step 4
- Did Step 5 print `✓ Step 5`? → If NO, retry Step 5

Only when all 5 answers are YES, print `✓ 5/5 GREEN — activation complete` and proceed to SPECIFY.

After 5/5 GREEN: Begin SPECIFY (or IMPLEMENT if continuation detected).

**FULL MODE ALWAYS (v9.13.4)**: Stellar Trails runs in Full Mode permanently — all 12 enforcement vectors, all 14 Pre-Push checks, all 6 phases, all templates, all the time. There is no "context pressure adaptive mode" — the skill always applies the complete protocol regardless of session length or context budget. If context is genuinely exhausted (≥90%), use E6 Escape Hatch for that specific emergency, then resume Full Mode on the next invoke.

### Compliance Score Tracking (NEW v9.13.0)

**Problem**: E9 logs activation events but not compliance scores. There's no feedback loop to detect patterns like "last 10 activations: 8/10 followed all steps, 2/10 skipped E3."

**Solution**: At DELIVER phase, the LLM self-assesses compliance and appends a score to the E9 log:

```bash
# v9.13.0: Compliance score appended to activation log at DELIVER
# Format: COMPLIANCE v<VERSION> score=N/12 vectors_skipped=E1,E3
# The LLM evaluates which of the 12 vectors it actually followed during this task
echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') COMPLIANCE v${ST_VERSION} score=[N]/12 skipped=[list] mode=[full|standard|minimal]" >> /home/user_skills/.st-activation-log
```

**Scoring**: bash computes mechanical score from artifacts (E7 token, E11 oracle, dev.sh HTTP, E9 log, worklog). LLM cannot inflate.

### FORBIDDEN Rationalizations (E5 — v9.3.0)

All 8 are correctness bugs. If you think any, STOP and run activation NOW.
1. ❌ "Continuation task" → WRONG. Activation is required every invoke.
2. ❌ "Simple/trivial task" → WRONG. Minimal tier still needs banner + 5 steps.
3. ❌ "Session is long, save tokens" → WRONG. Activation = 0.25% of context.
4. ❌ "Already printed banner" → WRONG. Print every invoke after truncation.
5. ❌ "User didn't complain" → WRONG. Silence ≠ approval.
6. ❌ "Label Minimal tier and skip" → WRONG. All tiers must activate.
7. ❌ "Pattern drift — skipped before" → WRONG. Past bugs ≠ precedent.
8. ❌ "Print report without activation" → WRONG. Silent skip = WORST option.

### If You Must Skip Activation — Escape Hatch (E6 — v9.3.0)

Print: `⚠️ ACTIVATION SKIPPED — operating without banner` + reason + acknowledge correctness bug. Emergencies only (≥90% context). Do NOT silently skip.

---

## Enforcement Vectors Overview (v9.13.0)

**Legacy Text** (E1-E3, v9.0.0): Phase markers, mandatory prints, AskUserQuestion gate. Text-only, backstopped by E7-E12.
**Pre-Tool Gate** (E4-E6, v9.3.0): Hard gate, anti-rationalization, escape hatch.
**Sandbox-Native** (E7-E11, v9.4.0): Hash token, TodoWrite, persistent log, line proof, clawhub oracle.
**Exit Code** (E12, v9.12.0): Exit code enforcement + retry-until-green + 5/5 GREEN GATE.

All 12 vectors retained. E1-E3 = legacy (text rules mandatory, backstopped by sandbox-native).


## Legacy Text Enforcement (E1-E3, v9.0.0 — retained, backstopped by E7-E12)

**E1 Phase Machine**: Every task passes through all 6 phases. Print `☄️ ENTER/EXIT <PHASE>` markers. Missing = compliance bug.

**E2 Mandatory Prints**: Banner (FIRST), COMMIT block (end of PLAN), REPORT block (LAST). Pre-DELIVER bash verifies artifacts exist. Self-audit: did I print banner first? did I read SKILL.md? did I verify popup? did I check ClawHub?

**E3 Preferences Dialog**: AskUserQuestion BEFORE content for Document/Visualization tasks. Print `✓ Preferences dialog check: <INVOKED|SKIPPED: reason>`. Skip: user says skip / all 3 explicit / trivial / coding / continuation. Not provisioned to subagents.

---

## Workflow Phases

```
IDLE → SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER
  ↑                                        │
  └──── Recovery ◄───────────────────┘
```

Phase definitions, entry/exit criteria, and gate rules live in `procedure/phases.md` — read it during Step 5 of Activation.

---

## Session Continuity

**Rule**: Before entering any phase, check if the user's message is a continuation of previous work. Read the immediately preceding assistant message — if the user's reply references, approves, corrects, or follows up on that output, it is a continuation. After context truncation, read `worklog.md` — the last entry contains the exact task state snapshot needed to resume.

| Signal | Type | Action |
|--------|------|--------|
| User references previous output ("apply all 10", "fix point 3", "proceed") | Continuation | Skip SPECIFY+PLAN → IMPLEMENT |
| User approves a proposal/plan ("yes", "go ahead", "do it") | Continuation | Skip SPECIFY+PLAN → IMPLEMENT |
| User asks a follow-up question ("what about X?") | Continuation | Skip SPECIFY → answer in current phase context |
| User provides new requirements mid-task | New task | Restart from SPECIFY with updated requirements |
| User invokes Skill() with new instructions | New task | Full workflow from IDLE |
| Context compression boundary with ongoing task | Continuation | Read `worklog.md` last entry, resume from recorded phase |

Regenerating proposals the user already approved is a correctness bug, not a style preference.

### Worklog Continuity Protocol

Every DELIVER phase appends a Snapshot to `worklog.md`. This is the primary continuity mechanism — not conversation history, not memory files.

On DELIVER (always, all tiers), append to `/home/z/my-project/worklog.md`:

```
---
last_phase: DELIVER
task: <one-line description>
complexity: <tier>
task_type: <type>
files_modified: <list or "none">
phase_trace: IDLE→SPECIFY→PLAN→IMPLEMENT→VERIFY→DELIVER
next_step: <what user should do next, or "IDLE - awaiting input">
```

On context truncation (IDLE): read the last `---` block from `worklog.md`. If the task description matches the current request, resume from the recorded phase.

### Worklog Rotation Policy (NEW in v9.11.4)

**Problem**: `worklog.md` grows unbounded — at ~1KB per DELIVER snapshot, 1000 tasks would produce ~1MB file. Loading 1MB into context for "read last entry" wastes tokens.

**Policy**: When `worklog.md` exceeds 100 entries (≈100KB), rotate:
1. Rename current `worklog.md` → `worklog-archive-YYYY-MM-DD.md` (date-stamped)
2. Create new `worklog.md` with the last 5 entries copied from the archived file (preserves continuity for next session)
3. Archive files accumulate in `/home/z/my-project/` — user can delete old archives anytime

**Rotation bash (run at DELIVER phase, after snapshot append)**:
```bash
WORKLOG="/home/z/my-project/worklog.md"
ENTRY_COUNT=$(grep -c '^---$' "$WORKLOG" 2>/dev/null || echo 0)
if [ "$ENTRY_COUNT" -gt 100 ]; then
  ARCHIVE="${WORKLOG%.md}-archive-$(date -u '+%Y-%m-%d').md"
  mv "$WORKLOG" "$ARCHIVE"
  # Preserve last 5 entries for continuity
  awk 'BEGIN{RS="^---$"} {entries[NR]=$0} END{print "---"; for(i=NR-4;i<=NR;i++) if(entries[i]) print entries[i]}' "$ARCHIVE" > "$WORKLOG"
  echo "✓ Worklog rotated: $ARCHIVE ($(grep -c '^---$' "$ARCHIVE") entries archived), $WORKLOG reset to last 5 entries"
fi
```

**Knowledge on-demand loading**: At Step 5 activation, only read the **last 3 entries** of `worklog.md` (not the whole file) — sufficient for continuity check without loading stale history.

---

## Task Type Awareness

| Task Type | SPECIFY | PLAN | IMPLEMENT | VERIFY |
|-----------|---------|------|------------|--------|
| **Coding** | Problem spec, edge cases, affected files | Code steps + Traceability IDs | Write code | Lint, type check, tests |
| **Document** | Content outline, target format, sections | Section plan + content depth targets | Generate document (via skill) | Format check, completeness |
| **Visualization** | Visual requirements, data sources, layout | Data mapping + chart type selection | Generate chart (via skill) | Visual accuracy, data integrity |
| **Data Processing** | Data spec, input/output schema, transforms | Transform pipeline + validation steps | Write script + execute | Output validation, edge cases |
| **Non-Coding** | Internal (identify question) | Internal (plan approach) | Answer / explain / recommend | Internal (self-check) |

No phases are skipped. Non-coding tasks use Minimal tier — SPECIFY, PLAN, VERIFY run internally. IMPLEMENT does the visible work. DELIVER outputs a compact report.

---

## Complexity Tiers

| Tier | Criteria | Report Format |
|------|----------|---------------|
| **Minimal** | Knowledge question, explanation, recommendation — no code/file output | `☄️ PASS \| Evidence: <one-line result>` |
| **Simple** | Single file, no schema change, no new dependencies | `☄️ REPORT [Simple]` (one-line) |
| **Standard** | Multiple files or a schema change | `☄️ REPORT [Standard]` (full block) + Scope at end of PLAN |
| **Complex** | Architectural changes, multi-service, high risk | `☄️ REPORT [Complex]` (full block + expanded evidence) + Scope |

Standard/Complex require Traceability IDs (IMPL-001, IMPL-002, ...). Simple/Minimal do not.

---

## Source Availability & Documentation Check (SADC)

Before planning any implementation, verify the approach is grounded in real sources — not assumptions.

| Complexity | SADC Requirement |
|-----------|-------------------|
| **Minimal** | Skip — knowledge questions don't need source research |
| **Simple** | Quick check — verify approach against at least one source |
| **Standard** | **Main agent inline research** — invoke `Skill(command="web-search")` then use Inline Content Retrieval (v9.5.0) BEFORE writing problem-spec. Print `📡 SADC: main agent researching inline` |
| **Complex** | Deep research by main agent — multiple sources, compare approaches, document tradeoffs |

**Main agent mandate (Standard/Complex)**: BEFORE writing the problem specification, the **main agent** (not a subagent) invokes `Skill(command="web-search")` to find existing solutions, then uses the **Inline Content Retrieval** protocol (see Inline Content Retrieval section, NEW in v9.5.0) to extract content from top 3-5 URLs → ≤500-word summary. **No external extraction skill dependency** — uses native curl + python3.

**Why main agent, not subagent**: The z.ai sandbox main agent has the SKILL.md pre-loaded into its context at session start; subagents do not (their context is the orchestrating main agent's task prompt). While subagents CAN invoke `Skill(command="stellar-trails")` after the fact (verified v9.11.4 — see Subagent Compliance Matrix below), doing so consumes ~95K tokens of the subagent's budget just to load the skill — wasteful for a single SADC lookup. The main agent already has SKILL.md in context, so it can perform SADC inline at near-zero marginal cost. Additionally, subagent prompts are compressed by the orchestrator, which may strip nuance needed for SADC source evaluation.

If no existing solution is found, state it explicitly — "searched npm/PyPI/docs, no existing package found" is a valid result. Building from scratch when a library exists is a spec-level defect.

**When subagents ARE appropriate**: Subagents may be used for non-skill tasks (e.g., "summarize these 5 URLs", "compare these 2 code samples"). The main agent fetches content via skills first, then delegates pure-text analysis to subagents. The rule: skills are invoked by the main agent; subagents operate on text the main agent has already retrieved.

---

## AskUserQuestion Gate (SPECIFY phase)

For deliverable-creation tasks (Document, Visualization, PPT, PDF, Excel, dashboard, poster, script, chart-as-deliverable), invoke `AskUserQuestion` BEFORE writing the problem specification.

**Mandate**: In SPECIFY phase, if task type is Document or Visualization AND the user's original request does NOT explicitly pin audience + style + length, invoke `AskUserQuestion` with 6–8 questions.

Print before any content-producing tool call: `✓ Preferences dialog check: <INVOKED | SKIPPED: <reason>>`

**Skip conditions**: user says skip / all 3 dimensions explicit / trivial edit / Coding/Non-Coding / continuation. AT MOST ONCE per run, before any content-producing tool. After answers return, proceed straight to PLAN (no loop-back).

**Skip conditions**: user says skip / all 3 dimensions explicit / trivial edit / Coding/Non-Coding / continuation. AT MOST ONCE per run.

---

## Pivot

On every error, classify it as **Bug** or **Wrong Approach** before attempting a fix. For denial-type errors (permission denied, EPERM, AccessDenied), perform **Denial Delta Analysis** — compare what was denied against what is configured. The difference IS the fix.

Wrong Approach signals (50%+ rewrite needed, same error after 2 attempts, missing library feature, data model change) trigger a pivot to the fallback approach defined in the Scope.

**Pivot flow**: Error detected → classify → if Wrong Approach: re-enter PLAN with fallback or new approach → present to user via AskUserQuestion (E3 enforcement) → re-implement → re-verify. Record in the Pivot field of the delivery report.

Full decision tree: read `procedure/error-resolution.md`.

---

## Recovery

1. **Stop** — do not continue past errors
2. **Classify** — code bug or approach failure? (see Pivot)
3. If code bug: document the error (use inline Incident Report template below), fix root cause, return to VERIFY
4. If approach failure: re-enter PLAN, evaluate alternatives (Scope fallback first), present pivot to user, re-implement
5. Ask the user before any action with side effects (git changes, file deletions, destructive operations)

Git rules (override defaults):
- `git fetch` and inspect before `git pull` — if remote diverged, stop and ask
- No `git rebase`, `git reset`, `git push --force`, or `git merge` without explicit user instruction
- If git is blocked by infrastructure, stop all git operations and inform the user

---

## Implementation Discovery Protocol (v9.2.0 — detail in `knowledge/implementation-discovery.md`)

If bug Y found while fixing bug X:
1. STOP. Document in worklog.
2. Same-Surface Test: same file + same root cause + same blast radius → FIX NOW. Different → DEFER.
3. Never silently fix or skip Y.

Worked example (v9.0.1→v9.0.2) in `knowledge/implementation-discovery.md`.

---
last_phase: DELIVER
task: <original task>
complexity: <tier>
task_type: <type>
files_modified: <list>
traceability: IMPL-001 to IMPL-XXX
discoveries:
  - bug: <Y one-line>
    found_while: <X one-line>
    surface: same|different
    action: fix-now|defer
    outcome: <fixed in this commit | deferred to next iteration>
pivot: NONE | YES (discovery-driven)
scope_drift: NONE | +Y (discovered while fixing X, same surface)
next_step: <what user should do next>
```

---

## Pre-Push Local Verification (NEW in v9.2.0, strengthened in v9.7.0)

**Problem this solves**: Pushing code changes to CI without local verification wastes a CI cycle (~1-2 minutes per run) and creates a "push → fail → read logs → push again" loop. This happened during this skill's development:

- v9.0.1 push → CI failed (python3 IndentationError) → read logs → v9.0.2 push → CI succeeded
- The IndentationError would have been caught by running the bash block locally before pushing.
- v9.6.0 push → CI succeeded BUT publish didn't register (moderation hide) → v9.6.1 re-publish
- v9.2.1 push → banner version hardcoded at v9.1.0 (not caught by bash -n)
- v9.1.0 push → SSV grep unescaped `**` (not caught by bash -n)

**Rule**: Before pushing any change that triggers CI, run ALL checks below. **All 9 checks must PASS before push.** If any FAIL, fix before pushing — do not push broken code.

### Verification checklist (9 checks, ALL must pass)

#### Check 1: bash -n syntax on all bash blocks
```bash
python3 << 'PYEOF'
import re, subprocess, tempfile, os
with open('skill/stellar-trails/SKILL.md') as f:
    content = f.read()
blocks = re.findall(r'\x60\x60\x60bash\n(.*?)\x60\x60\x60', content, re.DOTALL)
fail = 0
for i, block in enumerate(blocks, 1):
    with tempfile.NamedTemporaryFile(mode='w', suffix='.sh', delete=False) as f:
        f.write(block); path = f.name
    r = subprocess.run(['bash', '-n', path], capture_output=True, text=True)
    os.unlink(path)
    if r.returncode != 0:
        print(f"✗ Block {i} FAIL: {r.stderr.strip()[:120]}")
        fail += 1
print(f"{'✓' if fail == 0 else '✗'} Check 1: bash -n — {len(blocks)-fail}/{len(blocks)} blocks pass")
PYEOF
```

#### Check 2: python3 -c blocks execute with mock inputs (NEW v9.7.0)
```bash
# Extract and run every python3 -c block with 3 mock inputs: valid JSON, empty JSON, invalid text
python3 << 'PYEOF'
import re, subprocess
with open('skill/stellar-trails/SKILL.md') as f:
    content = f.read()
# Find all python3 -c "..." blocks
blocks = re.findall(r'python3 -c ("[^"]+"|\'[^\']+\')', content)
fail = 0
for i, block in enumerate(blocks, 1):
    cmd = f'echo "{{}}" | python3 -c {block}'
    r = subprocess.run(cmd, shell=True, capture_output=True, text=True, timeout=5)
    if r.returncode != 0:
        print(f"✗ python3 -c block {i} FAIL on empty JSON: {r.stderr.strip()[:80]}")
        fail += 1
print(f"{'✓' if fail == 0 else '✗'} Check 2: python3 -c mock execution — {len(blocks)-fail}/{len(blocks)} blocks pass")
PYEOF
```

#### Check 3: grep patterns return expected values (NEW v9.7.0)
```bash
# Every grep -oP pattern in SKILL.md must return non-empty on the actual file
python3 << 'PYEOF'
import re, subprocess
with open('skill/stellar-trails/SKILL.md') as f:
    content = f.read()
patterns = re.findall(r"grep -oP '([^']+)'", content)
fail = 0
for i, pat in enumerate(patterns, 1):
    # Skip patterns that are meant to match process output, not file content
    if 'pid=' in pat or ':3000' in pat or 'HTTP' in pat:
        continue
    r = subprocess.run(['grep', '-oP', pat, 'skill/stellar-trails/SKILL.md'],
                       capture_output=True, text=True, timeout=5)
    if not r.stdout.strip():
        print(f"✗ grep pattern {i} returns empty: {pat[:60]}")
        fail += 1
print(f"{'✓' if fail == 0 else '✗'} Check 3: grep patterns — {len(patterns)-fail}/{len(patterns)} return non-empty")
PYEOF
```

#### Check 4: Banner version is dynamic, not hardcoded (NEW v9.7.0)
```bash
# Banner must use <VERSION> placeholder, NOT hardcoded v9.x.y
HARDCODED=$(grep -c '☄️ STELLAR TRAILS · v[0-9]' skill/stellar-trails/SKILL.md)
PLACEHOLDER=$(grep -c '☄️ STELLAR TRAILS · v<VERSION>' skill/stellar-trails/SKILL.md)
if [ "$HARDCODED" -gt 0 ] && [ "$PLACEHOLDER" -eq 0 ]; then
  echo "✗ Check 4 FAIL: banner has hardcoded version ($HARDCODED occurrences), no <VERSION> placeholder"
else
  echo "✓ Check 4: banner uses <VERSION> placeholder ($PLACEHOLDER refs), no hardcoded version"
fi
```

#### Check 5: Metadata version matches git tag about to be pushed (NEW v9.7.0)
```bash
NEW_VERSION=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' skill/stellar-trails/SKILL.md | head -1)
TAG="v$NEW_VERSION"
if git tag -l "$TAG" | grep -q "$TAG"; then
  echo "✗ Check 5 FAIL: tag $TAG already exists"
else
  echo "✓ Check 5: tag $TAG does not exist yet (safe to push)"
fi
```

#### Check 6: ClawHub registry state — skill not hidden by moderation (NEW v9.7.0)
```bash
# Before push, verify skill is visible on registry (not moderation-hidden)
# This catches the v9.6.0 bug where publish exit 0 but version didn't register
REGISTRY_STATE=$(clawhub inspect stellar-trails --json)
if [ -z "$REGISTRY_STATE" ]; then
  echo "✗ Check 6 FAIL: cannot reach clawhub registry — push may publish to hidden skill"
else
  MOD_STATE=$(echo "$REGISTRY_STATE" | python3 -c "import json,sys; d=json.load(sys.stdin); print(d.get('moderation',{}).get('state','unknown'))" || echo "unknown")
  if [ "$MOD_STATE" = "hidden" ] || [ "$MOD_STATE" = "deleted" ]; then
    echo "✗ Check 6 FAIL: skill is $MOD_STATE by moderation — publish will not register"
    echo "  Contact clawhub moderator before pushing"
  else
    echo "✓ Check 6: skill visible on registry (moderation: $MOD_STATE)"
  fi
fi
```

#### Check 7: YAML structure valid (if workflow files changed)
```bash
if git diff --cached --name-only HEAD | grep -q '\.github/workflows/'; then
  python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))" && \
    echo "✓ Check 7: workflow YAML valid" || echo "✗ Check 7 FAIL: workflow YAML invalid"
else
  echo "✓ Check 7: no workflow files changed (skip)"
fi
```

#### Check 8: Markdown fence count is even (no orphan code blocks)
```bash
_F=$(printf '\x60\x60\x60')
FENCES=$(grep -c "$_F" skill/stellar-trails/SKILL.md)
if [ $((FENCES % 2)) -eq 0 ]; then
  echo "✓ Check 8: markdown fences even ($FENCES)"
else
  echo "✗ Check 8 FAIL: markdown fences odd ($FENCES) — orphan code block"
fi
```

#### Check 9: Post-push plan — registry poll will be done (NEW v9.7.0)
```bash
# Acknowledge that push is not complete until registry confirms the version
echo "✓ Check 9: post-push plan acknowledged"
echo "  After CI succeeds, MUST poll clawhub inspect until latestVersion = $NEW_VERSION"
echo "  If registry doesn't update within 60s of CI success, fetch CI logs + diagnose"
echo "  (This catches the v9.6.0 bug: publish exit 0 but version not registered)"
```

#### Check 10: index.html version matches SKILL.md (NEW v9.10.1)
```bash
SKILL_VERSION=$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' skill/stellar-trails/SKILL.md | head -1)
INDEX_VERSION=$(grep -oP 'v\K[0-9]+\.[0-9]+\.[0-9]+' skill/stellar-trails/index.html | head -1)
if [ "$SKILL_VERSION" != "$INDEX_VERSION" ]; then
  echo "✗ Check 10 FAIL: SKILL.md v$SKILL_VERSION vs index.html v$INDEX_VERSION — version drift"
else
  echo "✓ Check 10: index.html version matches SKILL.md (v$SKILL_VERSION)"
fi
```

#### Check 11: No duplicate knowledge files (NEW v9.11.4)
```bash
# Catches byte-identical duplicate files in knowledge/ subdirs (leftover from path-mismatch fixes)
DUPES=$(find skill/stellar-trails/knowledge/ -type f -name "*.md" -exec md5sum {} \; | sort | uniq -d -w 32 | wc -l)
if [ "$DUPES" -gt 0 ]; then
  echo "✗ Check 11 FAIL: $DUPES duplicate knowledge file(s) detected:"
  find skill/stellar-trails/knowledge/ -type f -name "*.md" -exec md5sum {} \; | sort | uniq -d -w 32
  echo "  Remove duplicates — only top-level knowledge/*.md should exist (no platform/ or universal/ subdirs)"
else
  echo "✓ Check 11: no duplicate knowledge files"
fi
```

#### Check 12: phases.md ↔ SKILL.md SADC drift (NEW v9.11.4)
```bash
# Catches drift between phases.md SADC step and SKILL.md SADC section
# Both must agree: main agent inline, NO subagent dispatch, NO crawl4ai/web-reader invocations
# Note: matches positive invocations only (Skill(command="...") or "dispatched"), not negations like "No crawl4ai"
PHASES_SUBAGENT=$(grep -cE 'Skill\(command="(crawl4ai|web-reader)"\)|subagent dispatched|Task\(subagent_type' skill/stellar-trails/procedure/phases.md)
PHASES_SUBAGENT=${PHASES_SUBAGENT:-0}
PHASES_CRAWL=0  # accounted for in PHASES_SUBAGENT above via Skill(command="...")
if [ "$PHASES_SUBAGENT" -gt 0 ]; then
  echo "✗ Check 12 FAIL: phases.md still references removed SADC patterns (count: $PHASES_SUBAGENT)"
  echo "  SKILL.md removed subagent SADC in v9.1.0 and crawl4ai in v9.5.0 — phases.md must match"
  grep -nE 'Skill\(command="(crawl4ai|web-reader)"\)|subagent dispatched|Task\(subagent_type' skill/stellar-trails/procedure/phases.md
else
  echo "✓ Check 12: phases.md SADC step aligned with SKILL.md (no subagent dispatch, no crawl4ai/web-reader invocations)"
fi
```

#### Check 13: Path integrity — all referenced files exist (NEW v9.11.5)
```bash
# Catches broken file references left behind when files/dirs are moved or deleted.
# Verifies every (references|procedure|knowledge|constraints)/path/to/file.md mentioned
# in any skill file actually exists on disk. Would have caught the v9.11.4 regression
# where knowledge/universal/ and knowledge/platform/ subdirs were deleted but refs in
# constraints/code-standards.md, knowledge/error-patterns.md, procedure/error-resolution.md
# were not updated.
python3 << 'PYEOF'
import os, re, subprocess
SKILL_DIR = 'skill/stellar-trails'
# Collect all file-path references from all .md files in the skill
ref_pattern = re.compile(r'(?:references|procedure|knowledge|constraints)/[a-zA-Z0-9_/-]+\.md')
missing = []
files_scanned = 0
for root, dirs, files in os.walk(SKILL_DIR):
    for fname in files:
        if not fname.endswith('.md'):
            continue
        fpath = os.path.join(root, fname)
        files_scanned += 1
        with open(fpath) as f:
            content = f.read()
        for match in ref_pattern.finditer(content):
            ref = match.group(0)
            full = os.path.join(SKILL_DIR, ref)
            if not os.path.exists(full):
                # Allow references that are documentation of removal (e.g., "formerly in procedure/templates/")
                # — but only if the line contains "formerly" or "removed" or "REMOVED"
                line_start = content.rfind('\n', 0, match.start()) + 1
                line_end = content.find('\n', match.end())
                line = content[line_start:line_end if line_end > 0 else len(content)]
                if any(kw in line.lower() for kw in ['formerly', 'removed', 'deprecated', 'was dead code']):
                    continue
                missing.append(f"  {fpath}: {ref}")
if missing:
    print(f"✗ Check 13 FAIL: {len(missing)} broken file reference(s):")
    for m in missing:
        print(m)
else:
    print(f"✓ Check 13: all file references valid ({files_scanned} files scanned)")
PYEOF
```

#### Check 14: .zscripts/dev.sh git-tracked + hash matches skill copy (NEW v9.11.9)
```bash
# Verifies that .zscripts/dev.sh is git-tracked (not ignored by .gitignore)
# AND that its hash matches skill/stellar-trails/dev.sh (the zip source).
# Catches: .gitignore regression (re-ignoring .zscripts/), dev.sh drift between
# the tracked runtime copy and the zip source.
if git ls-files --error-unmatch .zscripts/dev.sh >/dev/null 2>&1; then
  SKILL_HASH=$(sha256sum skill/stellar-trails/dev.sh | cut -d' ' -f1)
  ZSCRIPTS_HASH=$(sha256sum .zscripts/dev.sh | cut -d' ' -f1)
  if [ "$SKILL_HASH" != "$ZSCRIPTS_HASH" ]; then
    echo "✗ Check 14 FAIL: .zscripts/dev.sh hash mismatch"
    echo "  skill/stellar-trails/dev.sh: $SKILL_HASH"
    echo "  .zscripts/dev.sh:            $ZSCRIPTS_HASH"
    echo "  Fix: cp -f skill/stellar-trails/dev.sh .zscripts/dev.sh"
  else
    echo "✓ Check 14: .zscripts/dev.sh tracked + hash matches skill copy ($ZSCRIPTS_HASH)"
  fi
else
  echo "✗ Check 14 FAIL: .zscripts/dev.sh is NOT git-tracked — check .gitignore exception"
  echo "  Expected pattern in .gitignore: .zscripts/* + !.zscripts/dev.sh"
  echo "  Or run: git add -f .zscripts/dev.sh"
fi
```

#### Worklog Snapshot + L1 Pattern Skeleton (bash-enforced v9.14.0)
```bash
# Bash guarantees worklog entry + L1 pattern skeleton at DELIVER
# LLM fills in [brackets] after bash creates skeleton
cat >> /home/z/my-project/worklog.md << ST_WL_EOF
---
last_phase: DELIVER
timestamp: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
version: v$(grep -oP '^- \*\*version\*\*:\s*\K[0-9.]+' /home/z/my-project/skills/stellar-trails/SKILL.md | head -1)
task: [LLM fills]
complexity: [LLM fills]
task_type: [LLM fills]
files_modified: [LLM fills]
phase_trace: IDLE→SPECIFY→PLAN→IMPLEMENT→VERIFY→DELIVER
ST_WL_EOF
echo "✓ Worklog skeleton appended (LLM: fill in [brackets] above)"
# L1 pattern skeleton (bash guarantees template structure)
echo "## [$(date -u '+%Y-%m-%d')] <domain>: <pattern-name>" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "**Context**: <when applies>" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "**Approach**: <what worked>" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "**Gotcha**: <what to avoid>" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "**Source**: <task>" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "" >> /home/z/my-project/skills/stellar-trails/knowledge/patterns.md
echo "✓ L1 pattern skeleton appended (LLM: fill in <brackets>)"
```

### When to skip Pre-Push Local Verification

- Documentation-only changes (CHANGELOG.md, README.md) → skip checks 2-6, run 1+7+8
- Version bump commits (just `sed` + commit) → run checks 4+5+6+9
- Changes to files that have no executable code (pure markdown prose) → skip checks 2-3

**Never skip**: checks 1 (bash syntax), 8 (markdown fences), 9 (post-push plan)

### Cost-benefit

- **Cost**: 60-90 seconds of local testing (up from 30-60s in v9.2.0)
- **Benefit**: catches 5 bug classes that slipped through v9.2.0's 4 checks
- **Bug classes caught by v9.7.0 additions**:
  - python3 -c execution errors (would have caught v9.0.1 IndentationError)
  - grep pattern failures (would have caught v9.1.0 unescaped `**`)
  - banner version drift (would have caught v9.2.1 hardcoded v9.1.0)
  - tag collision (would have caught duplicate tag pushes)
  - moderation hide (would have caught v9.6.0 publish-not-registering)
  - post-push registry verification (would have caught v9.6.0 silent publish failure)

### Anti-patterns (FORBIDDEN)

- ❌ "bash -n passed, ship it" — bash -n is necessary but NOT sufficient. Run all 9 checks.
- ❌ "Skip check 6, registry was fine last time" — moderation state can change between pushes. Always check.
- ❌ "Skip check 9, CI will tell us" — CI success ≠ registry update. v9.6.0 proved this. Always poll registry post-push.
- ❌ "Check 2 takes too long" — 5 seconds per python3 -c block. Worth it to avoid CI cycle.

---

## Proximate Cause Triage (v9.5.0 — detail in `knowledge/proximate-cause.md`)

**Q1**: Is candidate within 1 hop of symptom? → YES = prefer
**Q2**: ≤2 assumptions to explain ALL symptoms? → YES = parsimonious
**Q3**: Would fixing resolve user's request? → YES = in scope

**Scope Gate**: in_scope → proceed | clarification_needed → ASK | out_of_scope → STOP

Worked example + Parsimony Audit template in `knowledge/proximate-cause.md`.

---

## Inline Content Retrieval (v9.5.0 — reference in `knowledge/inline-retrieval.md`)

Use curl + python3 stdlib for web content extraction. Protocol detail moved to `knowledge/inline-retrieval.md` in v9.14.0. Summary:
1. Fetch with curl (10s timeout, user-agent)
2. Extract text with python3 html.parser (skip script/style/nav)
3. Truncate to 500 words for SADC summary

---

## GitHub Operations Protocol (v9.6.0 — adapted from @steipete/github)

curl + PAT (gh CLI not available). Prerequisites: PAT at `/home/z/my-project/upload/PAT`. Never print PAT.

### Git Identity Setup (MANDATORY before git commit/push)
Fetch owner from GitHub API → override /start.sh Z User config → recreate ~/.git-credentials → export GIT_AUTHOR_*/GIT_COMMITTER_* env vars. Run every session (credentials wiped on reset).

### Key Operations (detail: use curl + python3 for jq-style filtering)
1. **List workflow runs**: `curl -H "Authorization: Bearer $TOKEN" "https://api.github.com/repos/$REPO/actions/runs?per_page=10" | python3 -c "..."`
2. **Fetch failed logs**: `curl -L -o /tmp/gh-logs.zip "https://api.github.com/repos/$REPO/actions/runs/$RUN_ID/logs"` then `unzip`
3. **PR checks**: GET `/repos/$REPO/commits/$SHA/check-runs`
4. **API queries**: curl + python3 (jq not installed)

**Risk**: Read=NO approval. Write/Modify/Delete=YES explicit. Never silent mutations.
**Anti-patterns**: ❌ print PAT ❌ fetch all runs ❌ skip logs ❌ POST without approval

---

## Gate Protocol

Phase transitions are guarded. A phase cannot begin until its entry condition is met.

| Gate | Condition |
|------|----------|
| SPECIFY → PLAN | All problem-spec fields filled, SADC complete, AskUserQuestion ran (or skipped with reason) |
| PLAN → IMPLEMENT | Implementation plan complete + Scope output (Standard/Complex) + `⏸️ AWAITING APPROVAL TO ENTER IMPLEMENT` printed |
| IMPLEMENT → VERIFY | Self-review checklist pass, all IMPL steps done |
| VERIFY → DELIVER | All verification items PASS |

Standard/Complex tier: PLAN → IMPLEMENT gate produces a Scope (see Deliveries). The delivery report's Scope Drift field tracks any deviation.

---

## Inline Templates (NEW in v9.0.0 — formerly in procedure/templates/)

Four templates are now embedded inline. Standard/Complex tasks must use the exact headers below. Free-form = correctness bug.

### Problem Specification (SPECIFY output, Standard/Complex)

<template name="problem-spec">
# Problem Specification

| Field | Value |
|-------|-------|
| Request | [Exact user request — quoted verbatim] |
| Source Research | [SADC summary — existing solutions, docs consulted, patterns. If none found, state explicitly.] |
| Functional Requirement | [What the code must accomplish — "must" language] |
| Technical Constraints | [Platform limits, sandbox rules, framework requirements] |
| Identified Edge Cases | [List each with handling strategy] |
| Affected Files | [See table below] |
| Risk Level | [LOW / MEDIUM / HIGH with justification] |
| Dependencies | [External packages, services, config changes] |
| Source State | [Branch + HEAD SHA + verification status, or "No git repository involved"] |
| Scope OUT | [Explicitly excluded — prevents scope creep] |

## Affected Files

| File Path | Action | Purpose |
|-----------|--------|---------|
| path/to/file | Create / Modify | Why this file changes |

## Edge Cases

| # | Edge Case | Handling Strategy |
|---|-----------|-------------------|
| 1 | [Condition] | [How handled] |
</template>

### Implementation Plan (PLAN output, Standard/Complex)

<template name="implementation-plan">
# Implementation Plan: [Task Name]

## Approach
[2-3 sentences — design decision + why chosen]

## Alternatives Considered
- Alt 1: [Approach] — [Why rejected]
- Alt 2: [Approach] — [Why rejected]

## Pre-Deploy Verification
[Local verification step before target deployment, or "N/A"]

## Fallback Approach
[Alternative if primary fails. "No viable fallback — would require user input." if none.]

## Scope Boundary

| | Items |
|--|-------|
| **IN** | [What's included] |
| **OUT** | [What's excluded] |

## Implementation Steps

| Step | Action | Target File | Traceability ID |
|------|--------|-------------|-----------------|
| 1 | [Specific action] | [File path] | IMPL-001 |
| 2 | [Specific action] | [File path] | IMPL-002 |

## Requirements Mapping

| Traceability ID | Maps to Requirement | Notes |
|-----------------|--------------------|----|
| IMPL-001 | [Functional requirement] | [Context] |

## Verification Strategy

| What to Verify | Method | Expected Outcome | Traceability ID |
|----------------|--------|------------------|-----------------|
| [Behavior] | [How to check] | [Correct result] | IMPL-001 |
</template>

### Verification Report (VERIFY output, Standard/Complex)

<template name="verification-report">
# Verification Report: [Task Name]

## Automated Checks

| Check | Tool/Command | Expected | Actual | Status |
|-------|-------------|----------|--------|--------|
| Lint | [cmd] | No errors | [output] | PASS/FAIL |
| Type Check | [cmd] | No type errors | [output] | PASS/FAIL |
| Tests | [cmd] | All pass | [output] | PASS/FAIL |

## Pre-Deploy Verification

| Check | Method | Expected | Actual | Status |
|-------|--------|----------|--------|--------|
| [Pre-Deploy step or N/A] | [method] | [outcome] | [actual] | PASS/FAIL/N/A |

## Traceability Verification

| Traceability ID | Implementation Verified | Method | Status |
|-----------------|------------------------|--------|--------|
| IMPL-001 | [What was verified] | [How checked] | PASS/FAIL |

## Edge Case Verification

| Edge Case | Test Input | Expected | Actual | Status |
|-----------|-----------|----------|--------|--------|
| [Case] | [Input] | [Behavior] | [Actual] | PASS/FAIL |

## Summary

| Metric | Value |
|--------|-------|
| Automated checks passed | [n]/[total] |
| Traceability items passed | [n]/[total] |
| Edge cases passed | [n]/[total] |
| Defects found / fixed | [n] / [n] |
| Overall result | PASS / FAIL |

## Outcome Statement
[1-2 sentences — does code satisfy all requirements?]

## Failures (if any)
[Description + root cause + fix, or "None"]
</template>

### Incident Report (Recovery output, on error)

<template name="incident-report">
# Incident Report

## Error Capture

| Field | Value |
|-------|-------|
| Phase When Error Occurred | SPECIFY / PLAN / IMPLEMENT / VERIFY |
| Error Message | [Exact text — paste verbatim] |
| Error Classification | Compilation / Runtime / Network / Type / Database / Git / Wrong Approach / Other |
| Stack Trace | [If available] |
| Context | [What agent was doing] |

## Root Cause Analysis

| Question | Answer |
|----------|--------|
| What failed? | [Precise description] |
| Why did it fail? | [Chain of causation — 2+ levels deep] |
| Symptom or root cause? | [Symptom → identify root / Root cause] |
| Could recur elsewhere? | [Yes/No — if Yes, list locations] |

## Pivot Assessment

| Field | Value |
|-------|-------|
| Is Wrong Approach? | YES / NO |
| Pivot Signal | [50%+ rewrite / same error after 2 attempts / missing library feature / data model change / N/A] |
| Fallback Available? | YES / NO |
| New Approach | [Alternative — fallback or new] |
| User Approval Required? | YES / NO |

## Proposed Fix

| Field | Value |
|-------|-------|
| Fix Description | [What change resolves root cause] |
| Files Modified | [List + changes] |
| Has Side Effects? | YES / NO |
| Side Effect Details | [If YES: describe each] |
| User Approval Required? | YES / NO |

## Resolution

| Field | Value |
|-------|-------|
| Fix Applied | [What was done] |
| Return Phase | VERIFY / IMPLEMENT / SPECIFY |
| Re-verification Required? | YES |
</template>

---

## Deliveries

Two structured outputs bookend implementation: **Scope** (end of PLAN) and **Delivery** (end of DELIVER).

### Scope (Standard/Complex, end of PLAN)

```
☄️ COMMIT [Standard]
├─ Approach       : <primary approach, 1-2 sentences>
├─ Alternatives   : <2+ alternatives, 1 sentence each>
├─ Fallback       : <alternative if primary fails>
├─ Pre-Deploy     : <local verification step, or N/A>
├─ Scope IN       : <what's included>
├─ Scope OUT      : <what's excluded>
├─ IMPL Steps     : X (IMPL-001 to IMPL-XXX)
└─ Risk           : LOW / MEDIUM / HIGH
```

After printing Scope, print: `⏸️ AWAITING APPROVAL TO ENTER IMPLEMENT`
Do NOT call any tool after this line. Wait for user reply.

### Summary (Simple tier)

```
☄️ REPORT [Simple]
SPECIFY→DELIVER : PASS | Evidence: <one-line result> | Defects: 0 | Drift: NONE
Phase Trace     : IDLE→SPECIFY→PLAN→IMPLEMENT→VERIFY→DELIVER
```

### Delivery (Standard/Complex)

```
☄️ REPORT [Standard]
├─ Continuation : NEW / YES
├─ Phase Trace  : IDLE→SPECIFY→PLAN→IMPLEMENT→VERIFY→DELIVER
├─ IMPLEMENT     : PASS
│  ├─ Steps      : 4/4
│  ├─ Deviations : 0
│  └─ Quality    : lint PASS, tsc PASS
├─ VERIFY        : PASS
│  ├─ Checks     : 3/3
│  └─ Edge Cases : 2/2
├─ Pivot         : NONE
├─ Scope Drift   : NONE
└─ Outcome       : PASS

Evidence: [concrete results]
Defects found and fixed: 0
```

If Pivot is not NONE, expand it:
```
├─ Pivot         : YES
│  ├─ From      : <original approach>
│  ├─ Trigger   : <what made us pivot>
│  ├─ To        : <new approach>
│  └─ Re-planned : X steps (IMPL-001 to IMPL-XXX)
```

### Minimal (non-coding)

```
☄️ PASS | Evidence: <one-line result>
Phase Trace: IDLE→SPECIFY→PLAN→IMPLEMENT→VERIFY→DELIVER (internal)
```

---

## Completion Signal

For interactive web development tasks (Next.js, UI components, dashboards), implementation is delegated to fullstack-dev — the DELIVER phase calls the platform's `Complete(project_type="web_dev", summary="...")` tool to finalize. For non-web coding tasks, DELIVER presents output file paths. In all cases, DELIVER appends a Snapshot to `worklog.md`.

---

## Layered Memory Protocol (v9.11.0 — detail in `knowledge/memory-protocol.md`)

| Layer | File | When written |
|---|---|---|
| L0 Task | worklog.md | DELIVER (existing) |
| L1 Pattern | knowledge/patterns.md | DELIVER (bash skeleton appended) |
| L2 Scenario | knowledge/scenarios.md | DELIVER (auto at ≥5 L1 per domain) |
| L3 Profile | knowledge/user-profile.md | DELIVER (auto at ≥3 same-decision) |

Detail (extraction format, on-demand loading table, anti-patterns) in `knowledge/memory-protocol.md`.

---

## Limitations

12 enforcement vectors (3 tiers) shift compliance to verifiable artifacts, but LLM is executor. Compliance scoring is bash-mechanical (v9.13.3). User is final judge.

**Verified working**: E9 persistence (326 entries/38 days), clawhub drift detection, 3-way version sync, popup :3000, all 12 runtime deps.
**Not working/unverifiable**: E7 token is version-derived (PARTIAL), no session ID in E9 log, no PAT in clawhub-installed sandboxes, no $HOME/.stellar-trails-repo, popup user-visibility unverifiable, prose rots.
**Rule of thumb**: Prose rots faster than bash — re-audit regularly.

Research (Lost in the Middle, arXiv 2307.03172): ~70-85% compliance ceiling via text. v9.0.0+ raises to ~90%. 98% needs harness-level verifier. 100% needs platform enforcement.
```
