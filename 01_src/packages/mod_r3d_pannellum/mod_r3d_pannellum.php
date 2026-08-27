<?php
/**
 * @package     Joomla.Module
 * @subpackage  mod_r3d_pannellum
 * @creation    2025-09-03
 * @author      Richard Dvorak, r3d.de
 * @copyright   Copyright (C) 2025 Richard Dvorak, https://r3d.de
 * @license     GNU GPL v3 or later (https://www.gnu.org/licenses/gpl-3.0.html)
 * @version     5.3.0
 * @file        modules/mod_r3d_pannellum/mod_r3d_pannellum.php
 */

defined('_JEXEC') or die;

use Joomla\CMS\Helper\ModuleHelper;
use Joomla\CMS\Factory;

require_once __DIR__ . '/helper.php';

// Asset Management
$doc = Factory::getApplication()->getDocument();
$wa = $doc->getWebAssetManager();

$localBase = 'media/mod_r3d_pannellum/pannellum/';
// Shared page-wide, bundled 2.5.7 assets. Per-instance CDN selection would let
// render order redefine a global Web Asset Manager handle.
$wa->registerAndUseStyle('mod_r3d_pannellum.pannellum.css', $localBase . 'pannellum.css', ['version' => '2.5.7', 'relative' => true]);
$wa->registerAndUseScript('mod_r3d_pannellum.pannellum.js', $localBase . 'pannellum.js', ['version' => '2.5.7', 'relative' => true], ['defer' => true]);

$wa->registerAndUseScript(
    'mod_r3d_pannellum.viewer',
    'media/mod_r3d_pannellum/viewer.js',
    ['version' => '5.3.0', 'relative' => true],
    ['defer' => true],
    ['mod_r3d_pannellum.pannellum.js']
);

$build = ModR3dPannellumHelper::build($params);
require ModuleHelper::getLayoutPath('mod_r3d_pannellum', $params->get('layout', 'default'));
