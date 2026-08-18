# Changelog

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
