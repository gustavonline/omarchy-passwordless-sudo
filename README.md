# Passwordless Sudo for Omarchy

An Omarchy bar plugin that opens Omarchy's own temporary passwordless-sudo
flow for a chosen duration.

The panel offers 15, 30, 60, and 120 minute shortcuts by default, displays
Omarchy's active expiration timer, and provides an early-disable action. The
intervals can be changed through the plugin's Omarchy settings.

Every action opens the standard Omarchy floating terminal and runs the public
command:

```bash
omarchy sudo passwordless MINUTES
```

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
