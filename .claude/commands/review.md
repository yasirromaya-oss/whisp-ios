---
description: Review code changes or a specific file for TCA correctness, performance, and safety
argument-hint: [file-path or leave empty for git diff]
---

# Code Review

If `$ARGUMENTS` is a file path, review that file. Otherwise review `git diff` (staged + unstaged).

## Checklist

### TCA Architecture
- State mutations ONLY in reducers
- `@ObservableState` on all State structs (not `@Observable`)
- `.delegate` for child-to-parent communication
- `@Presents` + `.ifLet` for navigation
- All long-running effects have `CancelID`
- Effects send completion/failure actions — no fire-and-forget

### SwiftUI Performance
- Views under 100 lines, extract if not
- No sorting/filtering in computed properties — memoize in reducer
- `Equatable` on custom views
- `LazyVStack`/`LazyHStack` for scrollable lists
- Search debounced

### Concurrency Safety
- `@unchecked Sendable` has safety justification
- `AsyncStream` continuations cannot be overwritten
- Locks protect ALL shared mutable state
- Continuations cannot be resumed twice

### Code Quality
- No `print()` — Logger/os_log
- Typed error enums, not raw Error
- `guard` for early exits
- No force unwraps without justification

### Testing
- New reducer logic has `TestStore` tests
- Full exhaustivity
- Error, cancellation, and empty-state paths tested

Report findings: **CRITICAL** > **WARNING** > **SUGGESTION** with file:line and concrete fix.
