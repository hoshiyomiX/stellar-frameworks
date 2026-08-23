<div align="center">

<img src="skill/stellar-trails/chibi.svg" alt="Stellar Trails mascot" width="180">

# Stellar Trails

**A structured six-phase workflow framework for LLM agents on the z.ai platform.**

Traceability IDs · Entry/Exit Gates · Scope Commitment · Adaptive Complexity · 5 Sandbox-Native Enforcement Vectors · Layered Memory Protocol

[![Version](https://img.shields.io/badge/version-9.13.3-blue.svg)](https://github.com/hoshiyomiX/stellar-trails/releases)
[![License](https://img.shields.io/badge/license-MIT--0-green.svg)](LICENSE)
[![ClawHub](https://img.shields.io/badge/clawhub-stellar--trails-orange.svg)](https://clawhub.ai/hoshiyomix/stellar-trails)

</div>

---

## ✨ What It Does

Stellar Trails enforces a disciplined six-phase workflow on every task — coding, document creation, data processing, audit/diagnosis, or even simple questions. The framework wraps around the LLM's natural reasoning to produce verifiable artifacts instead of trusting the LLM to "remember" to follow a process.

```
IDLE → SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER
  ↑                                        │
  └──── Recovery ◄───────────────────┘
```

| Feature | Description |
|---------|-------------|
| **Six-Phase Workflow** | Every task passes through IDLE → SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER — no phase skipping |
| **Traceability IDs** | IMPL-001, IMPL-002... chain through every phase — gaps are visible |
| **Adaptive Complexity** | Minimal / Simple / Standard / Complex tiers — ceremony scales, phases don't skip |
| **5 Enforcement Vectors (E7–E11)** | Hash token gate, TodoWrite live marker, persistent activation log, line-number proof, clawhub oracle cross-check |
| **Pre-Push Verification (13 checks)** | bash -n, python3 mock, grep patterns, banner version, tag collision, moderation state, markdown fences, index.html version match, no duplicate knowledge files, SADC drift, path integrity |
| **Layered Memory Protocol (L0–L3)** | Worklog (L0) + patterns (L1) + scenarios (L2) + user-profile (L3) — adapted from TencentDB-Agent-Memory |
| **Proximate Cause Triage** | Orisinil decision tree to prevent GLM-5.2's tendency to rabbit-hole into deep causal chains |
| **Inline Content Retrieval** | curl + python3 stdlib — no external crawl4ai dependency |
| **Auto Git Identity Setup** | Detects PAT, fetches GitHub identity, configures git config + credentials + env vars |
| **Pure Markdown by Design** | No shell execution in Skill() invoke — pure markdown data that the LLM reads and follows |

---

## 🚀 Quick Start

### Path A — ZAI Platform (recommended)

```bash
curl -sL https://github.com/hoshiyomiX/stellar-trails/releases/latest/download/stellar-trails.zip -o /home/user_skills/stellar-trails.zip && touch /home/user_skills/.stellar-trails.usermark && echo "✓ installed"
```

Next session: ZAI service auto-extracts zip to `/home/z/my-project/skills/stellar-trails/`. Invoke via:

```
Skill(command="stellar-trails")
```

### Path B — Standalone (non-ZAI)

```bash
curl -sL https://github.com/hoshiyomiX/stellar-trails/releases/latest/download/stellar-trails.zip -o /tmp/st.zip && unzip -q /tmp/st.zip -d /tmp/ && cp -a /tmp/skill/stellar-trails /home/z/my-project/skills/ && mkdir -p /home/z/my-project/.zscripts && cp /home/z/my-project/skills/stellar-trails/{chibi.svg,index.html,dev.sh} /home/z/my-project/.zscripts/ && chmod +x /home/z/my-project/.zscripts/dev.sh && rm -rf /tmp/skill /tmp/st.zip && echo "✓ installed"
```

For popup preview: `bash /home/z/my-project/.zscripts/dev.sh` (serves :3000 with no-cache headers).

### Path C — ClawHub

```bash
clawhub install stellar-trails
```

---

## 📦 What's Inside

```
stellar-trails/                          (repo root)
├── .github/workflows/release.yml        # CI/CD: build zip + publish to ClawHub on tag push
├── .checksums                           # SHA-256 verification manifest
├── .githooks/pre-commit                 # Prevents commits on diverged branch
├── .gitattributes + .gitignore          # Line-ending + ignore rules
├── CHANGELOG.md                         # Full version history (v4.4.2 → v9.11.7)
├── README.md                            # This file
└── skill/stellar-trails/                # Git-tracked source of truth
    ├── SKILL.md                          # Skill definition (activation + framework reference)
    ├── dev.sh                            # Standalone no-cache HTTP server (popup preview)
    ├── index.html                        # Landing page (minimalist, v9.5.0+)
    ├── chibi.svg                         # Mascot (SVG, passes ClawHub text-file filter)
    ├── skill-card.md                     # ClawHub skill card metadata
    ├── watermark.md                      # Popup preview customization guide
    ├── procedure/
    │   ├── phases.md                     # 6-phase workflow definitions + gates
    │   └── error-resolution.md           # Error decision tree + pivot assessment
    ├── knowledge/                        # Layered Memory Protocol (L1–L3) + platform knowledge
    │   ├── patterns.md                   # L1: reusable patterns from past tasks
    │   ├── scenarios.md                  # L2: grouped patterns by domain
    │   ├── user-profile.md               # L3: stable user preferences
    │   ├── zai-sandbox.md                # Platform constraints + sandbox quirks
    │   ├── architecture.md               # Runtime environment + directory layout
    │   ├── conventions.md                # Universal coding conventions
    │   └── error-patterns.md             # Common error patterns + fixes
    ├── constraints/                     # Prescriptive coding standards
    │   ├── code-standards.md             # Function standards, naming, max 50 lines/function
    │   └── type-safety.md                 # TypeScript strict-mode rules
    ├── evals/
    │   └── evals.json                   # Programmatic eval assertions for transcript checking
    └── references/
        └── askuserquestion-gate.md      # Full 6-8 question template + skip conditions
```

---

## 🏗️ Architecture

### Activation Sequence (5 steps, every invoke)

```
Step 1  Refresh context + SSV              # Read SKILL.md, write E7 hash token
Step 2  Start popup server                  # E7 gate check, copy dev.sh + index.html to .zscripts/
Step 3  Auto-update via ClawHub            # E11 oracle, force update if drift detected
Step 4  Verify files + restart dev.sh      # E11 cross-check, kill stale supervisor, sync zip
Step 5  Load phases + classify              # E9 persistent log, determine tier + type + continuity
```

### Enforcement Vectors (E7–E11)

| Vector | What it enforces | LLM can fake? |
|--------|-------------------|---------------|
| **E7** Hash Token Gate | Steps 2–5 cannot run without Step 1 | NO — token requires actual file read |
| **E8** TodoWrite Live Marker | Steps visible in real-time UI | Partially — transitions are visible |
| **E9** Persistent Activation Log | Cross-session audit trail | Partially — timestamps must be monotonic |
| **E10** Line-Number Proof | Step 1 actually called Read | Partially — LLM knows line 19 |
| **E11** Clawhub Oracle | Step 3 actually ran clawhub | NO — external binary output is ground truth |

### Pre-Push Local Verification (13 checks)

| # | Check | Catches |
|---|-------|---------|
| 1 | bash -n on all blocks | Syntax errors in bash code |
| 2 | python3 -c mock execution | IndentationError, NameError in embedded python |
| 3 | grep patterns return non-empty | Broken regex patterns |
| 4 | Banner version dynamic | Hardcoded version in banner |
| 5 | Tag does not exist | Duplicate tag pushes |
| 6 | ClawHub moderation state | Publish to hidden skill |
| 7 | YAML structure valid | Workflow syntax errors |
| 8 | Markdown fences even | Orphan code blocks |
| 9 | Post-push registry poll plan | Silent publish failures |
| 10 | index.html version matches SKILL.md | Version drift between files |
| 11 | No duplicate knowledge files | Stray subdirs from path-mismatch fixes |
| 12 | phases.md ↔ SKILL.md SADC drift | Protocol drift between files |
| 13 | Path integrity (all refs exist) | Broken cross-file references |

---

## 💾 Persistence Model (ZAI Platform)

| Layer | Mechanism | Survives reset? |
|-------|-----------|-----------------|
| `/home/user_skills/stellar-trails.zip` | Persistent mount | ✓ |
| `/home/user_skills/.stellar-trails.usermark` | "Skill approved" marker | ✓ |
| `/home/user_skills/.st-activation-log` | E9 persistent activation log | ✓ (world-writable — best-effort audit) |
| ZAI service auto-extract | Extracts zip to `skills/stellar-trails/` at session start | ✓ (re-extracted every session) |
| `/home/z/my-project/skills/stellar-trails/` | Working copy (from zip) | ✓ (re-extracted) |
| `/home/z/my-project/.zscripts/` | Popup server assets (dev.sh + index.html + chibi.svg) | ✓ (force-overridden in Step 4) |
| `/tmp/st-active` | E7 hash token (session-scoped) | ✗ (wiped on reset) |
| `/tmp/st-clawhub-oracle.json` | E11 oracle cache | ✗ (wiped on reset) |

---

## 📋 Version History (recent)

| Version | Date | Summary |
|---------|------|---------|
| **9.11.7** | 2026-08-12 | Bug 4 fix: kill orphaned python3 listener after supervisor kill in Step 4c |
| **9.11.6** | 2026-08-09 | Fix 3 dev.sh bugs from cross-sandbox diagnosis (PID collision, EXIT trap, Step 4 kill target) |
| **9.11.5** | 2026-08-09 | Fix 11 re-audit findings + add Pre-Push Check 13 (path integrity) |
| **9.11.4** | 2026-08-09 | Implement 16 audit findings (4 P0 + 5 P1 + 4 P2 + 3 P3) + Check 11/12 |
| **9.11.3** | 2026-08-07 | Remove all `2>/dev/null` — errors visible, skill must report abnormalities |
| **9.11.2** | 2026-08-06 | Step 3 silent update failure fix — removed `2>/dev/null`, added POST_VERSION verification |
| **9.11.1** | 2026-08-06 | Layered Memory Protocol (L0–L3) adapted from TencentDB-Agent-Memory |
| **9.11.0** | 2026-08-06 | scenarios.md created (L2 placeholder for LMP) |
| **9.10.4** | 2026-08-06 | Emoji 📍 → ☄️ for phase markers |
| **9.10.1** | 2026-08-06 | Auto Git Identity Setup in Step 1 + index.html version match Check 10 |
| **9.10.0** | 2026-08-06 | dev.sh v9.0.0 — improved from v7.2.2, reject v8.0.0 bugs |
| **9.5.0** | 2026-08-04 | Proximate Cause Triage + Inline Content Retrieval (orsinil features) |
| **9.0.0** | 2026-07-26 | Three enforcement layers (E1–E3) + inline templates |
| **8.0.0** | 2026-06-27 | Major restructure: 9 steps → 5, no silent failures |

See [CHANGELOG.md](CHANGELOG.md) for full history (v4.4.2 → v9.11.7).

---

## 🔗 Links

- **ClawHub**: https://clawhub.ai/hoshiyomix/stellar-trails
- **GitHub**: https://github.com/hoshiyomiX/stellar-trails
- **Releases**: https://github.com/hoshiyomiX/stellar-trails/releases
- **Issues**: https://github.com/hoshiyomiX/stellar-trails/issues
- **Changelog**: [CHANGELOG.md](CHANGELOG.md)

---

## 📄 License

MIT-0 (Free to use, modify, and redistribute. No attribution required.)

---

<div align="center">

<sub>Built with ☄️ Stellar Trails — six-phase workflow framework for LLM agents</sub>

</div>
