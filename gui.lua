local plugin_label = 'batmobile'
local plugin_version = '0.0.9'

local get_character_class = function (local_player)
    if not local_player then
        local_player = get_local_player();
    end
    if not local_player then return end
    local class_id = local_player:get_character_class_id()
    local character_classes = {
        [0] = 'sorcerer',
        [1] = 'barbarian',
        [3] = 'rogue',
        [5] = 'druid',
        [6] = 'necromancer',
        [7] = 'spiritborn',
        [8] = 'default', -- new class in expansion, dont know name yet
        [9] = 'paladin'
    }
    if character_classes[class_id] then
        return character_classes[class_id]
    else
        return 'default'
    end
end

local gui = {}

local function create_checkbox(value, key)
    return checkbox:new(value, get_hash(plugin_label .. '_' .. key))
end

gui.plugin_label = plugin_label
gui.plugin_version = plugin_version

gui.elements = {
    main_tree = tree_node:new(0),
    main_toggle = create_checkbox(true, '_main_toggle'),
    use_keybind = create_checkbox(true, 'use_keybind'),
    keybind_toggle = keybind:new(0x0A, true, get_hash(plugin_label .. '_keybind_toggle' )),
    draw_keybind_toggle = keybind:new(0x0A, true, get_hash(plugin_label .. '_draw_keybind_toggle' )),
    movement_tree = tree_node:new(1),
    use_movement = create_checkbox(false, "use_movement"),
    use_evade = create_checkbox(false, "use_evade"),
    use_teleport = create_checkbox(false, "use_teleport"),
    use_teleport_enchanted = create_checkbox(false, "use_teleport_enchanted"),
    use_dash = create_checkbox(false, "use_dash"),
    use_soar = create_checkbox(false, "use_soar"),
    use_hunter = create_checkbox(false, "use_hunter"),
    use_leap = create_checkbox(false, "use_leap"),
    use_charge = create_checkbox(false, "use_charge"),
    use_falling_star = create_checkbox(false, "use_falling_star"),
    use_aoj = create_checkbox(false, "use_aoj"),
}
function gui.render()
    if not gui.elements.main_tree:push('Batmobile | Leoric | v' .. gui.plugin_version) then return end
    gui.elements.main_toggle:render('Enable', 'Enable Batmobile')
    -- gui.elements.use_keybind:render('Use keybind', 'Keybind to quick toggle the bot')
    -- if gui.elements.use_keybind:get() then
        gui.elements.keybind_toggle:render('Toggle Keybind', 'Toggle the bot for quick enable')
        gui.elements.draw_keybind_toggle:render('Toggle Drawing', 'Toggle drawing')
    -- end
    local class = get_character_class()
    if class ~= 'default' and class ~= 'druid' and class ~= 'necromancer' then
        if gui.elements.movement_tree:push('Movement Spells') then
            gui.elements.use_movement:render('use movement spells', 'use movement spells')
            if gui.elements.use_movement:get() then
                gui.elements.use_evade:render('evade', 'use evade for movement')
                if class == 'sorcerer' then
                    gui.elements.use_teleport:render('teleport', 'use teleport for movement')
                    gui.elements.use_teleport_enchanted:render('teleport enchanted', 'use teleport enchanted for movement')
                elseif class == 'rogue' then
                    gui.elements.use_dash:render('dash', 'use dash for movement')
                elseif class == 'spiritborn' then
                    gui.elements.use_soar:render('soar', 'use soar for movement')
                    gui.elements.use_hunter:render('hunter', 'use hunter for movement')
                elseif class == 'barbarian' then
                    gui.elements.use_leap:render('leap', 'use leap for movement')
                    gui.elements.use_charge:render('charge', 'use charge for movement')
                elseif class == 'paladin' then
                    gui.elements.use_falling_star:render('falling star', 'use falling star for movement')
                    gui.elements.use_aoj:render('Arbiter of Justice', 'use Arbiter of Justice for movement')
                end
            end
            gui.elements.movement_tree:pop()
        end
    end
    gui.elements.main_tree:pop()
end

return gui