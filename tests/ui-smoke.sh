#!/bin/bash
# Compile a fresh, hidden instance against the installed Omarchy components.
set -euo pipefail
plugin_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
omarchy_path=${OMARCHY_PATH:-/usr/share/omarchy}
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
ln -s "$omarchy_path/shell/Commons" "$fixture/Commons"
ln -s "$omarchy_path/shell/Ui" "$fixture/Ui"
python3 - "$plugin_dir/Panel.qml" "$fixture/shell.qml" <<'PY'
import json,sys
from pathlib import Path
source=json.dumps(str(Path(sys.argv[1]).resolve()))
Path(sys.argv[2]).write_text('''import QtQuick
import Quickshell
ShellRoot {
  Loader {
    source: '''+source+'''
    onLoaded: {
      if (item.clock(65) !== "01:05") throw new Error("Countdown format failed")
      console.log("AGENT_ACCESS_COMPONENT_READY")
      Qt.callLater(function() { Qt.quit() })
    }
  }
  Timer { interval: 8000; running: true; onTriggered: Qt.quit() }
}
''')
PY
timeout 12 quickshell -p "$fixture" --no-color >"$fixture/log" 2>&1
cat "$fixture/log"
grep -q AGENT_ACCESS_COMPONENT_READY "$fixture/log"
if grep -Eq 'ReferenceError|TypeError|Unable to assign|Type .* unavailable' "$fixture/log"; then
  exit 1
fi
