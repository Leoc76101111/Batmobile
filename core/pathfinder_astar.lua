
local pathfinder_astar = {
    counter = 0,
    neighors_distance = 0.5,
    normalizer = 2, -- *10/5 to get steps of 0.5
}

local normalize_value= function (val)
    local normalizer = pathfinder_astar.normalizer
    return tonumber(string.format("%.1f", math.floor(val * normalizer + 0.5) / normalizer))
end
local normalize_node = function (node)
    local norm_x = normalize_value(node:x())
    local norm_y = normalize_value(node:y())
    return vec3:new(norm_x, norm_y, 0)
end
local vec_to_string = function (node)
    return tostring(node:x()) .. ',' .. tostring(node:y())
end
local string_to_vec = function (str)
    local node = {}
    for match in string.gmatch(str, "([^,]+)") do
        node[#node+1] = normalize_value(tonumber(match))
    end
    return vec3:new(node[1], node[2], 0)
end
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
local distance = function (a, b)
    local dx = math.abs(a:x() - b:x())
    local dy = math.abs(a:y() - b:y())
    return math.max(dx, dy) + (math.sqrt(2) - 1) * math.min(dx, dy)
end
local is_equal = function(a, b)
    return a:x() == b:x() and a:y() == b:y()
end
local get_set_count = function (set)
    local counter = 0
    for _, item in pairs(set) do
        counter = counter + 1
    end
    return counter
end
local reconstruct_path = function (prev_nodes, cur_node)
    local cur_walkable_node = utility.set_height_of_valid_position(cur_node)
    -- local rev_path = {cur_walkable_node}
    local path = {cur_walkable_node}
    local cur_str = vec_to_string(cur_node)
    while prev_nodes[cur_str] ~= nil do
        cur_str = prev_nodes[cur_str]
        cur_node = string_to_vec(cur_str)
        cur_walkable_node = utility.set_height_of_valid_position(cur_node)
        -- rev_path[#rev_path+1] = cur_walkable_node
        table.insert(path, 1, cur_walkable_node)
    end
    -- local index = #rev_path
    -- path = {}
    -- for _, node in ipairs(rev_path) do
    --     path[index] = node
    --     index = index - 1
    -- end
    return path
end
local get_neighbors = function (node, goal)
    local neighbors = {}
    local dist = pathfinder_astar.neighors_distance
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
        local neigh_node = vec3:new(newx, newy, 0)
        local valid = utility.set_height_of_valid_position(neigh_node)
        local walkable = utility.is_point_walkeable(valid)
        if walkable or (newx == goal:x() and newy == goal:y()) then
            neighbors[#neighbors+1] = neigh_node
        end
    end
    return neighbors
end
pathfinder_astar.get_counter = function ()
    return pathfinder_astar.counter
end
pathfinder_astar.find_path = function (start, goal)
    console.print('start pathfinding')
    local start_node = normalize_node(start)
    local goal_node = normalize_node(goal)
    local start_str = vec_to_string(start_node)
    local open_set = {[start_str] = start_node}
    local closed_set = {}
    local g_score = {[start_str] = 0}
    local f_score = {[start_str] = heuristic(start_node, goal_node)}
    local prev_nodes = {}
    pathfinder_astar.counter = 0
    while get_set_count(open_set) > 0 do
        if pathfinder_astar.counter > 3000 then
            console.print('over counter')
            return {}
        end
        pathfinder_astar.counter = pathfinder_astar.counter + 1
        local cur_str, cur_node = get_lowest_f_score(open_set, f_score)
        if is_equal(cur_node, goal_node) then
            console.print('path found')
            return reconstruct_path(prev_nodes, cur_node)
        end
        open_set[cur_str] = nil
        closed_set[cur_str] = cur_node

        for _, neighbor in ipairs(get_neighbors(cur_node, goal_node)) do
            local neigh_str = vec_to_string(neighbor)
            if closed_set[neigh_str] == nil then
                local t_g_score = g_score[cur_str] + distance(cur_node, neighbor)
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
    console.print('no openset')
    return {}
end

return pathfinder_astar