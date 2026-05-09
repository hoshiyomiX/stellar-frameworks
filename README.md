<div align="center">

# ☄️ stellar-coding-agent

**Deterministic coding workflow for LLM agents**

[![Version](https://img.shields.io/badge/version-5.2.0-blue.svg)](skill/stellar-coding-agent/CHANGELOG.md)

Structures coding tasks as a **phase state machine** with traceability IDs, artifact templates, source state verification, and file-based agent memory. Designed for the [z.ai](https://z.ai) platform.

```text
IDLE → SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER
  ↑                                        │
  └──── Error Recovery ◄───────────────────┘
```

</div>

---

## Quick Start

```bash
# 1. Clone into your project
cd ~/my-project
git clone https://github.com/hoshiyomiX/stellar-coding-agent.git

# 2. Bootstrap (install + auto-update + dev server — one command)
bash stellar-coding-agent/boot.sh
```

Invoke in any session:

```
Skill(command="stellar-coding-agent")
```

Look for `☄️ STELLAR · v5.2.0 · ACTIVE` — confirms the framework loaded.

That's it. `boot.sh` handles everything: first-time install, auto-updates from remote, self-healing if files get wiped, and dev server startup. Run it once per session.

---

## How It Works

The framework provides **tools, not rules**. Each phase produces an artifact the next phase consumes, creating a chain that prevents skipping straight to code.

### Phase State Machine

| Phase | Output | Why |
|-------|--------|-----|
| **IDLE** | Complexity classification | Routes the task to the right verbosity level |
| **SPECIFY** | Problem specification | Forces precise thinking before writing code |
| **PLAN** | Implementation plan with Traceability IDs | Maps requirements to code locations |
| **IMPLEMENT** | Annotated code | Each block references its Traceability ID |
| **VERIFY** | Evidence-based report | Automated checks + edge case tracing |
| **DELIVER** | Summary + compliance report | Traceable record of what was done |

### Complexity Tiers

Not every task needs the same ceremony. The framework always runs all six phases, but adjusts verbosity:

| Tier | Criteria | PCR Format | Artifacts |
|------|----------|-----------|-----------|
| **Simple** | Single file, no schema change | 1-line compact | Abbreviated (no templates) |
| **Standard** | Multiple files or schema change | Full block | Full templates + Traceability IDs |
| **Complex** | Architectural, multi-service | Full block + detailed evidence | Full templates + extra detail |

Error recovery always uses full ceremony regardless of tier.

### Traceability IDs

`IMPL-001`, `IMPL-002`, ... chain through every phase — requirement → code → verification. If something is dropped, the gap is visible.

### Source State Verification (SSV)

Before analyzing git repositories, the framework verifies data freshness:

```bash
git fetch → compare HEAD to origin → sync if behind → proceed
```

Prevents stale-checkout analysis (the failure that inspired this feature).

### Agent Memory (v5.2.0)

File-based memory system inspired by [Hermes](https://github.com/NousResearch/hermes-agent) and [Memweave](https://github.com/sachinsharma9780/memweave):

```
memory/
├── MEMORY.md          ← Evergreen: preferences, patterns (~2K char budget)
├── decisions.md       ← Evergreen: architectural decisions with rationale
├── incidents.md       ← Evergreen: error patterns and fixes
└── YYYY-MM-DD.md      ← Dated: session digest (auto-created daily)
```

- **Evergreen files** are permanent — loaded during IDLE for session continuity
- **Dated files** capture what happened and why — preserving decision rationale across sessions
- **Bounded budget** (~2,000 chars for MEMORY.md) with agent-driven curation — the LLM decides what to keep/evict
- **Rich session summaries** for Standard/Complex tasks capture decisions, context, and caveats

### Error Recovery

Structured 5-step decision tree: **capture → classify → identify actions → fix → re-verify**. Git operations have explicit safety rules — `git fetch` before `git pull`, no force push without user instruction, stop all git ops if infrastructure blocks.

### Session Persistence

The z.ai platform may wipe the `skills/` directory on session reset. `boot.sh` handles this automatically by copying git-tracked `skill/` → `skills/` before starting the dev server. No manual re-install needed.

---

## File Structure

```
stellar-coding-agent/
├── boot.sh                           # Install + session bootstrap (single entry point)
├── setup.sh                          # [Legacy] Standalone installer — boot.sh handles this now
├── README.md                         # This file
├── skill/stellar-coding-agent/       # Git-tracked source (copied to skills/ on install)
│   ├── SKILL.md                      # Core framework (phases, SSV, error recovery, PCR)
│   ├── CHANGELOG.md                  # Version history
│   ├── memory-template.md            # Memory system docs & file templates
│   ├── procedure/
│   │   ├── phases.md                 # Phase definitions with entry/exit criteria
│   │   ├── templates/
│   │   │   ├── problem-spec.md       # SPECIFY artifact
│   │   │   ├── implementation-plan.md # PLAN artifact (Traceability IDs)
│   │   │   ├── verification-report.md # VERIFY artifact (evidence capture)
│   │   │   └── incident-report.md    # Error documentation
│   │   └── decision-trees/
│   │       └── error-resolution.md   # 5-step structured decision tree
│   ├── constraints/
│   │   ├── code-standards.md         # Function, file, import, quality standards
│   │   └── type-safety.md            # Type system constraints with examples
│   ├── knowledge/
│   │   ├── architecture.md           # Runtime environment, directory layout, service topology
│   │   ├── conventions.md            # Coding conventions, state management, import order
│   │   ├── platform-constraints.md   # Sandbox-specific limitations (gateway, routes, SDK)
│   │   └── error-patterns.md         # Common errors with cause → fix mapping
│   └── assets/
│       └── page.tsx                  # Custom splash page (closeable + minimizable)
└── skills/stellar-coding-agent/      # Platform-managed (auto-healed by boot.sh)
```

---

## Philosophy (v5.0.0)

> **Stop telling the LLM what it MUST do. Start giving it tools it WANTS to use.**

v5.0.0 is a philosophical reset based on an honest audit:

- **What works**: Traceability IDs, templates, SSV, error decision tree — they work because they're useful, not because they're mandatory
- **What doesn't work**: Compliance enforcement language ("must", "mandatory", "do not skip") — has no measurable effect on LLM behavior regardless of wording
- **What's honest**: The framework cannot guarantee compliance, force behavior, or persist across sessions. It's text in a skill file. The user is the final judge of quality.

---

## Version History

| Version | Summary |
|---------|---------|
| [**v5.2.0**](skill/stellar-coding-agent/CHANGELOG.md) | Agent memory system (Hermes+Memweave inspired), complexity tiers, compact PCR, path safety, triggering improvements. |
| [**v5.1.0**](skill/stellar-coding-agent/CHANGELOG.md) | Completion signal moved to high-attention zone, abbreviation floor added. |
| [v5.0.0](skill/stellar-coding-agent/CHANGELOG.md) | Philosophical reset. Removed compliance theater, kept useful tools. Added `boot.sh` self-heal. |
| [v4.6.0](skill/stellar-coding-agent/CHANGELOG.md) | Source State Verification (SSV). Evidence tiers in attestation. |
| [v4.5.0](skill/stellar-coding-agent/CHANGELOG.md) | Coexistence mode with fullstack-dev. *(Removed in v5.0.0)* |
| [v4.4.0](skill/stellar-coding-agent/CHANGELOG.md) | Git error classification and safety rules. |
| [v4.3.0](skill/stellar-coding-agent/CHANGELOG.md) | OUTCOME gate, evidence requirement, defect counter. |
| [v4.0.0](skill/stellar-coding-agent/CHANGELOG.md) | Complete redesign: phase state machine, artifact templates, traceability IDs. |
