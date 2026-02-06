---
description: Screenshot the running simulator and analyze the UI
allowed-tools: mcp__xcodebuild__*, mcp__XcodeBuildMCP__*, mcp__ios-simulator__*
---

# UI Snapshot

1. Take a screenshot of the booted simulator
2. Describe what's on screen — layout, content, visual state
3. Check for:
   - Layout issues (clipping, misalignment, overflow)
   - Empty states not handled
   - Loading states missing
   - Accessibility concerns (contrast, touch targets)
   - Consistency with other screens
4. If the user asked about a specific issue, focus analysis there
