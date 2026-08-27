(function () {
    'use strict';
    var state = { row: null, yaw: null, pitch: null, viewer: null, modal: null };
    function input(row, name) { return row.querySelector('[name*="[hotspot][' + name + ']"]'); }
    function safeUrl(value) {
        value = (value || '').trim();
        if (!value || /^\/\//.test(value) || /\\/.test(value) || /^javascript:/i.test(value)) { return null; }
        try { return new URL(value, window.location.origin).href; } catch (e) { return null; }
    }
    function panoramaFor(row) {
        var scope = row;
        while (scope) {
            var scene = scope.querySelector('[name*="[scene][panorama]"]');
            if (scene) { return scene; }
            scope = scope.parentElement;
        }
        return document.querySelector('[name="jform[params][panorama]"]');
    }

    window.R3dPannellumPicker = { safeUrl: safeUrl, panoramaFor: panoramaFor };
    function status(message) { state.modal.querySelector('[data-r3d-coords]').textContent = message || ''; }
    function close() { if (state.viewer) { state.viewer.destroy(); } state.viewer = null; state.modal.hidden = true; state.row = null; }
    function makeModal() {
        var labels=(window.Joomla&&Joomla.getOptions('mod_r3d_pannellum.picker'))||{}, modal = document.createElement('div'), dialog=document.createElement('div'), title=document.createElement('h2'), help=document.createElement('p'), host=document.createElement('div'), coords=document.createElement('p'), apply=document.createElement('button'), cancel=document.createElement('button'); modal.className='r3d-pan-picker'; modal.hidden=true; dialog.className='r3d-pan-picker__dialog'; dialog.setAttribute('role','dialog'); dialog.setAttribute('aria-modal','true'); title.textContent=labels.title||''; help.textContent=labels.help||''; host.className='r3d-pan-picker__viewer'; coords.setAttribute('data-r3d-coords',''); apply.type=cancel.type='button'; apply.setAttribute('data-r3d-apply',''); cancel.setAttribute('data-r3d-cancel',''); apply.textContent=labels.apply||''; cancel.textContent=labels.cancel||''; dialog.append(title,help,host,coords,apply,cancel); modal.appendChild(dialog);
        document.body.appendChild(modal); modal.querySelector('[data-r3d-cancel]').addEventListener('click', close);
        modal.querySelector('[data-r3d-apply]').addEventListener('click', function () { if (state.row && state.yaw !== null) { ['yaw','pitch'].forEach(function (n) { var el=input(state.row,n); if(el){el.value=String(n==='yaw'?state.yaw:state.pitch); ['input','change'].forEach(function(t){el.dispatchEvent(new Event(t,{bubbles:true}));});} }); } close(); });
        return modal;
    }
    document.addEventListener('click', function (event) {
        var button = event.target.closest('.r3d-pan-picker-button'); if (!button) { return; }
        var row = button.closest('.subform-repeatable-group, .row'), panorama = row && panoramaFor(row), labels=(window.Joomla&&Joomla.getOptions('mod_r3d_pannellum.picker'))||{};
        if (!row || !window.pannellum) { return; } state.modal=state.modal||makeModal(); if (!panorama || !panorama.value) { state.modal.hidden=false; status(labels.missing); return; } var url = safeUrl(panorama.value); if (!url) { state.modal.hidden=false; status(labels.invalid); return; }
        state.row=row; state.yaw=null; state.pitch=null; state.modal=state.modal||makeModal(); var host=state.modal.querySelector('.r3d-pan-picker__viewer'); host.textContent=''; state.modal.hidden=false;
        state.viewer=window.pannellum.viewer(host,{type:'equirectangular',panorama:url,autoLoad:true,escapeHTML:true}); state.viewer.on('error',function(){status(labels.invalid);}); host.addEventListener('mousedown',function(e){var c=state.viewer.mouseEventToCoords(e);state.pitch=c[0];state.yaw=c[1];status((labels.yaw||'')+': '+state.yaw+'; '+(labels.pitch||'')+': '+state.pitch);},{once:true});
    });
}());
