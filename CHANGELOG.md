# Changelog

## 0.3.0 — 2026-08-27

- Show concrete runtime errors and keep them visible until the next action
- Clear successful action feedback automatically after a short delay
- Add public installation, update, removal, CI, and release documentation
- Harden systemd unit argument handling and add portable release checks

## 0.2.2

- Show the real remaining duration for Omarchy's monotonic expiration timer
  instead of falling back to one minute.

## 0.2.1

- Fix command-window launch when Warp is the preferred desktop terminal by
  using Omarchy's bundled Foot terminal for this flow only.
- Call Omarchy's native `omarchy-sudo-passwordless` command directly, matching
  the stock Security menu action.

## 0.2.0

- Replace the four shortcuts with 60- and 120-minute presets.
- Add a validated, theme-native custom-duration field.
- Render the bar icon through Omarchy's native optical glyph component.

## 0.1.0

- Add configurable duration shortcuts.
- Launch the native Omarchy passwordless-sudo workflow in its floating terminal.
- Display whether the Omarchy-managed expiration timer is active.
- Add an early-disable action.
- Improve bar-icon contrast while retaining the active security indicator.
