# Release checklist

1. Update `manifest.json` and `CHANGELOG.md` to the same semantic version.
2. Run `./test.sh` on a current Omarchy installation.
3. Install from a fresh clone and verify status, both presets, a custom duration,
   error feedback, and the early-disable flow.
4. Confirm the repository contains no sudoers files, credentials, local
   configuration, or machine-specific paths.
5. Push `main`, tag the manifest version, and create a GitHub Release from the
   matching changelog section.
