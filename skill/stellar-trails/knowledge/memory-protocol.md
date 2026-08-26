# Layered Memory Protocol (Detail)

Moved from SKILL.md in v9.14.0. Reference-only.

## L1 Pattern Extraction Format
```
## [YYYY-MM-DD] <domain>: <pattern-name>
**Context**: <when this pattern applies>
**Approach**: <what worked>
**Gotcha**: <what to avoid>
**Source**: <task that produced this pattern>
```

## L2 Scenario Accumulation (auto-triggered at ≥5 L1 per domain)
```
# Scenario: <domain>
## Patterns:
- [date] domain: pattern
## Composite insight: <summary>
```

## L3 User Profile (auto-triggered at ≥3 same-decision patterns)
```
# User Profile (L3 Memory)
## Preferences:
- <preference>
```

## Knowledge On-Demand Loading
| Task type | Load |
|---|---|
| Coding (git/CI) | zai-sandbox.md + error-patterns.md + patterns.md |
| Coding (web dev) | zai-sandbox.md + architecture.md |
| Document | conventions.md + patterns.md |
| Audit/Diagnosis | error-patterns.md + patterns.md + scenarios.md |
| Continuation | Only scenarios.md for that domain |
| Cold start | user-profile.md + patterns.md |

## Anti-patterns
- ❌ "Just append to worklog" — extract patterns, don't just log state
- ❌ "Load all knowledge files" — load only relevant subset
- ❌ "Skip L2/L3" — auto-triggered by count, not manual
