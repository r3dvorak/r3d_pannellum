<?php
/**
 * @package     Joomla.Plugin
 * @subpackage  System.r3d_adminui
 * @creation    2025-09-04
 * @author      Richard Dvorak, r3d.de
 * @copyright   Copyright (C) 2025 Richard Dvorak, https://r3d.de
 * @license     GNU GPL v3 or later (https://www.gnu.org/licenses/gpl-3.0.html)
 * @version     5.3.0
 * @file        plugins/system/r3d_adminui/r3d_adminui.php
 */

defined('_JEXEC') or die;

use Joomla\CMS\Factory;
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
        if ($in->getCmd('option') !== 'com_modules' || $in->getCmd('view') !== 'module') {
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

        $document = $this->app->getDocument();
        $document->getWebAssetManager()->registerAndUseScript(
            'plg_system_r3d_adminui.admin',
            'media/plg_system_r3d_adminui/adminui.js',
            ['version' => '5.3.0', 'relative' => true],
            ['defer' => true]
        );
    }
}
