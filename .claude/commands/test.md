---
description: Run unit tests and report results
allowed-tools: mcp__xcodebuild__*, mcp__XcodeBuildMCP__*, Bash(fastlane *)
---

# Test

1. Run tests using XcodeBuildMCP on iPhone 17 Pro simulator
2. If XcodeBuildMCP unavailable, fall back to `fastlane ci_test`
3. Report: total passed/failed/skipped
4. For failures: show test name, assertion, file:line, and suggest fix
5. Flag any tests using `.exhaustivity = .off` as needing attention
