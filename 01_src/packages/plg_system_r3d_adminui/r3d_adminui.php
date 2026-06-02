<?php
/**
 * @package     Joomla.Plugin
 * @subpackage  System.r3d_adminui
 * @creation    2025-09-04
 * @author      Richard Dvorak, r3d.de
 * @copyright   Copyright (C) 2025 Richard Dvorak, https://r3d.de
 * @license     GNU GPL v3 or later (https://www.gnu.org/licenses/gpl-3.0.html)
 * @version     5.0.5
 * @file        plugins/system/r3d_adminui/r3d_adminui.php
 */

defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Plugin\CMSPlugin;

final class PlgSystemR3d_adminui extends CMSPlugin
{
    protected $app;

    public function onBeforeCompileHead(): void
    {
        if (!$this->app->isClient('administrator')) {
            return;
        }

        $in = $this->app->getInput();
        if ($in->getCmd('option') !== 'com_modules' || $in->getCmd('view') !== 'module') {
            return;
        }

        // Detect our module for both new & edit forms
        $isOurs = false;
        $id = $in->getInt('id');
        if ($id) {
            $db = Factory::getContainer()->get('DatabaseDriver');
            $query = $db->getQuery(true)
                ->select($db->quoteName('module'))
                ->from('#__modules')
                ->where('id = ' . (int) $id);
            $db->setQuery($query);
            $isOurs = ((string) $db->loadResult() === 'mod_r3d_pannellum');
        } else {
            $isOurs = ($in->getCmd('module') === 'mod_r3d_pannellum'); // "New" module
        }
        if (!$isOurs) {
            return;
        }

        $js = <<<'JS'
(function(){
  function $(sel, root){ return (root||document).querySelector(sel); }
  function $all(sel, root){ return Array.prototype.slice.call((root||document).querySelectorAll(sel)); }

  function getSetupSelect(){
    return document.querySelector('[name="jform[params][setup_level]"]');
  }

  function getMainTab(){
    // Prefer the canonical ID Joomla uses on module edit
    return document.querySelector('joomla-tab#myTab') || document.querySelector('joomla-tab');
  }

  function getTopTabButtons(){
    var tab = getMainTab();
    if (!tab) return [];
    var tablist = tab.querySelector('[role="tablist"]');
    if (!tablist) return [];
    // Buttons (or anchors) that control panes via aria-controls
    return $all('[role="tab"][aria-controls]', tablist).map(function(el){
      var targetId = el.getAttribute('aria-controls') || '';
      var pane = targetId ? document.getElementById(targetId) : null;
      return { el: el, targetId: (targetId||'').toLowerCase(), pane: pane };
    });
  }

  function isActive(ctrl){
    return ctrl && (ctrl.el.getAttribute('aria-selected') === 'true' || ctrl.el.classList.contains('active'));
  }

  function firstVisible(ctrls){
    for (var i=0;i<ctrls.length;i++){
      var c = ctrls[i];
      if (c.el.style.display !== 'none') return c;
    }
    return null;
  }

  function toggleTabs(){
    var sel = getSetupSelect();
    if (!sel) return;

    var level = sel.value; // 'basic' | 'intermediate' | 'advanced'
    var ctrls = getTopTabButtons();
    if (!ctrls.length) return;

    ctrls.forEach(function(c){
      var id = c.targetId; // e.g. 'general', 'assignment', 'attrib-intermediate', 'attrib-advanced', 'permissions'
      var isInter = /(^|-)intermediate$/.test(id);
      var isAdv   = /(^|-)advanced$/.test(id);

      var hide = false;
      if (level === 'basic') {
        hide = isInter || isAdv;
      } else if (level === 'intermediate') {
        hide = isAdv;
      } // advanced => show all

      c.el.style.display = hide ? 'none' : '';
      if (c.pane) c.pane.style.display = hide ? 'none' : '';

      if (hide && isActive(c)) {
        // switch to first visible (ideally "general")
        var next = ctrls.find(function(x){ return x.targetId === 'general' && x.el.style.display !== 'none'; }) || firstVisible(ctrls);
        if (next && typeof next.el.click === 'function') {
          next.el.click();
        }
      }
    });
  }

  function boot(){
    var sel = getSetupSelect();
    if (!sel) return;

    sel.addEventListener('change', toggleTabs);

    // Run now and again after Joomla finishes enhancing the form
    toggleTabs();
    setTimeout(toggleTabs, 150);
    setTimeout(toggleTabs, 400);
    setTimeout(toggleTabs, 900);

    // Observe mutations on the main tab to re-apply (defensive)
    var mainTab = getMainTab();
    if (mainTab && window.MutationObserver) {
      var mo = new MutationObserver(function(){ setTimeout(toggleTabs, 0); });
      mo.observe(mainTab, {childList:true, subtree:true, attributes:true});
    }
  }

  document.addEventListener('DOMContentLoaded', boot);
})();
JS;

        Factory::getDocument()->addScriptDeclaration($js);
    }
}
