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
cat >"$test_root/bin/xdg-terminal-exec" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} == --print-id ]] && printf '%s\n' 'foot.desktop'
EOF
cat >"$test_root/bin/omarchy-launch-floating-terminal-with-presentation" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$PASSWORDLESS_SUDO_TEST_LOG"
EOF
chmod +x \
  "$test_root/bin/xdg-terminal-exec" \
  "$test_root/bin/omarchy-launch-floating-terminal-with-presentation"
export PASSWORDLESS_SUDO_TEST_LOG="$test_root/launch.log"

PATH="$test_root/bin:$PATH" "$plugin_dir/passwordless-sudo-control" launch 30
PATH="$test_root/bin:$PATH" "$plugin_dir/passwordless-sudo-control" disable
grep -Fxq 'omarchy-sudo-passwordless 30' "$PASSWORDLESS_SUDO_TEST_LOG"
grep -Fxq 'omarchy-sudo-passwordless' "$PASSWORDLESS_SUDO_TEST_LOG"

# Warp cannot execute xdg-terminal-exec commands. Verify that only this flow is
# routed through Foot while the user's desktop-terminal preference is untouched.
cat >"$test_root/bin/xdg-terminal-exec" <<'EOF'
#!/usr/bin/env bash
[[ ${1:-} == --print-id ]] && printf '%s\n' 'dev.warp.Warp.desktop'
EOF
cat >"$test_root/bin/omarchy-restart-gum" <<'EOF'
# Sourced by the helper; no theme exports are required in this isolated test.
EOF
cat >"$test_root/bin/setsid" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$PASSWORDLESS_SUDO_TEST_LOG"
EOF
cat >"$test_root/bin/foot" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$test_root/bin/omarchy-restart-gum" "$test_root/bin/setsid" "$test_root/bin/foot"
PATH="$test_root/bin:$PATH" "$plugin_dir/passwordless-sudo-control" launch 60
grep -Fq 'uwsm-app -- foot --app-id=org.omarchy.terminal --title=Omarchy bash -c' "$PASSWORDLESS_SUDO_TEST_LOG"
grep -Fq 'omarchy-sudo-passwordless 60' "$PASSWORDLESS_SUDO_TEST_LOG"

if PATH="$test_root/bin:$PATH" "$plugin_dir/passwordless-sudo-control" launch nope 2>/dev/null; then
  printf 'Invalid duration unexpectedly succeeded\n' >&2
  exit 1
fi

if command -v omarchy >/dev/null; then
  omarchy plugin validate "$plugin_dir" >/dev/null
fi

printf 'Passwordless Sudo plugin checks passed\n'
