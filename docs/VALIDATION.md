# Validation record

Date: November 9, 2026. Engine: Godot 4.6.3 stable. This is an initial development build, not a claim of full original-game parity.

## Passed

- Original reference files match the SHA-256 hashes in `reference/manifest.json`.
- Godot imports the native project without GDScript parse errors.
- Headless integration checks pass for District's 517 colliders, raycasts, rifle ammunition, reserve transfer during reload, physical movement, jump/double jump, grapple acquisition/release, simultaneous touch movement/fire, kill scoring, player damage, pause/resume, and grenade creation.
- Mexico's 321 colliders load; destructible removal, wave-five checkpoint/boss scheduling, and all ten enemy/boss model variants pass integration checks.
- Native data contains English enemy display names and no CJK text. Port menus, controls, credits, configuration description, and project documentation have been translated to English.
- Android debug APK export succeeds with native ARM64 and x86_64 libraries, map data, and bundled credits.
- APK signature verification succeeds. Android application ID: `com.doodleshooter.port`; version: `0.1.0`; minimum SDK: 24; target SDK: 36; landscape orientation.

Run `python3 tools/check.py` to repeat the automated checks. Logs are written to the system temporary directory as `doodleshooter-check-import.log` and `doodleshooter-check-smoke.log`.

## Environment limitations

ADB could not start its local daemon: the environment rejected the socket listener and USB access. The APK has not been installed or played on an emulator or physical phone.

The macOS graphical launch attempt could not connect to the system graphical services. No rendered screenshot or visual QA was completed. Headless execution does not verify GPU shader rendering, final layouts, frame rates, safe areas, or physical multitouch behavior.

The macOS engine also reports a system certificate-store access error in this restricted environment. Gameplay integration checks still reach both completion markers without script errors.

The Android resource inspector reports a Godot-template warning about a missing themed-icon XML reference. Signature and package inspection succeed; Android launcher behavior still needs device validation.

## Deferred

The first iOS export attempt stopped with `App Store Team ID not specified`. The user explicitly deferred iOS setup. The iOS preset retains `com.doodleshooter.port`; no iOS build or device validation is claimed.

Networking, complete boss behavior, exact movement/combat tuning, original music, and visual parity remain listed in `PARITY.md`.
