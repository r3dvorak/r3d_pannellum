# Changelog

## [5.3.26] - Unreleased

- Added global standard hotspot icon scale and opacity settings for built-in
  Pannellum icons; custom CSS hotspot classes remain untouched.
- Disabled automatic view reset after interaction by default. It is now an
  explicit configurable auto-rotation option with a delay.
- Corrected Scene hotspot hover text and refined the hotspot editor order:
  type, visual position button, yaw, pitch, then type-specific fields.
- Replaced the empty-looking visual picker control with a localized Joomla
  administrator button.

## [5.3.22] - Unreleased

- Separated root-hotspot and scene-hotspot forms. Single Panorama hotspots now
  offer only Info and Link; scene navigation is available only inside a tour
  scene.

## [5.3.21] - Unreleased

- Removed the unsafe single-panorama fallback for a tour without valid scenes.
  Such a module now displays a clear configuration message and does not start
  a Pannellum viewer with unrelated single-panorama data.

## [5.3.20] - Unreleased

- Fixed mode-aware tab selection for Joomla radio inputs: the checked viewer
  mode is now used, rather than always reading the first radio input.
- Restored Joomla's native tab/accordion visibility while hiding only the
  inactive configuration mode.
- Added executable regression coverage for single and tour tab visibility and
  fixed safe access to Joomla script options in both administrator scripts.

## [5.3.19] - Unreleased

- Expanded the administrator workflow documentation for single panoramas and
  multi-scene tours, including global-default inheritance and scene overrides.
- Documented the visual picker behaviour for root hotspots and scene hotspots.

## [5.3.18] - 2026-08-28

- Fixed Joomla 6 tab handling by using the `joomla-tab` component's actual
  tab structure instead of relying on its generated button markup.
- Hide single-panorama hotspots in tour mode and reveal the Multi-Scene Tour
  tab reliably in Joomla Core and Advanced Module Manager editors.
- Fixed picker panorama resolution so a root hotspot always previews the
  configured single panorama, never a tour scene.

## [5.3.17] - 2026-08-28

- Load administrator picker and mode-aware editor assets in Advanced Module
  Manager (`com_advancedmodules`) as well as Joomla's core module editor.

## [5.3.16] - 2026-08-28

- Clarified global viewer settings and their inheritance by tour scenes.
- Kept single panorama image and root hotspots specific to Single Panorama
  mode while preserving all stored values across mode changes.

## [5.3.15] - 2026-08-28

- Reworked mode-specific editor guidance and localized package description.

## [5.3.14] - 2026-08-28

- Moved tour fields out of Joomla's reserved `advanced` fieldset so the
  Multi-Scene Tour tab contains the intended tour configuration.

## [5.3.13] - 2026-08-28

- Fixed visual picker modal sizing so its Apply and Cancel controls remain
  reachable on smaller administrator viewports.

## [5.3.0] - Unreleased

Feature release: added backward-compatible multi-scene panorama tours with
repeatable scene configuration, scene-to-scene hotspots, per-scene hotspots,
and deterministic first-scene selection. Bundled Pannellum is updated from
2.5.6 to 2.5.7, including upstream hotspot and URL hardening; local assets are
the deterministic default. Viewer URLs, hotspots, and numeric configuration
are hardened while escaped hotspot rendering and single-panorama instances are
preserved. The package supports Joomla 4.4, 5.x, and 6.x. Builds now use an
explicit inventory and deterministic archives; release gates include artifact
SHA-256 binding, guarded Live publication, NoPublish safety, and regressions.

- Added local administrator visual hotspot placement for single panoramas and
  individual tour scenes, with safe preview URL validation, temporary markers,
  decimal coordinate writeback, and non-mutating cancellation.
- Added picker regression coverage and explicit package inventory/archive
  validation for picker assets.

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
