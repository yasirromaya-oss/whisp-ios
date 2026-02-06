---
description: Refactor a file or feature for clarity, performance, and TCA correctness
argument-hint: <file-path or feature-name>
allowed-tools: Read, Write, Edit, Glob, Grep, mcp__xcodebuild__*, mcp__XcodeBuildMCP__*, mcp__apple-docs__*
---

# Refactor: $ARGUMENTS

## Process
1. Read the target file(s) and all related files (views, reducers, tests, clients)
2. Identify issues in priority order:
   - **Bugs**: Crashes, race conditions, data loss
   - **Performance**: Unnecessary recomputation, missing memoization
   - **TCA correctness**: State leaks, missing cancellation, wrong patterns
   - **Simplicity**: Over-abstraction, dead code, unnecessary indirection
3. Propose changes — explain what and why before editing
4. Implement changes
5. Build with XcodeBuildMCP
6. Run tests
7. Write tests for refactored code if none existed

## Rules
- Simpler is better. Remove code when possible.
- No abstractions for one-time operations.
- No behavior changes — only structure and correctness.
- Every effect that changes state must have a success/failure action path.
- Verify Apple APIs with Apple Docs MCP before using them.
