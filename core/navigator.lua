local explorer_dfs = require 'core.explorer_dfs'
local path_finder = require 'core.pathfinder_astar'
local utils = require 'core.utils'
local tracker = require 'core.tracker'

local navigator = {
    last_pos = nil,
    last_update = nil,
    target = nil,
    goal = nil,
    step = 0.5,
    normalizer = 2, -- *10/5 to get steps of 0.5
    done = false,
    paused = false,
    path = {},
    last_trav = nil,
    trav_delay = nil,
    done_delay = nil,
    movement_step = 4,
    is_custom_target = false,
    unstuck_nodes = {},
    blacklisted_trav = {},
}
local vec_to_string = function (node)
    return tostring(node:x()) .. ',' .. tostring(node:y())
end
local normalize_value = function (val)
    local normalizer = navigator.normalizer
    return tonumber(string.format("%.1f", math.floor(val * normalizer + 0.5) / normalizer))
end
local normalize_node = function (node)
    local norm_x = normalize_value(node:x())
    local norm_y = normalize_value(node:y())
    return vec3:new(norm_x, norm_y, 0)
end
local distance = function (a, b)
    local dx = math.abs(a:x() - b:x())
    local dy = math.abs(a:y() - b:y())
    return math.max(dx, dy) + (math.sqrt(2) - 1) * math.min(dx, dy)
end
local distance_z = function (a, b)
    return math.abs(a:z() - b:z())
