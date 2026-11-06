---
name: omarchy-agent-access
description: Set up and use Omarchy Agent Access for phone-approved, temporary root access from a local or remote agent. Use when installing this plugin, requesting an access window, or checking its health after an Omarchy update.
---

# Omarchy Agent Access

The plugin lives at `~/.config/omarchy/plugins/io.github.gustavonline.passwordless-sudo`.
Its user command is `omarchy-agent-access`; if it is not on PATH, run `./agent-access` from the plugin folder.

## Setup

Install with `omarchy plugin add https://github.com/gustavonline/omarchy-passwordless-sudo.git --enable`.
Read the installed `SKILL.md`, then run `./agent-access install-skill` and `./agent-access doctor`.
The bar also registers the skill when loaded. The links live beside Omarchy's own skills in the user's agent skill folders, not in `/usr/share/omarchy`.

Run `./agent-access setup` to open installation and phone enrollment in the owner's terminal. Install missing dependencies reported by doctor through Omarchy's normal package flow. The owner enters their normal sudo password for the first install, scans the QR in an authenticator, and confirms a code there. Keep QR enrollment out of agent transcripts, screenshots and third-party QR services. For a headless machine, the owner can perform enrollment in their own SSH terminal. Existing enrollment survives an upgrade; do not reset it.

## Request and use access

1. Choose a short duration, 1–15 minutes, and describe the authorized work:
   `omarchy-agent-access request 5 "Install the reviewed change"`.
2. Read the returned request ID and tell the human the duration and purpose. Ask for a fresh phone code when ready to use it.
3. Approve in a PTY with `sudo -n /usr/local/sbin/z13-admin approve REQUEST_ID`. Enter the code only at the hidden prompt, never as an argument, environment variable or saved file. Over SSH use `ssh -tt HOST ...`. If the pending request expired, create a fresh request for the same authorized work before approval.
4. Run multiple commands during the window:
   `omarchy-agent-access run REQUEST_ID -- /usr/bin/id`.
5. Check `omarchy-agent-access status`. Close unused access with `omarchy-agent-access close` when the task is done.

One code opens the window, not just one command. The human can reduce the requested duration at approval with `--minutes N`. `shorten N` can reduce an open window; extension needs a new request/code. Do not restore broad `NOPASSWD: ALL` to avoid approval. If approval or access fails, report the failure rather than seeking another route to root.

Expiry/revoke blocks new starts through the broker. It does not stop running root processes, undo changes or sandbox root code. The granted window does not authorize unrelated work, publication, a reboot or other actions outside the user's request.

## Updates

Use `omarchy plugin update io.github.gustavonline.passwordless-sudo --yes`, then `omarchy-agent-access doctor`. User plugin files and skill links survive Omarchy package updates. A changed root source needs an explicit setup/upgrade under normal sudo or an already approved operation; never replace the protected broker silently. A future Omarchy API change can still require a plugin update. Read README.md for recovery and compatibility details.
