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
| Touch | Floating joystick, look region, simultaneous movement/combat buttons | Real multitouch testing, safe areas, responsive placement, and sensitivity settings |
| Controller | Basic stick, button, and trigger mappings | Complete menu navigation, vibration, and device-specific hints |
| Rifle/shotgun/sniper | Ammunition, spread, aiming, interruptible shell reload, pump/bolt delays, scope, recoil, and body-part hitboxes | Compare weapon timing, damage, animations, and scope rendering with the original |
| Katana | Directional block/return, perfect parry window, melee parry, slash combo poses, charge from kills, and solo execution | Compare damage, timing, combo behavior, execution placement, and animation fidelity |
| Grenades | Charged throws, trajectory preview, bouncing physics, fuse, radial damage, impact pools, and effects | Compare trajectory, blast geometry, and effects; validate online synchronization |
| Enemies | Seven types, line of sight, bursts, sniper telegraph, bomber fuse, flyer dive, melee parry, navigation, and body-part hitboxes | Compare AI state transitions, vertical navigation, balance, and effects |
| Bosses | Doodler throw/stomp, Eraser charge/rub, Inkblot hop/spray/summon, five-wave rotation, and health scaling | Compare each pattern, phase, movement, timing, and scaling with the original |
| Survival | Growing waves, spawn queues, intermissions, scoring, pickups, checkpoints, random modifiers, and combo scoring | Hitstop, exact weighted selection, and balance comparison |
| Destructibles | Mexico props with health/removal, piñata pickups, sound, particles, and online removal relay | Debris, taco visuals, effects fidelity, and concurrent destruction behavior |
| Audio | 59 effects rendered from original WebAudio code; both map scores with three intensity variants; persistent volume controls | Listening comparison, original spatial/reel behavior, loop transitions, and device mixing |
| Online | Experimental native WebSocket client and Python server; public/private rooms, five-character codes, ten-player cap, quick play, late join, FFA scoring, respawn, host migration, and idle removal | End-to-end Godot client sessions, device/LAN play, lag/disconnect cases, authoritative hit validation, and original rule comparison; server protocol tests alone do not verify a playable match |
| English language | All port menus, prompts, controls, credits, extracted display names, and project documentation | Preserve English for future changes; retain the historical source snapshot unchanged |
| Attribution | In-game Credits screen, bundled notice, and per-file provenance | Preserve attribution as the project expands |
| New maps | Not started | Begin after reaching and verifying the agreed original-game parity |

Work order: rebuild and validate Android, compare solo movement/combat and presentation against the reference, verify native client/server matches and rules, resume iOS and verify both platforms, then add maps. Online is experimental and requires a separately running server. Interoperability with web lobbies is not implemented.
