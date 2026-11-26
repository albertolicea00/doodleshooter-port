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

## Port additions, third pass (November 15)

`python3 tools/check.py` passes with cylinder colliders on the port maps' round props and the new shading style. Desktop still frames (1280×720) were inspected for District, Harbor, and School in the coloured-pencil style, and all nine preview strips were re-rendered in it.

Not verified: collision against the cylinder colliders in play (walking around trees, shooting past barrels, standing on canopies), the new props from every angle, the original-hatching option after the shader change beyond one District still, and the frame-rate cost of the pencil shader on a phone GPU (it samples noise about ten more times per pixel than the hatching).

See `PARITY.md` for the remaining comparison and implementation work.

## Survival difficulty rebalance (November 19)

Survival now offers four port-only tiers: Easy, Normal (former Easy), Hard (former Normal), and Insane (former Hard). Normal remains the default. Easy uses 0.35× base enemy damage, 0.5× enemy health, and 0.5× ordinary wave counts, and halves boss-wave escorts; the existing global 1.2 damage multiplier still applies. Enemy smoke remains exclusive to the two highest tiers, and predictive gunner aiming to Insane. The separate bot difficulty settings are unchanged.

Headless smoke checks exercise all four tiers through actual wave-one starts: damage multipliers of 0.42/0.72/1.2/1.62, health multipliers of 0.5/0.75/1.0/1.3, and queues of 4/5/7/9 enemies at the default wave size. Import, both gameplay smoke markers, native LAN protocol checks, and both LAN game behavior markers passed. The first full checker run nevertheless failed because the guest process reported six resources still in use at exit; an immediate repeat of `python3 tools/check.py` passed in full. No visual, Android, or hands-on difficulty-balance verification was performed for this change.

## Bot difficulty rebalance (November 19)

The follow-up applies the same four-tier scale to offline bots: Normal retains former Easy tuning, Hard retains former Normal tuning, and Insane retains former Hard tuning. New Easy bots wait 0.75 seconds between shots and use 0.2 random aim spread (Normal: 0.48 seconds and 0.12; Hard: 0.3 and 0.065; Insane: 0.19 and 0.028). The selector and match HUD use all four names. The bot integration smoke scenario now requests Insane and asserts that the match accepts tier 3 before exercising bot combat. `python3 tools/check.py` passed in full after this follow-up, including both gameplay smoke markers and all LAN checks. No visual, device, or hands-on balance verification was performed for this follow-up.

## Bot count selector (November 19)

Replaced the offline bot count dropdown with a centered count between minus and plus buttons. The decrement button is disabled at 1 and increment at 9. `python3 tools/check.py` passed in full. A temporary graphical harness emitted button signals to increase from 1 to 9 and decrease back to 1, verifying the count, singular/plural labels, and disabled limits. Desktop screenshots of both endpoints were inspected at 1280×720 using macOS OpenGL Compatibility; captures are `/private/tmp/doodleshooter-bot-selector/bot-count-1.png` and `bot-count-9.png`. This verifies desktop layout and callbacks, not physical touch input or Android behavior.

## Expanded bot count and compact selector (November 19)

Offline matches now allow 1–30 bots (up to 31 participants including the player). The centered minus/count/plus group originally used a fixed 120-pixel counter (now 100 pixels to fit beside duration) so the buttons sit close to the number. A red inline performance warning appears at 20 bots; at 30 it changes to a stronger playful warning. Both warnings allow starting the match.

A temporary graphical harness verified increasing/decreasing the count, clamping at 1 and 30, showing the warning at 20, hiding it again at 19, and changing its text at 30 and back at 29. The final desktop layout at 30 bots was rendered and inspected at 1280×720 using macOS OpenGL Compatibility (`/private/tmp/doodleshooter-bot-selector/bot-count-30-warning.png`). `python3 tools/check.py` passed with the expanded limit; its gameplay smoke scenario creates 30 bots and verifies 31 scoreboard entries before running the existing three-bot combat scenario. The final spacing adjustment was then verified with the graphical harness. No physical-device input, full 30-bot match, or frame-rate measurement was performed.

## Offline mode cards and matching start buttons (November 19)

