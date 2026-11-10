# doodleshooter-port

An unofficial native port of [Doodle District](https://doodleshooter.vercel.app/) for Android and iOS, built with Godot 4.6.3 and GDScript. The name combines **port** and **portable**. Reproduce the original game first; create new maps afterward.

The project provides native survival gameplay and an experimental client/server free-for-all mode. **It is not yet a complete clone**: reference comparison, end-to-end multiplayer validation, and device and visual verification remain unfinished. See [docs/PARITY.md](docs/PARITY.md) for the full status.

All port UI and project documentation are in English. The original game's attribution appears in the game and in [CREDITS.md](CREDITS.md). The historical upstream source snapshot is preserved unchanged for provenance and contains its own localized strings; it is not shipped in the native application.

## Run

Install standard Godot 4.6.3. Open `native/project.godot` and press Run, or use:

```sh
godot --path native
```

To display touch controls on desktop:

```sh
godot --path native -- --touch
```

Touch controls appear automatically on mobile. Survival gameplay runs locally without an Internet connection. Online mode requires the separate lobby server described below.

## Android

The current development APK is stored at `builds/android/doodleshooter-port-debug.apk`. Application ID: `com.doodleshooter.port`. It includes ARM64 and x86_64 binaries and uses a debug signing key. It has not been published to Google Play. The current source was exported and its APK signature and bundled resources were verified on November 10, 2026; device play remains unverified.

To rebuild, install the Godot 4.6.3 export templates and configure Java 17, the Android SDK, and a debug keystore in the editor settings:

```sh
mkdir -p builds/android
godot --headless --path native --export-debug Android
```

Private signing keys are not stored in the project. AAB exports and store releases require a Gradle build and release signing configuration.

## Experimental online play

Run the native lobby server with Python 3.11 or later:

```sh
python3 -m venv .venv
.venv/bin/python -m pip install -r server/requirements.txt
.venv/bin/python server/lobby.py
```

The server binds to `127.0.0.1:8911` by default. For LAN testing, set `DOODLE_BIND=0.0.0.0` when starting it. In **Play online**, enter a WebSocket URL reachable from the client: `ws://127.0.0.1:8911` on the same desktop, `ws://10.0.2.2:8911` from the Android emulator, or the server computer's LAN address from a phone. There is no hosted matchmaking service or web-lobby interoperability.

The implementation includes public/private lobbies, codes, quick play, ten-player rooms, late joining, a 20-kill/10-minute limit, respawning, and host migration. Server protocol tests pass; a complete match between Godot clients has not been verified. The server caps reported damage but trusts client hit reports and movement.

## iOS

**Deferred at the user's request.** The `iOS` preset uses the same scene and controls, with bundle identifier `com.doodleshooter.port`.

When resuming iOS work, install Xcode and the Godot export templates on macOS. Set your Apple Team ID in `native/export_presets.cfg` or Project → Export → iOS:

```sh
mkdir -p builds/ios
godot --headless --path native --export-debug iOS
```

The initial export attempt stopped because `App Store Team ID` was missing. No iOS build has been produced or tested.

## Verification

```sh
python3 tools/check.py
.venv/bin/python -m unittest discover -s tests -v
```

The Godot check verifies reference hashes, imports the project, rejects engine/script errors, and runs headless gameplay integration checks. Coverage includes collision, weapons, shell reload interruption, directional parries, grappling, multitouch, enemy hitboxes, boss projectile emission, and checkpoint scheduling. Python tests exercise the lobby protocol over real local WebSocket connections.

The development environment blocked ADB access and macOS graphical services. Device/emulator execution and visual rendering have not been verified. See [docs/VALIDATION.md](docs/VALIDATION.md).

## Reference and layout

- `native/`: shared native project and gameplay code.
- `reference/upstream/`: unmodified web source snapshot.
- `reference/manifest.json`: source repository, revision, and original file hashes.
- `tools/extract-reference.mjs`: deterministic geometry, model, hitbox, and parameter conversion.
- `tools/extract-audio.mjs`: offline rendering of the original soundtrack and effects.
- `server/` and `tests/`: native lobby server and protocol tests.
- `docs/PARITY.md`: specific differences from the original game.

To regenerate native data without downloading dependencies:

```sh
node --experimental-vm-modules tools/extract-reference.mjs
```

The converter executes the reference's procedural generators with its local Three.js dependency, reverses triangle winding for Godot, and preserves coordinates. Online matches load the converted arena variants. Extracted display names are normalized to English.

To render the original audio again, install Node.js, ffmpeg, and the build-only dependencies:

```sh
npm ci --prefix tools
npm run audio --prefix tools
```

The renderer reuses existing music files; remove the relevant generated OGG files before regenerating a changed composition. The reference snapshot remains unchanged.
