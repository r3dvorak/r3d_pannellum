<?php
/**
 * @package     Joomla.Package
 * @subpackage  pkg_r3d_pannellum
 * @creationDate 2025-09-15
 * @author      Richard Dvorak, r3d.de
 * @copyright   Copyright (C) 2025 Richard Dvorak, https://r3d.de
 * @license     GPL-3.0-or-later https://www.gnu.org/licenses/gpl-3.0.html
 * @version     5.2.6
 */

defined('_JEXEC') or die;

use Joomla\CMS\Factory;

/**
 * Package installer script: post-install tweaks.
 */
final class pkg_r3d_pannellumInstallerScript
{
    /**
     * Auto-enable the system plugin r3d_adminui after install/update.
     *
     * @param string $type
     * @param object $parent
     * @return void
     */
    public function postflight($type, $parent): void
    {
        try {
            $db = Factory::getContainer()->get('DatabaseDriver');

            // Find the plugin
            $query = $db->getQuery(true)
                ->select($db->quoteName('extension_id'))
                ->from($db->quoteName('#__extensions'))
                ->where($db->quoteName('type') . ' = ' . $db->quote('plugin'))
                ->where($db->quoteName('element') . ' = ' . $db->quote('r3d_adminui'))
                ->where($db->quoteName('folder') . ' = ' . $db->quote('system'))
                ->setLimit(1);

            $pluginId = (int) $db->setQuery($query)->loadResult();

            if ($pluginId) {
                $query = $db->getQuery(true)
                    ->update($db->quoteName('#__extensions'))
                    ->set($db->quoteName('enabled') . ' = 1')
                    ->where($db->quoteName('extension_id') . ' = ' . (int) $pluginId);

                $db->setQuery($query)->execute();
            }
        } catch (\Throwable $e) {
            // Soft-fail: don't block package install if enabling fails.
        }
    }
}
