'use strict';

const fs = require('fs');
const path = require('path');
const vm = require('vm');

const attributes = new Map([
    ['data-r3d-pannellum-config', JSON.stringify({
        escapeHTML: true, r3dHotspotIconScale: 1.5, r3dHotspotIconOpacity: 0.5,
        r3dManualReset: true, r3dResetLabel: 'Reset view', r3dAutoRotateSpeed: 2
    })]
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
let viewerResizes = 0;
const standardHotspot = { div: { style: {} } };
const sceneHotspot = { type: 'scene', div: { style: {} } };
const customHotspot = { cssClass: 'my-icon', div: { style: {} } };
const viewerListeners = {};
const zoomControl = { nextSibling: null };
const controls = {
    children: [],
    querySelector(selector) {
        if (selector === '.pnlm-zoom-controls') return zoomControl;
        if (selector === '.r3d-pan-reset-control') return this.children.find((node) => node.className?.includes('r3d-pan-reset-control')) || null;
        return null;
    },
    insertBefore(node) { this.children.push(node); }
};
let resetLookAt = null;
let resetAutoRotate = null;
global.window = {
    location: { href: 'https://example.test/' },
    pannellum: {
        viewer(id, config) {
            if (id !== 'viewer-test' || config.escapeHTML !== true || 'r3dHotspotIconScale' in config || 'r3dHotspotIconOpacity' in config || 'r3dManualReset' in config || 'r3dResetLabel' in config || 'r3dAutoRotateSpeed' in config) {
                throw new Error('Unexpected viewer arguments.');
            }
            viewerCalls += 1;
            return {
                getConfig() { return { hotSpots: [standardHotspot, sceneHotspot, customHotspot] }; },
                getContainer() { return { querySelector(selector) { return selector === '.pnlm-controls-container' ? controls : null; } }; },
                getScene() { return null; },
                getPitch() { return 10; },
                getYaw() { return 20; },
                getHfov() { return 90; },
                lookAt(...args) { resetLookAt = args; },
                startAutoRotate(...args) { resetAutoRotate = args; },
                on(event, callback) { viewerListeners[event] = callback; },
                resize() { viewerResizes += 1; }
            };
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
    createElement(tagName) {
        const listeners = {};
        return {
            tagName,
            style: {},
            children: [],
            addEventListener(event, callback) { listeners[event] = callback; },
            appendChild(child) { this.children.push(child); },
            setAttribute() {},
            trigger(event) { listeners[event]?.({ preventDefault() {}, stopPropagation() {} }); }
        };
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
if (standardHotspot.div.style.width !== '39px' || standardHotspot.div.style.height !== '39px'
    || standardHotspot.div.style.backgroundSize !== '39px 312px'
    || standardHotspot.div.style.backgroundPosition !== '0 -156px'
    || standardHotspot.div.style.opacity !== '0.5' || viewerResizes !== 1) {
    throw new Error('Global standard hotspot appearance was not applied without a renderer repositioning pass.');
}
if (sceneHotspot.div.style.backgroundPosition !== '0 -195px') {
    throw new Error('Scaled Scene hotspot sprite position was not retained.');
}
if (customHotspot.div.style.width || customHotspot.div.style.height || customHotspot.div.style.opacity) {
    throw new Error('Custom hotspot CSS styling must not be overridden globally.');
}
const resetButton = controls.children[0];
if (!resetButton || !resetButton.className.includes('r3d-pan-reset-control') || resetButton.title !== 'Reset view' || resetButton.children[0].src !== 'https://example.test/media/mod_r3d_pannellum/reset-view.svg') {
    throw new Error('Manual reset control was not rendered with its localized SVG icon.');
}
resetButton.trigger('click');
if (JSON.stringify(resetLookAt) !== JSON.stringify([10, 20, 90, 750]) || JSON.stringify(resetAutoRotate) !== JSON.stringify([2, 10])) {
    throw new Error('Manual reset did not restore the current scene default view and restart auto-rotation.');
}

console.log('JavaScript viewer regression tests: OK');

const adminPath = path.join(__dirname, '..', '..', '01_src', 'packages', 'plg_system_r3d_adminui', 'media', 'adminui.js');
const adminSource = fs.readFileSync(adminPath, 'utf8');
if (/attributes\s*:\s*true/.test(adminSource)) {
    throw new Error('Admin MutationObserver still watches its own style mutations.');
}
for (const required of ['function getViewerModeInputs', 'function getViewerModeInput', 'input.checked', 'inputs.forEach', 'function toggleModeTabs', 'function renameGlobalTab', 'function setControlVisible', 'Array.isArray(tab.tabs)', 'item.tabButton', 'tabRetry < 10', "select.value === 'tour'", 'singleHotspots', 'var tour', 'mod_r3d_pannellum.adminui', 'labels.globalTab']) {
    if (!adminSource.includes(required)) throw new Error(`Mode-aware tab visibility is missing ${required}.`);
}
if (adminSource.includes('jform[params][setup_level]')) {
    throw new Error('Obsolete setup-level tab visibility is still active.');
}

function adminNode(id = '') {
    const attributes = new Map();
    const listeners = new Map();
    return {
        id,
        hidden: false,
        style: { display: '' },
        textContent: id,
        classList: { contains() { return false; } },
        getAttribute(name) { return attributes.get(name) || null; },
        setAttribute(name, value) { attributes.set(name, value); },
        hasAttribute(name) { return attributes.has(name); },
        addEventListener(name, listener) { listeners.set(name, listener); },
        emit(name) { listeners.get(name)?.(); }
    };
}
const singleRadio = adminNode();
singleRadio.value = 'single';
singleRadio.checked = false;
const tourRadio = adminNode();
tourRadio.value = 'tour';
tourRadio.checked = true;
const generalPane = adminNode('general');
const singlePane = adminNode('attrib-intermediate');
const tourPane = adminNode('attrib-tour');
const singleButton = adminNode();
const tourButton = adminNode();
const tourAccordion = adminNode();
tourAccordion.hidden = true;
const adminTab = {
    tabs: [
        { tab: generalPane, tabButton: adminNode(), accordionButton: adminNode() },
        { tab: singlePane, tabButton: singleButton, accordionButton: adminNode() },
        { tab: tourPane, tabButton: tourButton, accordionButton: tourAccordion }
    ]
};
const adminContext = {
    window: { Joomla: { getOptions() { return { globalTab: 'Global viewer settings' }; } } },
    document: {
        readyState: 'complete',
        addEventListener() {},
        querySelector(selector) { return selector === 'joomla-tab#myTab' ? adminTab : null; },
        querySelectorAll(selector) { return selector.includes('viewer_mode') ? [singleRadio, tourRadio] : []; },
        getElementById() { return null; }
    }
};
vm.runInNewContext(adminSource, adminContext, { filename: adminPath });
if (!singlePane.hidden || !singleButton.hidden || tourPane.hidden || tourButton.hidden || !tourAccordion.hidden) {
    throw new Error('Tour mode did not show only the tour tab or changed Joomla accordion visibility.');
}
if (adminTab.tabs[0].tabButton.textContent !== 'Global viewer settings') {
    throw new Error('Global viewer tab was not renamed.');
}
singleRadio.checked = true;
tourRadio.checked = false;
singleRadio.emit('change');
if (singlePane.hidden || singleButton.hidden || !tourPane.hidden || !tourButton.hidden) {
    throw new Error('Single mode did not show only the single-panorama hotspots tab.');
}
console.log('JavaScript admin mode-tab regression checks: OK');

const pickerPath = path.join(__dirname, '..', '..', '01_src', 'packages', 'plg_system_r3d_adminui', 'media', 'picker.js');
const pickerSource = fs.readFileSync(pickerPath, 'utf8');
for (const required of ['function safeUrl', 'function panoramaFor', 'hotspotName.indexOf(\'[scenes]\')', 'scenePrefix + \'[panorama]\'', 'mouseEventToCoords', "['input','change']", "[name=\"jform[params][panorama]\"]"]) {
    if (!pickerSource.includes(required)) throw new Error(`Picker implementation missing ${required}.`);
}
if (/innerHTML/.test(pickerSource) || /javascript:\/i/.test(pickerSource.replace('/^javascript:/i', ''))) {
    throw new Error('Picker contains unsafe HTML or URL handling.');
}
console.log('JavaScript picker regression checks: OK');

// Picker helpers are deliberately exposed only for repository-local regression checks.
const pickerContext = {
    window: { location: { origin: 'https://site.test' }, Joomla: { getOptions() { return {}; } } },
    document: { addEventListener() {}, querySelector() { return { value: 'global.jpg' }; }, querySelectorAll() { return []; }, createElement() { return {}; }, body: { appendChild() {} } },
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
const sceneB = { name: 'jform[params][scenes][0][scene][panorama]', value: 'scene-b.jpg' };
const sceneYaw = { name: 'jform[params][scenes][0][scene][hotspots][0][hotspot][yaw]' };
pickerContext.document.querySelectorAll = () => [sceneB];
const sceneRow = { querySelector(selector) { return selector.includes('[hotspot][yaw]') ? sceneYaw : null; }, parentElement: null };
if (picker.panoramaFor(sceneRow) !== sceneB) throw new Error('Scene-b panorama was not resolved.');
const rootYaw = { name: 'jform[params][hotspots][0][hotspot][yaw]' };
const rootRow = { querySelector(selector) { return selector.includes('[hotspot][yaw]') ? rootYaw : null; }, parentElement: null };
if (picker.panoramaFor(rootRow).value !== 'global.jpg') throw new Error('Root panorama was not resolved.');
const dynamicScenePanorama = { name: 'jform[params][scenes][new][scene][panorama]', value: 'dynamic-scene.jpg' };
const dynamicSceneYaw = { name: 'jform[params][scenes][new][scene][hotspots][new][hotspot][yaw]' };
pickerContext.document.querySelectorAll = () => [sceneB, dynamicScenePanorama];
const dynamicHotspotRow = { querySelector(selector) { return selector.includes('[hotspot][yaw]') ? dynamicSceneYaw : null; }, parentElement: null };
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
