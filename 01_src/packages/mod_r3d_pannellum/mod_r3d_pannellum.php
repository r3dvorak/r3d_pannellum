<?php
/**
 * @package     Joomla.Module
 * @subpackage  mod_r3d_pannellum
 * @creation    2025-09-03
 * @author      Richard Dvorak, r3d.de
 * @copyright   Copyright (C) 2025 Richard Dvorak, https://r3d.de
 * @license     GNU GPL v3 or later (https://www.gnu.org/licenses/gpl-3.0.html)
 * @version     5.2.2
 * @file        modules/mod_r3d_pannellum/mod_r3d_pannellum.php
 */

defined('_JEXEC') or die;

use Joomla\CMS\Helper\ModuleHelper;
use Joomla\CMS\Factory;

require_once __DIR__ . '/helper.php';

// Asset Management
$doc = Factory::getApplication()->getDocument();
$wa = $doc->getWebAssetManager();

// Get from params
$useCdn = (int) ($params->get('useCdn', 1)); // 1 = CDN, 0 = local
$cdnVersion = trim((string) $params->get('cdnVersion', '2.5.6'));
$cdnBase = "https://cdn.jsdelivr.net/npm/pannellum@{$cdnVersion}/build/";
$localBase = 'media/mod_r3d_pannellum/pannellum/';

if ($useCdn) {
    // Register CDN, with fallback loader
    // registerAndUse*(name, uri, OPTIONS, ATTRIBUTES, DEPENDENCIES)
    $wa->registerAndUseStyle(
        'mod_r3d_pannellum.pannellum.css',
        $cdnBase . 'pannellum.css',
        ['version' => null, 'relative' => false], // options
        [],                                       // attributes
        []                                        // dependencies
    );

    $wa->registerAndUseScript(
        'mod_r3d_pannellum.pannellum.js',
        $cdnBase . 'pannellum.js',
        ['version' => null, 'relative' => false], // options
        ['defer' => true, 'crossorigin' => 'anonymous'], // attributes
        []                                        // dependencies
    );

    // Fallback to local if CDN fails
    $doc->addScriptDeclaration(<<<'JS'
(function () {
  function base() {
    try { return (Joomla && Joomla.getOptions && Joomla.getOptions('system.paths').base) || ''; }
    catch(e){ return ''; }
  }
  function loadLocal() {
    if (document.getElementById('pannellum-local-js')) return;
    var lcss = document.createElement('link');
    lcss.rel = 'stylesheet';
    lcss.href = base() + '/media/mod_r3d_pannellum/pannellum/pannellum.css';
    document.head.appendChild(lcss);

    var s = document.createElement('script');
    s.id = 'pannellum-local-js';
    s.defer = true;
    s.src = base() + '/media/mod_r3d_pannellum/pannellum/pannellum.js';
    s.onload = function () { document.dispatchEvent(new CustomEvent('pannellum:ready')); };
    document.head.appendChild(s);
  }

  document.addEventListener('DOMContentLoaded', function () {
    if (typeof window.pannellum === 'undefined') loadLocal();
    else document.dispatchEvent(new CustomEvent('pannellum:ready'));
  });
})();
JS
    );
} else {
    // Pure local
    $wa->registerAndUseStyle(
        'mod_r3d_pannellum.pannellum.css',
        $localBase . 'pannellum.css',
        ['version' => null, 'relative' => true], // options
        [],                                      // attributes
        []                                       // dependencies
    );

    $wa->registerAndUseScript(
        'mod_r3d_pannellum.pannellum.js',
        $localBase . 'pannellum.js',
        ['version' => null, 'relative' => true], // options
        ['defer' => true],                       // attributes
        []                                       // dependencies
    );

    $doc->addScriptDeclaration(
        "document.addEventListener('DOMContentLoaded',function(){document.dispatchEvent(new CustomEvent('pannellum:ready'));});"
    );
}

$build = ModR3dPannellumHelper::build($params);
require ModuleHelper::getLayoutPath('mod_r3d_pannellum', $params->get('layout', 'default'));
