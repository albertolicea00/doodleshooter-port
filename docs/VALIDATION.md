# Validation record

Date: November 10, 2026. Engine: Godot 4.6.3 stable. This records automated checks and desktop menu screenshots, not full original-game parity.

## Automated coverage

Run the native checks:

```sh
python3 tools/check.py
```

The November 10 run passes. The checker verifies the original source SHA-256 hashes, imports the native project, rejects engine/script errors, and requires both smoke completion markers, the native LAN protocol marker, and completion markers from two separate Godot game processes. Logs are written to the system temporary directory as `doodleshooter-check-import.log` and `doodleshooter-check-smoke.log`.

Headless gameplay coverage includes:

- District's 517 colliders, raycasts, rifle ammunition, reserve transfer during reload, movement, jump/double jump, grapple acquisition, persistent swing, and second-press release.
- Simultaneous touch movement/fire, scoring, player damage, pause/resume, and grenade creation.
- Menu clicks navigate Credits → full notices → Credits → main menu. Menu touch-to-mouse emulation is enabled; it is disabled during gameplay to avoid turning movement touches into mouse-bound fire. These checks inject viewport mouse events, not physical touchscreen input.
- Shell-by-shell shotgun reload and firing interruption; frontal perfect parry, cooldown, and rejection of rear projectiles.
- Mexico's 321 colliders, destructible removal, wave-five boss scheduling, and all ten enemy/boss models with damage hitboxes.
- A physical raycast against the animated grunt head hitbox and damage forwarding to its actor.
- Doodler throw projectile creation and the start of Inkblot's spray sequence. This does not verify complete boss behavior or visual timing.

Offline bot integration also passes: District arena loading with three bots, selecting another bot as the nearest opponent, AI hitscan damage between bots, player quick-slash damage against a bot, spawn protection, kill scoring, bot/player respawns, pausing the match clock, and ending a match at 20 kills. Difficulty, sustained navigation, and a complete ten-minute match have not been playtested.

Native LAN protocol checks use the real Godot WebSocket client and embedded server: host/join, host-only start, late join, state relay, spawn shields, damage caps, kill scoring, respawn, self-blast scoring, match completion, and rejection of finished rooms. Two separate processes running the actual game scene also load an arena, create remote avatars, deliver scripted damage, update scores, and respawn the guest. These are loopback tests on one computer, not Wi-Fi or device tests. Additional logs use `doodleshooter-check-lan*.log` in the system temporary directory.

The model conversion was rerun from the unchanged reference. Shared head/torso markers now retain the hit-sphere part name for bombers, flyers, the Eraser, and the Inkblot. Native data display names remain English.

Run the lobby tests after installing `server/requirements.txt` in a virtual environment:

```sh
.venv/bin/python -m unittest discover -s tests -v
```

Six tests pass over real local WebSocket connections. They cover private lobby visibility, ten-player capacity, host migration, quick play, late join, damage caps, kill scoring, respawn, state relay, malformed messages/coordinates, the 20-kill match ending, rejection of finished rooms, grenade spawn protection, and elimination of self-kill score rewards. These tests exercise the Python server with Python clients; they do not establish Godot client interoperability or a playable online match.

## Android build status

The November 10 current-source debug APK export succeeds. Independent `apksigner verify --verbose` passes with v2 and v3 signatures. Package inspection confirms application ID `com.doodleshooter.port`, version `0.1.0`, minimum SDK 24, and target SDK 36. Archive inspection confirms ARM64 and x86_64 native libraries, bundled credits, the font license, audio manifest, and enemy data.

The initial attempt failed with `A valid Java SDK path is required in Editor Settings`. Configuring Godot's local `export/android/java_sdk_path` to the installed Temurin 17 JDK resolved the failure; setting `JAVA_HOME` alone did not. No signing credentials were added to the repository. The artifact is `builds/android/doodleshooter-port-debug.apk`.

## Desktop menu rendering

Graphical capture now succeeds on macOS using OpenGL 4.1 Compatibility on Apple M4. The main, Credits, offline setup, and LAN setup screens were rendered at 1280×720 and inspected. The text fits the scrollable menu and the main/offline buttons are visible. Long credits and LAN content require scrolling. Screenshots are in `builds/validation/doodleshooter-menu-*.png`; reproduce them with `godot --path native --script "$PWD/tools/capture-menus.gd"`.

This is desktop menu verification only. Gameplay rendering, shader fidelity, mobile layouts, physical touch and text entry, and safe areas have not been visually verified.

## Unverified behavior and environment limitations

No reference gameplay comparison, listening comparison, physical multitouch test, or device/emulator play session has been completed. Headless execution does not verify GPU shaders, final layouts, frame rates, safe areas, audio mixing, or touchscreen feel.

Earlier ADB and graphical launch attempts were blocked by the environment; desktop graphical capture now works. The current export attempt also reported that it could not connect to the ADB daemon. An Android install and play session remains outstanding.

Original audio assets include 59 rendered effects and six OGG music variants. Resource loading is exercised headlessly; audible fidelity and music loop transitions require listening tests.

Online mode requires a separately running Python server; the LAN mode hosts its own native server. Complete matches, physical LAN/device networking, lag, reconnection, synchronized destruction, match-clock expiration, and hostile client validation remain unverified. The server caps damage and checks message shapes but trusts movement and hit reports.

## Deferred

The earlier iOS export attempt stopped with `App Store Team ID not specified`. The user explicitly deferred iOS setup. The preset retains `com.doodleshooter.port`; no signing credentials, iOS build, or device validation have been added.

See `PARITY.md` for the remaining comparison and implementation work. No new maps have been added.
