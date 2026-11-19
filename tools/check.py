#!/usr/bin/env python3
"""Run native integration checks and fail on script errors, not only exit codes."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parent.parent
GODOT = os.environ.get('GODOT_BIN') or shutil.which('godot')
if not GODOT:
    raise SystemExit('Godot 4.6.3 is required. Set GODOT_BIN or add godot to PATH.')
manifest = json.loads((ROOT / 'reference/manifest.json').read_text())
for relative, expected in manifest['files_sha256'].items():
    actual = hashlib.sha256((ROOT / 'reference/upstream' / relative).read_bytes()).hexdigest()
    if actual != expected:
        raise SystemExit(f'Reference changed unexpectedly: {relative}')
for snapshot in (ROOT / 'reference').glob('web-*/manifest.json'):
    extra = json.loads(snapshot.read_text())
    for relative, expected in extra['files_sha256'].items():
        if hashlib.sha256((snapshot.parent / relative).read_bytes()).hexdigest() != expected:
            raise SystemExit(f'Deployed reference changed unexpectedly: {relative}')
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
    if result.returncode or any(error in output for error in ['ERROR:', 'Parse Error', 'Assertion failed']):
        print(output)
        raise SystemExit(f'FAIL: {tag}; log: {logfile}')
    if tag == 'smoke' and output.count('SMOKE PASS:') != 2:
        print(output)
        raise SystemExit('FAIL: smoke did not reach both completion markers')
    if tag == 'jungle' and 'JUNGLE PASS:' not in output:
        raise SystemExit('FAIL: Jungle check did not reach its completion marker')
    if tag == 'lan' and 'LAN PASS:' not in output:
        raise SystemExit('FAIL: native LAN test did not reach its completion marker')
    print('\n'.join(line for line in output.splitlines() if line.startswith(('SMOKE PASS:', 'LAN PASS:', 'JUNGLE PASS:'))) or f'PASS: {tag}')
    print(f'Log: {logfile}')

run(['--editor', '--import'], 'import')
try:
    run(['--', '--smoke'], 'smoke')
finally:
    (ROOT / 'native/.smoke-progress.cfg').unlink(missing_ok=True)
run(['--script', str(ROOT / 'tests/jungle.gd')], 'jungle')
run(['--script', str(ROOT / 'tests/native_lan.gd')], 'lan')

def run_lan_game():
    """Exercise the actual game scene in two separate engine processes."""
    paths = [Path(tempfile.gettempdir()) / f'doodleshooter-check-lan-{role}.log' for role in ('host', 'guest')]
    processes = []
    try:
        with paths[0].open('w') as host_log, paths[1].open('w') as guest_log:
            command = [GODOT, '--headless', '--path', str(ROOT / 'native'), '--script', str(ROOT / 'tests/lan_game_peer.gd')]
            host = subprocess.Popen([*command, '--', '--host'], stdout=host_log, stderr=subprocess.STDOUT)
            processes.append(host)
            deadline = time.monotonic() + 12
            while 'LAN HOST READY' not in paths[0].read_text():
                if host.poll() is not None or time.monotonic() > deadline:
                    raise RuntimeError('LAN game host did not become ready')
                time.sleep(0.05)
            guest = subprocess.Popen(command, stdout=guest_log, stderr=subprocess.STDOUT)
            processes.append(guest)
            for process in processes:
                process.wait(timeout=40)
        for process, path in zip(processes, paths):
            output = path.read_text()
            if process.returncode or 'ERROR:' in output or 'LAN GAME PASS:' not in output:
                raise RuntimeError(f'LAN game peer failed; log: {path}')
            print(next(line for line in output.splitlines() if line.startswith('LAN GAME PASS:')))
            print(f'Log: {path}')
    except (RuntimeError, subprocess.TimeoutExpired) as error:
        for path in paths:
            print(path.read_text() if path.exists() else '')
        raise SystemExit(f'FAIL: {error}')
    finally:
        for process in processes:
            if process.poll() is None:
                process.kill()
                process.wait()
        for role in ('host', 'guest'):
            (ROOT / f'native/.lan-test-{role}.cfg').unlink(missing_ok=True)

run_lan_game()
