(function () {
    'use strict';

    function all(selector, root) {
        return Array.prototype.slice.call((root || document).querySelectorAll(selector));
    }

    function getSetupSelect() {
        return document.querySelector('[name="jform[params][setup_level]"]');
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

    function toggleTabs() {
        var select = getSetupSelect();
        var controls = getTopTabButtons();
        if (!select || !controls.length) {
            return;
        }

        controls.forEach(function (control) {
            var intermediate = /(^|-)intermediate$/.test(control.targetId);
            var advanced = /(^|-)advanced$/.test(control.targetId);
            var hide = select.value === 'basic'
                ? intermediate || advanced
                : select.value === 'intermediate' && advanced;
            var display = hide ? 'none' : '';

            setDisplay(control.element, display);
            setDisplay(control.pane, display);

            if (hide && isActive(control)) {
                var next = controls.find(function (candidate) {
                    return candidate.targetId === 'general' && candidate.element.style.display !== 'none';
                }) || firstVisible(controls);
                if (next && typeof next.element.click === 'function') {
                    next.element.click();
                }
            }
        });
    }

    function boot() {
        var select = getSetupSelect();
        if (!select || select.hasAttribute('data-r3d-adminui-ready')) {
            return;
        }

        select.setAttribute('data-r3d-adminui-ready', 'true');
        select.addEventListener('change', toggleTabs);
        toggleTabs();

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
                    toggleTabs();
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
