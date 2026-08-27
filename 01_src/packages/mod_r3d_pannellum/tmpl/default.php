<?php
/**
 * @package     Joomla.Module
 * @subpackage  mod_r3d_pannellum
 * @creation    2025-09-05
 * @author      Richard Dvorak, r3d.de
 * @copyright   Copyright (C) 2025 Richard Dvorak, https://r3d.de
 * @license     GNU GPL v3 or later (https://www.gnu.org/licenses/gpl-3.0.html)
 * @version     5.3.0
 * @file        modules/mod_r3d_pannellum/tmpl/default.php
 */

defined('_JEXEC') or die;

/** $build is prepared in mod_r3d_pannellum.php via ModR3dPannellumHelper::build($params) */
$containerId = isset($build['id']) ? (string) $build['id'] : ('pano-' . (int) $module->id);
$style = isset($build['style']) ? (string) $build['style'] : 'width:100%;height:500px;';
$config = isset($build['config']) && is_array($build['config']) ? $build['config'] : [];

$json = json_encode(
    $config,
    JSON_HEX_TAG | JSON_HEX_AMP | JSON_HEX_APOS | JSON_HEX_QUOT
        | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE
        | JSON_INVALID_UTF8_SUBSTITUTE | JSON_THROW_ON_ERROR
);
?>
<div
    id="<?php echo htmlspecialchars($containerId, ENT_QUOTES, 'UTF-8'); ?>"
    style="<?php echo htmlspecialchars($style, ENT_QUOTES, 'UTF-8'); ?>"
    data-r3d-pannellum-config="<?php echo htmlspecialchars($json, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); ?>"
></div>
