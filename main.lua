local plugin_label = 'batmobile_explorer'

local gui          = require 'gui'
local settings     = require 'core.settings'
local external      = require 'core.external'
local explorer     = require 'core.explorer'
-- local external     = require 'core.external'
local drawing      = require 'core.drawing'

local local_player, player_position
local debounce_time = nil
local debounce_timeout = 0

local function update_locals()
    local_player = get_local_player()
    player_position = local_player and local_player:get_position()
end

local function main_pulse()
    if debounce_time ~= nil and debounce_time + debounce_timeout > get_time_since_inject() then return end
    debounce_time = get_time_since_inject()
    settings:update_settings()
    if not local_player then return end
    if (not settings.enabled or not settings.get_keybind_state()) then return end
    explorer.update()
    -- explorer.move()
end

local function render_pulse()
    -- if not (settings.get_keybind_state()) then return end
    if not local_player or not settings.enabled then return end
    drawing.draw_nodes()
end

on_update(function()
    update_locals()
    main_pulse()
end)

on_render_menu(function ()
    gui.render()
end)
on_render(render_pulse)
BatmobilePlugin = external