Play offline now uses two side-by-side paper cards, one for survival and one for offline bots. The page title, connection note, and Back button sit outside both cards. Each card contains its own options and a blue start button at the bottom. Both start buttons share the same size and align horizontally. Back has a red outline and red text with no fill, and bot difficulty appears above the bot count. Returning to another menu restores its standard single-panel layout.

`python3 tools/check.py` passed after the card restructuring. Subsequent presentation refinements (card margins, compact wording, height updates when warnings change, and equally sized blue start buttons, a red outlined Back button, and bot difficulty above the count) were checked using the temporary graphical harness. Desktop captures at 1280×720 were inspected with the default bot count and with the 30-bot warning; the final layout fits the title, both cards, and Back. The selector harness still passes its count-limit and warning-transition checks. The final 30-bot capture is `/private/tmp/doodleshooter-bot-selector/bot-count-30-warning.png`. No Android or physical-touch verification was performed for this layout.

## Configurable offline bot match duration (November 19)

The bot card now has a centered minus/plus duration selector: 5–30 minutes in five-minute steps. The time and bot-count selectors share one horizontal row; the time selector shows only minutes, and the description above updates with the selected time and kill target. The target is two kills per minute (5/10, 10/20, 15/30, 20/40, 25/50, 30/60). The selected duration is saved under `bots.minutes`; new installs default to 10 minutes. The match controller, HUD, and pause summary all use the selected limit. The round ends at that kill target or when the clock expires. This is a port addition; LAN and online rules are unchanged.

`python3 tools/check.py` passed in full. Gameplay smoke coverage starts a 15-minute/30-kill round, checks its 900-second clock, verifies that 20 kills do not finish it, then reaches 30 and verifies completion. It also starts a 5-minute/10-kill round, checks its 300-second clock, and advances the final fraction of a second to verify timeout completion. A temporary graphical harness checks both duration-selector endpoints, their proportional labels, and the saved duration value read back from a temporary config file; existing bot count/warning checks still pass.

The desktop layout with 30 bots, the performance warning, and the new duration selector was rendered and inspected at 1280×720. Card spacing was tightened so both start buttons and Back fit. The final capture remains `/private/tmp/doodleshooter-bot-selector/bot-count-30-warning.png`. No full timed match, Android/device layout, or physical touch input was verified for this change.

The duration/count row refinement was verified with the graphical harness: the time label shows only minutes, changing to 30 minutes updates the description to 60 kills, and changing to 5 updates it to 10 kills. Count limits and warning transitions still pass. The final desktop capture at 1280×720 was inspected with both selectors side by side, the 30-bot warning, both blue start buttons, and the red outlined Back button visible. This follow-up changes menu presentation only; the full gameplay checker was not rerun after it.

## Main menu network row (November 19)

Play Online and Local Network now share a horizontal row in the main menu; the Local Network button no longer includes the LAN suffix. The existing callbacks are retained. Desktop menu captures were rendered and the main menu was inspected at 1280×720 using macOS OpenGL Compatibility (`/private/tmp/doodleshooter-main-network-row/doodleshooter-menu-main.png`). Both labels fit, and the complete menu remains visible. This presentation-only change was not verified on Android; the full gameplay checker was not rerun.

## Main menu Exit button (November 19)

Added Exit below the Controls/Settings/Credits row, using the red outline button style. It calls `SceneTree.quit()` when activated. A temporary headless harness verified the label, style variation, placement, and successful process termination through the button signal. The graphical capture attempt stalled before reaching the main menu and was stopped; this new button has not been visually or device verified. No gameplay logic changed, and the full gameplay checker was not rerun.

The main-menu footer now displays `v0.1.0 · development build` beneath Exit, with no best-score text. It reads the version from `application/config/version`, matching the existing export presets. This text-only footer change was checked in source; it was not rendered or device verified.

## Controls reference layout (November 19)

Controls now uses a wide two-column reference: Mouse + Keyboard and PS5 Controller, with red input labels, blue action text, and ruled headings. The reference reflects the native input map rather than copying unsupported bindings from the supplied visual reference: Q grapples, C slides/dashes, R3 throws grenades, and unbound controller scoreboard/smoke shortcuts are omitted. Wall jump, double jump, rope release, charged katana execution in survival, and the seven-weapon loadout are documented. Touch instructions remain below the columns, followed by a red outlined Back button. Gameplay inputs and sensitivity were not changed.

