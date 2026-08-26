# Proximate Cause Triage (Detail)

Moved from SKILL.md in v9.14.0. Reference-only — Q1/Q2/Q3 + Scope Gate stay in SKILL.md.

## Parsimony Audit Template
```
# Parsimony Audit: <symptom>
## Candidates: A: <hyp1>  B: <hyp2>  C: <hyp3>
## Fit check: A? B? C?
## Assumption load: A: N  B: N  C: N
## Proximate check: A? B? C?
## Preferred: <fewest assumptions + most proximate>
## Over-shave check: <preferred fits all evidence?>
## What would overturn: <distinguishing evidence>
```

## Worked Example
Scenario: "Step 3 activation fails with '✗ GATE FAILED'"
1. Symptom: EXPECTED_TOKEN != ACTUAL_TOKEN
2. Q1: Within 1 hop? YES — token in Step 1 bash
3. Q2: ≤2 assumptions? YES (Step 1 didn't run OR wrote wrong hash)
4. Q3: Fixes request? YES
5. Action: check /tmp/st-active exists
6. STOP at first resolution

## Anti-patterns
- ❌ "Trace deeper to be sure" — STOP at proximate cause
- ❌ "Check 5 more files" — out_of_scope unless full audit requested
