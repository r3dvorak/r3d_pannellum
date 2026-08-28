(function () {
    'use strict';

    var configAttribute = 'data-r3d-pannellum-config';
    var initializedAttribute = 'data-r3d-pannellum-initialized';
    var scriptUrl = document.currentScript && document.currentScript.src
        ? document.currentScript.src
        : window.location.href;
    var assetBase = new URL('.', scriptUrl);
    var localLoadPromise;

    function hotspotAppearance(config) {
        var source = config.default || config;
        var appearance = {
            scale: Number(source.r3dHotspotIconScale),
            opacity: Number(source.r3dHotspotIconOpacity)
        };
        if (!isFinite(appearance.scale) || appearance.scale < 0.25 || appearance.scale > 4) {
            appearance.scale = 1;
        }
        if (!isFinite(appearance.opacity) || appearance.opacity < 0 || appearance.opacity > 1) {
            appearance.opacity = 1;
        }
        delete source.r3dHotspotIconScale;
        delete source.r3dHotspotIconOpacity;
        return appearance;
    }

    function applyHotspotAppearance(viewer, appearance) {
        if (!viewer || typeof viewer.getConfig !== 'function') {
            return;
        }
        var hotspots = viewer.getConfig().hotSpots || [];
        hotspots.forEach(function (hotspot) {
            if (hotspot.cssClass || !hotspot.div) {
                return;
            }
            hotspot.div.style.scale = appearance.scale === 1 ? '' : String(appearance.scale);
            hotspot.div.style.opacity = appearance.opacity === 1 ? '' : String(appearance.opacity);
        });
    }

    function bindHotspotAppearance(viewer, appearance) {
        function apply() {
            applyHotspotAppearance(viewer, appearance);
        }
        apply();
        if (viewer && typeof viewer.on === 'function') {
            viewer.on('load', apply);
            viewer.on('scenechange', function () { window.setTimeout(apply, 0); });
        }
    }

    function initializeElement(element) {
        if (element.hasAttribute(initializedAttribute)) {
            return;
        }

        var config;
        try {
            config = JSON.parse(element.getAttribute(configAttribute) || '{}');
        } catch (error) {
            console.error('Invalid R3D Pannellum configuration:', error);
            return;
        }

        if (!window.pannellum || typeof window.pannellum.viewer !== 'function') {
            return;
        }

        var appearance = hotspotAppearance(config);
        element.setAttribute(initializedAttribute, 'true');
        try {
            bindHotspotAppearance(window.pannellum.viewer(element.id, config), appearance);
        } catch (error) {
            element.removeAttribute(initializedAttribute);
            console.error('Pannellum init error:', error);
        }
    }

    function initializeAll() {
        document.querySelectorAll('[' + configAttribute + ']').forEach(initializeElement);
    }

    function loadLocalPannellum() {
        if (localLoadPromise) {
            return localLoadPromise;
        }

        localLoadPromise = new Promise(function (resolve, reject) {
            if (!document.getElementById('r3d-pannellum-local-css')) {
                var style = document.createElement('link');
                style.id = 'r3d-pannellum-local-css';
                style.rel = 'stylesheet';
                style.href = new URL('pannellum/pannellum.css', assetBase).href;
                document.head.appendChild(style);
            }

            var existing = document.getElementById('r3d-pannellum-local-js');
            if (existing) {
                existing.addEventListener('load', resolve, { once: true });
                existing.addEventListener('error', reject, { once: true });
                return;
            }

            var script = document.createElement('script');
            script.id = 'r3d-pannellum-local-js';
            script.src = new URL('pannellum/pannellum.js', assetBase).href;
            script.addEventListener('load', resolve, { once: true });
            script.addEventListener('error', reject, { once: true });
            document.head.appendChild(script);
        });

        return localLoadPromise;
    }

    function start() {
        if (window.pannellum && typeof window.pannellum.viewer === 'function') {
            initializeAll();
            return;
        }

        loadLocalPannellum().then(initializeAll).catch(function (error) {
            console.error('Unable to load local Pannellum assets:', error);
        });
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', start, { once: true });
    } else {
        start();
    }

    document.addEventListener('r3d-pannellum:refresh', start);
})();
