local utils = require 'core.utils'
local settings = require 'core.settings'

local pathfinder_astar = {}

local get_lowest_f_score = function (open_set, f_score)
    local lowest = nil
    local lowest_node = nil
    for node_str, node in pairs(open_set) do
        if lowest == nil or f_score[node_str] < f_score[lowest] then
            lowest = node_str
            lowest_node = node
        end
    end
    return lowest, lowest_node
end
local heuristic = function (a, b)
    local dx = math.abs(a:x() - b:x())
    local dy = math.abs(a:y() - b:y())
    return math.max(dx, dy) + (math.sqrt(2) - 1) * math.min(dx, dy)
end
local reconstruct_path = function (closed_set, prev_nodes, cur_node)
    local path = {cur_node}
    local cur_str = utils.vec_to_string(cur_node)
    while prev_nodes[cur_str] ~= nil do
        cur_str = prev_nodes[cur_str]
        cur_node = closed_set[cur_str]
        table.insert(path, 1, cur_node)
    end
    return path
end
local get_neighbors = function (node, goal)
    local neighbors = {}
    local dist = settings.step
    local directions = {
        {-dist, 0},  -- up
        {0, dist}, -- right
        {dist, 0}, -- down
        {0, -dist}, -- left
        {-dist, dist}, -- up-right
        {-dist, -dist}, -- up-left
        {dist, dist}, -- down-right
        {dist, -dist}, -- down-left
    }
    for _, direction in ipairs(directions) do
        local dx = direction[1]
        local dy = direction[2]
        local newx = node:x() + dx
        local newy = node:y() + dy
        local neigh_node = vec3:new(newx, newy, node:z())
        local neigh_node_alt = vec3:new(newx, newy, goal:z())
        local valid = utility.set_height_of_valid_position(neigh_node)
        local walkable = utility.is_point_walkeable(valid)
        local walkable_alt = utility.is_point_walkeable(neigh_node_alt)
        if walkable then
            neighbors[#neighbors+1] = neigh_node
        elseif (newx == goal:x() and newy == goal:y()) then
            neighbors[#neighbors+1] = goal
        elseif walkable_alt then
            neighbors[#neighbors+1] = neigh_node_alt
        end
    end
    return neighbors
end
pathfinder_astar.get_counter = function ()
    return pathfinder_astar.counter
end
pathfinder_astar.find_path = function (start, goal)
    -- console.print('start pathfinding')
    local start_node = utils.normalize_node(start)
    local goal_node = utils.normalize_node(goal)
    local start_str = utils.vec_to_string(start_node)
    local open_set = {[start_str] = start_node}
    local closed_set = {}
    local g_score = {[start_str] = 0}
    local f_score = {[start_str] = heuristic(start_node, goal_node)}
    local prev_nodes = {}
    local counter = 0
    while utils.get_set_count(open_set) > 0 do
        if counter > 1500 then
            console.print('no path (over counter) ' .. utils.vec_to_string(start) .. '>' .. utils.vec_to_string(goal))
            return {}
        end
        counter = counter + 1
        local cur_str, cur_node = get_lowest_f_score(open_set, f_score)
        if utils.distance(cur_node, goal_node) == 0 then
            -- console.print('path found')
            return reconstruct_path(closed_set, prev_nodes, cur_node)
        end
        open_set[cur_str] = nil
        closed_set[cur_str] = cur_node

        for _, neighbor in ipairs(get_neighbors(cur_node, goal_node)) do
            local neigh_str = utils.vec_to_string(neighbor)
            if closed_set[neigh_str] == nil then
                local t_g_score = g_score[cur_str] + utils.distance(cur_node, neighbor)
                if open_set[neigh_str] == nil or t_g_score < g_score[neigh_str] then
                    prev_nodes[neigh_str] = cur_str
                    g_score[neigh_str] = t_g_score
                    f_score[neigh_str] = t_g_score + heuristic(neighbor, goal_node)
                end
                if open_set[neigh_str] == nil then
                    open_set[neigh_str] = neighbor
                end
            end
        end
    end
    console.print('no path (no openset) ' .. utils.vec_to_string(start) .. '>' .. utils.vec_to_string(goal))
    return {}
end

return pathfinder_astar