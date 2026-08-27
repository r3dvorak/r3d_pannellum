<?php

namespace Joomla\CMS\Uri {
    final class Uri
    {
        public static function root(): string
        {
            return 'https://example.test/';
        }
    }
}

namespace Joomla\Registry {
    class Registry
    {
        private array $data;

        public function __construct(array $data = [])
        {
            $this->data = $data;
        }

        public function get(string $key, $default = null)
        {
            return $this->data[$key] ?? $default;
        }

        public function toArray(): array
        {
            return $this->data;
        }
    }
}

namespace {
    define('_JEXEC', 1);
    set_error_handler(static function (int $severity, string $message, string $file, int $line): bool {
        throw new ErrorException($message, 0, $severity, $file, $line);
    });

    require dirname(__DIR__, 2) . '/01_src/packages/mod_r3d_pannellum/helper.php';

    function expect(bool $condition, string $message): void
    {
        if (!$condition) {
            throw new RuntimeException($message);
        }
    }

    $payload = '</script><img src=x onerror=alert(1)>';
    $params = new Joomla\Registry\Registry([
        'container_width' => '100%;background:url(https://evil.test/x)',
        'container_height' => '60vh',
        'panorama' => 'images/panorama.jpg',
        'disable_keyboard_ctrl' => '1',
        'hotspots' => [
            [
                'yaw' => '10',
                'pitch' => '-5',
                'type' => 'info',
                'text' => $payload,
                'url' => 'javascript:alert(1)',
                'cssClass' => 'valid invalid<script> also-valid',
            ],
            (object) [
                'hotspot' => (object) [
                    'yaw' => 30,
                    'pitch' => 4,
                    'type' => 'link',
                    'text' => 'Safe link',
                    'url' => 'https://example.test/info',
                ],
            ],
            ['yaw' => 999, 'pitch' => 0, 'type' => 'info'],
        ],
    ]);

    $build = ModR3dPannellumHelper::build($params);
    $config = $build['config'];

    expect($build['style'] === 'width:100%;height:60vh;', 'Unsafe CSS dimension was not replaced.');
    expect($config['escapeHTML'] === true, 'Pannellum HTML escaping is not enabled.');
    expect($config['disableKeyboardCtrl'] === true, 'disableKeyboardCtrl mapping is incorrect.');
    expect(!array_key_exists('keyboardCtrl', $config), 'Legacy keyboardCtrl property remains.');
    expect(count($config['hotSpots']) === 2, 'Hotspot array/object/group normalization failed.');
    expect($config['hotSpots'][0]['text'] === $payload, 'Tooltip text should be escaped by Pannellum, not altered.');
    expect(!isset($config['hotSpots'][0]['URL']), 'Unsafe URL scheme was accepted.');
    expect($config['hotSpots'][0]['cssClass'] === 'valid also-valid', 'CSS class normalization failed.');
    expect($config['hotSpots'][1]['URL'] === 'https://example.test/info', 'Valid HTTPS URL was removed.');

    $tour = ModR3dPannellumHelper::build(new Joomla\Registry\Registry([
        'viewer_mode' => 'tour', 'first_scene' => 'scene-b', 'auto_rotate' => 2, 'show_zoom_ctrl' => '0', 'compass' => '1', 'scene_fade_duration' => 300,
        'scenes' => [[
            'scene' => ['sceneId' => 'scene-a', 'panorama' => 'images/a.jpg', 'northOffset' => 45, 'hotspots' => [[
                'hotspot' => ['yaw' => 1, 'pitch' => 2, 'type' => 'scene', 'sceneId' => 'scene-b', 'targetYaw' => 10]
            ]]]
        ], [
            'scene' => ['sceneId' => 'scene-b', 'panorama' => 'https://example.test/b.jpg', 'hotspots' => [[
                'hotspot' => ['yaw' => 1, 'pitch' => 2, 'type' => 'scene', 'sceneId' => 'missing']
            ]]]
        ], ['scene' => ['sceneId' => 'scene-a', 'panorama' => 'images/duplicate.jpg']]],
    ]));
    expect($tour['config']['default']['firstScene'] === 'scene-b', 'Explicit valid firstScene was not retained.');
    expect($tour['config']['default']['autoRotate'] === 2.0 && $tour['config']['default']['sceneFadeDuration'] === 300.0, 'Global tour defaults missing.');
    expect(!isset($tour['config']['scenes']['scene-a']['autoRotate']), 'Global controls leaked into a scene.');
    expect($tour['config']['scenes']['scene-a']['northOffset'] === 45.0, 'Scene northOffset was not retained.');
    expect(count($tour['config']['scenes']) === 2, 'Duplicate scene IDs were not rejected.');
    expect($tour['config']['scenes']['scene-a']['hotSpots'][0]['sceneId'] === 'scene-b', 'Valid scene target missing.');
    expect(!isset($tour['config']['scenes']['scene-b']['hotSpots']), 'Invalid scene target was not skipped.');
    $malformed = ModR3dPannellumHelper::build(new Joomla\Registry\Registry(['yaw' => '1e999', 'panorama' => 'images/a.jpg']));
    expect(!isset($malformed['config']['yaw']), 'Infinite numeric input was accepted.');

    $module = (object) ['id' => 1];
    ob_start();
    require dirname(__DIR__, 2) . '/01_src/packages/mod_r3d_pannellum/tmpl/default.php';
    $html = ob_get_clean();

    expect(stripos($html, '<script') === false, 'Template still emits executable inline script.');
    expect(strpos($html, $payload) === false, 'Raw script-termination payload reached HTML.');
    expect(strpos($html, '\\u003C/script\\u003E') !== false, 'JSON_HEX_TAG encoding is missing.');
    expect(strpos($html, 'data-r3d-pannellum-config=') !== false, 'External initializer data is missing.');

    echo "PHP module regression tests: OK\n";
}
