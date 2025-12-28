local plugin_label = 'batmobile_explorer'
local plugin_version = '0.0.1'

local gui = {}

local function create_checkbox(value, key)
    return checkbox:new(value, get_hash(plugin_label .. '_' .. key))
end

gui.plugin_label = plugin_label
gui.plugin_version = plugin_version

gui.elements = {
    main_tree = tree_node:new(0),
    main_toggle = create_checkbox(true, '_main_toggle'),
    use_keybind = create_checkbox(false, 'use_keybind'),
    keybind_toggle = keybind:new(0x0A, true, get_hash(plugin_label .. '_keybind_toggle' )),
    draw_keybind_toggle = keybind:new(0x0A, true, get_hash(plugin_label .. '_draw_keybind_toggle' )),
    chest_toggle = create_checkbox(false, 'main_toggle'),
    priority = combo_box:new(1, get_hash(plugin_label .. '_priority')),
    drop_sigil_keybind = keybind:new(0x0A, true, get_hash(plugin_label .. '_drop_sigil_keybind' )),
}
function gui.render()
    if not gui.elements.main_tree:push('Batmobile | Leoric | v' .. gui.plugin_version) then return end
    gui.elements.main_toggle:render('Enable', 'Enable Batmobile')
    gui.elements.use_keybind:render('Use keybind', 'Keybind to quick toggle the bot')
    if gui.elements.use_keybind:get() then
        gui.elements.keybind_toggle:render('Toggle Keybind', 'Toggle the bot for quick enable')
        gui.elements.draw_keybind_toggle:render('Toggle Drawing', 'Toggle drawing')
    end
    gui.elements.main_tree:pop()
end

return gui