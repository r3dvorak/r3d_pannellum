# pkg_r3d_pannellum

Joomla package that installs the R3D Pannellum viewer stack in one step.

It bundles the `mod_r3d_pannellum` module together with the
`plg_system_r3d_adminui` system plugin so the panorama viewer and its
admin UI integration stay in sync.

The package is built from the local `01_src/` source tree and released as a
single installable ZIP for Joomla.

Release notes:

- The package keeps a JED-friendly root language file name.
- Language files are normalized for checker compatibility.
- Module and plugin versions are bumped when their source files change.
- Package language files now live under `01_src/language/<tag>/`.
