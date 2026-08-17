---
name: Stellar Trails
tagline: Six-phase workflow framework for LLM agents — traceability, gates, and sandbox-native enforcement
topics:
  - agent-workflow
  - phase-machine
  - llm-agents
  - task-management
  - traceability
  - zai
  - enforcement
  - layered-memory
---

# Stellar Trails

Six-phase workflow framework for LLM agents on the z.ai platform. Enforces traceability IDs, entry/exit gates, scope commitment, and adaptive complexity — with 5 sandbox-native enforcement vectors that LLMs cannot fabricate.

## What It Does

Structures every task as a **six-phase workflow**:

```
IDLE → SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER
  ↑                                        │
  └──── Recovery ◄───────────────────┘
```

- **Coding tasks**: full phases with Traceability IDs (IMPL-001, IMPL-002...)
- **Non-coding tasks** (questions, explanations): Minimal tier — phases run internally, only IMPLEMENT produces visible output
- **Adaptive complexity**: Minimal, Simple, Standard, Complex — all 6 phases always run, only ceremony adjusts

## Key Features

| Feature | Description |
|---------|-------------|
| **Six-Phase Workflow** | IDLE → SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER — no phase skipping |
| **Traceability IDs** | IMPL-001 chains through every phase — gaps are visible in transcript |
| **Adaptive Complexity** | Minimal / Simple / Standard / Complex tiers — ceremony scales, phases don't skip |
| **5 Enforcement Vectors (E7–E11)** | Hash token gate, TodoWrite live marker, persistent activation log, line-number proof, clawhub oracle cross-check |
| **Pre-Push Verification (13 checks)** | bash -n, python3 mock, grep patterns, banner version, tag collision, moderation state, markdown fences, version match, duplicate files, SADC drift, path integrity |
| **Layered Memory Protocol (L0–L3)** | Worklog (L0) + patterns (L1) + scenarios (L2) + user-profile (L3) — adapted from TencentDB-Agent-Memory |
| **Proximate Cause Triage** | Orisinil decision tree to prevent deep rabbit-holing |
| **Inline Content Retrieval** | curl + python3 stdlib — no external crawl4ai dependency |
| **Auto Git Identity Setup** | Detects PAT, configures git identity from GitHub API |
| **Pure Markdown by Design** | No shell execution in Skill() invoke — pure markdown data |

## Install

```bash
clawhub install stellar-trails
```

Or via GitHub release:

```bash
curl -sL https://github.com/hoshiyomiX/stellar-trails/releases/latest/download/stellar-trails.zip -o /home/user_skills/stellar-trails.zip
```

## Invoke

```
Skill(command="stellar-trails")
```

## Source

- **ClawHub**: https://clawhub.ai/hoshiyomix/stellar-trails
- **GitHub**: https://github.com/hoshiyomiX/stellar-trails
- **Releases**: https://github.com/hoshiyomiX/stellar-trails/releases
- **Changelog**: https://github.com/hoshiyomiX/stellar-trails/blob/main/CHANGELOG.md

## License

MIT-0 (Free to use, modify, and redistribute. No attribution required.)
