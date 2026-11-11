#!/usr/bin/env python3
"""RetroGrzmot EXIT: BCM26, active low. No shutdown or forced process kills."""
import fcntl
import signal
import subprocess
import time
from pathlib import Path
import gpiod
from gpiod.line import Direction, Bias, Value

running = True
def stop(*_):
    global running
    running = False

def game_running():
    for proc in Path('/proc').iterdir():
        if not proc.name.isdecimal():
            continue
        try:
            args = (proc / 'cmdline').read_bytes().split(b'\0')[:3]
            if any(a.rsplit(b'/', 1)[-1] == b'emulatorlauncher' for a in args):
                return True
        except (OSError, PermissionError):
            pass
    return False

signal.signal(signal.SIGTERM, stop)
signal.signal(signal.SIGINT, stop)
with open('/tmp/retrogrzmot-exit.lock', 'w') as lock:
    fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
    with gpiod.request_lines('/dev/gpiochip0', consumer='retrogrzmot_exit', config={
        26: gpiod.LineSettings(direction=Direction.INPUT, bias=Bias.PULL_UP, active_low=True)
    }) as line:
        print('READY BCM26 input pull-up; press then release to exit game', flush=True)
        raw = stable = line.get_value(26) == Value.ACTIVE
        changed = time.monotonic()
        armed = False
        pressed_in_game = False
        cooldown = 0.0
        while running:
            now = time.monotonic()
            value = line.get_value(26) == Value.ACTIVE
            if value != raw:
                raw, changed = value, now
            if now - changed >= 0.06:
                if stable != raw:
                    stable = raw
                    if stable:
                        pressed_in_game = armed and now >= cooldown and game_running()
                        armed = False
                        print('PRESS', flush=True)
                    else:
                        print('RELEASE', flush=True)
                        if pressed_in_game and game_running():
                            result = subprocess.run(['/usr/bin/hotkeygen', '--send', 'exit'], timeout=5, check=False)
                            print('EXIT sent, returncode=' + str(result.returncode), flush=True)
                            cooldown = time.monotonic() + 2.0
                        pressed_in_game = False
                if not stable:
                    armed = True
            time.sleep(0.01)
