# Project instructions

- Use English for all game UI, prompts, controls, display names, comments, and project documentation.
- Project name: `doodleshooter-port`. The name combines porting and portability.
- Android application ID and iOS bundle identifier: `com.doodleshooter.port`.
- Build a native Android/iOS port with the shared Godot project in `native/`.
- Keep reproducing and verifying the original game's behavior. The user asked for extra maps, weapons, and options before parity was reached; always label such port additions as not part of the original in the game, `docs/PARITY.md`, and the credits.
- Preserve clear original-game attribution in the game and in `CREDITS.md` / `native/CREDITS.txt`.
- Keep `reference/upstream/` unchanged as a historical snapshot, including its original localization and embedded license notices. It is not shipped in the native app. Convert display strings to English when extracting native data.
- iOS export/signing work is deferred at the user's request. Do not invent Apple signing credentials.
- Run `python3 tools/check.py` after gameplay changes. Keep `docs/PARITY.md` and `docs/VALIDATION.md` accurate; do not claim visual or device verification from headless tests.
