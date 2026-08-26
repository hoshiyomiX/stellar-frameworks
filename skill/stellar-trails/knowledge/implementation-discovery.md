# Implementation Discovery Protocol (Detail)

Moved from SKILL.md in v9.14.0. Reference-only — protocol + decision tree stay in SKILL.md.

## Worked Example (v9.0.1 → v9.0.2)
- Task: "fix Step 3 broken regex + add undelete step"
- Discovery: while writing new python3 -c block, used multi-line indented python inside single-quoted bash string → IndentationError
- Same-Surface Test: same file (SKILL.md), same bash block (Step 3), same root cause (new code) → FIX NOW
- Action: rewrote python3 -c as one-liner, pushed as v9.0.2

## Worklog Entry Format
```
---
last_phase: DELIVER
discoveries:
  - bug: <Y one-line>
    found_while: <X one-line>
    surface: same|different
    action: fix-now|defer
    outcome: <fixed|deferred>
```

## Anti-patterns
- ❌ "Fix Y real quick" — no documentation
- ❌ "Mention in commit message" — commit messages ≠ delivery reports
- ❌ "Skip Y" — without logging, Y is forgotten
