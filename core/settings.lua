local gui = require 'gui'

local settings = {
    plugin_label = gui.plugin_label,
    plugin_version = gui.plugin_version,
    enabled = true,
    draw = false,
    step = 0.5,
    normalizer = 2, -- *10/5 to get steps of 0.5
    use_movement = false,
    use_evade = false,
    use_teleport = false,
    use_teleport_enchanted = false,
    use_dash = false,
    use_soar = false,
    use_hunter = false,
    use_leap = false,
    use_charge = false,
    use_falling_star = false,
    use_aoj = false,
}

settings.get_keybind_state = function ()
    local toggle_key = gui.elements.keybind_toggle:get_key()
    local toggle_state = gui.elements.keybind_toggle:get_state()
    local use_keybind = true
    -- If not using keybind, skip
    if not use_keybind then
        return true
    end

    if use_keybind and toggle_key ~= 0x0A and toggle_state == 1 then
        return true
    end
    return false
end

settings.update_settings = function ()
    settings.enabled = gui.elements.main_toggle:get()
    settings.draw = gui.elements.draw_keybind_toggle:get_state()
    settings.use_movement = gui.elements.use_movement:get()
    settings.use_evade = gui.elements.use_evade:get()
    settings.use_teleport = gui.elements.use_teleport:get()
    settings.use_teleport_enchanted = gui.elements.use_teleport_enchanted:get()
    settings.use_dash = gui.elements.use_dash:get()
    settings.use_soar = gui.elements.use_soar:get()
    settings.use_hunter = gui.elements.use_hunter:get()
    settings.use_leap = gui.elements.use_leap:get()
    settings.use_charge = gui.elements.use_charge:get()
    settings.use_falling_star = gui.elements.use_falling_star:get()
    settings.use_aoj = gui.elements.use_aoj:get()
end

return settings