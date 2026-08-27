<?php
/**
 * @package     Joomla.Plugin
 * @subpackage  System.r3d_adminui
 * @creation    2025-09-04
 * @author      Richard Dvorak, r3d.de
 * @copyright   Copyright (C) 2025 Richard Dvorak, https://r3d.de
 * @license     GNU GPL v3 or later (https://www.gnu.org/licenses/gpl-3.0.html)
 * @version     5.3.17
 * @file        plugins/system/r3d_adminui/r3d_adminui.php
 */

defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\Plugin\CMSPlugin;
use Joomla\Database\DatabaseInterface;

final class PlgSystemR3d_adminui extends CMSPlugin
{
    protected $app;

    public function onBeforeCompileHead(): void
    {
        if (!$this->app->isClient('administrator')) {
            return;
        }

        $in = $this->app->getInput();
        if (!in_array($in->getCmd('option'), ['com_modules', 'com_advancedmodules'], true) || $in->getCmd('view') !== 'module') {
            return;
        }

        // Detect our module for both new & edit forms
        $isOurs = false;
        $id = $in->getInt('id');
        if ($id) {
            $db = Factory::getContainer()->get(DatabaseInterface::class);
            $query = $db->getQuery(true)
                ->select($db->quoteName('module'))
                ->from($db->quoteName('#__modules'))
                ->where($db->quoteName('id') . ' = ' . (int) $id);
            $db->setQuery($query);
            $isOurs = ((string) $db->loadResult() === 'mod_r3d_pannellum');
        } else {
            $isOurs = ($in->getCmd('module') === 'mod_r3d_pannellum');
            $extensionId = $in->getInt('eid');
            if (!$isOurs && $extensionId) {
                $db = Factory::getContainer()->get(DatabaseInterface::class);
                $query = $db->getQuery(true)
                    ->select($db->quoteName('element'))
                    ->from($db->quoteName('#__extensions'))
                    ->where($db->quoteName('extension_id') . ' = ' . $extensionId)
                    ->where($db->quoteName('type') . ' = ' . $db->quote('module'));
                $isOurs = ((string) $db->setQuery($query)->loadResult() === 'mod_r3d_pannellum');
            }
        }
        if (!$isOurs) {
            return;
        }

        // Module language files live below the site module path. Explicitly load
        // that domain for the administrator edit form on Joomla 4.4, 5 and 6.
        // Without this, form XML constants can fall back to their raw keys.
        $this->app->getLanguage()->load('mod_r3d_pannellum', JPATH_SITE, null, true, true);

        $document = $this->app->getDocument();
		$document->addScriptOptions('mod_r3d_pannellum.picker', [
			'title' => Text::_('MOD_R3D_PAN_PICKER_TITLE'), 'help' => Text::_('MOD_R3D_PAN_PICKER_HELP'),
			'apply' => Text::_('MOD_R3D_PAN_PICKER_APPLY'), 'cancel' => Text::_('MOD_R3D_PAN_PICKER_CANCEL'),
			'invalid' => Text::_('MOD_R3D_PAN_PICKER_INVALID'), 'missing' => Text::_('MOD_R3D_PAN_PICKER_MISSING'),
			'yaw' => Text::_('MOD_R3D_PAN_PICKER_YAW'), 'pitch' => Text::_('MOD_R3D_PAN_PICKER_PITCH'),
		]);
		$document->addScriptOptions('mod_r3d_pannellum.adminui', [
			'globalTab' => Text::_('MOD_R3D_PAN_FIELDSET_GLOBAL'),
		]);
		$wa = $document->getWebAssetManager();
		$wa->registerAndUseStyle('plg_system_r3d_adminui.picker', 'media/plg_system_r3d_adminui/picker.css', ['version' => '5.3.17', 'relative' => true]);
		$wa->registerAndUseStyle('plg_system_r3d_adminui.pannellum', 'media/mod_r3d_pannellum/pannellum/pannellum.css', ['version' => '2.5.7', 'relative' => true]);
		$wa->registerAndUseScript('plg_system_r3d_adminui.pannellum', 'media/mod_r3d_pannellum/pannellum/pannellum.js', ['version' => '2.5.7', 'relative' => true], ['defer' => true]);
		$wa->registerAndUseScript(
            'plg_system_r3d_adminui.admin',
            'media/plg_system_r3d_adminui/adminui.js',
			['version' => '5.3.17', 'relative' => true],
			['defer' => true], ['plg_system_r3d_adminui.pannellum']
        );
		$wa->registerAndUseScript('plg_system_r3d_adminui.picker', 'media/plg_system_r3d_adminui/picker.js', ['version' => '5.3.17', 'relative' => true], ['defer' => true], ['plg_system_r3d_adminui.pannellum']);
    }
}
