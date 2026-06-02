<?php
/**
 * @package     Joomla.Module
 * @subpackage  mod_r3d_pannellum
 * @creation    2025-09-05
 * @author      Richard Dvorak, r3d.de
 * @copyright   Copyright (C) 2025 Richard Dvorak, https://r3d.de
 * @license     GNU GPL v3 or later (https://www.gnu.org/licenses/gpl-3.0.html)
 * @version     5.2.2
 * @file        modules/mod_r3d_pannellum/tmpl/default.php
 */

defined('_JEXEC') or die;

/** $build is prepared in mod_r3d_pannellum.php via ModR3dPannellumHelper::build($params) */
$containerId = isset($build['id']) ? (string) $build['id'] : ('pano-' . (int) $module->id);
$style = isset($build['style']) ? (string) $build['style'] : 'width:100%;height:500px;';
$config = isset($build['config']) && is_array($build['config']) ? $build['config'] : [];

$json = json_encode($config, JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE);
?>
<div id="<?php echo htmlspecialchars($containerId, ENT_QUOTES, 'UTF-8'); ?>" style="<?php echo $style; ?>"></div>

<script>
  (function () {
    var id = <?php echo json_encode($containerId); ?>;
    var cfg = <?php echo $json ?: '{}'; ?>;

    function init() {
      try {
        if (!window.pannellum || typeof pannellum.viewer !== 'function') return;
        pannellum.viewer(id, cfg);
      } catch (e) {
        console.error('Pannellum init error:', e);
      }
    }

    // If already loaded, go now…
    if (window.pannellum && typeof pannellum.viewer === 'function') {
      init();
      return;
    }

    // Prefer our custom event (fired by the module after CDN/local load)
    document.addEventListener('pannellum:ready', function handleReady() {
      init();
    }, { once: true });

    // Belt-and-braces: if for some reason the custom event didn’t fire but the script
    // finished loading by DOMContentLoaded, try again.
    document.addEventListener('DOMContentLoaded', function () {
      if (window.pannellum && typeof pannellum.viewer === 'function') init();
    });
  })();
</script>