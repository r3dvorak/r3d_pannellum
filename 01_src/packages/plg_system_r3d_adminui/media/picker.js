(function () {
    'use strict';

    var markerId = 'r3d-pan-picker-marker';
    var state = { row: null, yaw: null, pitch: null, viewer: null, modal: null };

    function hotspotInput(row, name) {
        return row.querySelector('[name*="[hotspot][' + name + ']"]');
    }

    function safeUrl(value) {
        value = String(value || '').trim();
        if (!value || /[\x00-\x1F\x7F]/.test(value) || /^\/\//.test(value) || /\\/.test(value)) {
            return null;
        }
        try {
            var url = new URL(value, window.location.origin);
            return url.protocol === 'http:' || url.protocol === 'https:' ? url.href : null;
        } catch (error) {
            return null;
        }
    }

    function panoramaFor(row) {
        var scope = row;
        while (scope) {
            var scenePanorama = scope.querySelector('[name*="[scene][panorama]"]');
            if (scenePanorama) {
                return scenePanorama;
            }
            scope = scope.parentElement;
        }
        return document.querySelector('[name="jform[params][panorama]"]');
    }

    function formatCoordinate(value) {
        return Number(value).toFixed(6).replace(/\.?0+$/, '');
    }

    function status(message) {
        state.modal.querySelector('[data-r3d-coords]').textContent = message || '';
    }

    function clearPreview() {
        if (state.viewer) {
            state.viewer.destroy();
        }
        state.viewer = null;
    }

    function close() {
        clearPreview();
        state.modal.hidden = true;
        state.row = null;
        state.yaw = null;
        state.pitch = null;
    }

    function writeCoordinates(row, yaw, pitch) {
        if (!row || yaw === null || pitch === null) {
            return false;
        }
        ['yaw', 'pitch'].forEach(function (name) {
                var field = hotspotInput(row, name);
                if (!field) {
                    return;
                }
                field.value = name === 'yaw' ? yaw : pitch;
                ['input','change'].forEach(function (type) {
                    field.dispatchEvent(new Event(type, { bubbles: true }));
                });
        });
        return true;
    }

    function apply() {
        writeCoordinates(state.row, state.yaw, state.pitch);
        close();
    }

    function setCoordinates(event, labels) {
        var coordinates;
        try {
            coordinates = state.viewer.mouseEventToCoords(event);
        } catch (error) {
            return;
        }
        if (!coordinates || !isFinite(coordinates[0]) || !isFinite(coordinates[1])) {
            return;
        }
        state.pitch = formatCoordinate(coordinates[0]);
        state.yaw = formatCoordinate(coordinates[1]);
        try {
            state.viewer.removeHotSpot(markerId);
        } catch (error) {
            // The marker is absent before the first selection.
        }
        state.viewer.addHotSpot({ id: markerId, type: 'info', pitch: Number(state.pitch), yaw: Number(state.yaw) });
        status((labels.yaw || '') + ': ' + state.yaw + '; ' + (labels.pitch || '') + ': ' + state.pitch);
    }

    function makeModal() {
        var labels = (window.Joomla && Joomla.getOptions('mod_r3d_pannellum.picker')) || {};
        var modal = document.createElement('div');
        var dialog = document.createElement('div');
        var title = document.createElement('h2');
        var help = document.createElement('p');
        var host = document.createElement('div');
        var coords = document.createElement('p');
        var actions = document.createElement('p');
        var applyButton = document.createElement('button');
        var cancelButton = document.createElement('button');

        modal.className = 'r3d-pan-picker';
        modal.hidden = true;
        dialog.className = 'r3d-pan-picker__dialog';
        dialog.setAttribute('role', 'dialog');
        dialog.setAttribute('aria-modal', 'true');
        title.textContent = labels.title || '';
        help.textContent = labels.help || '';
        host.className = 'r3d-pan-picker__viewer';
        coords.setAttribute('data-r3d-coords', '');
        actions.className = 'r3d-pan-picker__actions';
        applyButton.type = cancelButton.type = 'button';
        applyButton.setAttribute('data-r3d-apply', '');
        cancelButton.setAttribute('data-r3d-cancel', '');
        applyButton.textContent = labels.apply || '';
        cancelButton.textContent = labels.cancel || '';
        actions.append(applyButton, cancelButton);
        dialog.append(title, help, host, coords, actions);
        modal.appendChild(dialog);
        document.body.appendChild(modal);
        cancelButton.addEventListener('click', close);
        applyButton.addEventListener('click', apply);
        return modal;
    }

    function open(button) {
        var row = button.closest('.subform-repeatable-group, .row');
        var panorama = row && panoramaFor(row);
        var labels = (window.Joomla && Joomla.getOptions('mod_r3d_pannellum.picker')) || {};

        if (!row || !window.pannellum) {
            return;
        }
        state.modal = state.modal || makeModal();
        state.row = row;
        state.yaw = null;
        state.pitch = null;
        if (!panorama || !panorama.value) {
            state.modal.hidden = false;
            status(labels.missing);
            return;
        }
        var url = safeUrl(panorama.value);
        if (!url) {
            state.modal.hidden = false;
            status(labels.invalid);
            return;
        }

        clearPreview();
        var host = state.modal.querySelector('.r3d-pan-picker__viewer');
        host.textContent = '';
        state.modal.hidden = false;
        state.viewer = window.pannellum.viewer(host, {
            type: 'equirectangular', panorama: url, autoLoad: true, escapeHTML: true
        });
        state.viewer.on('error', function () { status(labels.invalid); });
        host.onclick = function (event) { setCoordinates(event, labels); };
    }

    // Delegation keeps the picker working for Joomla repeatable subform rows added or reordered after load.
    document.addEventListener('click', function (event) {
        var button = event.target.closest('.r3d-pan-picker-button');
        if (button) {
            open(button);
        }
    });

    window.R3dPannellumPicker = {
        safeUrl: safeUrl,
        panoramaFor: panoramaFor,
        formatCoordinate: formatCoordinate,
        writeCoordinates: writeCoordinates,
        apply: apply,
        close: close
    };
}());
