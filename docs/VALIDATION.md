# Validation record

Date: November 15, 2026. Engine: Godot 4.6.3 stable. This records automated checks and desktop menu screenshots, not full original-game parity.

## Automated coverage

Run the native checks:

```sh
python3 tools/check.py
```

The November 15 run passes. The checker verifies the original source SHA-256 hashes, imports the native project, rejects engine/script errors, and requires both smoke completion markers, the native LAN protocol marker, and completion markers from two separate Godot game processes. Logs are written to the system temporary directory as `doodleshooter-check-import.log` and `doodleshooter-check-smoke.log`.

Headless gameplay coverage includes:

- District's 517 colliders, raycasts, rifle ammunition, reserve transfer during reload, movement, jump/double jump, grapple acquisition, persistent swing, and second-press release.
- Simultaneous touch movement/fire using the fire position reported by the touch layout, scoring, player damage, pause/resume, and grenade creation. A full forward joystick push must sprint while a sideways push must not, the sprint must stop when that option is off, the second fire button must appear when enabled, auto fire must spend rifle ammunition while an enemy head hitbox is under the crosshair, and a saved layout entry must move and resize its control. Weapon chips, chip reload, run lock, latching and hold-to-aim, look-while-firing, sensitivity scaling, inverted look, gyroscope input, the fixed joystick, and the layout editor's dragging and saving have no automated coverage.
- Synthetic screen-touch events pass through Godot's Input parser to navigate Credits → full notices → Credits → main menu → offline setup. Tests cover swipes starting on buttons, cancellation of button activation during a swipe, taps with four pixels of finger drift, scroll reset on screen changes, and touch pause/resume. Menu buttons pass pointer events to the scroll container, which uses a 12-pixel drag deadzone. Touch-to-mouse emulation is enabled in menus and disabled during gameplay. Physical touchscreen behavior remains unverified.
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

The November 15 current-source debug APK export succeeds and Godot's own signing verification step passes. The independent `apksigner verify --verbose` run, package inspection, and archive inspection below were last performed on the November 11 build and were not repeated. Package inspection confirms application ID `com.doodleshooter.port`, version `0.1.0`, minimum SDK 24, and target SDK 36. Archive inspection confirms ARM64 and x86_64 native libraries, bundled credits, the font license, audio manifest, and enemy data.

The initial attempt failed with `A valid Java SDK path is required in Editor Settings`. Configuring Godot's local `export/android/java_sdk_path` to the installed Temurin 17 JDK resolved the failure; setting `JAVA_HOME` alone did not. No signing credentials were added to the repository. The artifact is `builds/android/doodleshooter-port-debug.apk`.

## Menu, HUD, and touch layout rendering

Graphical capture succeeds on macOS using OpenGL 4.1 Compatibility on Apple M4. After the November 15 pen-style restyle, the main, Credits, offline setup, and LAN setup screens were rendered at 1280×720 and inspected: the main, offline, and LAN screens fit without scrolling and Credits scrolls. One survival frame was captured at 1280×720 with the desktop HUD and one at 1600×720 with touch controls. Screenshots are in `builds/validation/doodleshooter-menu-*.png` and `doodleshooter-game-*.png`; reproduce the menus with `godot --path native --script "$PWD/tools/capture-menus.gd"` and gameplay with `godot --path native -- --capture [--touch]`.

The same build was installed on an Android emulator (1080×2400, landscape). The main menu, offline setup, a survival frame with touch controls, and the pause menu were captured (`builds/validation/android-main.png`, `android-offline.png`, `android-survival-touch.png`, `android-paused.png`). Injected `adb shell input tap` events switched to the shotgun through its weapon chip, latched AIM, and opened the pause menu. In the layout editor (`android-layout-editor.png`) an injected swipe moved FIRE and two BIGGER taps enlarged it; after DONE and an app restart the saved layout was still applied, and RESET restored the defaults. An injected upward swipe past the RUN marker locked running and the player kept moving forward with no finger down (`android-run-lock.png`). The Settings and Touch & aiming screens were captured (`android-settings.png`, `android-touch-settings.png`, `android-touch-settings-2.png`); options toggled there were still set after an app restart, and the optional left fire and reload buttons appeared in play. With gyroscope aiming set to Always, rotation rates injected through `adb emu sensor set gyroscope` turned the camera left for a positive rate around the device's long-edge axis and pitched it down for a positive rate around its short-edge axis, which matches turning a phone held in that landscape rotation. That is a synthetic sensor in one rotation, not a hand-held test. The other `android-*.png` files predate the restyle.

