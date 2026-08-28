(function () {
    'use strict';

    var tabRetry = 0;

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
        if (tab && Array.isArray(tab.tabs) && tab.tabs.length) {
            return tab.tabs.map(function (item) {
                return {
                    element: item.tabButton,
                    accordionButton: item.accordionButton,
                    targetId: (item.tab.id || '').toLowerCase(),
                    pane: item.tab
                };
            });
        }
        var tablist = tab ? tab.querySelector('[role="tablist"]') : null;
        if (!tablist) {
            return [];
        }

        return all('[role="tab"][aria-controls]', tablist).map(function (element) {
            var targetId = element.getAttribute('aria-controls') || '';
            return {
                element: element,
                accordionButton: null,
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
            return !control.element.hidden && control.element.style.display !== 'none';
        }) || null;
    }

    function renameGlobalTab(controls) {
        var labels = (window.Joomla && Joomla.getOptions('mod_r3d_pannellum.adminui')) || {};
        var global = controls.find(function (control) {
            return /(^|-)(general|basic)$/.test(control.targetId);
        });
        if (global && labels.globalTab && global.element.textContent !== labels.globalTab) {
            global.element.textContent = labels.globalTab;
        }
    }

    function setDisplay(element, value) {
        if (element && element.style.display !== value) {
            element.style.display = value;
        }
    }

    function setControlVisible(control, visible) {
        setDisplay(control.element, visible ? '' : 'none');
        setDisplay(control.pane, visible ? '' : 'none');
        setDisplay(control.accordionButton, visible ? '' : 'none');
        if (control.element) {
            control.element.hidden = !visible;
        }
        if (control.pane) {
            control.pane.hidden = !visible;
        }
        if (control.accordionButton) {
            control.accordionButton.hidden = !visible;
        }
    }

    function toggleModeTabs() {
        var select = getViewerModeSelect();
        var controls = getTopTabButtons();
        if (!select) {
            return;
        }
        if (!controls.length) {
            if (tabRetry < 10 && window.requestAnimationFrame) {
                tabRetry += 1;
                window.requestAnimationFrame(toggleModeTabs);
            }
            return;
        }
        tabRetry = 0;

        renameGlobalTab(controls);

        controls.forEach(function (control) {
            var singleHotspots = /(^|-)intermediate$/.test(control.targetId);
            var tour = /(^|-)tour$/.test(control.targetId);
            var hide = select.value === 'tour' ? singleHotspots : tour;

            setControlVisible(control, !hide);

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
