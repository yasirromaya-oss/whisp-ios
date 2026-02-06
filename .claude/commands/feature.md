---
description: Scaffold a new TCA feature with reducer, view, and tests
argument-hint: <FeatureName>
allowed-tools: Read, Write, Edit, Glob, mcp__apple-docs__*
---

# Create Feature: $ARGUMENTS

## Steps
1. Read existing features to match project patterns (start with RecordingFeature as reference)
2. Create `DXWhisp/Sources/$ARGUMENTS/` directory
3. Create `$ARGUMENTS Feature.swift`:
   - `@Reducer struct` with `@ObservableState` State and Action enum
   - `@Dependency` for needed clients
   - `.delegate` actions for parent communication
   - `CancelID` enum if long-running effects needed
4. Create `$ARGUMENTS View.swift`:
   - Accept `StoreOf<$ARGUMENTS Feature>`
   - Use `@Bindable` for bindings
   - Keep under 100 lines — extract subviews
5. Create `DXWhispTests/$ARGUMENTS FeatureTests.swift`:
   - `TestStore` with mock dependencies
   - Test happy path, error path, and cancellation
   - Full exhaustivity
6. Tell the user to add the new files to the Xcode project manually

## DO NOT
- Modify .pbxproj
- Create ViewModels or ObservableObjects
- Skip the test file