These are still-frame and single-tap checks. They were inspected for layout and style, not compared against the running original. Multitouch, drag-to-look feel, thumb reach on a physical phone, notch/safe-area insets (the emulator reported none), online/lobby/settings screens, the katana tube, boss bar, and scoreboard panel have not been visually verified.

## Unverified behavior and environment limitations

No reference gameplay comparison, listening comparison, physical multitouch test, or device play session has been completed; emulator use is limited to the screenshots and taps described above. Headless execution does not verify GPU shaders, final layouts, frame rates, safe areas, audio mixing, or touchscreen feel.

Earlier ADB and graphical launch attempts were blocked by the environment; desktop graphical capture and emulator installation now work. The export step restarts the ADB daemon, so the emulator briefly reports offline afterwards. A play session on a physical Android device remains outstanding.

Original audio assets include 59 rendered effects and six OGG music variants. Resource loading is exercised headlessly; audible fidelity and music loop transitions require listening tests.

Online mode requires a separately running Python server; the LAN mode hosts its own native server. Complete matches, physical LAN/device networking, lag, reconnection, synchronized destruction, match-clock expiration, and hostile client validation remain unverified. The server caps damage and checks message shapes but trusts movement and hit reports.

## Deferred

The earlier iOS export attempt stopped with `App Store Team ID not specified`. The user explicitly deferred iOS setup. The preset retains `com.doodleshooter.port`; no signing credentials, iOS build, or device validation have been added.

## Port additions (November 15)

Automated checks added: every enemy spawn on the seven port maps reaches the player start on the baked navigation mesh; a corpse's hitboxes are disabled and no longer crash when shot; a smoke cloud blocks only sight lines that cross it; the bazooka launches a friendly rocket and spends its round. Desktop still frames were inspected for the ported hatching, the reload pose, the revolver, SMG and bazooka view models, the Castle map in first person, and the map picker.

Not verified: the animated previews in motion, tracers leaving the muzzle (too brief for the still), shell/bolt/cylinder reload motion, smoke clouds on screen, the hurt vignette and score pop-ups, difficulty and wave-size balance, the graphics detail levels' frame rates, any port map in play, and all of this on Android — the final build was installed on the emulator but not exercised. The Python lobby tests were not rerun because the `.venv` is absent on this machine; `server/lobby.py` changed (new weapon ids, damage entries, and map keys).

## Port additions, second pass (November 15)

Automated checks added: standing in a smoke cloud raises the blur, haze, and sway values and shows the overlay; switching the sway off keeps the blur; the view clears when the cloud is removed; an enemy smoke grenade is created on an upward arc and is not the player's. The port-map navigation check now waits for the navigation server to publish the baked mesh (it arrives a few frames late on the busier maps) before requiring every enemy spawn to reach the player start; all seven maps pass with the added props.

Desktop still frames (macOS, OpenGL Compatibility, 1280×720) were inspected for: Forest, School, Base, and Castle in first person with the round props and tinted pen-colour hatching; the regenerated preview strips of all seven port maps; a smoke cloud seen from 13 m; the view from inside a cloud (grey, blurred world with a sharp HUD); the low-health view; and the round bazooka view model.

Not verified: any of this in motion (cloud billow and fade, sway, double image, rolling horizon, pickup bob), enemies actually choosing to throw smoke during a wave, Hard-difficulty shot leading, frame rate with the extra props and the full-screen blur on a phone GPU, and whether the sway is comfortable on a handheld screen. Nothing in this pass was playtested.

See `PARITY.md` for the remaining comparison and implementation work.
