# Omarchy Agent Access

Phone-approved sudo for local and remote agents. One code opens a short access window; the agent can run multiple commands until it closes.

## Install

```sh
omarchy plugin add https://github.com/gustavonline/omarchy-passwordless-sudo.git --enable
```

Click the lock in the centre of the bar to set up your phone. Enter your normal administrator password for the first installation, scan the QR in an authenticator app, then confirm a code in the terminal. Existing phone enrollment is preserved when upgrading.

Installing through an agent? Ask it to read [SKILL.md](SKILL.md) in the plugin folder. The widget registers that skill beside Omarchy's own skills for Codex, Claude and other compatible agents. A remote agent can register it without opening the panel:

```sh
~/.config/omarchy/plugins/io.github.gustavonline.passwordless-sudo/agent-access install-skill
```

Requires Omarchy with Quickshell, Python 3, sudo, jq, qrencode, Foot and flock. Setup reports missing dependencies; it does not install packages or restart the computer.

## Quick access

- **Left-click:** open the phone-code terminal with the default duration. If access is already open, show its status.
- **Right-click:** open the panel to choose a duration, shorten a window or close it.
- **Default:** five minutes. Change it in Omarchy's widget settings; the limit is 15 minutes.

The widget starts in the centre section and can be moved like other Omarchy widgets. It uses the stock panel components, foreground colours, typography and progress style. The bar counts down while access is open.

After enrollment you do not need to be near the computer. Your agent can request access and ask for a fresh phone code in your existing trusted chat. The plugin does not read chat or install a public approval server.

## Agent commands

```sh
omarchy-agent-access request 5 "Install the reviewed change"
sudo -n /usr/local/sbin/z13-admin approve REQUEST_ID
omarchy-agent-access run REQUEST_ID -- /usr/bin/id
omarchy-agent-access run REQUEST_ID -- /usr/bin/true
omarchy-agent-access status
omarchy-agent-access shorten 1
omarchy-agent-access close
```

Approval needs a PTY. Enter the code at the hidden prompt, never in command arguments or environment variables. One code opens the window, not just one command. The human may reduce the requested duration at approval with `--minutes N`. A longer window requires a new request and code.

The protected broker retains its older `z13-admin` name for compatibility with existing enrollment. It is not tied to Z13 hardware. This version supports one enrolled owner account; remote agents use that account's existing authorized connection.

## Updates

```sh
omarchy plugin update io.github.gustavonline.passwordless-sudo --yes
omarchy-agent-access doctor
```

The plugin, skill links and root broker live outside Omarchy's packaged files. They survive normal package updates. Plugin updates refresh the skill through its links. A changed root component shows **Update access service** and needs an explicit authorized upgrade; it is never replaced silently.

Tested with Omarchy 4.0.6. CI runs the tests, a clean installation in a disposable container and manifest validation against current Omarchy source. A future shell API change may still require a plugin update. `doctor` reports missing dependencies, invalid manifests, stale root code and missing skill registration.

## Access boundaries

Only the broker is passwordless. Ordinary sudo/PAM and existing permissions are preserved. Expiry and early close prevent new commands through the broker; they do not stop running root processes, undo changes or sandbox approved root code. Do not leave a separate broad passwordless-sudo grant open if phone approval is to gate access.

QR secrets and replay protection stay in root-only state outside the checkout. The panel, status output and logs do not expose codes or enrollment secrets. Normal owner sudo remains the recovery route.

The original Omarchy passwordless flow is available through the optional **Show legacy Omarchy sudo** setting. Its timer is separate from phone-approved access.

## Remove

Close any open window first. Removing the bar widget leaves the protected broker and enrollment intact. To disable root access through this plugin, use normal owner sudo to remove `/etc/sudoers.d/90-z13-admin`, then run `visudo -c`. Remove the broker and its private state only when you intend to retire enrollment too. Skill and command links point at the plugin folder; remove those links when removing the plugin permanently.

## Development

```sh
./test.sh
omarchy plugin validate .
./tests/ui-smoke.sh
docker build -f tests/Dockerfile -t agent-access-test .
docker run --rm --network=none --pids-limit=128 --memory=384m agent-access-test
```

The container tests use a synthetic owner and generated test credentials. No host directories or real enrollment data are mounted.

MIT. See [LICENSE](LICENSE).
