<?php
/**
 * @package     Joomla.Package
 * @subpackage  pkg_r3d_pannellum
 * @creationDate 2026-08-27
 * @author      Richard Dvorak, r3d.de
 * @copyright   Copyright (C) 2025 Richard Dvorak, https://r3d.de
 * @license     GPL-3.0-or-later https://www.gnu.org/licenses/gpl-3.0.html
 * @version     5.3.25
 */

defined('_JEXEC') or die;

use Joomla\CMS\Factory;
use Joomla\CMS\Language\Text;
use Joomla\CMS\Log\Log;
use Joomla\Database\DatabaseInterface;

/**
 * Package installer script: post-install tweaks.
 */
final class pkg_r3d_pannellumInstallerScript
{
    /**
     * Enable the helper plugin on first install and direct the administrator
     * to create a module instance. Updates preserve existing extension state.
     *
     * @param string $type
     * @param object $parent
     * @return void
     */
    public function postflight($type, $parent): void
    {
        if (!in_array($type, ['install', 'discover_install'], true)) {
            return;
        }

        $application = Factory::getApplication();
        $application->getLanguage()->load('pkg_r3d_pannellum.sys', JPATH_ADMINISTRATOR);

        try {
            $db = Factory::getContainer()->get(DatabaseInterface::class);
            if (!$this->enableExtension($db, 'plugin', 'r3d_adminui', 'system')) {
                throw new \RuntimeException('The r3d_adminui system plugin extension row was not found.');
            }
        } catch (\Throwable $e) {
            Log::add($e->getMessage(), Log::WARNING, 'pkg_r3d_pannellum');
            $application->enqueueMessage(
                Text::_('PKG_R3D_PANNELLUM_POSTINSTALL_ENABLE_WARNING'),
                'warning'
            );
        }

        $modulesUrl = 'index.php?option=com_modules&view=modules&client_id=0';
        $application->enqueueMessage(
            Text::sprintf('PKG_R3D_PANNELLUM_POSTINSTALL_CREATE_MODULE', $modulesUrl),
            'message'
        );
    }

    /**
     * Enable a specific extension row if it exists.
     *
     * @param DatabaseInterface $db
     * @param string $type
     * @param string $element
     * @param string $folder
     * @return bool
     */
    private function enableExtension(DatabaseInterface $db, string $type, string $element, string $folder): bool
    {
        $query = $db->getQuery(true)
            ->select([$db->quoteName('extension_id'), $db->quoteName('enabled')])
            ->from($db->quoteName('#__extensions'))
            ->where($db->quoteName('type') . ' = ' . $db->quote($type))
            ->where($db->quoteName('element') . ' = ' . $db->quote($element))
            ->setLimit(1);

        if ($folder !== '') {
            $query->where($db->quoteName('folder') . ' = ' . $db->quote($folder));
        } else {
            $query->where($db->quoteName('client_id') . ' = 0');
        }

        $extension = $db->setQuery($query)->loadAssoc();

        if (!$extension) {
            return false;
        }

        if ((int) $extension['enabled'] !== 1) {
            $query = $db->getQuery(true)
                ->update($db->quoteName('#__extensions'))
                ->set($db->quoteName('enabled') . ' = 1')
                ->where($db->quoteName('extension_id') . ' = ' . (int) $extension['extension_id']);
            $db->setQuery($query)->execute();
        }

        return true;
    }
}