A temporary graphical harness rendered and captured the top and bottom at 1280×720 using macOS OpenGL Compatibility (`/private/tmp/doodleshooter-controls.png` and `/private/tmp/doodleshooter-controls-bottom.png`). Both captures were inspected, including the PlayStation symbols. The harness scrolled to the touch reference, activated Back, and verified return to the main menu with its standard 680-pixel panel width. No physical controller, touch, or Android verification was performed; the full gameplay checker was not rerun for this presentation-only change.

The controls follow-up integrates revolver, SMG, and bazooka into the normal weapon-switching list and removes the separate port-loadout annotation from this reference. Existing port-addition attribution remains in credits and parity documentation. Square and triangle now use bundled 24×24 SVG icons rendered inline at 22×22, avoiding the tiny fallback font glyphs. Godot asset import passed; the graphical controls harness passed again, and the updated desktop capture was inspected for readable symbols and the wrapped weapon list. Android rendering remains unverified.

Circle and cross now use matching bundled SVG icons too, with the same 22×22 inline size, red stroke, and weight as square and triangle. Asset import and the graphical controls harness passed; the refreshed desktop capture was inspected for all four shapes. Device rendering remains unverified.

## Xbox controller reference (November 19)

The controller column now has PS5 Controller and Xbox Controller tabs. Xbox labels reflect the existing Godot joypad input map: A jumps, B slides/dashes, X reloads, Y changes weapon, LB grapples, RB performs a quick slash, LT aims/blocks, RT fires/slashes, LS click sprints, RS click throws grenades, and Menu pauses. The choice remains selected when reopening Controls during the current session. The input map and gameplay behavior are unchanged.

A temporary graphical harness verified Xbox labels, switching back to the PS5 inline icons, and retaining Xbox selection when rebuilding Controls. The Xbox desktop capture at 1280×720 (`/private/tmp/doodleshooter-controls-xbox.png`) was inspected for layout and text. The existing controls scrolling/Back harness also passed with the tabs. This verifies reference UI only; no physical Xbox/PS5 controller or Android connection was tested, and the full gameplay checker was not rerun for this presentation-only change.

The PS5/Xbox picker now uses plain text headings with transparent button styles and an underline for the selected heading (also shown for keyboard focus), rather than outlined boxes. The graphical selector harness passed again after explicitly updating toggle state when emitting its synthetic button signals, and the refreshed Xbox capture was inspected with the Xbox heading underlined. No gameplay changes were made.

## Card menu restyling and LAN bots (November 19)

Controls, Settings, Touch & aiming, Credits, Full credits & notices, Godot Engine license, Play online, Local network · LAN, and Lobby now use card-based layouts with outer titles/subtitles and red outlined Back/Leave buttons (Main menu Exit also uses the compact 240 px red outline style, and Local network uses the blue outline style). LAN hosting now supports host-configurable match duration (5–30 minutes, `2 * min` kill target), 0–30 host-simulated LAN bots (default 1; difficulty disabled at 0 bots), a 12-slot lobby capacity (counting the host, connected human guests, and 1 slot for bots when bots > 0, shown in four 3-row bulleted columns under the host IP note), and a full-width 9-map selector strip for the LAN host.

Headless `python3 tools/check.py` (with `tests/lan_game_peer.gd` setting `lan_bot_count = 0` for its two-player loopback run) is used to verify imports, smoke gameplay, and 2-player LAN protocol/game flow; LAN bot matches (`lan_bot_count > 0`), multi-device Wi-Fi play, 12-slot lobby capacity, and visual rendering of the updated card layouts have not been verified on devices or visually inspected.

### Lobby subtitle and map selection (November 19)

