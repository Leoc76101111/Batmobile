local explorer_dfs = require 'core.explorer_dfs'
local path_finder = require 'core.pathfinder_astar'
local utils = require 'core.utils'
local settings = require 'core.settings'
local tracker = require 'core.tracker'

local navigator = {
    last_pos = nil,
    last_update = nil,
    target = nil,
    done = false,
    paused = false,
    path = {},
    last_trav = nil,
    trav_delay = nil,
    done_delay = nil,
    movement_step = 4,
    movement_dist = math.sqrt(4*4*2), -- diagonal dist
    spell_dist = 12,
    spell_time = -1,
    spell_timeout = 0.5,
    blacklisted_spell_node = {},
    unstuck_nodes = {},
    blacklisted_trav = {},
    move_time = -1,
    move_timeout = 0.05,
    update_time = -1,
    update_timeout = 0.05,
    disable_spell = nil,
    is_custom_target = false,
}
local get_nearby_travs = function (local_player)
    local traversals = {}
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name:match('[Tt]raversal_Gizmo') then
            traversals[#traversals+1] = actor
        end
    end
    return traversals
end
local has_traversal_buff = function (local_player)
    local buffs = local_player:get_buffs()
    for _, buff in pairs(buffs) do
        if buff:name():match('Player_Traversal')  then
            return true
        end
    end
    return false
end
local get_closeby_node = function (trav_node, max_dist)
    local local_player = get_local_player()
    if not local_player then return nil end
    local cur_node = utils.normalize_node(local_player:get_position())
    local norm_trav = utils.normalize_node(trav_node)
    local step = settings.step

    local nodes = {}
    for i = norm_trav:x()-max_dist, norm_trav:x()+max_dist, step do
        for j = norm_trav:y()-max_dist, norm_trav:y()+max_dist, step do
            local new_node =  vec3:new(i, j, cur_node:z())
            local valid = utility.set_height_of_valid_position(new_node)
            local walkable = utility.is_point_walkeable(valid)
            local diff_z = utils.distance_z(trav_node, valid)
            if walkable and diff_z < 1 then
                nodes[#nodes+1] = new_node
            end
        end
    end
    table.sort(nodes, function(a, b)
        return utils.distance(a, norm_trav) < utils.distance(b, norm_trav)
    end)
    for _, node in ipairs(nodes) do
        local result = path_finder.find_path(cur_node, node, navigator.is_custom_target)
        if #result > 0 then return node end
    end
    return nil
end
local get_movement_spell_id = function(local_player)
    if not settings.use_movement then return end
    if navigator.disable_spell == true then return end
    if navigator.spell_time + navigator.spell_timeout > get_time_since_inject() then return end
    navigator.spell_time = get_time_since_inject()
    local class = utils.get_character_class(local_player)
    if class == 'sorcerer' then
        if settings.use_teleport and utility.can_cast_spell(288106) then
            return 288106, false
        end
        if settings.use_teleport_enchanted and utility.can_cast_spell(959728) then
            return 959728, false
        end
    elseif class == 'spiritborn' then
        if settings.use_soar and utility.can_cast_spell(1871821) then
            return 1871821, false
        end
        if settings.use_rushing_claw and utility.can_cast_spell(1871761) then
            return 1871761, false
        end
        if settings.use_hunter and utility.can_cast_spell(1663206) then
            return 1663206, false
        end
    elseif class == 'rogue' then
        if settings.use_dash and utility.can_cast_spell(358761) then
            return 358761, false
        end
    elseif class == 'barbarian' then
        if settings.use_leap and utility.can_cast_spell(196545) then
            return 196545, false
        end
        if settings.use_charge and utility.can_cast_spell(204662) then
            return 204662, true
        end
    elseif class == 'paladin' then
        if settings.use_falling_star and utility.can_cast_spell(2106904) then
            return 2106904, true
        end
        if settings.use_aoj and utility.can_cast_spell(2297125) then
            return 2297125, true
        end
    end
    -- class == 'default' or class == 'druid' or class == 'necromancer'
    -- everyone has evade (hopefully)
    if settings.use_evade and utility.can_cast_spell(337031) then
        return 337031, false
    end
    return nil, false
end
local select_target
select_target = function (prev_target)
    local local_player = get_local_player()
    if not local_player then return nil end
    local player_pos = local_player:get_position()
    local traversals = get_nearby_travs(local_player)
    if #traversals > 0 then
        local closest_trav = nil
        local closest_dist = nil
        local closest_pos = nil
        local closest_str = nil
        for _, trav in ipairs(traversals) do
            local trav_pos = trav:get_position()
            local trav_name = trav:get_skin_name()
            local trav_str = trav_name .. utils.vec_to_string(trav_pos)
            local cur_dist = utils.distance_z(player_pos, trav_pos)
            if navigator.blacklisted_trav[trav_str] == nil and
                (closest_trav == nil or cur_dist < closest_dist) and
                utils.distance(player_pos, trav_pos) <= 15
            then
                closest_dist = cur_dist
                closest_trav = trav
                closest_pos = trav_pos
                closest_str = trav_str
            end
        end
        -- local diff_z = utils.distance_z(closest_pos, player_pos)
        if closest_trav ~= nil and
            closest_dist <= 15 and
            navigator.last_trav == nil and
            closest_pos ~= nil and
            math.abs(closest_pos:z() - player_pos:z()) <= 3 and
            (navigator.trav_delay == nil or get_time_since_inject() > navigator.trav_delay)
        then
            local closest_node = get_closeby_node(closest_trav:get_position(), 2)
            if closest_node == nil then
                navigator.blacklisted_trav[closest_str] = closest_str
                return select_target(prev_target)
            end
            navigator.last_trav = closest_trav
            utils.log(1, 'selecting traversal ' .. closest_trav:get_skin_name())
            return closest_node
        end
    else
        navigator.last_trav = nil
        navigator.blacklisted_trav = {}
    end
    local target = explorer_dfs.select_node(local_player, prev_target)
    if target ~= nil then
        utils.log(2, 'selecting target ' .. utils.vec_to_string(target))
    else
        utils.log(2, 'selecting target nil')
    end
    return target
end
local function shuffle_table(tbl)
    local len = #tbl
    for i = len, 2, -1 do
        -- Generate a random index 'j' between 1 and 'i' (inclusive)
        local j = math.random(i)
        -- Swap the elements at positions 'i' and 'j'
        tbl[i], tbl[j] = tbl[j], tbl[i]
    end
    return tbl
end
local get_unstuck_node = function ()
    -- get a node that is perpendicular to the first node in path from current node
    -- i.e. turn 90 degress left or right 
    local cur_node = navigator.last_pos
    local step = navigator.movement_step
    local test_node, test_node_str, valid, walkable

    if cur_node ~= nil then
        local x = cur_node:x()
        local y = cur_node:y()

        local directions = {
            {-step, 0},  -- up
            {0, step}, -- right
            {step, 0}, -- down
            {0, -step}, -- left
            {-step, step}, -- up-right
            {-step, -step}, -- up-left
            {step, step}, -- down-right
            {step, -step}, -- down-left
        }
        -- randomize direction order
        directions = shuffle_table(directions)
        for _, direction in ipairs(directions) do
            local dx = direction[1]
            local dy = direction[2]
            local new_x = x + dx
            local new_y = y + dy
            test_node = vec3:new(new_x, new_y, cur_node:z())
            test_node_str = utils.vec_to_string(test_node)
            valid = utility.set_height_of_valid_position(test_node)
            walkable = utility.is_point_walkeable(valid)
            if walkable and navigator.unstuck_nodes[test_node_str] ~= 'injected' then
                return valid, test_node_str
            end
        end
    end
    return nil, nil
end
local unstuck = function (local_player)
    local unstuck_node, unstuck_node_str = get_unstuck_node()
    if unstuck_node ~= nil and unstuck_node_str ~= nil then
        -- try evade if not add to path
        local movement_spell_id, need_raycast = get_movement_spell_id(local_player)
        local raycast_success = true
        if need_raycast then
            local dist = utils.distance(navigator.last_pos, unstuck_node)
            raycast_success = utility.is_ray_cast_walkeable(navigator.last_pos, unstuck_node, 0.5, dist)
        end
        if utility.can_cast_spell(337031) and
            navigator.unstuck_nodes[unstuck_node_str] == nil
        then
            utils.log(1, 'unstuck by evading')
            navigator.unstuck_nodes[unstuck_node_str] = 'evaded'
            cast_spell.position(337031, unstuck_node, 0)
            return
        elseif movement_spell_id ~= nil and raycast_success and
            (navigator.unstuck_nodes[unstuck_node_str] == nil or
            navigator.unstuck_nodes[unstuck_node_str] == 'evaded')
        then
            utils.log(1, 'unstuck by movement spell')
            navigator.unstuck_nodes[unstuck_node_str] = 'teleporting'
            cast_spell.position(movement_spell_id, unstuck_node, 0)
            return
        else
            utils.log(1, 'unstuck by injecting path')
            navigator.unstuck_nodes[unstuck_node_str] = 'injected'
            table.insert(navigator.path, 1, unstuck_node)
            return
        end
    end
    utils.log(1, 'unstuck by choosing new target')
    navigator.target = select_target(navigator.target)
    navigator.is_custom_target = false
    navigator.unstuck_nodes = {}
end
navigator.is_done = function ()
    return navigator.done
end
navigator.pause = function ()
    navigator.paused = true
    tracker.paused = true
end
navigator.unpause = function ()
    navigator.paused = false
    tracker.paused = false
end
navigator.update = function ()
    if navigator.update_time + navigator.update_timeout > get_time_since_inject() then return end
    navigator.update_time = get_time_since_inject()
    local local_player = get_local_player()
    if not local_player then return end
    if has_traversal_buff(local_player) then return end
    explorer_dfs.update(local_player)
end
navigator.reset = function ()
    utils.log(1, 'reseting')
    explorer_dfs.reset()
    navigator.target = nil
    navigator.is_custom_target = false
    navigator.done = false
    navigator.done_delay = nil
    navigator.path = {}
    navigator.last_trav = nil
    navigator.trav_delay = nil
    navigator.last_pos = nil
    navigator.last_update = nil
    navigator.done_delay = nil
    navigator.unstuck_nodes = {}
    navigator.blacklisted_trav = {}
    navigator.blacklisted_spell_node = {}
end
navigator.set_target = function (target, disable_spell)
    if target.get_position then
        target = target:get_position()
    end
    local new_target = utils.normalize_node(target)
    if navigator.target == nil or
        utils.distance(navigator.target, new_target) > 0 or
        navigator.disable_spell ~= disable_spell
    then
        navigator.target = new_target
        navigator.is_custom_target = true
        navigator.path = {}
        navigator.disable_spell = disable_spell
    end
    explorer_dfs.backtracking = false
end
navigator.clear_target = function ()
    navigator.target = nil
    navigator.is_custom_target = false
    navigator.path = {}
    navigator.disable_spell = nil
end
navigator.move = function ()
    if navigator.move_time + navigator.move_timeout > get_time_since_inject() then return end
    navigator.move_time = get_time_since_inject()
    local local_player = get_local_player()
    if not local_player then return end
    local player_pos = local_player:get_position()
    local cur_node = utils.normalize_node(player_pos)
    local traversals = get_nearby_travs(local_player)
    if #traversals > 0 then
        local trav = navigator.last_trav
        if trav ~= nil and utils.distance(player_pos, trav:get_position()) <= 3 and
            (navigator.trav_delay == nil or get_time_since_inject() > navigator.trav_delay)
        then
            interact_object(trav)
            local name = trav:get_skin_name()
            if name:match('Jump') then
                -- jump doesnt have traversal buff for some reason
                navigator.target = nil
                navigator.is_custom_target = false
                navigator.path = {}
                navigator.disable_spell = nil
                navigator.last_trav = nil
                navigator.trav_delay = get_time_since_inject() + 4
            end
        end
        if has_traversal_buff(local_player) then
            navigator.trav_delay = get_time_since_inject() + 4
            navigator.target = nil
            navigator.is_custom_target = false
            navigator.path = {}
            navigator.disable_spell = nil
            navigator.last_trav = nil
        end
    end

    -- movement spells
    if not utils.player_in_town() and #navigator.path > 0 then
        local movement_spell_id, need_raycast = get_movement_spell_id(local_player)
        if movement_spell_id ~= nil then
            local spell_node = nil
            local node_dist = -1
            local new_path = {}
            local selected = false
            for _, node in ipairs(navigator.path) do
                local dist = utils.distance(node, cur_node)
                local node_str = utils.vec_to_string(node)
                if selected or dist > navigator.spell_dist or node_dist > dist then
                    new_path[#new_path+1] = node
                    selected = true
                elseif navigator.blacklisted_spell_node[node_str] == nil and
                    -- move to nodes that is >= movement step 
                    utils.distance(node, cur_node) >= navigator.movement_step
                then
                    spell_node = node
                    node_dist = dist
                end
            end
            if spell_node ~= nil then
                local raycast_success = true
                if need_raycast then
                    local dist = utils.distance(cur_node, spell_node)
                    raycast_success = utility.is_ray_cast_walkeable(cur_node, spell_node, 0.5, dist)
                end
                if raycast_success then
                    local success = cast_spell.position(movement_spell_id, spell_node, 0)
                    if success then
                        utils.log(2, 'movement spell to ' .. utils.vec_to_string(spell_node))
                        if not navigator.paused then navigator.update() end
                        player_pos = local_player:get_position()
                        cur_node = utils.normalize_node(player_pos)
                        navigator.path = new_path
                        local node_str = utils.vec_to_string(spell_node)
                        navigator.blacklisted_spell_node[node_str] = spell_node
                    end
                end
            end
        end
    end

    local update_timeout = 1
    if utils.player_in_town() then update_timeout = 10 end
    if not has_traversal_buff(local_player) and
        navigator.last_trav == nil and
        (navigator.target == nil or utils.distance(cur_node, navigator.target) <= 1)
    then
        navigator.blacklisted_spell_node = {}
        if navigator.paused then return end
        navigator.target = select_target(nil)
        navigator.is_custom_target = false
        navigator.path = {}
        navigator.disable_spell = nil
    elseif navigator.target ~= nil and
        navigator.last_update ~= nil and
        navigator.last_update + update_timeout < get_time_since_inject() and
        not utils.is_cced(local_player)
    then
        unstuck(local_player)
        navigator.last_update = navigator.last_update + 0.25
    end
    if navigator.last_pos == nil or
        utils.distance(cur_node, navigator.last_pos) >= 0.5 or
        has_traversal_buff(local_player) or
        utils.is_cced(local_player)
    then
        navigator.last_pos = cur_node
        navigator.unstuck_nodes = {}
        if navigator.last_update == nil or navigator.last_update < get_time_since_inject() then
            navigator.last_update = get_time_since_inject()
        end
    end

    if navigator.target == nil and
        navigator.last_trav == nil and
        not has_traversal_buff(local_player)
    then
        if navigator.done_delay ~= nil and navigator.done_delay < get_time_since_inject() then
            if explorer_dfs.frontier_count > 0 and #explorer_dfs.backtrack == 0 then
                utils.log(1, 'not done but no more backtrack, reseting')
                navigator.reset()
                return
            else
                navigator.done = true
                utils.log(1, 'finish exploration')
            end
        elseif navigator.done_delay == nil then
            navigator.done_delay = get_time_since_inject() + 1
        end
        return
    else
        navigator.done_delay = nil
    end

    if navigator.target ~= nil and (#navigator.path == 0 or
        utils.distance(navigator.path[1], navigator.last_pos) > navigator.movement_dist)
    then
        local result = path_finder.find_path(navigator.last_pos, navigator.target, navigator.is_custom_target)
        if #result == 0 then
            tracker.debug_node = navigator.target
            if navigator.paused then return end
            navigator.target = select_target(navigator.target)
            navigator.is_custom_target = false
            navigator.path = {}
            navigator.disable_spell = nil
            return
        end
        tracker.debug_node = nil
        navigator.path = result
    end

    local moved = false
    local new_path = {}
    for _, node in ipairs(navigator.path) do
        if utils.distance(node, cur_node) >= 1 then
            if not moved and
                -- move to nodes that is >= movement step 
                (utils.distance(node, cur_node) >= navigator.movement_step or
                -- or if it is close to target
                (navigator.target ~= nil and utils.distance(node, navigator.target) == 0))
            then
                pathfinder.request_move(node)
                moved = true
                utils.log(2, 'moving to ' .. utils.vec_to_string(node))
            end
            new_path[#new_path+1] = node
        else
            new_path = {}
        end
    end
    navigator.path = new_path
end


return navigator