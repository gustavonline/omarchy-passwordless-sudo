#!/usr/bin/env bash
set -euo pipefail

plugin_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

jq -e '
  .schemaVersion == 1 and
  .id == "io.github.gustavonline.passwordless-sudo" and
  (.kinds | index("bar-widget")) != null and
  .entryPoints.barWidget == "Panel.qml"
' "$plugin_dir/manifest.json" >/dev/null

bash -n "$plugin_dir/passwordless-sudo-control"
"$plugin_dir/passwordless-sudo-control" status | jq -e '
  (.active | type == "boolean") and
  (.timerActive | type == "boolean") and
  (.remainingSeconds | type == "number") and
  (.label | type == "string")
' >/dev/null

test_root=$(mktemp -d)
trap 'rm -rf -- "$test_root"' EXIT
mkdir -p "$test_root/bin"
cat >"$test_root/bin/omarchy-launch-floating-terminal-with-presentation" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$PASSWORDLESS_SUDO_TEST_LOG"
EOF
chmod +x "$test_root/bin/omarchy-launch-floating-terminal-with-presentation"
export PASSWORDLESS_SUDO_TEST_LOG="$test_root/launch.log"

PATH="$test_root/bin:$PATH" "$plugin_dir/passwordless-sudo-control" launch 30
PATH="$test_root/bin:$PATH" "$plugin_dir/passwordless-sudo-control" disable
grep -Fxq 'omarchy sudo passwordless 30' "$PASSWORDLESS_SUDO_TEST_LOG"
grep -Fxq 'omarchy sudo passwordless' "$PASSWORDLESS_SUDO_TEST_LOG"

if PATH="$test_root/bin:$PATH" "$plugin_dir/passwordless-sudo-control" launch nope 2>/dev/null; then
  printf 'Invalid duration unexpectedly succeeded\n' >&2
  exit 1
fi

if command -v omarchy >/dev/null; then
  omarchy plugin validate "$plugin_dir" >/dev/null
fi

printf 'Passwordless Sudo plugin checks passed\n'
