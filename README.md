# pkg_r3d_pannellum

Joomla package that installs the R3D Pannellum viewer stack in one step.

It bundles the `mod_r3d_pannellum` module together with the
`plg_system_r3d_adminui` system plugin so the panorama viewer and its
admin UI integration stay in sync.

The package is built from the local `01_src/` source tree and released as a
single installable ZIP for Joomla.

## Viewer modes

Existing module instances continue to use **Single Panorama** mode unchanged.
Select **Multi-scene tour** in module configuration to enable a tour. Add each
scene with a unique `sceneId`, its panorama, and optional initial yaw, pitch,
and horizontal FOV. Choose an optional `first_scene`; otherwise the first valid
configured scene is used. Each scene has its own hotspots. A scene hotspot
uses its target `sceneId` and may specify `targetYaw`, `targetPitch`, and
`targetHfov`; invalid targets are safely ignored.

## Compatibility

- Joomla 4.4 with PHP 8.1 or newer
- Joomla 5.x with PHP 8.1 or newer
- Joomla 6.x with PHP 8.3 or newer, as required by Joomla 6

Joomla update XML has one global `php_minimum` value and cannot express a
different PHP minimum for each Joomla major. The release feed therefore uses
PHP 8.1 as the extension minimum; Joomla itself enforces PHP 8.3 for Joomla 6.

## Content Security Policy

The module uses external JavaScript assets and is compatible with a strict
`script-src` policy that does not allow executable inline scripts. It does not
claim fully strict `style-src` / `style-src-attr` compatibility: configured
container dimensions and upstream Pannellum runtime layout use styles.

## Local Build And Release Modes

This package-only repository uses `scripts/build-r3d_pannellum.ps1` as its
authoritative builder. The central `04-build-extension.ps1` and
`05-build-package.ps1` tools assume a component-oriented source layout and are
not equivalent for this repository.

- `scripts/publish-r3d_pannellum.ps1 -Mode BuildOnly` builds and validates locally without invoking publication tooling.
- `scripts/publish-r3d_pannellum.ps1 -Mode DryRun` passes `-DryRun` to both central publication stages.
- `scripts/publish-r3d_pannellum.ps1 -Mode Live` is the only mode that permits publication.
- `-NoPublish` is a compatibility alias for `BuildOnly` and invokes no publication stage.

Generated files under `05_updates/` describe the currently published release
until a later release dry-run regenerates them. Preparing source for a new
version does not modify the live update feed.

Release notes:

- The package keeps a JED-friendly root language file name.
- Language files are normalized for checker compatibility.
- Module and plugin versions are bumped when their source files change.
- Package description constants use the `PKG_...` naming convention.
- Package language files now follow the sibling-package root naming convention.
- The installer script explicitly loads the package system language before showing the post-install note.
- The ZIP also contains the exact `language/en-GB/...` and `language/de-DE/...` package language paths Joomla expects during install.
