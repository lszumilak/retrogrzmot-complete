#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
APP=/userdata/system/retrogrzmot/exit_button.py
SERVICE=/userdata/system/services/retrogrzmot_exit

[ "$(id -u)" = 0 ] || { echo 'Run as root in Batocera SSH.'; exit 1; }
command -v batocera-services >/dev/null
command -v hotkeygen >/dev/null
python3 - <<'PY'
from pathlib import Path
import ast
import gpiod
from gpiod.line import Direction, Bias
model = Path('/proc/device-tree/model').read_text().rstrip('\0')
if not model.startswith('Raspberry Pi 3 Model B Plus'):
    raise SystemExit('This installer is intended for Raspberry Pi 3B+ only.')
ast.parse(Path('exit_button.py').read_text())
with gpiod.Chip('/dev/gpiochip0') as chip:
    info = chip.get_line_info(26)
    if info.name != 'GPIO26':
        raise SystemExit('GPIO chip mapping differs; installation stopped.')
    if info.used and info.consumer != 'retrogrzmot_exit':
        raise SystemExit('GPIO26 is already used: ' + str(info.consumer))
    if not info.used:
        with gpiod.request_lines('/dev/gpiochip0', consumer='retrogrzmot_exit_check',
                config={26: gpiod.LineSettings(direction=Direction.INPUT, bias=Bias.PULL_UP)}):
            pass
print('GPIO26 and Python gpiod API checked.')
PY
bash -n retrogrzmot_exit
BACKUP=$(mktemp -d /userdata/system/retrogrzmot-exit-backup-XXXXXXXX)
cp -p /userdata/system/batocera.conf "$BACKUP/batocera.conf"
for target in "$APP" "$SERVICE"; do
    if [ -e "$target" ]; then cp -p "$target" "$BACKUP/$(basename "$target")"; fi
done
echo "Backup: $BACKUP"
if [ -f "$SERVICE" ]; then
    bash "$SERVICE" stop
    for attempt in {1..50}; do
        if ! bash "$SERVICE" status; then break; fi
        sleep 0.1
    done
    if bash "$SERVICE" status; then echo 'Previous service did not stop.'; exit 1; fi
fi
mkdir -p /userdata/system/retrogrzmot /userdata/system/services
install -m 755 exit_button.py "$APP"
install -m 755 retrogrzmot_exit "$SERVICE"
if ! batocera-services start retrogrzmot_exit; then
    echo 'Start failed. Read /tmp/retrogrzmot-exit.log. Backup retained.'
    exit 1
fi
batocera-services enable retrogrzmot_exit
case " $(batocera-settings-get system.services) " in
    *' retrogrzmot_exit '*) ;;
    *) batocera-services stop retrogrzmot_exit; echo 'Could not enable autostart.'; exit 1 ;;
esac
sync
echo 'EXIT installed. Launch a game, press and release EXIT, then repeat.'
echo 'Power off and restart later to check autostart. No reboot was performed.'