Added host setup guidance and guest waiting guidance below the lobby title. Map cards now keep a subtle outline in all button states and put the selected blue fill only behind the map title. This presentation change has not been visually or device verified. `python3 tools/check.py` passed reference hashes, import, both gameplay smoke markers, and native LAN protocol checks; the two-process LAN game check failed waiting for the two-player lobby/arena load, followed by a null-player error. The full checker therefore did not pass. The first sandboxed attempt also failed on macOS certificate/editor-settings access; the reported checks are from the subsequent unrestricted run.

### Map card styling revision (November 19)

Restored the previous blue selection/border styling and original title spacing, retaining the lobby subtitle. A preview shader rounds only the upper image corners, using local coordinates so animated atlas frames and covered image scaling retain the same corner radius. This revision has not been visually or device verified.

Godot headless editor import passed for this presentation revision. No gameplay checks were rerun because gameplay was unchanged; headless import does not verify shader rendering.

### Inline offline map picker (November 19)

Play offline now uses the same compact animated nine-map row as the LAN host, between its subtitle and setup cards. A temporary graphical harness verified all nine cards, selecting Castle, and retaining bot count/time across the menu rebuild. The resulting 1280×720 desktop screenshot (`/private/tmp/doodleshooter-offline-preview.png`) was inspected: the map strip appears above both setup cards with rounded upper preview corners and blue selected-card styling. The Back button requires scrolling at this viewport. This is desktop UI verification, not physical-device or gameplay verification.

`python3 tools/check.py` passed for this change: reference hashes, import, both gameplay smoke markers, native LAN protocol, and both host/guest LAN game completion markers.

### Smoother map preview rotation (November 19)

Regenerated all nine preview atlases using the native renderer: 120 evenly spaced angles (3° steps) in a 12×10 grid of 160-pixel cells. Playback is 30 fps with a four-second orbit, replacing ten angles (36° steps) changing every 0.16 seconds. Atlas filtering clips each cell to avoid sampling neighbouring views. The shared picker applies this to offline, LAN, and the full map menu.

A temporary graphical harness passed checks for all nine 1920×1600 atlases, frame bounds across all ten rows, wrap after 120 steps, and automatic timer progression. Desktop screenshots around the loop boundary (`/private/tmp/doodleshooter-smooth-frame-0.png` and `doodleshooter-smooth-frame-119.png`) were inspected for rendering and consistent layout. These checks do not establish perceived smoothness or performance on physical phones. The denser atlases increase menu texture memory; phone performance remains unverified.

`python3 tools/check.py` passed after the preview update: reference hashes, import, both smoke markers, LAN protocol, and host/guest game integration.

### Keep previews animated during selection (November 19)

Offline selection no longer rebuilds the menu or replaces its preview textures. A ButtonGroup updates the exclusive highlight and title colours in place. Preview regions use a shared uptime-based phase so lobby rebuilds retain the orbit phase too. A temporary graphical harness selected Castle, Station, Base, then District, verifying all nine textures advanced after each selection, the same row survived, exactly one card remained pressed, and bot count/time were retained. It also verified a rebuilt picker starts at the current shared phase. The desktop screenshot `/private/tmp/doodleshooter-selection-animation.png` was inspected for the retained layout/highlight. Physical phone behavior and network-triggered lobby redraw performance remain unverified.

`python3 tools/check.py` passed after this fix: source hashes, import, both smoke markers, LAN protocol, and host/guest LAN integration.

### Preserve the LAN map row during server updates (November 19)

The prior shared-clock fix retained orbit phase but still destroyed/recreated LAN preview controls on every lobby acknowledgment. `show_lobby()` now temporarily reparents the existing LAN host map row while rebuilding the remaining lobby controls, then restores it and synchronizes the authoritative selected map. Textures, materials, buttons, and the timer remain alive. Leaving the lobby still frees the row.

A temporary graphical harness hosted an actual loopback LAN room, selected Castle, Station, Base, and District through the real button/server acknowledgment path, and sent a config update. It verified row/timer/texture identity, advancing regions for all nine maps after every selection, exclusive selection, retention across the config acknowledgment, and row cleanup on leaving. The 1280×720 desktop screenshot `/private/tmp/doodleshooter-lan-animation.png` was inspected for the retained strip and layout. This does not verify phone smoothness or physical Wi-Fi play.

