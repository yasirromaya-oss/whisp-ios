fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios ci_test

```sh
[bundle exec] fastlane ios ci_test
```

CI: run unit tests on simulator (no signing)

### ios ci_ui_test

```sh
[bundle exec] fastlane ios ci_ui_test
```

CI: run UI tests on simulator (no signing)

### ios ci_build

```sh
[bundle exec] fastlane ios ci_build
```

CI: build for simulator (no signing)

### ios certificates

```sh
[bundle exec] fastlane ios certificates
```

Sync App Store certificates and profiles (readonly in CI)

### ios certificates_dev

```sh
[bundle exec] fastlane ios certificates_dev
```

Sync development certificates (local only)

### ios certificates_refresh

```sh
[bundle exec] fastlane ios certificates_refresh
```

Force-renew App Store certificates (local only)

### ios build

```sh
[bundle exec] fastlane ios build
```

Build IPA for App Store

### ios test

```sh
[bundle exec] fastlane ios test
```

Run unit tests

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Capture App Store screenshots (dark mode, all devices)

### ios whisp_frame

```sh
[bundle exec] fastlane ios whisp_frame
```

Frame raw screenshots with branded backgrounds and headlines (overwrites in place)

### ios screenshots_and_frame

```sh
[bundle exec] fastlane ios screenshots_and_frame
```

Capture screenshots then frame them for App Store

### ios metadata

```sh
[bundle exec] fastlane ios metadata
```

Upload metadata and screenshots (no binary)

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

### ios release

```sh
[bundle exec] fastlane ios release
```

Full release: build and submit for App Store review (screenshots always uploaded)

### ios bump

```sh
[bundle exec] fastlane ios bump
```

Bump version (type: patch|minor|major)

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
