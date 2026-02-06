---
description: Audit a feature or full app for performance issues
argument-hint: [feature-name or leave empty for full audit]
---

# Performance Audit: $ARGUMENTS

## SwiftUI Rendering
1. Computed State properties that sort/filter (recompute on every view read)
2. `ForEach` over non-Equatable items (full list redraws)
3. Views accepting closures without `Equatable` conformance
4. `@State`/`@Binding` used where TCA store state should be
5. Missing `LazyVStack`/`LazyHStack` in scrollable lists
6. Search inputs not debounced

## TCA Effects
1. `.run` effects that don't send completion actions (fire-and-forget)
2. Long-running effects without `CancelID`
3. Effects capturing `state` instead of extracting values before closure
4. Same effect triggered by multiple actions (duplicate work)

## Memory & Lifecycle
1. `@unchecked Sendable` classes — actual thread safety
2. `AsyncStream` continuations that can be overwritten
3. Strong reference cycles in closures (self capture in continuations)
4. `static let shared` singletons — lifecycle and cleanup
5. Large data held in state that should be loaded on demand

## Concurrency
1. `NSLock` / `Mutex` — all shared state protected?
2. `try?` silently swallowing errors users should see
3. Continuations that could be resumed twice or never

Report findings with file:line, severity, and concrete fix for each.
