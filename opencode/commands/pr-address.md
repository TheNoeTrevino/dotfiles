---
description: Address comments from a PR on Github. Args <[PR num] [notes]>
agent: build
argument-hint: <[PR num] [notes]>
---

# Context 

Use the GitHub CLI tool to view PR $1. View its comments.

$2

First, figure out which comments are changes we should actually implement.

Check for these things: 
- Did we already implement the change? If so, we can ignore it.
- Does the comment suggest a change that violates the codebase's existing style or patterns? If so, we should ignore it.
- Does the comment suggested provide genuine value to the codebase? Then we should implement it.

Give me a list of the comments that require changes in this format: 

```
1. DRY Violation: NextMonth() and PrevMonth() Duplication (date_picker_state.go:86-112)
- Severity: High
- Location: internal/tui/state/date_picker_state.go
- Issue: 22 lines of nearly identical logic for month navigation
- Value: High - This is core navigation logic that will be maintained long-term. The duplication creates significant risk of bugs if one function is updated but not the other
- Recommendation: ✓ Implement - Extract to `changeMonth(delta int)` helper as suggested
- Effort: Low 
```
