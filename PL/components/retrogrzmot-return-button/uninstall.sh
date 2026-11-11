#!/bin/bash
set -euo pipefail
batocera-services stop retrogrzmot_exit
batocera-services disable retrogrzmot_exit
case " $(batocera-settings-get system.services) " in
    *' retrogrzmot_exit '*) echo 'Could not disable autostart.'; exit 1 ;;
esac
sync
echo 'EXIT stopped and disabled. Program files and backups retained.'
