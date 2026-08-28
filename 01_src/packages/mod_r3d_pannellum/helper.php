<?php
/**
 * @package     Joomla.Module
 * @subpackage  mod_r3d_pannellum
 * @version     5.3.0
 */

defined('_JEXEC') || die;

use Joomla\CMS\Uri\Uri;
use Joomla\Registry\Registry;

class ModR3dPannellumHelper
{
    public static function build(Registry $params): array
    {
        $id = 'r3dpan_' . bin2hex(random_bytes(4));
        $width = self::normalizeDimension($params->get('container_width', '100%'), '100%');
        $height = self::normalizeDimension($params->get('container_height', '500px'), '500px');

        $config = self::buildCommonConfig($params);
        $renderViewer = true;
        if (self::isTourMode($params)) {
            $config = self::buildTourConfig($params, $config);
            $renderViewer = $config !== null;
            $config ??= [];
        } else {
            $config['type'] = 'equirectangular';
            $config['panorama'] = self::normalizePanoramaUrl($params->get('panorama', ''));
            $hotspots = self::normalizeHotspots($params->get('hotspots', []), []);
            if ($hotspots !== []) {
                $config['hotSpots'] = $hotspots;
            }
        }

        return ['id' => $id, 'style' => 'width:' . $width . ';height:' . $height . ';', 'config' => $config, 'renderViewer' => $renderViewer];
    }

    private static function buildCommonConfig(Registry $params): array
    {
        $config = ['escapeHTML' => true, 'autoLoad' => (bool) $params->get('autoload', 1)];
        $numbers = [
            'yaw' => ['yaw', -180, 180], 'pitch' => ['pitch', -90, 90], 'hfov' => ['hfov', 1, 180],
            'minHfov' => ['min_hfov', 1, 180], 'maxHfov' => ['max_hfov', 1, 180],
            'autoRotate' => ['auto_rotate', -360, 360],
            'autoRotateStopDelay' => ['auto_rotate_stop', 0, 86400000], 'northOffset' => ['north_offset', -360, 360],
            'sceneFadeDuration' => ['scene_fade_duration', 0, 60000], 'r3dHotspotIconScale' => ['hotspot_icon_scale', 0.25, 4],
            'r3dHotspotIconOpacity' => ['hotspot_icon_opacity', 0, 1],
        ];
        foreach ($numbers as $name => $rule) {
            $value = self::normalizeNumber($params->get($rule[0], null), $rule[1], $rule[2]);
            if ($value !== null) { $config[$name] = $value; }
        }
        if (self::normalizeBoolean($params->get('reset_view_after_inactivity', false)) === true) {
            $delay = self::normalizeNumber($params->get('auto_rotate_inactivity', null), 0, 86400000);
            if ($delay !== null) { $config['autoRotateInactivityDelay'] = $delay; }
        }
        foreach (['showZoomCtrl' => 'show_zoom_ctrl', 'showFullscreenCtrl' => 'show_fullscreen_ctrl', 'doubleClickZoom' => 'double_click_zoom', 'mouseZoom' => 'mouse_zoom', 'draggable' => 'draggable', 'disableKeyboardCtrl' => 'disable_keyboard_ctrl', 'compass' => 'compass'] as $name => $param) {
            $value = self::normalizeBoolean($params->get($param, null));
            if ($value !== null) { $config[$name] = $value; }
        }
        return $config;
    }

    private static function buildTourConfig(Registry $params, array $defaults): ?array
    {
        $validRows = [];
        $ids = [];
        foreach (self::normalizeCollection($params->get('scenes', [])) as $row) {
            $row = self::normalizeRow($row, 'scene');
            $sceneId = self::normalizeIdentifier($row['sceneId'] ?? '');
            $panorama = self::normalizePanoramaUrl($row['panorama'] ?? '');
            if ($sceneId === '' || $panorama === '' || isset($ids[$sceneId])) { continue; }
            $ids[$sceneId] = true;
            $validRows[] = [$sceneId, $row, $panorama];
        }
        if ($validRows === []) {
            return null;
        }
        $scenes = [];
        foreach ($validRows as [$sceneId, $row, $panorama]) {
            $scene = ['type' => 'equirectangular', 'panorama' => $panorama];
            $title = self::normalizeText($row['title'] ?? '', 200);
            if ($title !== '') { $scene['title'] = $title; }
            foreach (['yaw' => [-180, 180], 'pitch' => [-90, 90], 'hfov' => [1, 180]] as $name => $bounds) {
                $value = self::normalizeNumber($row[$name] ?? null, $bounds[0], $bounds[1]);
                if ($value !== null) { $scene[$name] = $value; }
            }
            $northOffset = self::normalizeNumber($row['northOffset'] ?? null, -360, 360);
            if ($northOffset !== null) { $scene['northOffset'] = $northOffset; }
            $hotspots = self::normalizeHotspots($row['hotspots'] ?? [], $ids);
            if ($hotspots !== []) { $scene['hotSpots'] = $hotspots; }
            $scenes[$sceneId] = $scene;
        }
        $firstScene = self::normalizeIdentifier($params->get('first_scene', ''));
        if ($firstScene === '' || !isset($scenes[$firstScene])) { $firstScene = $validRows[0][0]; }
        return ['default' => $defaults + ['firstScene' => $firstScene], 'scenes' => $scenes];
    }

