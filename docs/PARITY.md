# Doodle District parity status

The goal is to reproduce the original game before adding new maps. This table describes implementation, not device validation. A button or model alone does not count as a completed system.

| System | Current implementation | Remaining parity work |
| --- | --- | --- |
| Android runtime | Current signed ARM64/x86_64 debug APK exported; signature, package identity, and bundled resources verified | Install and play on devices; measure performance, heat, and battery use |
| iOS runtime | Shared project and export preset; bundle ID `com.doodleshooter.port` | Deferred by the user; add Team ID, export, build, and test on iPhone/iPad |
| Maps | Geometry and box colliders converted from District and Mexico; arena data included | Compare traversal against the web version; Mexico is disabled in the reference's menu |
| Graphics | Native ink shader, depth outline shader, particles, impact pools, ruled paper, red margin, and handwritten UI font | Render and compare with the original; reproduce normal-based edges and validate mobile GPUs |
| Models | Original weapons, figures, accessories, basic joint animations, and animated damage hitboxes | Compare animations, impacts, dismemberment, and view transitions |
| Movement | Walking, sprinting, double/wall jumps, sliding, air dash, acceleration, friction, air control, step-up, mantling, and jump buffering | Compare traversal and tune timing, collision edge cases, and overall feel against the original |
| Grapple | Hook travel, persistent swing, rope length constraint, reeling, obstruction release, enemy yank, rings, and moving plane colliders | Verify pendulum feel, moving platform behavior, and rope obstruction handling visually and on devices |
| Touch | Floating joystick, look region, simultaneous movement/combat buttons, quick slash, scoreboard, touch-to-mouse emulation in menus only, and scroll gestures starting on menu buttons with a drag deadzone | Physical touch testing, safe areas, responsive placement, sensitivity settings, and scroll/keyboard behavior on phones |
| Controller | Basic stick, button, and trigger mappings | Complete menu navigation, vibration, and device-specific hints |
| Rifle/shotgun/sniper | Ammunition, spread, aiming, interruptible shell reload, pump/bolt delays, scope, recoil, and body-part hitboxes | Compare weapon timing, damage, animations, and scope rendering with the original |
| Katana | Directional block/return, perfect parry window, melee parry, slash combo poses, charge from kills, and solo execution | Compare damage, timing, combo behavior, execution placement, and animation fidelity |
| Grenades | Charged throws, trajectory preview, bouncing physics, fuse, radial damage, impact pools, and effects | Compare trajectory, blast geometry, and effects; validate online synchronization |
| Enemies | Seven types, line of sight, bursts, sniper telegraph, bomber fuse, flyer dive, melee parry, navigation, and body-part hitboxes | Compare AI state transitions, vertical navigation, balance, and effects |
| Bosses | Doodler throw/stomp, Eraser charge/rub, Inkblot hop/spray/summon, five-wave rotation, and health scaling | Compare each pattern, phase, movement, timing, and scaling with the original |
| Survival | Growing waves, spawn queues, intermissions, scoring, pickups, checkpoints, random modifiers, and combo scoring | Hitstop, exact weighted selection, and balance comparison |
| Destructibles | Mexico props with health/removal, piñata pickups, sound, particles, and online removal relay | Debris, taco visuals, effects fidelity, and concurrent destruction behavior |
| Audio | 59 effects rendered from original WebAudio code; both map scores with three intensity variants; persistent volume controls | Listening comparison, original spatial/reel behavior, loop transitions, and device mixing |
| Offline bots | Arena free-for-all with 1–9 bots, three difficulty settings, bot-versus-bot targeting/fire, player damage, scoreboards, automatic respawns, two-second shields, and 20-kill/10-minute limits | Device performance, navigation/stuck cases, difficulty balance, and full match playtesting; this is a port extension |
| LAN | Built-in native host on TCP 8912, direct IPv4 joining, host map/start controls, ten-player cap, late join, scoring, respawns, clock, and destruction relay | Physical-device/Wi-Fi testing, disconnect/lag cases, and long matches; host must stay connected; discovery, LAN host migration, and LAN bots are not implemented |
| Online | Experimental native WebSocket client and Python server; public/private rooms, five-character codes, ten-player cap, quick play, late join, FFA scoring, respawn, host migration, and idle removal | Complete online game sessions against the Python server, device/Internet play, lag/disconnect cases, authoritative hit validation, and original rule comparison; native LAN tests do not verify the separate Python service |
| English language | All port menus, prompts, controls, credits, extracted display names, and project documentation | Preserve English for future changes; retain the historical source snapshot unchanged |
| Attribution | Scrollable Credits sections, original-game/source links, full bundled notices, font and engine license screens, and per-file provenance | Preserve attribution as the project expands |
| New maps | Not started | Begin after reaching and verifying the agreed original-game parity |

Work order: rebuild and validate Android, compare solo movement/combat and presentation against the reference, verify native client/server matches and rules, resume iOS and verify both platforms, then add maps. LAN hosting runs inside the game; online is experimental and requires a separately running server. Interoperability with web lobbies is not implemented.
