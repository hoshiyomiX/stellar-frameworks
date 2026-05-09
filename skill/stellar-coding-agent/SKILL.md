---
name: stellar-coding-agent
version: 5.2.0
description: "Deterministic coding workflow with phase state machine, artifact templates, and structured verification. Trigger this skill whenever building, implementing, fixing bugs, refactoring, or auditing code — especially multi-file changes, schema modifications, or tasks requiring traceability. Also activate on phrases like 'follow the process', 'use stellar', 'phase machine', 'structured workflow', or when the user explicitly asks for planning-before-coding discipline. For trivial single-line fixes, the framework auto-abbreviates to keep overhead minimal."
---
<!-- VERSION SYNC: on bump, update (1) frontmatter above, (2) activation banner below, (3) boot.sh header, (4) setup.sh header -->

## Activation

```
☄️ STELLAR · v5.2.0 · ACTIVE
   Phase State Machine · Traceability IDs · Artifact Templates · SSV · Memory
```

This framework structures coding work as a phase machine. It provides templates and traceability tools — use them when they help, abbreviate when they don't. The phases exist because skipping straight to code is how most bugs happen, not because every task needs a formal spec.

## Limitations

This framework is text in a skill file. It cannot guarantee compliance, force behavior, or persist across sessions. The LLM reading this may follow it closely, loosely, or not at all depending on context, attention, and task complexity. The QA Attestation is self-graded — useful as a confidence signal, not independent verification. The user is the final judge of quality.

## Phase State Machine

```
IDLE → SPECIFY → PLAN → IMPLEMENT → VERIFY → DELIVER
  ↑                                        │
  └──── Error Recovery ◄───────────────────┘
```

On error: stop, diagnose, fix, return to VERIFY.

| Phase | Purpose |
|-------|---------|
| IDLE | Receive task, classify complexity |
| SPECIFY | Restate problem, identify constraints and edge cases, list affected files |
| PLAN | Create implementation steps with Traceability IDs |
| IMPLEMENT | Write code, reference Traceability IDs |
| VERIFY | Run checks, trace edge cases, confirm Traceability IDs satisfied |
| DELIVER | Present results with attestation |

Phase definitions, entry/exit criteria, and transition rules are in `procedure/phases.md`.

## Phase References

| Phase | Artifact Template | Knowledge Files |
|-------|-------------------|-----------------|
| SPECIFY | `procedure/templates/problem-spec.md` | `knowledge/architecture.md` |
| PLAN | `procedure/templates/implementation-plan.md` | `knowledge/conventions.md` |
| IMPLEMENT | (code output) | `constraints/code-standards.md`, `constraints/type-safety.md` |
| VERIFY | `procedure/templates/verification-report.md` | `knowledge/error-patterns.md` |
| Error Recovery | `procedure/templates/incident-report.md` | `procedure/decision-trees/error-resolution.md` |

## Source State Verification (SSV)

Before analyzing or auditing a git repository, verify data freshness:

1. `git fetch` to sync remote references
2. Compare local HEAD against `origin/<branch>`
3. If behind, `git pull` or `git checkout <branch>` after fetch
4. If referencing a specific commit, verify it exists in history
5. Only proceed after SSV passes

SSV is required after cross-session boundaries or when previous sessions involved git operations. Skip SSV for purely creative tasks with no git involvement.

## Error Recovery

1. **Stop** — do not continue past errors
2. Document the error (incident report template)
3. Ask the user before any action with side effects (git changes, file deletions, destructive operations)
4. Fix root cause, not symptom
5. Return to VERIFY and re-verify

Git rules (overrides defaults):
- `git fetch` and inspect before `git pull` — if remote diverged, stop and ask
- No `git rebase`, `git reset`, `git push --force`, or `git merge` without explicit user instruction
- If git is blocked by infrastructure, stop all git operations and inform the user

Full decision tree: `procedure/decision-trees/error-resolution.md`.

## Process Compliance Report

After completing a task, output this block. Phases not applicable to the task are marked N/A.

```
☄️ PCR
├─ SPECIFY     : PASS / N/A
├─ PLAN        : PASS / N/A
├─ IMPLEMENT   : PASS / N/A
├─ VERIFY      : PASS / N/A
└─ OUTCOME     : PASS / FAIL

Evidence: [concrete results — e.g. "lint 0 errors, 4/4 traceability verified"]
Defects found and fixed: [n]
```

Self-graded. The evidence requirement and defect counter make fabrication harder but cannot guarantee independence. A claim of 0 defects means first-attempt correctness. If OUTCOME is FAIL, do not deliver — return to the appropriate phase.
