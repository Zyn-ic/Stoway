# Risk Level Reference

## Key Concepts

- Roblox classifies Open Cloud endpoints into low, medium, high, and critical risk levels.
- These levels are used in OAuth-related "try it out" experiences and warn about endpoint sensitivity.
- Higher risk usually means more destructive or less reversible actions.
- Critical-risk endpoints are not available through "try it out."

## Rules

- Use risk level as a least-privilege design signal when choosing scopes.
- Be more conservative when an app requests scopes that unlock medium- or high-risk operations.
- Treat high-risk and critical operations as requiring stronger product justification and clearer user consent.
- Do not assume risk level replaces endpoint-by-endpoint review.

## Patterns

### Risk meanings

- Low:
  - usually read-oriented or low-impact
  - informational warning only
- Medium:
  - can create, update, or access private data
  - confirmation warning applies
- High:
  - destructive or hard-to-reverse operations
  - stronger warning before use
- Critical:
  - highly sensitive account or privacy impact
  - "try it out" disabled

### Scope review heuristic

```text
requested feature
-> endpoint set
-> scope set
-> endpoint risk level review
-> keep only the least powerful scope set that satisfies the feature
```

## Examples

- Read-only profile helper: likely low-risk scope set.
- Universe mutation tool: medium or high-risk surface, so minimize scopes and tighten who can authorize it.
- Delete-capable admin tool: require explicit justification and avoid bundling those permissions into unrelated features.
