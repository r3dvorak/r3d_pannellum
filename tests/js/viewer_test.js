'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const attributes = new Map([
    ['data-r3d-pannellum-config', JSON.stringify({ escapeHTML: true })]
]);
const element = {
    id: 'viewer-test',
    hasAttribute(name) {
        return attributes.has(name);
    },
    getAttribute(name) {
        return attributes.get(name) || null;
    },
    setAttribute(name, value) {
        attributes.set(name, value);
    },
    removeAttribute(name) {
        attributes.delete(name);
    }
};

let viewerCalls = 0;
global.window = {
    location: { href: 'https://example.test/' },
    pannellum: {
        viewer(id, config) {
            if (id !== 'viewer-test' || config.escapeHTML !== true) {
                throw new Error('Unexpected viewer arguments.');
            }
            viewerCalls += 1;
        }
    }
};
global.document = {
    currentScript: { src: 'https://example.test/media/mod_r3d_pannellum/viewer.js' },
    readyState: 'complete',
    head: { appendChild() {} },
    querySelectorAll() {
        return [element];
    },
    addEventListener() {},
    getElementById() {
        return null;
    },
    createElement() {
        return { addEventListener() {} };
    }
};

const scriptPath = path.join(__dirname, '..', '..', '01_src', 'packages', 'mod_r3d_pannellum', 'media', 'viewer.js');
const source = fs.readFileSync(scriptPath, 'utf8');
vm.runInThisContext(source, { filename: scriptPath });
vm.runInThisContext(source, { filename: scriptPath });

if (viewerCalls !== 1) {
    throw new Error(`Viewer initialized ${viewerCalls} times instead of once.`);
}
if (!attributes.has('data-r3d-pannellum-initialized')) {
    throw new Error('Initialization marker was not set.');
}

console.log('JavaScript viewer regression tests: OK');

const adminPath = path.join(__dirname, '..', '..', '01_src', 'packages', 'plg_system_r3d_adminui', 'media', 'adminui.js');
const adminSource = fs.readFileSync(adminPath, 'utf8');
if (/attributes\s*:\s*true/.test(adminSource)) {
    throw new Error('Admin MutationObserver still watches its own style mutations.');
}
for (const required of ['function getViewerModeSelect', 'function toggleModeTabs', 'function renameGlobalTab', "select.value === 'tour'", 'singleHotspots', 'var tour', 'mod_r3d_pannellum.adminui', 'labels.globalTab']) {
    if (!adminSource.includes(required)) throw new Error(`Mode-aware tab visibility is missing ${required}.`);
}
if (adminSource.includes('jform[params][setup_level]')) {
    throw new Error('Obsolete setup-level tab visibility is still active.');
}

const pickerPath = path.join(__dirname, '..', '..', '01_src', 'packages', 'plg_system_r3d_adminui', 'media', 'picker.js');
const pickerSource = fs.readFileSync(pickerPath, 'utf8');
for (const required of ['function safeUrl', 'function panoramaFor', 'mouseEventToCoords', "['input','change']", "[name=\"jform[params][panorama]\"]"]) {
    if (!pickerSource.includes(required)) throw new Error(`Picker implementation missing ${required}.`);
}
if (/innerHTML/.test(pickerSource) || /javascript:\/i/.test(pickerSource.replace('/^javascript:/i', ''))) {
    throw new Error('Picker contains unsafe HTML or URL handling.');
}
console.log('JavaScript picker regression checks: OK');

// Picker helpers are deliberately exposed only for repository-local regression checks.
const pickerContext = {
    window: { location: { origin: 'https://site.test' }, Joomla: { getOptions() { return {}; } } },
    document: { addEventListener() {}, querySelector() { return { value: 'global.jpg' }; }, createElement() { return {}; }, body: { appendChild() {} } },
    URL,
    Event
};
pickerContext.window.window = pickerContext.window;
vm.runInNewContext(pickerSource, pickerContext, { filename: pickerPath });
const picker = pickerContext.window.R3dPannellumPicker;
for (const unsafeUrl of ['javascript:alert(1)', 'data:text/html,unsafe', '//evil.test/x', 'bad\nurl']) {
    if (picker.safeUrl(unsafeUrl) !== null) throw new Error(`Unsafe picker URL accepted: ${unsafeUrl}`);
}
if (picker.safeUrl('images/panorama.jpg') !== 'https://site.test/images/panorama.jpg') throw new Error('Relative picker URL was not resolved.');
const sceneB = { value: 'scene-b.jpg' };
const sceneRow = { querySelector() { return sceneB; }, parentElement: null };
if (picker.panoramaFor(sceneRow) !== sceneB) throw new Error('Scene-b panorama was not resolved.');
const rootRow = { querySelector() { return null; }, parentElement: null };
if (picker.panoramaFor(rootRow).value !== 'global.jpg') throw new Error('Root panorama was not resolved.');
const dynamicScenePanorama = { value: 'dynamic-scene.jpg' };
const dynamicSceneRow = { querySelector() { return dynamicScenePanorama; }, parentElement: null };
const dynamicHotspotRow = { querySelector() { return null; }, parentElement: dynamicSceneRow };
if (picker.panoramaFor(dynamicHotspotRow) !== dynamicScenePanorama) throw new Error('Dynamic scene row was not resolved.');

const events = [];
const yaw = { value: '1', dispatchEvent(event) { events.push(`yaw:${event.type}`); } };
const pitch = { value: '2', dispatchEvent(event) { events.push(`pitch:${event.type}`); } };
const writebackRow = {
    querySelector(selector) { return selector.includes('[yaw]') ? yaw : pitch; }
};
if (!picker.writeCoordinates(writebackRow, '12.345678', '-6.500001')) throw new Error('Picker writeback failed.');
if (yaw.value !== '12.345678' || pitch.value !== '-6.500001') throw new Error('Picker lost decimal coordinates.');
if (events.join(',') !== 'yaw:input,yaw:change,pitch:input,pitch:change') throw new Error('Picker writeback events are incomplete.');
if (picker.writeCoordinates(null, '1', '2') !== false || yaw.value !== '12.345678') throw new Error('Picker cancellation guard changed fields.');
console.log('JavaScript picker resolution, safety, and writeback tests: OK');

const pickerCssPath = path.join(__dirname, '..', '..', '01_src', 'packages', 'plg_system_r3d_adminui', 'media', 'picker.css');
const pickerCss = fs.readFileSync(pickerCssPath, 'utf8');
for (const required of ['.r3d-pan-picker__dialog', 'display: flex;', 'flex-direction: column;', 'max-height: 100%;', '.r3d-pan-picker__viewer', 'flex: 1 1 auto;', 'min-height: 0;']) {
    if (!pickerCss.includes(required)) throw new Error(`Picker layout regression protection missing ${required}.`);
}
if (/\.r3d-pan-picker__viewer\s*\{[^}]*height:\s*70vh/s.test(pickerCss)) {
    throw new Error('Picker viewer still uses a viewport height that can push its actions below the modal.');
}
console.log('JavaScript picker layout regression checks: OK');
