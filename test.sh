#!/bin/bash
set -euo pipefail
plugin_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
jq -e '.schemaVersion == 1 and .id == "io.github.gustavonline.passwordless-sudo" and .version == "0.5.0" and .entryPoints.barWidget == "Panel.qml"' "$plugin_dir/manifest.json" >/dev/null
bash -n "$plugin_dir/native-sudo-control" "$plugin_dir/install-approval.sh"
python3 -B "$plugin_dir/test_control.py"
python3 -B "$plugin_dir/approval/test_z13_admin.py"
shellcheck "$plugin_dir/native-sudo-control" "$plugin_dir/install-approval.sh"
bash "$plugin_dir/test_native.sh"
if command -v omarchy >/dev/null; then
  omarchy plugin validate "$plugin_dir"
fi
echo 'Sudo Access tests passed'
