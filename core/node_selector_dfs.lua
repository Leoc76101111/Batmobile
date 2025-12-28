
local node_selector_dfs = {
    visited = {},
    frontier = {},
    frontier_order = {},
    cur_pos = nil,
    prev_pos = nil,
    backtrack = {},
    last_dir = nil,
    radius = 10,
    frontier_radius = 11,
    step = 0.5,
    normalizer = 2, -- *10/5 to get steps of 0.5
    backtracking = false,
}
local normalize_value = function (val)
    local normalizer = node_selector_dfs.normalizer
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
local distance = function (a, b)
    local dx = math.abs(a:x() - b:x())
    local dy = math.abs(a:y() - b:y())
    return math.max(dx, dy) + (math.sqrt(2) - 1) * math.min(dx, dy)
end
local remove_frontier = function (node_str)
    node_selector_dfs.frontier[node_str] = nil
    local key = nil
    for index, cur_str in ipairs(node_selector_dfs.frontier_order) do
        if cur_str == node_str then
            key = index
            break
        end
    end
    if key ~= nil then
        table.remove(node_selector_dfs.frontier_order, key)
    end
end
local get_perimeter = function (node)
    local perimeter = {}

    local cur_pos = node_selector_dfs.cur_pos
    local radius = node_selector_dfs.radius
    local step = node_selector_dfs.step
    local x = cur_pos:x()
    local y = cur_pos:y()
    local min_x = x - radius
    local max_x = x + radius
    local min_y = y - radius
    local max_y = y + radius
    for i = min_x, max_x, step do
        for j = min_y, max_y, step do
            if not (i == node:x() and j == node:y()) and
                not (i ~= min_x and i ~= max_x and j ~= min_y and j ~= max_y)
            then
                local norm_x = normalize_value(i)
                local norm_y = normalize_value(j)
                local new_node =  vec3:new(norm_x, norm_y, 0)
                local new_node_str = vec_to_string(new_node)
                if node_selector_dfs.visited[new_node_str] == nil then
                    local valid = utility.set_height_of_valid_position(new_node)
                    local walkable = utility.is_point_walkeable(valid)
                    if walkable then
                        perimeter[#perimeter+1] = new_node
                    end
                end
            end
        end
    end
    return perimeter
end
node_selector_dfs.get_perimeter = function (local_player)
    if node_selector_dfs.cur_pos == nil then
        node_selector_dfs.set_current_pos(local_player)
    end
    return get_perimeter(node_selector_dfs.cur_pos)
end
node_selector_dfs.reset = function ()
    node_selector_dfs.visited = {}
    node_selector_dfs.frontier = {}
    node_selector_dfs.frontier_order = {}
    node_selector_dfs.cur_pos = nil
    node_selector_dfs.prev_pos = nil
    node_selector_dfs.backtrack = {}
    node_selector_dfs.last_dir = nil
    node_selector_dfs.backtracking = false
end
node_selector_dfs.set_current_pos = function (local_player)
    node_selector_dfs.prev_pos = node_selector_dfs.cur_pos
    node_selector_dfs.cur_pos = normalize_node(local_player:get_position())
    if not node_selector_dfs.backtracking then
        if #node_selector_dfs.backtrack > 0 then
            local last_index = #node_selector_dfs.backtrack
            local last_pos = node_selector_dfs.backtrack[last_index]

            local dist = distance(last_pos, node_selector_dfs.cur_pos)
            if dist >= 4 then
                node_selector_dfs.backtrack[last_index+1] = node_selector_dfs.cur_pos
            end
        else
            node_selector_dfs.backtrack[1] = node_selector_dfs.cur_pos
        end
    end
end
node_selector_dfs.update = function (local_player)
    node_selector_dfs.set_current_pos(local_player)
    local cur_pos = node_selector_dfs.cur_pos
    local prev_pos = node_selector_dfs.prev_pos
    if prev_pos ~= nil and distance(cur_pos,prev_pos) == 0 then return end

    local x = cur_pos:x()
    local y = cur_pos:y()

    local f_radius = node_selector_dfs.frontier_radius
    local v_radius = node_selector_dfs.radius
    local step = node_selector_dfs.step

    local f_min_x = x - f_radius
    local f_max_x = x + f_radius
    local f_min_y = y - f_radius
    local f_max_y = y + f_radius

    local v_min_x = x - v_radius + step
    local v_max_x = x + v_radius - step
    local v_min_y = y - v_radius + step
    local v_max_y = y + v_radius - step

    for i = f_min_x, f_max_x, step do
        for j = f_min_y, f_max_y, step do
            local norm_x = normalize_value(i)
            local norm_y = normalize_value(j)
            local node =  vec3:new(norm_x, norm_y, 0)
            local node_str = vec_to_string(node)

            if node_selector_dfs.visited[node_str] == nil then
                if i >= v_min_x and i <= v_max_x and j >= v_min_y and j <= v_max_y then
                    node_selector_dfs.visited[node_str] = node
                    if node_selector_dfs.frontier[node_str] ~= nil and
                        node_selector_dfs.frontier[node_str] ~= nil
                    then
                        remove_frontier(node_str)
                    end
                elseif node_selector_dfs.frontier[node_str] == nil then
                    local valid = utility.set_height_of_valid_position(node)
                    local walkable = utility.is_point_walkeable(valid)
                    if walkable then
                        node_selector_dfs.frontier[node_str] = node
                        local index = #node_selector_dfs.frontier_order
                        node_selector_dfs.frontier_order[index+1] = node_str
                    end
                end
            end
        end
    end
end
node_selector_dfs.select_node = function (local_player, failed)
    if node_selector_dfs.cur_pos == nil then
        node_selector_dfs.set_current_pos(local_player)
    end
    if failed ~= nil then
        -- if failed at backtrack, try again
        if node_selector_dfs.backtracking then return failed end
        failed = normalize_node(failed)
        local failed_str = vec_to_string(failed)
        node_selector_dfs.visited[failed_str] = failed
    end
    -- get all perimeter (unvisited) of current position
    local perimeter = get_perimeter(node_selector_dfs.cur_pos)

    -- if there are unvisited perimeter, try to maintain direction
    if #perimeter > 0 then
        if node_selector_dfs.last_dir ~= nil then
            local last_dx = node_selector_dfs.last_dir[1]
            local last_dy = node_selector_dfs.last_dir[2]
            local check_pos = node_selector_dfs.cur_pos
            if failed ~= nil then
                check_pos = failed
            end

            -- closest direction
            local closest_dir_node = nil
            local closest_dir_diff = nil
            local closest_dir_dx = nil
            local closest_dir_dy = nil

            for _, p_node in ipairs(perimeter) do
                local dx = p_node:x() - check_pos:x()
                local dy = p_node:y() - check_pos:y()
                local diff = math.abs(dx - last_dx) + math.abs(dy - last_dy)
                if closest_dir_diff == nil or closest_dir_diff > diff then
                    closest_dir_diff = diff
                    closest_dir_node = p_node
                    closest_dir_dx = dx
                    closest_dir_dy = dy
                end
            end

            node_selector_dfs.last_dir = {closest_dir_dx, closest_dir_dy}
            node_selector_dfs.backtracking = false
            return closest_dir_node
        end

        -- if no last direction, just pick first one
        local dx = perimeter[1]:x() - node_selector_dfs.cur_pos:x()
        local dy = perimeter[1]:y() - node_selector_dfs.cur_pos:y()
        node_selector_dfs.last_dir = {dx, dy}
        node_selector_dfs.backtracking = false
        return perimeter[1]
    end

    -- if no unvisited perimeter, try to find an unexplored node in frontier within distance
    while #node_selector_dfs.frontier_order > 0 do
        -- simulating pop()
        local last_index = #node_selector_dfs.frontier_order
        local most_recent_str = node_selector_dfs.frontier_order[last_index]
        node_selector_dfs.frontier_order[last_index] = nil

        -- skip if node is visited
        if node_selector_dfs.visited[most_recent_str] ~= nil then
            node_selector_dfs.frontier[most_recent_str] = nil
        else
            local frontier_node =  node_selector_dfs.frontier[most_recent_str]
            if distance(frontier_node, node_selector_dfs.cur_pos) <= 20 then
                node_selector_dfs.frontier[most_recent_str] = nil
                node_selector_dfs.backtracking = false
                return frontier_node
            end
            -- add back to frontier order, it is too far. use backtrack
            node_selector_dfs.frontier_order[last_index] = most_recent_str
            break
        end
    end
    -- only backtrack if there are still frontier nodes (to get closer to frontier node)
    if #node_selector_dfs.frontier_order > 0 then
        while #node_selector_dfs.backtrack > 0 do
            -- simulating pop()
            local last_index = #node_selector_dfs.backtrack
            local last_pos = node_selector_dfs.backtrack[last_index]
            node_selector_dfs.backtrack[last_index] = nil
            if distance(last_pos, node_selector_dfs.cur_pos) ~= 0 then
                node_selector_dfs.backtracking = true
                return last_pos
            end
        end
    end
    -- no perimeter, no frontier all explored
    return nil
end

return node_selector_dfs