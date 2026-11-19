# Reference Assets

This directory holds reference material from the original Doodle Shooter web game used for parity verification and build-time data extraction.

## Tracked in Git (`upstream/` and `manifest.json`)

- `upstream/`: Unmodified historical web source snapshot (~1.8 MB total: ~400 KB of readable `src/` code and ~1.4 MB of vendored dependencies such as Three.js and PeerJS). Do not modify these files; `tools/check.py` verifies their integrity against `manifest.json`.
- `manifest.json`: Source repository metadata, revision, and SHA-256 hashes for `upstream/`.

### Why `upstream/` is kept in version control

- **Offline reproducibility:** External repositories or web deployments can change or go offline. Keeping `upstream/` and its vendored Three.js copy in the repository ensures `tools/check.py`, `make assets-reference`, and `make assets-audio` work reliably without network access or external package installs.
- **Readable parity reference:** `upstream/src/` provides the unminified original source code in a fixed historical state so gameplay mechanics, physics, weapons, and levels can be verified against a stable baseline.
- **Documented provenance:** `upstream/` comes from the historical source repository with its origin, revision, and license notices preserved in `manifest.json` and `upstream/`.

## Untracked Deployed Web Snapshots (`reference/web-*/`)

Deployed web bundles (such as `reference/web-2026-11-19/`) are excluded from version control via `.gitignore`.

### Why `reference/web-*/` is excluded from Git

- **No inferred license:** Unlike `upstream/`, the deployed bundle is a minified build artifact fetched from the live site without an inferred code license, so it should not be redistributed in the repository.
- **Secret-scanner false positives:** The minified bundle and SHA-256 manifest trigger high-entropy string false positives in pre-commit secret scanners.
- **Not needed for normal builds or checks:** `tools/extract-jungle.mjs` already generated `native/data/jungle.json` and `native/data/jungle_arena.json`, which are committed directly to the repository. Normal builds and `python3 tools/check.py` do not require `reference/web-*/`.

### How to obtain `reference/web-2026-11-19/`

If you need to re-run `tools/extract-jungle.mjs` to regenerate the Doodle Jungle map data:

1. Create the directory:
   ```sh
   mkdir -p reference/web-2026-11-19
   ```
2. Download the deployed page and bundle from the original game:
   ```sh
   curl -fsSL https://doodleshooter.vercel.app/ -o reference/web-2026-11-19/index.html
   curl -fsSL https://doodleshooter.vercel.app/game.7LCERBLR.js -o reference/web-2026-11-19/game.7LCERBLR.js
   ```
3. Generate `reference/web-2026-11-19/manifest.json` with the local SHA-256 checksums expected by `tools/extract-jungle.mjs`:
   ```sh
   python3 - <<'PY'
   import hashlib, json
   from pathlib import Path

   ref = Path("reference/web-2026-11-19")
   manifest = {
       "original_game": "https://doodleshooter.vercel.app/",
       "bundle_url": "https://doodleshooter.vercel.app/game.7LCERBLR.js",
       "retrieved": "2026-11-19",
       "notes": "Deployed original-game assets supplying Doodle Jungle, which is absent from the historical repository snapshot. Build-time reference only; not shipped in the native app. No game-code license is inferred.",
       "files_sha256": {
           name: hashlib.sha256((ref / name).read_bytes()).hexdigest()
           for name in ("index.html", "game.7LCERBLR.js")
       },
   }
   (ref / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
   PY
   ```
4. Run the extractor (requires Node.js):
   ```sh
   node --experimental-vm-modules tools/extract-jungle.mjs
   ```
