# Release checks

- Run ./test.sh and validate the manifest with the installed Omarchy CLI.
- Run tests/ui-smoke.sh in an Omarchy graphical session.
- Run the clean-install container test, including enrollment, upgrade preservation and rollback.
- Verify local quick access, remote approval, multiple commands, expiry and early close.
- Check that no enrollment data, codes, machine settings or private network details enter the commit.
- Update the changelog and manifest together. Preserve the plugin ID and existing enrollment paths.
- Publish from the verified commit; check CI before tagging a release.
