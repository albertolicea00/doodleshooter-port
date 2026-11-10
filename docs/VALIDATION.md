# Validation record

Date: November 10, 2026. Engine: Godot 4.6.3 stable. This records source-level and headless checks, not full original-game parity.

## Automated coverage

Run the native checks:

```sh
python3 tools/check.py
```

The November 10 run passes. The checker verifies the original source SHA-256 hashes, imports the native project, rejects engine/script errors, and requires both smoke completion markers. Logs are written to the system temporary directory as `doodleshooter-check-import.log` and `doodleshooter-check-smoke.log`.

Headless gameplay coverage includes:

- District's 517 colliders, raycasts, rifle ammunition, reserve transfer during reload, movement, jump/double jump, grapple acquisition, persistent swing, and second-press release.
- Simultaneous touch movement/fire, scoring, player damage, pause/resume, and grenade creation.
- Shell-by-shell shotgun reload and firing interruption; frontal perfect parry, cooldown, and rejection of rear projectiles.
- Mexico's 321 colliders, destructible removal, wave-five boss scheduling, and all ten enemy/boss models with damage hitboxes.
- A physical raycast against the animated grunt head hitbox and damage forwarding to its actor.
- Doodler throw projectile creation and the start of Inkblot's spray sequence. This does not verify complete boss behavior or visual timing.

The model conversion was rerun from the unchanged reference. Shared head/torso markers now retain the hit-sphere part name for bombers, flyers, the Eraser, and the Inkblot. Native data display names remain English.

Run the lobby tests after installing `server/requirements.txt` in a virtual environment:

```sh
.venv/bin/python -m unittest discover -s tests -v
```

Six tests pass over real local WebSocket connections. They cover private lobby visibility, ten-player capacity, host migration, quick play, late join, damage caps, kill scoring, respawn, state relay, malformed messages/coordinates, the 20-kill match ending, rejection of finished rooms, grenade spawn protection, and elimination of self-kill score rewards. These tests exercise the Python server with Python clients; they do not establish Godot client interoperability or a playable online match.

## Android build status

The November 10 current-source debug APK export succeeds. Independent `apksigner verify --verbose` passes with v2 and v3 signatures. Package inspection confirms application ID `com.doodleshooter.port`, version `0.1.0`, minimum SDK 24, and target SDK 36. Archive inspection confirms ARM64 and x86_64 native libraries, bundled credits, the font license, audio manifest, and enemy data.

The initial attempt failed with `A valid Java SDK path is required in Editor Settings`. Configuring Godot's local `export/android/java_sdk_path` to the installed Temurin 17 JDK resolved the failure; setting `JAVA_HOME` alone did not. No signing credentials were added to the repository. The artifact is `builds/android/doodleshooter-port-debug.apk`.

## Unverified behavior and environment limitations

No current rendered screenshot, visual comparison, listening comparison, physical multitouch test, or device/emulator play session has been completed. Headless execution does not verify GPU shaders, final layouts, frame rates, safe areas, audio mixing, or touchscreen feel.

Earlier ADB and graphical launch attempts were blocked by the environment. The current export attempt also reported that it could not connect to the ADB daemon. An Android install and play session remains outstanding.

Original audio assets include 59 rendered effects and six OGG music variants. Resource loading is exercised headlessly; audible fidelity and music loop transitions require listening tests.

Native online mode requires a separately running server. Full matches between Godot clients, LAN/device networking, lag, reconnection, synchronized destruction, match-clock behavior, and hostile client validation remain unverified. The server caps damage and checks message shapes but trusts movement and hit reports.

## Deferred

The earlier iOS export attempt stopped with `App Store Team ID not specified`. The user explicitly deferred iOS setup. The preset retains `com.doodleshooter.port`; no signing credentials, iOS build, or device validation have been added.

See `PARITY.md` for the remaining comparison and implementation work. No new maps have been added.
