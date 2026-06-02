<?php
/**
 * @package     Joomla.Module
 * @subpackage  mod_r3d_pannellum
 * @creation    2025-09-05
 * @author      Richard Dvorak, r3d.de
 * @copyright   Copyright (C) 2025 Richard Dvorak, https://r3d.de
 * @license     GNU GPL v3 or later (https://www.gnu.org/licenses/gpl-3.0.html)
 * @version     5.2.1
 * @file        modules/mod_r3d_pannellum/helper.php
 */

defined('_JEXEC') || die;

use Joomla\CMS\Uri\Uri;
use Joomla\Registry\Registry;

class ModR3dPannellumHelper
{
    /** Build the Pannellum config + container info from params */
    public static function build(Registry $params): array
    {
        // Unique DOM id
        $id = 'r3dpan_' . bin2hex(random_bytes(4));

        // Container size (defaults already set in XML)
        $width  = trim((string) $params->get('container_width', '100%'));
        $height = trim((string) $params->get('container_height', '400px'));
        $style  = 'width:' . htmlspecialchars($width, ENT_QUOTES) . ';height:' . htmlspecialchars($height, ENT_QUOTES) . ';';

        // Resolve panorama URL (allow absolute or relative)
        $pan = (string) $params->get('panorama', '');
        $panorama = $pan !== '' && !preg_match('#^https?://#i', $pan)
            ? Uri::root() . ltrim($pan, '/')
            : $pan;

        $cfg = [
            'type'     => 'equirectangular',
            'panorama' => $panorama,
        ];

        // Helper closures to only set options when user provided a value
        $setNum = function(string $name, string $param) use (&$cfg, $params) {
            $raw = $params->get($param, '');
            if ($raw !== '' && $raw !== null) {
                // Cast to float when numeric
                $cfg[$name] = (float) $raw;
            }
        };
        $setBool3 = function(string $name, string $param) use (&$cfg, $params) {
            // Param is '', '1', '0'  -> only set when not ''
            $raw = $params->get($param, '');
            if ($raw === '1' || $raw === 1) {
                $cfg[$name] = true;
            } elseif ($raw === '0' || $raw === 0) {
                $cfg[$name] = false;
            }
        };

        // Auto-load
        $cfg['autoLoad'] = (bool) $params->get('autoload', 1);

        // Initial view
        $setNum('yaw',  'yaw');
        $setNum('pitch','pitch');
        $setNum('hfov', 'hfov');
        $setNum('minHfov', 'min_hfov');
        $setNum('maxHfov', 'max_hfov');

        // Auto-rotate
        $setNum('autoRotate', 'auto_rotate');
        $setNum('autoRotateInactivityDelay', 'auto_rotate_inactivity');
        $setNum('autoRotateStopDelay', 'auto_rotate_stop');

        // Controls / interaction
        $setBool3('showZoomCtrl',        'show_zoom_ctrl');
        $setBool3('showFullscreenCtrl',  'show_fullscreen_ctrl');
        $setBool3('doubleClickZoom',     'double_click_zoom');
        $setBool3('mouseZoom',           'mouse_zoom');
        $setBool3('draggable',           'draggable');

        // Keyboard control (param is "disable_*")
        $rawDisableKb = $params->get('disable_keyboard_ctrl', '');
        if ($rawDisableKb === '1' || $rawDisableKb === 1) {
            $cfg['keyboardCtrl'] = false;
        } elseif ($rawDisableKb === '0' || $rawDisableKb === 0) {
            $cfg['keyboardCtrl'] = true;
        }

        // Compass
        $setBool3('compass', 'compass');
        $setNum('northOffset', 'north_offset');

        // -------------------------
        // Hotspots (subform)
        // -------------------------
        $hotspotsParam = $params->get('hotspots', []);
        $hotspots = [];

        if (is_array($hotspotsParam)) {
            foreach ($hotspotsParam as $row) {
                if (!is_array($row)) {
                    continue;
                }

                // Required: position
                $yaw   = isset($row['yaw'])   && $row['yaw']   !== '' ? (float) $row['yaw']   : null;
                $pitch = isset($row['pitch']) && $row['pitch'] !== '' ? (float) $row['pitch'] : null;

                if ($yaw === null || $pitch === null) {
                    continue; // skip incomplete rows
                }

                $type = $row['type'] ?? 'info';
                $hs = [
                    'yaw'   => $yaw,
                    'pitch' => $pitch,
                    // default type; we may rewrite below
                    'type'  => $type === 'link' ? 'info' : $type,
                ];

                // Common fields
                if (!empty($row['cssClass'])) {
                    $hs['cssClass'] = (string) $row['cssClass'];
                }

                // Info / Link
                if ($type === 'info' || $type === 'link') {
                    if (!empty($row['text'])) {
                        $hs['text'] = (string) $row['text'];
                    }
                    if (!empty($row['url'])) {
                        // Pannellum expects 'URL' property (uppercase) for info hotspots
                        $hs['URL'] = (string) $row['url'];
                    }
                }

                // Scene link
                if ($type === 'scene') {
                    if (!empty($row['sceneId'])) {
                        $hs['sceneId'] = (string) $row['sceneId'];
                    }
                    if ($row['targetYaw']   !== '' && $row['targetYaw']   !== null) $hs['targetYaw']   = (float) $row['targetYaw'];
                    if ($row['targetPitch'] !== '' && $row['targetPitch'] !== null) $hs['targetPitch'] = (float) $row['targetPitch'];
                    if ($row['targetHfov']  !== '' && $row['targetHfov']  !== null) $hs['targetHfov']  = (float) $row['targetHfov'];
                }

                $hotspots[] = $hs;
            }
        }

        if ($hotspots) {
            $cfg['hotSpots'] = $hotspots;
        }

        return [
            'id'     => $id,
            'style'  => $style,
            'config' => $cfg,
        ];
    }
}
