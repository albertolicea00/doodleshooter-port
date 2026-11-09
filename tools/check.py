#!/usr/bin/env python3
"""Run native integration checks and fail on script errors, not only exit codes."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
GODOT = os.environ.get('GODOT_BIN') or shutil.which('godot')
if not GODOT:
    raise SystemExit('Godot 4.6.3 is required. Set GODOT_BIN or add godot to PATH.')
manifest = json.loads((ROOT / 'reference/manifest.json').read_text())
for relative, expected in manifest['files_sha256'].items():
    actual = hashlib.sha256((ROOT / 'reference/upstream' / relative).read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f'Reference changed unexpectedly: {relative}')
print('PASS: reference source hashes')

def run(extra, tag):
    logfile = Path(tempfile.gettempdir()) / f'doodleshooter-check-{tag}.log'
    command = [GODOT, '--headless', '--path', str(ROOT / 'native'), '--log-file', str(logfile), *extra]
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=90)
    except subprocess.TimeoutExpired as error:
        print((error.stdout or b'').decode() if isinstance(error.stdout, bytes) else error.stdout)
        raise SystemExit(f'FAIL: {tag} timed out')
    output = result.stdout
    if result.returncode or any(error in output for error in ['SCRIPT ERROR', 'Parse Error', 'Assertion failed', 'SHADER ERROR']):
        print(output)
        raise SystemExit(f'FAIL: {tag}; log: {logfile}')
    if tag == 'smoke' and output.count('SMOKE PASS:') != 2:
        print(output)
        raise SystemExit('FAIL: smoke did not reach both completion markers')
    print('\n'.join(line for line in output.splitlines() if line.startswith('SMOKE PASS:')) or f'PASS: {tag}')
    print(f'Log: {logfile}')

run(['--editor', '--import'], 'import')
try:
    run(['--', '--smoke'], 'smoke')
finally:
    (ROOT / 'native/.smoke-progress.cfg').unlink(missing_ok=True)
