local plugin_label = 'batmobile'

local gui          = require 'gui'
local settings     = require 'core.settings'
local utils      = require 'core.utils'
local external      = require 'core.external'
local navigator     = require 'core.navigator'
local drawing      = require 'core.drawing'
local tracker      = require 'core.tracker'

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

    if utils.player_loading() then
        -- extend last_update so that it doesnt trigger unstuck straight after loading
        navigator.last_update = get_time_since_inject() + 5
        navigator.unstuck_nodes = {}
    end
    settings:update_settings()
    if not local_player then return end
    if (not settings.enabled or not settings.get_keybind_state()) then return end

    if local_player:is_dead() then
        revive_at_checkpoint()
    elseif not tracker.paused and not utils.player_loading() then
        local start_update = os.clock()
        navigator.update()
        tracker.timer_update = os.clock() - start_update
        -- local goal = vec3:new(-2058.5,-1081,32.373046875)
        -- BatmobilePlugin.set_target(plugin_label, goal)
        local start_move = os.clock()
        navigator.move()
        tracker.timer_move = os.clock() - start_move
    end
    -- local start_update = os.clock()
    -- navigator.update()
    -- tracker.timer_update = os.clock() - start_update
    -- BatmobilePlugin.pause(plugin_label)
    -- local goal = vec3:new(-2058.5,-1081,32.373046875)
    -- BatmobilePlugin.set_target(plugin_label, goal)
    -- local goal1 = vec3:new(-0.48046875, 4.6123046875, 0.0390625 )
    -- local goal2 = vec3:new(4.828125, 0.0380859375, 0.0390625 )
    -- if get_time_since_inject() % 2 < 1 then
    --     BatmobilePlugin.set_target(plugin_label, goal1)
    -- else
    --     BatmobilePlugin.set_target(plugin_label, goal2)
    -- end
    -- local start_move = os.clock()
    -- navigator.move()
    -- tracker.timer_update = os.clock() - start_move

    -- local buffs = local_player:get_buffs()
    -- for _, buff in pairs(buffs) do
    --     if tostring(buff.name_hash) == '386126' then
    --         console.print(buff:get_remaining_time())
    --     end
    -- end
end

local function render_pulse()
    -- if not (settings.get_keybind_state()) then return end
    if not local_player or not settings.enabled or settings.draw ~= 1 then return end
    drawing.draw_nodes(local_player)
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