`python3 tools/check.py` passed reference hashes, import, both gameplay smoke markers, and LAN protocol checks, but its two-process game test timed out waiting for the lobby/arena load, followed by null-player errors. The full invocation therefore failed.

An isolated rerun of the unchanged `run_lan_game()` function from `tools/check.py` passed both host and guest completion markers. The earlier full-run timeout remains recorded above.

## Original Jungle and online map selector (November 19)

The deployed original website at https://doodleshooter.vercel.app/ offers District and Jungle as its two public maps; Jungle is absent from the historical `reference/upstream/` revision. The deployed HTML/bundle were archived unchanged in `reference/web-2026-11-19/` with a SHA-256 manifest, independently of the unchanged historical snapshot. `tools/extract-jungle.mjs` verifies the bundle hash and converts its Jungle builder deterministically using the archived Three.js 0.170 dependency. Geometry/normals are rounded to five decimals. Both survival/arena files preserve 647 box colliders, 17 enemy spawns, 12 sniper spots, 28 arena spawns, pickup/ring positions, 20 grapple targets, the map palette/paper colour, and all 25 animation formulas (15 swinging lianas and ropes, five flying birds with wing flaps, five flames). The original soundtrack selector uses the District score for Jungle, as does the native map.

`tests/jungle.gd` checks survival and bot-arena loading, counts/spawns, a physical ground ray at the player start, palette restoration when returning to District, and native positions/scales/quaternions against source-generated motion fixtures at 0, 1.25, and 7 seconds, including rope and wing transforms. The full native checker now runs this test and verifies both reference manifests. LAN protocol and Python lobby tests include Jungle map selection. These are automated checks, not original traversal/feel parity or device testing. Loose props remain static, health pickups still use the generic native model, and moving grapple targets use native sphere colliders instead of the original web aim-assist test.

A native desktop scenic capture was inspected and saved as `docs/screenshots/jungle.jpg`. The new 120-frame Jungle preview was generated with the native renderer. Desktop UI screenshots `/private/tmp/doodleshooter-offline-jungle.png` and `/private/tmp/doodleshooter-online-selector.png` were inspected at 1280×720: all ten offline cards fit in their strip; Play online shows only the compact District/Jungle buttons with their original English blurbs, immediately to the right of the server URL. Offline/LAN retain the animated map selector.

A temporary graphical harness verified exclusive online selection, retained typed name/server values, session retention, and that Quick Play, Create private lobby, and Create public lobby all use the chosen Jungle key (requests intercepted locally, without contacting an external service). It also verified the offline map choice stays independent and all ten offline cards remain available. This does not establish a real Internet game session.

`python3 -m unittest discover -s tests -p 'test_lobby.py'` passed all seven server tests, including Jungle selection. The first full native-check attempt passed source hashes/import and the District smoke marker but timed out during the remaining smoke run; it did not reach the Jungle or LAN stages.

## Menu polish, controller navigation, and background replay (November 19)

`native/scripts/game.gd`, `native/scripts/pen.gd`, and `native/scripts/replay.gd` were updated with the Play Offline `CHECKPOINT · WAVE <N>` red-outlined button, main menu layout (`DOODLE SHOOTER port`, `START`, `PLAY LAN`, stacked info buttons), global tilted headers with tight subtitle spacing, borderless full-height scroll with 12 px inner padding, non-selectable `RichTextLabel` text, `PS CONTROLLER` label, top-center controller navigation hint (hidden on scroll), black 4 px focus outlines on buttons and `LineEdit`s with focus blip/pulse, `ui_cancel` back support, `LineEdit` initial-focus skipping, license/full-credits autoscroll, and the `DoodleReplay` menu background recorder/player (`user://last_replay.json` with a default District loop).

Headless Godot tests verified the Play Online custom-map selector (`ONLINE_SELECTOR_PASS`) and Play Offline checkpoint button (`OFFLINE_CHECKPOINT_PASS`). `python3 tools/check.py` passed all stages after the `DoodleReplay` orientation fix (`player.rotation.y` / `player.camera.rotation.x`). Interactive controller feel, visual alignment, and live background replay smoothness were not verified by automated headless checks.

## Normalized back buttons and desktop export presets (November 19)

