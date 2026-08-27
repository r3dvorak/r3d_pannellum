(function () {
    'use strict';

    function all(selector, root) {
        return Array.prototype.slice.call((root || document).querySelectorAll(selector));
    }

    function getViewerModeSelect() {
        return document.querySelector('[name="jform[params][viewer_mode]"]');
    }

    function getMainTab() {
        return document.querySelector('joomla-tab#myTab') || document.querySelector('joomla-tab');
    }

    function getTopTabButtons() {
        var tab = getMainTab();
        var tablist = tab ? tab.querySelector('[role="tablist"]') : null;
        if (!tablist) {
            return [];
        }

        return all('[role="tab"][aria-controls]', tablist).map(function (element) {
            var targetId = element.getAttribute('aria-controls') || '';
            return {
                element: element,
                targetId: targetId.toLowerCase(),
                pane: targetId ? document.getElementById(targetId) : null
            };
        });
    }

    function isActive(control) {
        return control && (
            control.element.getAttribute('aria-selected') === 'true'
            || control.element.classList.contains('active')
        );
    }

    function firstVisible(controls) {
        return controls.find(function (control) {
            return control.element.style.display !== 'none';
        }) || null;
    }

    function setDisplay(element, value) {
        if (element && element.style.display !== value) {
            element.style.display = value;
        }
    }

    function toggleModeTabs() {
        var select = getViewerModeSelect();
        var controls = getTopTabButtons();
        if (!select || !controls.length) {
            return;
        }

        controls.forEach(function (control) {
            var singleHotspots = /(^|-)intermediate$/.test(control.targetId);
            var tour = /(^|-)tour$/.test(control.targetId);
            var hide = select.value === 'tour' ? singleHotspots : tour;
            var display = hide ? 'none' : '';

            setDisplay(control.element, display);
            setDisplay(control.pane, display);

            if (hide && isActive(control)) {
                var next = firstVisible(controls);
                if (next && typeof next.element.click === 'function') {
                    next.element.click();
                }
            }
        });
    }

    function boot() {
        var select = getViewerModeSelect();
        if (!select || select.hasAttribute('data-r3d-adminui-ready')) {
            return;
        }

        select.setAttribute('data-r3d-adminui-ready', 'true');
        select.addEventListener('change', toggleModeTabs);
        toggleModeTabs();

        var mainTab = getMainTab();
        if (mainTab && window.MutationObserver) {
            var pending = false;
            var observer = new MutationObserver(function () {
                if (pending) {
                    return;
                }
                pending = true;
                window.requestAnimationFrame(function () {
                    pending = false;
                    toggleModeTabs();
                });
            });
            observer.observe(mainTab, { childList: true, subtree: true });
        }
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', boot, { once: true });
    } else {
        boot();
    }
})();
