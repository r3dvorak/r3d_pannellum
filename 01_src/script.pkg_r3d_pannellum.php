<?php
/**
 * @package     Joomla.Package
 * @subpackage  pkg_r3d_pannellum
 * @creationDate 2025-09-15
 * @author      Richard Dvorak, r3d.de
 * @copyright   Copyright (C) 2025 Richard Dvorak, https://r3d.de
 * @license     GPL-3.0-or-later https://www.gnu.org/licenses/gpl-3.0.html
 * @version     5.2.20
 */

defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;

/**
 * Package installer script: post-install tweaks.
 */
final class pkg_r3d_pannellumInstallerScript
{
    /**
     * Auto-enable the module and system plugin after install/update.
     *
     * @param string $type
     * @param object $parent
     * @return void
     */
    public function postflight($type, $parent): void
    {
        try {
            Factory::getApplication()->getLanguage()->load('pkg_r3d_pannellum', JPATH_ADMINISTRATOR);

            $db = Factory::getContainer()->get('DatabaseDriver');

            $this->enableExtension($db, 'module', 'mod_r3d_pannellum', '');
            $this->enableExtension($db, 'plugin', 'r3d_adminui', 'system');

            $modulesUrl = 'index.php?option=com_modules&view=modules&filter[search]=R3D';
            Factory::getApplication()->enqueueMessage(
                Text::sprintf(
                    'PKG_R3D_PANNELLUM_POSTINSTALL_CHECK_MODULE',
                    $modulesUrl
                ),
                'success'
            );
        } catch (\Throwable $e) {
            // Soft-fail: don't block package install if enabling fails.
        }
    }

    /**
     * Enable a specific extension row if it exists.
     *
     * @param object $db
     * @param string $type
     * @param string $element
     * @param string $folder
     * @return void
     */
    private function enableExtension($db, string $type, string $element, string $folder): void
    {
        $query = $db->getQuery(true)
            ->select($db->quoteName('extension_id'))
            ->from($db->quoteName('#__extensions'))
            ->where($db->quoteName('type') . ' = ' . $db->quote($type))
            ->where($db->quoteName('element') . ' = ' . $db->quote($element))
            ->setLimit(1);

        if ($folder !== '') {
            $query->where($db->quoteName('folder') . ' = ' . $db->quote($folder));
        } else {
            $query->where($db->quoteName('client_id') . ' = 0');
        }

        $extensionId = (int) $db->setQuery($query)->loadResult();

        if ($extensionId) {
            $query = $db->getQuery(true)
                ->update($db->quoteName('#__extensions'))
                ->set($db->quoteName('enabled') . ' = 1')
                ->where($db->quoteName('extension_id') . ' = ' . (int) $extensionId);

            $db->setQuery($query)->execute();
        }
    }
}
