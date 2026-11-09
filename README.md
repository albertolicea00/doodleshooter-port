# doodleshooter-port

An unofficial native port of [Doodle District](https://doodleshooter.vercel.app/) for Android and iOS, built with Godot 4.6.3 and GDScript. The name combines **port** and **portable**. Reproduce the original game first; create new maps afterward.

The project currently provides an initial executable survival build. **It is not yet a complete clone**: networking, several movement details, original boss patterns, and audiovisual fidelity remain unfinished. See [docs/PARITY.md](docs/PARITY.md) for the full status.

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

Touch controls appear automatically on mobile. Gameplay runs locally without an Internet connection.

## Android

The development APK is generated at `builds/android/doodleshooter-port-debug.apk`. Application ID: `com.doodleshooter.port`. It includes ARM64 and x86_64 binaries and uses a debug signing key. It has not been published to Google Play.

To rebuild, install the Godot 4.6.3 export templates and configure Java 17, the Android SDK, and a debug keystore in the editor settings:

```sh
mkdir -p builds/android
godot --headless --path native --export-debug Android
```

Private signing keys are not stored in the project. AAB exports and store releases require a Gradle build and release signing configuration.

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
```

The check imports the project and runs headless integration tests covering maps, native collisions, firing, reloading, movement, double jumps, grappling, multitouch input, scoring, damage, pause, grenades, destructibles, checkpoints, and enemy model loading.

The development environment blocked ADB access and macOS graphical services. Device/emulator execution and visual rendering have not been verified. See [docs/VALIDATION.md](docs/VALIDATION.md).

## Reference and layout

- `native/`: shared native project and gameplay code.
- `reference/upstream/`: unmodified web source snapshot.
- `reference/manifest.json`: source repository, revision, and original file hashes.
- `tools/extract-reference.mjs`: deterministic geometry, model, and parameter conversion.
- `docs/PARITY.md`: specific differences from the original game.

To regenerate native data without downloading dependencies:

```sh
node --experimental-vm-modules tools/extract-reference.mjs
```

The converter executes the reference's procedural generators with its local Three.js dependency, reverses triangle winding for Godot, and preserves coordinates. Arena variants are converted as data, but are not yet selectable in a native match. Extracted display names are normalized to English.
