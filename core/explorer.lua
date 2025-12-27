local node_selector = require 'core.node_selector_dfs'
local path_finder = require 'core.pathfinder_astar'

local explorer = {
    last_pos = nil,
    last_update = -1,
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
}
local vec_to_string = function (node)
    return tostring(node:x()) .. ',' .. tostring(node:y())
end
local normalize_value = function (val)
    local normalizer = explorer.normalizer
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
    local dx = math.abs(a:x() - b:x())
    local dy = math.abs(a:y() - b:y())
    local dz = math.abs(a:z() - b:z())

    -- Sort differences: d1 >= d2 >= d3
    local diffs = {dx, dy, dz}
    table.sort(diffs, function(x, y) return x > y end)

    return diffs[1] + (math.sqrt(2) - 1) * diffs[2] + (math.sqrt(3) - math.sqrt(2)) * diffs[3]
end
local get_nearby_travs = function (local_player)
    local traversals = {}
    local actors = actors_manager:get_all_actors()
    for _, actor in pairs(actors) do
        local name = actor:get_skin_name()
        if name:match('[Tt]raversal') then
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
local is_cced = function (local_player)
    return false
end
local get_closeby_node = function (trav_node, max_dist)
    local local_player = get_local_player()
    if not local_player then return nil end
    local cur_node = normalize_node(local_player:get_position())
    local step = explorer.step

    local closest_node = nil
    local closest_dist = nil

    for i = trav_node:x()-max_dist, trav_node:x()+max_dist, step do
        for j = trav_node:y()-max_dist, trav_node:y()+max_dist, step do
            local new_node =  vec3:new(i, j, 0)
            local valid = utility.set_height_of_valid_position(new_node)
            local walkable = utility.is_point_walkeable(valid)
            if walkable then
                local result = path_finder.find_path(cur_node, new_node)
                local dist = distance(trav_node,new_node)
                if #result > 0 and (closest_dist == nil or dist < closest_dist) then
                    closest_node = new_node
                    closest_dist = dist
                end
            end
        end
    end
    return closest_node
end
local select_target = function (prev_target)
    local local_player = get_local_player()
    if not local_player then return nil end
    local traversals = get_nearby_travs(local_player)
    if #traversals > 0 then
        local closest_trav = nil
        local closest_dist = nil
        for _, trav in ipairs(traversals) do
            local cur_dist = distance_z(local_player:get_position(), trav:get_position())
            if closest_trav == nil or cur_dist < closest_dist then
                closest_dist = cur_dist
                closest_trav = trav
            end
        end
        if closest_trav ~= nil and closest_dist <= 15 and explorer.last_trav == nil then
            explorer.last_trav = closest_trav
            return get_closeby_node(normalize_node(closest_trav:get_position()), 2)
        end
    else
        explorer.last_trav = nil
    end
    return node_selector.select_node(prev_target)
end
local unstuck = function (local_player)
    explorer.target = node_selector.select_node(local_player, explorer.target)
    explorer.path = {}
    -- explorer.last_update = get_time_since_inject()
end
explorer.distance = function (a, b)
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
explorer.is_done = function ()
    return explorer.done
end
explorer.pause = function ()
    explorer.paused = true
end
explorer.unpause = function ()
    explorer.paused = false
end
explorer.update = function ()
    local local_player = get_local_player()
    if not local_player then return end
    local cur_node = normalize_node(local_player:get_position())
    local traversals = get_nearby_travs(local_player)
    if #traversals > 0 and has_traversal_buff(local_player) then return end

    node_selector.set_current_pos(local_player)
    node_selector.update_frontier(local_player)
    node_selector.mark_visited(cur_node)
end
explorer.reset = function ()
    node_selector.reset()
    explorer.target = nil
    explorer.done = false
    explorer.path = {}
    explorer.last_trav = nil
    explorer.trav_delay = nil
    explorer.last_pos = nil
    explorer.done_delay = nil
end
explorer.set_target = function (target)
    if target.get_position then
        target = target:get_position()
    end
    local new_target = normalize_node(target)
    if explorer.target == nil or
        distance(explorer.target, new_target) > 0 or
        #explorer.path < 5
    then
        explorer.target = new_target
        explorer.path = {}
    end
end
explorer.set_goal = function (goal)
    if type(goal) == 'string' then
        
    elseif goal.get_position then
        explorer.goal = normalize_node(goal:get_position())
        if distance(explorer.last_pos, explorer.goal) <= 50 then
            explorer.set_target(explorer.goal)
        end
    elseif goal.x and goal.y and goal.z then
        explorer.goal = normalize_node(goal)
        if distance(explorer.last_pos, explorer.goal) <= 50 then
            explorer.set_target(explorer.goal)
        end
    else
        -- not implemented
    end
end
local vec_to_string = function (node)
    return tostring(node:x()) .. ',' .. tostring(node:y())
end
explorer.move = function ()
    local local_player = get_local_player()
    if not local_player then return end
    local cur_node = normalize_node(local_player:get_position())
    local traversals = get_nearby_travs(local_player)
    if #traversals > 0 then
        if explorer.trav_delay == nil or get_time_since_inject() > explorer.trav_delay then
            for _, trav in ipairs(traversals) do
                if distance(cur_node, normalize_node(trav:get_position())) <= 3 and explorer.target ~= nil then
                    interact_object(trav)
                end
            end
        end
        if has_traversal_buff(local_player) then
            explorer.trav_delay = get_time_since_inject() + 2
            explorer.target = nil
            return
        end
    end
    if explorer.target == nil or distance(cur_node, explorer.target) <= 1 then
        if explorer.paused then return end
        if type(explorer.goal) == 'string' then
        
        elseif explorer.goal == nil then
            explorer.target = select_target(nil)
            explorer.path = {}
        end
    elseif explorer.last_update + 1 < get_time_since_inject() and not is_cced(local_player) then
        if not explorer.paused then
            unstuck()
        else
            -- explorer paused, probably in combat, extend update
            explorer.last_update = get_time_since_inject()
            return
        end
    end

    if explorer.last_pos == nil or distance(cur_node, explorer.last_pos) >= 0.5 then
        explorer.last_pos = cur_node
        explorer.last_update = get_time_since_inject()
    end

    if explorer.target == nil then
        if explorer.done_delay ~= nil and explorer.done_delay < get_time_since_inject() then
            explorer.done = true
        elseif explorer.done == nil then
            explorer.done_delay = get_time_since_inject() + 1
        end
        return
    else
        explorer.done_delay = nil
    end

    if #explorer.path == 0 or distance(explorer.path[1],explorer.last_pos) > 2 then
        local result = path_finder.find_path(explorer.last_pos, explorer.target)
        if #result == 0 then
            console.print('no path to target')
            if not explorer.paused then
                explorer.target = node_selector.select_node(local_player, explorer.target)
                explorer.path = {}
            end
            return
        end
        explorer.path = result
    end

    local moved = false
    local new_path = {}
    for _, node in ipairs(explorer.path) do
        if distance(node, cur_node) > 0 then
            if not moved and distance(node, cur_node) >= 1 then
                console.print(vec_to_string(node))
                pathfinder.force_move(node)
                moved = true
            end
            new_path[#new_path+1] = node
        end
    end
    explorer.path = new_path
end


return explorer