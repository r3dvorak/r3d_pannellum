# Changelog

## [5.2.20] - 2026-06-02

- Added the package language files under the exact paths Joomla looks for during install.
- Kept the root package language copies for consistency with the existing source convention.

## [5.2.19] - 2026-06-02

- Matched the package language file layout to the sibling package convention.
- Explicitly load the package language file in the installer script before enqueuing the post-install note.

## [5.2.18] - 2026-06-02

- Restored the package language files to the sibling-package root naming convention.
- Added a post-install notice linking to the Modules manager.
- Auto-enables the module alongside the system plugin after install/update.

## [5.2.17] - 2026-06-02

- Restored the package description constant to the `PKG_...` naming convention.
- Aligned the package language files with Joomla's package language loading pattern.

## [5.2.16] - 2026-06-02

- Moved the package language file into the package `language/` folders.
- Added both `en-GB` and `de-DE` package language files to the ZIP.
- Updated the package build script to include the localized package language files.

## [5.2.15] - 2026-06-02

- Bumped the module and plugin versions after their source files changed.
- Kept the package version in sync with the new embedded extension versions.

## [5.2.14] - 2026-06-02

- Added the JED-expected package language file name.
- Removed the duplicate module language hint key.
- Normalized the package language metadata for checker compatibility.

## [5.2.13] - 2026-06-02

- Aligned package metadata with JED checker expectations.
- Added package-level language metadata and removed unsupported manifest fields.
- Relaxed the module XML structure so the JED schema validator stops flagging `showon`.

## [5.2.12] - 2026-06-02

- Fixed package manifest child file names to point at the ZIP archives.
- Joomla package installation should now resolve the embedded module and plugin archives correctly.

## [5.2.11] - 2026-06-02

- Fixed package manifest layout so Joomla can install the package ZIP correctly.
- Kept the release env local-only for admin and FTP credentials.

## [5.2.10] - 2026-06-02

- Restored the canonical `01_src/` package source layout.
- Added local release wrappers for uptick, build, publish, and combined release flows.
- Kept `project.json` local-only and out of GitHub publishing.

## [5.2.9] - 2026-06-02

- Removed Joomla version text from the package metadata.
- Published the package tree restructure for the new repository layout.

## [5.2.8] - 2026-06-02

- Restructured the package source tree and aligned the package metadata.
- Published the initial GitHub repo layout for `r3d_pannellum`.
