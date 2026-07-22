# Native Apple Silicon macOS app

This target packages the original ActionScript 2 game with Ruffle's native
desktop runtime. Both executables in the resulting app are arm64-only, and the
player is forced to use Ruffle's Metal graphics backend. It does not use the old
Windows projector, Rosetta, Electron, or a browser view.

## Requirements

- An Apple Silicon Mac
- macOS 13 or later
- Xcode Command Line Tools
- Internet access for the first build, to download the pinned Ruffle runtime

## Build and run

```sh
./scripts/build-macos-app.sh
open "dist/Super Mario 63.app"
```

The first build downloads and checksum-verifies a fixed Ruffle nightly. Later
builds reuse the copy under `.build/macos/downloads`. The app itself is fully
offline after it has been built. Build outputs are written to
`dist/Super Mario 63.app` and `dist/Super Mario 63-macOS-arm64.zip`.

For local development the app receives an ad-hoc signature. To create a
Developer ID-signed build, provide an installed signing identity:

```sh
CODE_SIGN_IDENTITY="Developer ID Application: Example (TEAMID)" \
  ./scripts/build-macos-app.sh
```

Developer ID distribution also requires Apple's notarization step, which is
intentionally not attempted by the local build script.

## Runtime behavior

- The game starts in a 900 x 600 window (exactly 2x its original stage size).
- Metal is selected explicitly as the graphics backend.
- Ruffle's development toolbar is hidden for a clean, game-only window.
- Save games live in `~/Library/Application Support/Super Mario 63/Saves`.
- Ruffle preferences and caches are isolated under the matching application
  support and cache directories.
- Relative file access is rooted at the app's read-only Resources directory.
- Gamepad D-pad and face buttons map to the original arrow, Z, X, and Space
  controls.
- Start the launcher from Terminal with `--fullscreen` to enter fullscreen
  immediately. Ruffle's standard fullscreen shortcut remains available.
- Set `SM63_DEBUG=1` when starting from Terminal to show Ruffle compatibility
  warnings while debugging the original SWF.

Run `./scripts/verify-macos-app.sh` to recheck the app architecture, resources,
signature, and bundled runtime version.