    private static function normalizeHotspots($value, array $sceneIds): array
    {
        $hotspots = [];
        foreach (self::normalizeCollection($value) as $row) {
            $row = self::normalizeRow($row, 'hotspot');
            $yaw = self::normalizeNumber($row['yaw'] ?? null, -180, 180);
            $pitch = self::normalizeNumber($row['pitch'] ?? null, -90, 90);
            if ($yaw === null || $pitch === null) { continue; }
            $type = (string) ($row['type'] ?? 'info');
            if (!in_array($type, ['info', 'link', 'scene'], true)) { $type = 'info'; }
            $text = self::normalizeText($row['text'] ?? '', 500);
            if ($type === 'scene') {
                $sceneId = self::normalizeIdentifier($row['sceneId'] ?? '');
                if ($sceneId === '' || !isset($sceneIds[$sceneId])) { continue; }
                $hotspot = ['yaw' => $yaw, 'pitch' => $pitch, 'type' => 'scene', 'sceneId' => $sceneId];
                foreach (['targetYaw' => [-180, 180], 'targetPitch' => [-90, 90], 'targetHfov' => [1, 180]] as $name => $bounds) {
                    $number = self::normalizeNumber($row[$name] ?? null, $bounds[0], $bounds[1]);
                    if ($number !== null) { $hotspot[$name] = $number; }
                }
            } else {
                $hotspot = ['yaw' => $yaw, 'pitch' => $pitch, 'type' => 'info'];
                $url = self::normalizeUrl($row['url'] ?? '');
                if ($url !== '') { $hotspot['URL'] = $url; }
            }
            if ($text !== '') { $hotspot['text'] = $text; }
            $cssClass = self::normalizeCssClasses($row['cssClass'] ?? '');
            if ($cssClass !== '') { $hotspot['cssClass'] = $cssClass; }
            $hotspots[] = $hotspot;
        }
        return $hotspots;
    }

    private static function isTourMode(Registry $params): bool { return (string) $params->get('viewer_mode', 'single') === 'tour'; }
    private static function normalizeCollection($value): array
    {
        if ($value instanceof Registry) { $value = $value->toArray(); } elseif (is_object($value)) { $value = get_object_vars($value); }
        return is_array($value) ? $value : [];
    }
    private static function normalizeRow($value, string $group): array
    {
        $value = self::normalizeCollection($value);
        return isset($value[$group]) ? self::normalizeCollection($value[$group]) : $value;
    }
    private static function normalizeDimension($value, string $default): string
    {
        $value = trim((string) $value);
        return preg_match('/^(?:0|(?:\d+(?:\.\d+)?)(?:%|px|em|rem|vw|vh|vmin|vmax))$/i', $value) ? $value : $default;
    }
    private static function normalizeNumber($value, float $minimum, float $maximum): ?float
    {
        if ($value === '' || $value === null || !is_numeric($value)) { return null; }
        $number = (float) $value;
        return is_finite($number) && $number >= $minimum && $number <= $maximum ? $number : null;
    }
    private static function normalizeBoolean($value): ?bool
    {
        if ($value === '1' || $value === 1 || $value === true) { return true; }
        if ($value === '0' || $value === 0 || $value === false) { return false; }
        return null;
    }
    private static function normalizeText($value, int $maximumBytes): string
    {
        $value = (string) $value;
        return preg_match('/[\x00-\x1F\x7F]/', $value) ? '' : substr(trim($value), 0, $maximumBytes);
    }
    private static function normalizeUrl($value): string
    {
        $value = self::normalizeText($value, 2048);
        if ($value === '' || str_starts_with($value, '//') || str_contains($value, '\\')) { return ''; }
        $parsed = parse_url($value);
        if ($parsed === false) { return ''; }
        $scheme = $parsed['scheme'] ?? null;
        if ($scheme !== null) { return in_array(strtolower($scheme), ['http', 'https'], true) && !empty($parsed['host']) ? $value : ''; }
        return isset($parsed['host']) ? '' : $value;
    }
    private static function normalizePanoramaUrl($value): string
    {
        $url = self::normalizeUrl($value);
        return $url === '' ? '' : (preg_match('#^https?://#i', $url) ? $url : Uri::root() . ltrim($url, '/'));
    }
    private static function normalizeCssClasses($value): string
    {
        $classes = preg_split('/\s+/', trim((string) $value), -1, PREG_SPLIT_NO_EMPTY) ?: [];
        $classes = array_filter($classes, static fn($class): bool => preg_match('/^[A-Za-z_][A-Za-z0-9_-]{0,63}$/', $class) === 1);
        return implode(' ', array_slice(array_values(array_unique($classes)), 0, 10));
    }
    private static function normalizeIdentifier($value): string
    {
        $value = trim((string) $value);
        return preg_match('/^[A-Za-z0-9_-]{1,128}$/', $value) ? $value : '';
    }
}
