<?php
/**
 * @package     Joomla.Module
 * @subpackage  mod_r3d_pannellum
 * @copyright   Copyright (C) 2025 Richard Dvorak, https://r3d.de
 * @license     GNU General Public License version 3 or later; see LICENSE.txt
 * SPDX-License-Identifier: GPL-3.0-or-later
 */

defined('_JEXEC') or die;

use Joomla\CMS\Form\FormField;
use Joomla\CMS\Language\Text;

/**
 * Renders the hotspot picker trigger without Joomla's label/input field pair.
 * The legacy class name remains loadable on Joomla 4.4 as well as Joomla 5/6.
 */
class JFormFieldVisualpicker extends FormField
{
    protected $type = 'Visualpicker';

    protected function getLabel()
    {
        return '';
    }

    protected function getInput()
    {
        $label = Text::_('MOD_R3D_PAN_PICKER_BUTTON');

        return '<button type="button" class="btn btn-secondary r3d-pan-picker-button"'
            . ' aria-label="' . htmlspecialchars($label, ENT_QUOTES, 'UTF-8') . '">'
            . '<span class="icon-location" aria-hidden="true"></span> '
            . htmlspecialchars($label, ENT_QUOTES, 'UTF-8')
            . '</button>';
    }
}