- **Back-button normalization (`native/scripts/game.gd`):** `_back_button` now defaults to `"BACK TO MAIN MENU"` (`RedButton`, red filled) when returning to the main menu. Submenus that return to an intermediate screen (`BACK TO PAUSE`, `BACK TO SETTINGS`, `BACK TO CONTROLS`, `BACK TO CREDITS`, `BACK TO LOBBY`, `BACK TO ONLINE`, `BACK TO LAN`) render the immediate back button on the left (`RedOutlineButton`) and `"BACK TO MAIN MENU"` (`RedButton`) on the right. `_find_back_button` matches `"RESUME"` or any `"BACK..."` label, and `run_smoke()` was updated to tap `"BACK TO MAIN MENU"`.
- **Desktop support (`native/export_presets.cfg`, `native/project.godot`, `native/scripts/game.gd`):** Added `Windows Desktop` (`x86_64`), `Linux` (`x86_64`), and unsigned `macOS` (`universal`, `com.doodleshooter.port`, `codesign=0`) export presets; enabled `textures/vram_compression/import_s3tc_bptc=true`; and added a non-mobile `Fullscreen` toggle in Settings persisted under `video/fullscreen`.
- **Verification:** `godot --headless --path native --editor --import` exited with code `0` after the final edits. Earlier, after the back-button edits, `python3 tools/check.py` passed `reference source hashes` and `import` and printed `SMOKE PASS: ...`, but exited with code `1` on a pre-existing `replay.gd:58` `yaw` error before reaching `jungle`, `lan`, or `lan_game`. Desktop export binaries and windowed desktop rendering were not run.


## Controller menu and gameplay mappings (November 26)

- **Menu input mappings (`native/scripts/game.gd`, `native/scripts/player.gd`):** Bound `JOY_BUTTON_A` (Xbox A / PlayStation ✕) to `ui_accept` and `JOY_BUTTON_B` (Xbox B / PlayStation ○) to `ui_cancel` in `_setup_inputs()`, updated the top-center menu hint to render the bundled Cross/Circle SVG icons (`A / ✕` and `B / ○`), debounced/rate-limited menu `ui_up`/`ui_down`/`ui_left`/`ui_right`/`ui_accept`/`ui_cancel` events (150 ms press debounce, 185 ms echo interval) so duplicate controller/OS key events and fast key-repeat step one item at a time, extended `_find_back_button` to match `"CANCEL"` and `"LEAVE LOBBY"`, and released GUI focus while suppressing `jump`/`dash` triggers for two physics frames in `resume_game()`.
- **Gameplay controller & wheel mappings (`native/scripts/game.gd`, `native/scripts/player.gd`):** Added `prev_weapon` (`MOUSE_BUTTON_WHEEL_UP` and `JOY_BUTTON_DPAD_LEFT`) alongside `next_weapon` (`MOUSE_BUTTON_WHEEL_DOWN`, `JOY_BUTTON_Y`, and `JOY_BUTTON_DPAD_RIGHT`), `JOY_BUTTON_DPAD_UP` for frag grenades (in addition to `JOY_BUTTON_RIGHT_STICK`), `JOY_BUTTON_DPAD_DOWN` for port-only smoke grenades, `JOY_BUTTON_BACK` (Create / View) for the arena scoreboard, `sprint_toggle` on `JOY_BUTTON_LEFT_STICK` (L3 toggles sprint while moving forward, matching the original), right-stick look scaling/aim-down-sights sensitivity/vertical inversion via `DoodleTouchControls.turn()`, and updated PS/Xbox Controls reference cards.
- **Verification:** Synthetic `InputEventJoypadButton`, `InputEventJoypadMotion`, and `InputEventMouseButton` coverage in `run_smoke()` verifies menu confirm/back (`JOY_BUTTON_A` / `JOY_BUTTON_B`), pause/resume without jump or slide leaks, D-pad Left/Right and mouse wheel up/down weapon switching, D-pad Down smoke grenade throws, D-pad Up charged frag throws, L3 sprint toggle and stop-reset, right-stick sensitivity and vertical inversion, and Create/View scoreboard display in bot matches. Physical controller hardware and visual layout rendering were not verified by headless tests.
