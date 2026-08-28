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

## Module Editor

The module editor adapts to the selected viewer mode. **Global viewer
settings** is always visible and contains the mode, container, interaction,
compass, auto-rotation, default view, and tour transition settings. Those
values are Pannellum defaults inherited by scenes unless a scene supplies its
own initial view or North offset. In **Single Panorama** mode, the global
page also shows the single panorama; **Single panorama hotspots** contains its
root-level hotspots. In **Multi-scene tour** mode, the single panorama and its
hotspot tab are hidden. **Multi-Scene Tour** contains the first scene,
repeatable tour scenes, and each scene's hotspots. Switching modes preserves
the inactive mode's stored values.

The first rendered panorama in a tour is the configured **First tour scene**;
when that value is empty or invalid, the first valid scene in the list is used.
The global single-panorama image is deliberately ignored while tour mode is
active, but remains stored for a later switch back to Single Panorama mode.
If a tour has no valid scene, the module does not fall back to that stored
single panorama; it displays a configuration message instead.

The global settings also contain **Reset view after inactivity**. It is off by
default, so visitor zoom and viewing direction remain unchanged after an
interaction. Enable it only when a panorama should return to its configured
starting view after the selected delay and resume auto-rotation. It requires a
non-zero **Rotate speed**; otherwise there is no rotation to restart.

**Standard hotspot appearance** is also global: **Standard icon scale** uses
`1` for Pannellum's normal icon size, while **Standard icon opacity** uses `1`
for fully opaque and `0` for fully transparent icons. These values apply to
the built-in Pannellum icons in both viewer modes; a hotspot with its own CSS
class deliberately retains its custom styling.

Each hotspot row starts with **Type**, followed by **Choose position in
panorama**. The button opens a local Pannellum
preview of the root panorama in single mode or of the enclosing scene panorama
in tour mode. Click the preview to place a temporary marker, then select
**Apply** to write decimal yaw and pitch values to that row. **Cancel** closes
the preview without changing fields. The control uses delegated events, so it
also works for repeatable rows added, removed, or reordered in the editor.
Root hotspots in Single Panorama mode offer only Info and Link. The Scene type
is available only inside a tour scene, where it can target another valid tour
scene. Text is displayed as the hover tooltip for Info, Link, and Scene
hotspots.

## Recent editor improvements

- **5.3.23:** The visual picker is a localized Joomla administrator button,
  rather than an empty-looking input control.
- **5.3.24:** Hotspot rows place **Type** before the picker button, followed by
  yaw and pitch, so the action is encountered in the natural editing order.
- **5.3.25:** Scene hotspot text is retained and appears as its hover tooltip.

The administrator integration supports both Joomla's core module editor and
Regular Labs Advanced Module Manager. After installing an updated package,
reload an open module edit page so its current administrator assets are used.

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
