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
