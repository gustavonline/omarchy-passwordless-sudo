# Passwordless Sudo for Omarchy

An Omarchy bar plugin for opening Omarchy's own temporary passwordless-sudo
flow with a chosen duration. It delegates every privileged operation to
Omarchy instead of editing sudoers or maintaining a second security mechanism.

## Features

- Two configurable duration presets and a validated custom duration
- Live status and remaining-time display for Omarchy's expiration timer
- Early-disable action through the same native Omarchy confirmation flow
- Short-lived success feedback and persistent, concrete error messages
- No background sudo calls, cached passwords, sudoers files, or private APIs

## Requirements

- A current Omarchy installation with `omarchy sudo passwordless`
- `jq`, `systemctl`, `busctl`, and `xdg-terminal-exec`
- Omarchy's bundled Foot terminal when Warp is the configured default terminal

The plugin checks status without privilege. Enabling or disabling passwordless
sudo always opens Omarchy's normal floating terminal, warning, confirmation,
and password prompt.

## Install

```bash
omarchy plugin add https://github.com/gustavonline/omarchy-passwordless-sudo.git --enable
```

The widget defaults to the right side of the bar. Its two presets and refresh
interval can be changed in Omarchy's plugin settings.

## Use

Open the panel, choose one of the presets or enter a duration from 1 to 1440
minutes, then complete Omarchy's terminal flow. While the timer is active, the
panel offers **Disable now**.

If Warp is the preferred terminal, this one confirmation window uses Omarchy's
bundled Foot terminal because Warp's Linux launcher cannot execute
`xdg-terminal-exec -e` commands. The desktop terminal preference is not
changed.

## Security

Passwordless sudo allows every process running as the current user to execute
commands as root for the selected period. Use the shortest practical interval
and disable it when the privileged task is finished.

The plugin does not inspect or change sudoers, create its own timers, cache
passwords, or bypass Omarchy's validation. Omarchy owns the sudoers rule,
expiration timer, and cleanup.

## Update and remove

```bash
omarchy plugin update io.github.gustavonline.passwordless-sudo --yes
omarchy plugin remove io.github.gustavonline.passwordless-sudo --yes
```

Removing the plugin does not change an already active Omarchy passwordless-sudo
timer. Use **Disable now** before removal when immediate revocation is required.

## Development

```bash
./test.sh
```

See [`RELEASING.md`](RELEASING.md) for the release gate.

## License

MIT
