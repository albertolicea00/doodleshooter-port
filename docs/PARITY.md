# Doodle District parity status

The goal is to reproduce the original game before adding new maps. This table describes implementation, not device validation. A button or model alone does not count as a completed system.

| System | Current implementation | Remaining parity work |
| --- | --- | --- |
| Android runtime | Signed ARM64/x86_64 debug APK generated and signature verified | Install and play on devices; measure performance, heat, and battery use |
| iOS runtime | Shared project and export preset; bundle ID `com.doodleshooter.port` | Deferred by the user; add Team ID, export, build, and test on iPhone/iPad |
| Maps | Geometry and box colliders converted from District and Mexico; arena data included | Compare traversal against the web version; Mexico is disabled in the reference's menu |
| Graphics | Native ink shader, static surface hatching, ruled paper, and red margin | Reproduce depth/normal postprocessing and original outlines; validate mobile GPUs |
| Models | Weapons, figures, and accessories converted from original generators | Reproduce animations, impacts, and view transitions |
| Movement | Walking, sprinting, jumping, double jumping, wall jumping, sliding, and air dashing | Match acceleration, friction, air control, step-up, mantling, jump buffering, and overall feel |
| Grapple | Native raycast, attachment, pulling, energy drain, and recovery | Pendulum rope, length constraints, hook travel, rideable planes, and rope cutting |
| Touch | Floating joystick, look region, simultaneous movement/combat buttons | Real multitouch testing, safe areas, responsive placement, and sensitivity settings |
| Controller | Basic stick, button, and trigger mappings | Complete menu navigation, vibration, and device-specific hints |
| Rifle/shotgun/sniper | Magazines, reserves, fire intervals, spread, damage, aiming, and basic reloads | Shell-by-shell shotgun reload, pumping, bolt cycle, scope, recoil, and exact hitboxes |
| Katana | Slashing, directional projectile blocking/return, charge, and basic execution | Exact parry windows, damage, combos, charge from kills, and animations |
| Grenades | Charged throws, bouncing physics body, fuse, and radial damage | Trajectory preview, scorch marks, and original effects |
| Enemies | Seven types with reference stats, native navigation, projectiles, and behavior variations | Exact AI states, bursts, body-part hitboxes, vertical navigation, and effects |
| Bosses | Doodler/Eraser/Inkblot models, stats, five-wave rotation, shared radial attack | Each boss's original attack patterns, phases, movement, and complete scaling |
| Survival | Growing waves, spawn queues, intermissions, scoring, pickups, and five-wave checkpoints | Modifiers, combos, hitstop, exact weighted selection, and balance |
| Destructibles | Individual Mexico props with health/removal; piñatas produce health pickups | Debris, taco visuals, sounds, and destruction effects |
| Audio | Basic native procedural sound effects | Port original melodies and WebAudio effects |
| Online | Not implemented; the menu explicitly marks it as unfinished | Native transport, matchmaking, public/private lobbies, codes, ten players, late join, scoring, respawn, and disconnect handling |
| English language | All port menus, prompts, controls, credits, extracted display names, and project documentation | Preserve English for future changes; retain the historical source snapshot unchanged |
| Attribution | In-game Credits screen, bundled notice, and per-file provenance | Preserve attribution as the project expands |
| New maps | Not started | Begin after reaching and verifying the agreed original-game parity |

Work order: validate the Android foundation, finish solo movement/combat and presentation, implement networking and match rules, resume iOS and verify both platforms, then add maps. Online play is not presented as working, and interoperability with web lobbies is not promised.
