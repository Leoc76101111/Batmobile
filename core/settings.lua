local gui = require 'gui'

local settings = {
    plugin_label = gui.plugin_label,
    plugin_version = gui.plugin_version,
    enabled = true,
    draw = false,
    step = 0.5,
    normalizer = 2,
}

settings.get_keybind_state = function ()
    local toggle_key = gui.elements.keybind_toggle:get_key();
    local toggle_state = gui.elements.keybind_toggle:get_state();
    local use_keybind = gui.elements.use_keybind:get()
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
end

return settings