end
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
    local cur_node = normalize_node(local_player:get_position())
    local norm_trav = normalize_node(trav_node)
    local step = navigator.step

    local nodes = {}
    for i = norm_trav:x()-max_dist, norm_trav:x()+max_dist, step do
        for j = norm_trav:y()-max_dist, norm_trav:y()+max_dist, step do
            local new_node =  vec3:new(i, j, 0)
            local valid = utility.set_height_of_valid_position(new_node)
            local walkable = utility.is_point_walkeable(valid)
            local diff_z = distance_z(trav_node, valid)
            if walkable and diff_z < 1 then
                nodes[#nodes+1] = new_node
            end
        end
    end
    table.sort(nodes, function(a, b)
        return distance(a, norm_trav) < distance(b, norm_trav)
    end)
    for _, node in ipairs(nodes) do
        local result = path_finder.find_path(cur_node, node)
        if #result > 0 then return node end
    end
    return nil
end
local select_target
select_target = function (prev_target)
    local local_player = get_local_player()
    if not local_player then return nil end
    navigator.is_custom_target = false
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
            local trav_str = trav_name .. vec_to_string(trav_pos)
            local cur_dist = distance_z(player_pos, trav_pos)
            if navigator.blacklisted_trav[trav_str] == nil and
                (closest_trav == nil or cur_dist < closest_dist) and
                distance(player_pos, trav_pos) <= 15
            then
                closest_dist = cur_dist
                closest_trav = trav
                closest_pos = trav_pos
                closest_str = trav_str
            end
        end
        -- local diff_z = distance_z(closest_pos, player_pos)
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
            return closest_node
        end
    else
        navigator.last_trav = nil
        navigator.blacklisted_trav = {}
    end
    return explorer_dfs.select_node(local_player, prev_target)
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
    local unstuck_node = nil
    local cur_node = navigator.last_pos
    local step = navigator.movement_step
    local test_node, test_node_str, valid, walkable

    
    -- -- to be worked on later
    -- local path_node = nil
    -- for _, node in ipairs(navigator.path) do
    --     if distance(node, cur_node) >= 1 then
    --         if path_node == nil and
    --             -- move to nodes that is >= movement step 
    --             (distance(node, cur_node) >= navigator.movement_step or
    --             -- or if it is close to target
    --             distance(node, navigator.target) == 0)
    --         then
    --             path_node = node
    --         end
    --     end
    -- end

    -- if path_node ~= nil and cur_node ~= nil then
    --     if cur_node:x() == path_node:x() then
    --         console.print('pattern 1')
    --         test_node = vec3:new(cur_node:x() + step, cur_node:y(), 0)
    --         test_node_str = vec_to_string(test_node)
    --         valid = utility.set_height_of_valid_position(test_node)
    --         walkable = utility.is_point_walkeable(valid)
    --         if walkable and navigator.unstuck_nodes[test_node_str] ~= 'injected' then
    --             navigator.unstuck_nodes[test_node_str] = test_node_str
    --             return valid, test_node_str
    --         else
    --             test_node = vec3:new(cur_node:x() - step, cur_node:y(), 0)
    --             test_node_str = vec_to_string(test_node)
    --             valid = utility.set_height_of_valid_position(test_node)
    --             walkable = utility.is_point_walkeable(valid)
    --         end
    --         if walkable and navigator.unstuck_nodes[test_node_str] ~= 'injected' then
    --             navigator.unstuck_nodes[test_node_str] = test_node_str
    --             return valid, test_node_str
    --         end
    --     elseif cur_node:y() == path_node:y() then
    --         console.print('pattern 2')
    --         test_node = vec3:new(cur_node:x(), cur_node:y() + step, 0)
    --         test_node_str = vec_to_string(test_node)
    --         valid = utility.set_height_of_valid_position(test_node)
    --         walkable = utility.is_point_walkeable(valid)
    --         if walkable and navigator.unstuck_nodes[test_node_str] ~= 'injected' then
    --             navigator.unstuck_nodes[test_node_str] = test_node_str
    --             return valid, test_node_str
    --         else
    --             test_node = vec3:new(cur_node:x(), cur_node:y() - step, 0)
    --             test_node_str = vec_to_string(test_node)
    --             valid = utility.set_height_of_valid_position(test_node)
    --             walkable = utility.is_point_walkeable(valid)
    --         end
    --         if walkable and navigator.unstuck_nodes[test_node_str] ~= 'injected' then
    --             navigator.unstuck_nodes[test_node_str] = test_node_str
    --             return valid, test_node_str
    --         end
    --     elseif (cur_node:x() > path_node:x() and cur_node:y() > path_node:y()) or
    --         (cur_node:x() < path_node:x() and cur_node:y() < path_node:y())
    --     then
    --         console.print('pattern 3')
    --         test_node = vec3:new(cur_node:x() - step, cur_node:y() + step, 0)
    --         test_node_str = vec_to_string(test_node)
    --         valid = utility.set_height_of_valid_position(test_node)
    --         walkable = utility.is_point_walkeable(valid)
    --         if walkable and navigator.unstuck_nodes[test_node_str] ~= 'injected' then
    --             navigator.unstuck_nodes[test_node_str] = test_node_str
    --             return valid, test_node_str
    --         else
    --             test_node = vec3:new(cur_node:x() + step, cur_node:y() - step, 0)
    --             test_node_str = vec_to_string(test_node)
    --             valid = utility.set_height_of_valid_position(test_node)
    --             walkable = utility.is_point_walkeable(valid)
    --         end
    --         if walkable and navigator.unstuck_nodes[test_node_str] ~= 'injected' then
    --             navigator.unstuck_nodes[test_node_str] = test_node_str
    --             return valid, test_node_str
    --         end
    --     elseif (cur_node:x() < path_node:x() and cur_node:y() > path_node:y()) or
    --         (cur_node:x() > path_node:x() and cur_node:y() < path_node:y())
    --     then
    --         console.print('pattern 4')
    --         test_node = vec3:new(cur_node:x() + step, cur_node:y() + step, 0)
    --         test_node_str = vec_to_string(test_node)
    --         valid = utility.set_height_of_valid_position(test_node)
    --         walkable = utility.is_point_walkeable(valid)
    --         if walkable and navigator.unstuck_nodes[test_node_str] ~= 'injected' then
    --             navigator.unstuck_nodes[test_node_str] = test_node_str
    --             return valid, test_node_str
    --         else
    --             test_node = vec3:new(cur_node:x() - step, cur_node:y() - step, 0)
    --             test_node_str = vec_to_string(test_node)
    --             valid = utility.set_height_of_valid_position(test_node)
    --             walkable = utility.is_point_walkeable(valid)
    --         end
    --         if walkable and navigator.unstuck_nodes[test_node_str] ~= 'injected' then
    --             navigator.unstuck_nodes[test_node_str] = test_node_str
    --             return valid, test_node_str
    --         end
    --     end
    -- end

    local messages = {}
    local msg = ''
    if cur_node ~= nil then
        -- console.print('pattern all')
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
            test_node = vec3:new(new_x, new_y, 0)
            test_node_str = vec_to_string(test_node)
            valid = utility.set_height_of_valid_position(test_node)
            walkable = utility.is_point_walkeable(valid)
            messages[#messages+1] = test_node_str .. '=' .. tostring(navigator.unstuck_nodes[test_node_str])
            if walkable and navigator.unstuck_nodes[test_node_str] ~= 'injected' then
                for _, parts in ipairs(messages) do
                    msg = msg .. parts ..','
                end
                console.print(msg)
                return valid, test_node_str
            end
        end
    end
    for _, parts in ipairs(messages) do
        msg = msg .. parts ..','
    end
    console.print(msg)
    return nil, nil
end
local unstuck = function (local_player)
    console.print('stuck')
    console.print('current time ' .. get_time_since_inject())
    console.print('update_time ' .. navigator.last_update)
    local cur_node = normalize_node(local_player:get_position())
    console.print(vec_to_string(cur_node))
    console.print(vec_to_string(navigator.target))
    if navigator.path[1] ~= nil then
        console.print(vec_to_string(navigator.path[1]))
    else
        console.print('nil')
    end
    local unstuck_node, unstuck_node_str = get_unstuck_node()
    if unstuck_node ~= nil and unstuck_node_str ~= nil then
        console.print('node')
        console.print(vec_to_string(unstuck_node))
        -- try evade if not add to path
        if local_player:is_spell_ready(337031) and
            navigator.unstuck_nodes[unstuck_node_str] == nil
        then
            console.print('unstuck by evading')
            navigator.unstuck_nodes[unstuck_node_str] = 'evaded'
            local success = cast_spell.position(337031, unstuck_node, 0)
            console.print(tostring(success))
            return
        elseif navigator.unstuck_nodes[unstuck_node_str] == 'evaded' then
            console.print('unstuck by injecting path')
            navigator.unstuck_nodes[unstuck_node_str] = 'injected'
            table.insert(navigator.path, 1, unstuck_node)
            return
        end
    end
    console.print('unstuck by choosing new target')
    navigator.target = select_target(navigator.target)
    navigator.unstuck_nodes = {}
end
navigator.distance = function (a, b)
    if a.get_position then
        a = a:get_position()
    end
    if b.get_position then
        b = b:get_position()
    end
    a = normalize_node(a)
    b = normalize_node(b)
    return distance(a, b)
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
    local local_player = get_local_player()
    if not local_player then return end
    local traversals = get_nearby_travs(local_player)
    if #traversals > 0 and has_traversal_buff(local_player) then return end
    explorer_dfs.update(local_player)
end
navigator.reset = function ()
    explorer_dfs.reset()
    navigator.target = nil
    navigator.done = false
    navigator.path = {}
    navigator.last_trav = nil
    navigator.trav_delay = nil
    navigator.last_pos = nil
    navigator.done_delay = nil
    navigator.unstuck_nodes = {}
    navigator.blacklisted_trav = {}
end
navigator.set_target = function (target)
    if target.get_position then
        target = target:get_position()
    end
    local new_target = normalize_node(target)
    if navigator.target == nil or
        distance(navigator.target, new_target) > 0 or
        #navigator.path < 5
    then
        navigator.is_custom_target = false
        navigator.target = new_target
        navigator.path = {}
    end
end
navigator.clear_target = function ()
    navigator.target = nil
    navigator.path = {}
end
navigator.clear_goal = function()
    navigator.goal = nil
end
navigator.set_goal = function (goal)
    if type(goal) == 'string' then
        
    elseif goal.get_position then
        navigator.goal = normalize_node(goal:get_position())
        if distance(navigator.last_pos, navigator.goal) <= 50 then
            navigator.set_target(navigator.goal)
        end
    elseif goal.x and goal.y and goal.z then
        navigator.goal = normalize_node(goal)
        if distance(navigator.last_pos, navigator.goal) <= 50 then
            navigator.set_target(navigator.goal)
        end
    else
        -- not implemented
    end
end
local vec_to_string = function (node)
    return tostring(node:x()) .. ',' .. tostring(node:y())
end
navigator.move = function ()
    local local_player = get_local_player()
    if not local_player then return end
    local player_pos = local_player:get_position()
    local cur_node = normalize_node(player_pos)
    local traversals = get_nearby_travs(local_player)
    if #traversals > 0 then
        local trav = navigator.last_trav
        if trav ~= nil and distance(player_pos, trav:get_position()) <= 3 and
            (navigator.trav_delay == nil or get_time_since_inject() > navigator.trav_delay)
        then
            interact_object(trav)
            local name = trav:get_skin_name()
            if name:match('Jump') then
                -- jump doesnt have traversal buff for some reason
                navigator.target = nil
                navigator.last_trav = nil
                navigator.trav_delay = get_time_since_inject() + 2
            end
        end
        if has_traversal_buff(local_player) then
            navigator.trav_delay = get_time_since_inject() + 2
            navigator.target = nil
            navigator.last_trav = nil
        end
    end
    if not navigator.paused and navigator.last_trav == nil and
        not has_traversal_buff(local_player)
    then
        -- cast_spell.self(514030, 0)
        -- cast_spell.self(517417, 0)
        -- cast_spell.position(288106, player_pos, 0)
    end

    local update_timeout = 1
    if utils.player_in_town() then update_timeout = 10 end
    if not has_traversal_buff(local_player) and
        navigator.last_trav == nil and
        (navigator.target == nil or distance(cur_node, navigator.target) <= 1)
    then
        if navigator.paused then return end
        if type(navigator.goal) == 'string' then

        elseif navigator.goal == nil then
            navigator.target = select_target(nil)
            navigator.path = {}
        end
    elseif navigator.target ~= nil and
        navigator.last_update ~= nil and
        navigator.last_update + update_timeout < get_time_since_inject() and
        not utils.is_cced(local_player)
    then
        unstuck(local_player)
        navigator.last_update = navigator.last_update + 0.25
    end
    if navigator.last_pos == nil or
        distance(cur_node, navigator.last_pos) >= 0.5 or
        has_traversal_buff(local_player) or
        utils.is_cced(local_player)
    then
        navigator.last_pos = cur_node
        navigator.unstuck_nodes = {}
        if navigator.last_update == nil or navigator.last_update < get_time_since_inject() then
            navigator.last_update = get_time_since_inject()
        end
    end

    if navigator.target == nil and not has_traversal_buff(local_player) then
        if navigator.done_delay ~= nil and navigator.done_delay < get_time_since_inject() then
            navigator.done = true
            console.print('finish exploration')
        elseif navigator.done_delay == nil then
            navigator.done_delay = get_time_since_inject() + 1
        end
        return
    else
        navigator.done_delay = nil
    end

    if navigator.target ~= nil and
        (#navigator.path == 0 or distance(navigator.path[1],navigator.last_pos) >= 2)
    then
        local result = path_finder.find_path(navigator.last_pos, navigator.target)
        if #result == 0 then
            -- console.print('no path to target ' .. vec_to_string(navigator.target))
            tracker.debug_node = navigator.target
            if not navigator.paused then
                navigator.target = select_target(navigator.target)
                navigator.path = {}
            end
            return
        end
        tracker.debug_node = nil
        navigator.path = result
    end

    local moved = false
    local new_path = {}
    for _, node in ipairs(navigator.path) do
        if distance(node, cur_node) >= 1 then
            if not moved and
                -- move to nodes that is >= movement step 
                (distance(node, cur_node) >= navigator.movement_step or
                -- or if it is close to target
                (navigator.target ~= nil and distance(node, navigator.target) == 0))
            then
                pathfinder.request_move(node)
                moved = true
            end
            new_path[#new_path+1] = node
        end
    end
    navigator.path = new_path
end


return navigator