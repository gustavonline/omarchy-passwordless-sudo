# Passwordless Sudo for Omarchy

An Omarchy bar plugin that opens Omarchy's own temporary passwordless-sudo
flow for a chosen duration.

The panel offers 60 and 120 minute presets, an editable custom duration from
1 to 1440 minutes, Omarchy's active expiration timer, and an early-disable
action. The two presets can be changed through the plugin's Omarchy settings.

Every action opens the standard Omarchy floating terminal and runs the public
command:

```bash
omarchy sudo passwordless MINUTES
```

If Warp is your preferred terminal, the confirmation window uses Omarchy's
bundled Foot terminal for this flow only. Warp remains your desktop default;
the fallback is needed because Warp's Linux launcher cannot run commands via
`xdg-terminal-exec`.

The plugin does not edit or inspect sudoers, create timers, cache passwords, or
duplicate Omarchy's security implementation. Its background status check is
unprivileged. Omarchy remains responsible for its warning, confirmation,
password prompt, sudoers validation, timer, and cleanup.

## Security

Passwordless sudo allows every process running as the current user to execute
commands as root for the selected period. Use the shortest practical interval
and disable it as soon as the privileged task is finished.

## Test

```bash
./test.sh
```
