# r3d_pannellum 5.3.0 Tour Backend UX TODO

## Planning

- [x] Verify the repository root and inspect the intentionally dirty 5.3.0 working tree.
- [x] Review module form, helper, frontend initializer, subforms, language files, administrator plugin, and regression tests.
- [x] Review Joomla 4.4 / 5 / 6-compatible form and Web Asset approaches.
- [x] Define one delegated visual-picker controller: resolve the invoking hotspot row and its enclosing scene row; use Pannellum `mouseEventToCoords()`; update only the resolved yaw/pitch inputs.
- [x] Keep global viewer controls in the Pannellum tour `default` object and scene-specific panorama / initial view / hotspots in `scenes`.
- [x] Retain explicit first-scene and target-scene IDs with translated validation/help. Dynamic selectors are intentionally excluded because nested Joomla subform cloning and reordering makes durable synchronization across Joomla 4.4–6 unnecessarily fragile.

## Backend tabs and visibility

- [x] Replace extension fieldset labels with translated Panorama & Display, Hotspots & Scenes, and Multi-Scene Tour labels.
- [x] Remove the Advanced Mockup placeholder and obsolete setup-level presentation.
- [x] Apply conservative `showon` visibility so single-only and tour-only fields are hidden without deleting stored values.

## Translations

- [x] Verify administrator module language files load on the Joomla 4.4 / 5 / 6 module edit view.
- [x] Verify German administrator UI resolves new constants in German without English fallback.
- [x] Replace all extension-controlled visible XML strings with module language constants.
- [x] Add complete matching English and German translations for tour fields, options, descriptions, picker controls, validation, and status messages.
- [x] Add a regression check that required language keys exist and new form labels are not hardcoded.

## Tour settings

- [x] Group global auto-rotation, interaction, compass, and scene-transition controls in the tour UI without duplicating them per scene.
- [x] Add scene-specific north offset only if implemented and validated as a Pannellum scene override.
- [x] Extend PHP regression coverage for default inheritance and backward-compatible single mode.

## Visual hotspot placement

- [x] Add project-owned administrator picker JavaScript and CSS, loaded through Joomla Web Assets only on the module editor.
- [x] Load bundled local Pannellum 2.5.7 assets for the modal preview; do not alter vendor files or use a CDN.
- [ ] Implement safe panorama URL handling, click-to-coordinate conversion, temporary marker, Apply, and Cancel.
- [ ] Support both root single-panorama hotspot rows and scene-contained hotspot rows through delegated events after add/remove/reorder.
- [ ] Trigger input and change events after Apply; preserve decimal yaw/pitch values and leave fields unchanged on Cancel.

## Tests

- [x] Add an explicit regression test that a scene-b hotspot picker resolves scene-b panorama, never global or sibling-scene panorama.
- [x] Add an explicit regression test that a root single-mode hotspot picker resolves the global single panorama.
- [ ] Add JavaScript tests for row/panorama resolution, writeback, cancellation, delegated dynamic rows, and safe preview handling.
- [ ] Run PHP lint/tests, JavaScript syntax/tests, XML/JSON checks, PowerShell parser/tests, isolated deterministic build, archive validation, and `git diff --check`.

## Documentation

- [ ] Add concise README guidance for the three backend sections and visual hotspot placement workflow.
- [ ] Update the 5.3.0 changelog after implementation and passing tests.
