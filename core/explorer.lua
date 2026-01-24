local utils = require 'core.utils'
local settings = require 'core.settings'

local explorer = {
    cur_pos = nil,
    prev_pos = nil,
    visited = {},
    visited_count = 0,
    radius = 12,
    retry = {},
    frontier = {},
    frontier_node = {},
    frontier_order = {},
    frontier_index = 0,
    frontier_count = 0,
    frontier_radius = 13,
    frontier_max_dist = 27,
    retry_count = 0,
    backtrack = {},
    backtrack_secondary = {},
    last_dir = nil,
    backtracking = false,
    backtrack_node = nil,
    backtrack_min_dist = 8,
    backtrack_failed_time = -1,
    backtrack_timeout = 5,
    priority = 'direction',
    wrong_dir_count = 0,
}
local add_frontier = function (node_str, node)
    explorer.frontier[node_str] = explorer.frontier_index
    explorer.frontier_node[node_str] = node
    explorer.frontier_order[explorer.frontier_index] = node_str
    explorer.frontier_index = explorer.frontier_index + 1
    explorer.frontier_count = explorer.frontier_count + 1
end
local remove_frontier = function (node_str)
    local index = explorer.frontier[node_str]
    if index ~= nil then
        explorer.frontier_order[index] = nil
        explorer.frontier[node_str] = nil
        explorer.frontier_node[node_str] = nil
        explorer.frontier_count = explorer.frontier_count - 1
    end
end
local add_visited = function (node_str)
    if explorer.visited[node_str] == nil then
        explorer.visited[node_str] = node_str
        explorer.visited_count = explorer.visited_count + 1
    end
end
local remove_visited = function (node_str)
    if explorer.visited[node_str] ~= nil then
        explorer.visited[node_str] = nil
        explorer.visited_count = explorer.visited_count - 1
    end
end
local add_retry = function (node_str)
    if explorer.retry[node_str] == nil then
        explorer.retry[node_str] = node_str
        explorer.retry_count = explorer.retry_count + 1
    end
end
local remove_retry = function (node_str)
    if explorer.retry[node_str] ~= nil then
        explorer.retry[node_str] = nil
        explorer.retry_count = explorer.retry_count - 1
    end
end
local get_perimeter = function (node)
    local perimeter = {}
    local radius = explorer.radius
    local step = settings.step
    local x = node:x()
    local y = node:y()
    local min_x = x - radius
    local max_x = x + radius
    local min_y = y - radius
    local max_y = y + radius
    for i = min_x, max_x, step do
        for j = min_y, max_y, step do
            if not (i == node:x() and j == node:y()) and
                not (i ~= min_x and i ~= max_x and j ~= min_y and j ~= max_y)
            then
                local norm_x = utils.normalize_value(i)
                local norm_y = utils.normalize_value(j)
                local new_node =  vec3:new(norm_x, norm_y, node:z())
                local new_node_str = utils.vec_to_string(new_node)
                if explorer.visited[new_node_str] == nil then
                    local valid = utility.set_height_of_valid_position(new_node)
                    local walkable = utility.is_point_walkeable(valid)
                    if walkable then
                        perimeter[#perimeter+1] = valid
                    end
                end
            end
        end
    end
    return perimeter
end
local restore_backtrack = function ()
    -- restore secondary backtrack, incase other frontier needs it
    local index = #explorer.backtrack_secondary
    local cur_node = explorer.cur_pos
    local backtrack_tertiary = {}
    -- add path back to when it first removed
    while index > 0 do
        local backtrack_node = explorer.backtrack_secondary[index]
        local need_backtrack_node = false
        local index2 = explorer.frontier_index
        while index2 >= 0 do
            local most_recent_str = explorer.frontier_order[index2]
            if most_recent_str ~= nil then
                -- skip if node is visited
                if explorer.visited[most_recent_str] ~= nil then
                    remove_frontier(most_recent_str)
                else
                    local frontier_node = explorer.frontier_node[most_recent_str]
                    local cur_dist = utils.distance(cur_node, frontier_node)
                    local backtrack_dist = utils.distance(backtrack_node, frontier_node)
                    if backtrack_dist < cur_dist and
                        backtrack_dist <= explorer.frontier_max_dist and
                        cur_dist > explorer.frontier_max_dist
                    then
                        need_backtrack_node = true
                        break
                    end
                end
            end
            index2 = index2 - 1
        end
        if need_backtrack_node then
            if #backtrack_tertiary ~= 0 then
                for _, t_backtrack_node in ipairs(backtrack_tertiary) do
                    utils.log(2, 'adding ' .. utils.vec_to_string(t_backtrack_node) .. ' backtracks')
                    explorer.backtrack[#explorer.backtrack+1] = t_backtrack_node
                end
                backtrack_tertiary = {}
            end
            explorer.backtrack[#explorer.backtrack+1] = backtrack_node
            utils.log(2, 'adding ' .. utils.vec_to_string(backtrack_node) .. ' backtracks')
        else
            backtrack_tertiary[#backtrack_tertiary+1] = backtrack_node
        end
        cur_node = backtrack_node
        index = index - 1
    end
    utils.log(2, 'skipping ' .. #backtrack_tertiary .. ' backtracks')
    utils.log(2, 'total ' .. #explorer.backtrack_secondary .. ' secondaries')
    -- add path from when it first removed (or first skipped) until now
    for index, backtrack in ipairs(explorer.backtrack_secondary) do
        if #backtrack_tertiary < index then
            utils.log(2, 'adding ' .. utils.vec_to_string(backtrack) .. ' backtracks')
            explorer.backtrack[#explorer.backtrack+1] = backtrack
        end
    end
    explorer.backtrack_secondary = {}
end
local select_node_distance = function ()
    -- get all perimeter (unvisited) of current position
    local perimeter = get_perimeter(explorer.cur_pos)
    -- furthest from first backtrack
    local furthest_node = nil
    local furthest_node_str = nil
    local furthers_dist = nil
    local check_pos = explorer.backtrack[1] or explorer.cur_pos
    local cur_dist = utils.distance(explorer.cur_pos, check_pos)

    -- check perimeter and frontier for furthest if not backtracking
    if explorer.wrong_dir_count <= 2 then
        for _, p_node in ipairs(perimeter) do
            local dist = utils.distance(p_node, check_pos)
            if furthest_node == nil or dist > furthers_dist then
                furthest_node = p_node
                furthers_dist = dist
            end
        end
        if furthers_dist ~= nil and furthers_dist < cur_dist then
            explorer.wrong_dir_count = explorer.wrong_dir_count + 1
        else
            explorer.wrong_dir_count = 0
        end
    end
    if furthest_node == nil then
        local index = explorer.frontier_index
        while index >= 0 do
            local most_recent_str = explorer.frontier_order[index]
            if most_recent_str ~= nil then
                -- skip if node is visited
                if explorer.visited[most_recent_str] ~= nil then
                    remove_frontier(most_recent_str)
                else
                    local frontier_node = explorer.frontier_node[most_recent_str]
                    local dist = utils.distance(frontier_node, check_pos)
                    if furthest_node == nil or dist > furthers_dist then
                        furthest_node = frontier_node
                        furthers_dist = dist
                        furthest_node_str = most_recent_str
                    end
                end
            end
            index = index - 1
        end
    end
    if furthest_node ~= nil and
        utils.distance(furthest_node, explorer.cur_pos) <= explorer.frontier_max_dist
    then
        if furthest_node_str ~= nil then
            explorer.wrong_dir_count = 0
            remove_frontier(furthest_node_str)
        end
        restore_backtrack()
        explorer.backtracking = false
        return furthest_node
    end
    -- only backtrack if there are still frontier nodes (to get closer to frontier node)
    if explorer.frontier_count > 0 then
        while #explorer.backtrack > 0 do
            -- simulating pop()
            local last_index = #explorer.backtrack
            local last_pos = explorer.backtrack[last_index]
            explorer.backtrack[last_index] = nil
            if utils.distance(last_pos, explorer.cur_pos) ~= 0 then
                explorer.backtracking = true
                -- store backrack to secondary so it can be restored
                explorer.backtrack_secondary[#explorer.backtrack_secondary+1] = last_pos
                return last_pos
            end
        end
    end
    -- no perimeter, no frontier all explored or unreachable
    explorer.backtracking = false
    return nil
end
local select_node_direction = function (failed)
    -- get all perimeter (unvisited) of current position
    local perimeter = get_perimeter(explorer.cur_pos)
    if #perimeter > 0 then
        if explorer.last_dir ~= nil then
            local last_dx = explorer.last_dir[1]
            local last_dy = explorer.last_dir[2]
            local check_pos = explorer.cur_pos
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

            explorer.last_dir = {closest_dir_dx, closest_dir_dy}
            explorer.backtracking = false
            return closest_dir_node
        end

        -- if no last direction, just pick first one
        local dx = perimeter[1]:x() - explorer.cur_pos:x()
        local dy = perimeter[1]:y() - explorer.cur_pos:y()
        explorer.last_dir = {dx, dy}
        explorer.backtracking = false
        return perimeter[1]
    end

    -- if no unvisited perimeter, try to find an unexplored node in frontier within distance
    local index = explorer.frontier_index
    while index >= 0 do
        local most_recent_str = explorer.frontier_order[index]
        if most_recent_str ~= nil then
            -- skip if node is visited
            if explorer.visited[most_recent_str] ~= nil then
                remove_frontier(most_recent_str)
            else
                local frontier_node = explorer.frontier_node[most_recent_str]
                if utils.distance(frontier_node, explorer.cur_pos) <= explorer.frontier_max_dist then
                    remove_frontier(most_recent_str)
                    explorer.backtracking = false
                    local dx = frontier_node:x() - explorer.cur_pos:x()
                    local dy = frontier_node:y() - explorer.cur_pos:y()
                    explorer.last_dir = {dx, dy}
                    return frontier_node
                end
            end
        end
        index = index - 1
    end
    -- only backtrack if there are still frontier nodes (to get closer to frontier node)
    if explorer.frontier_count > 0 then
        while #explorer.backtrack > 0 do
            -- simulating pop()
            local last_index = #explorer.backtrack
            local last_pos = explorer.backtrack[last_index]
            explorer.backtrack[last_index] = nil
            if utils.distance(last_pos, explorer.cur_pos) ~= 0 then
                explorer.backtracking = true
                local dx = last_pos:x() - explorer.cur_pos:x()
                local dy = last_pos:y() - explorer.cur_pos:y()
                explorer.last_dir = {dx, dy}
                return last_pos
            end
        end
    end
    -- no perimeter, no frontier all explored or unreachable
    explorer.backtracking = false
    return nil
end
explorer.get_perimeter = get_perimeter
explorer.reset = function ()
    explorer.visited = {}
    explorer.visited_count = 0
    explorer.frontier = {}
    explorer.frontier_order = {}
    explorer.frontier_node = {}
    explorer.frontier_index = 0
    explorer.frontier_count = 0
    explorer.retry = {}
    explorer.retry_count = 0
    explorer.cur_pos = nil
    explorer.prev_pos = nil
    explorer.backtrack = {}
    explorer.backtrack_secondary = {}
    explorer.backtrack_node = nil
    explorer.backtracking = false
    explorer.backtrack_failed_time = -1
    explorer.last_dir = nil
    explorer.wrong_dir_count = 0
end
explorer.set_priority = function (priority)
    local allowed = {
        ['direction'] = true,
        ['distance'] = true,
    }
    if allowed[priority] then
        explorer.priority = priority
    end
end
explorer.set_current_pos = function (local_player)
    explorer.prev_pos = explorer.cur_pos
    explorer.cur_pos = utils.normalize_node(local_player:get_position())
    if not explorer.backtracking then
        if #explorer.backtrack > 0 then
            local last_index = #explorer.backtrack
            local last_pos = explorer.backtrack[last_index]

            local dist = utils.distance(last_pos, explorer.cur_pos)
            if dist >= explorer.backtrack_min_dist then
                explorer.backtrack[last_index+1] = explorer.cur_pos
            end
        else
            restore_backtrack()
            explorer.backtrack[1] = explorer.cur_pos
        end
    end
end
explorer.update = function (local_player)
    explorer.set_current_pos(local_player)
    local cur_pos = explorer.cur_pos
    local prev_pos = explorer.prev_pos
    if prev_pos ~= nil and utils.distance(cur_pos,prev_pos) == 0 then return end

    local x = cur_pos:x()
    local y = cur_pos:y()

    local f_radius = explorer.frontier_radius
    local v_radius = explorer.radius
    local step = settings.step

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
            local norm_x = utils.normalize_value(i)
            local norm_y = utils.normalize_value(j)
            local node = vec3:new(norm_x, norm_y, cur_pos:z())
            local node_str = utils.vec_to_string(node)

            if explorer.visited[node_str] == nil or
                explorer.retry[node_str] ~= nil
            then
                if i >= v_min_x and i <= v_max_x and j >= v_min_y and j <= v_max_y then
                    add_visited(node_str)
                    remove_retry(node_str)
                    remove_frontier(node_str)
                elseif explorer.frontier[node_str] == nil then
                    if explorer.retry[node_str] ~= nil then
                        remove_visited(node_str)
                        remove_retry(node_str)
                    end
                    local valid = utility.set_height_of_valid_position(node)
                    local walkable = utility.is_point_walkeable(valid)
                    if walkable then
                        add_frontier(node_str, valid)
                    end
                end
            end
        end
    end
end
explorer.select_node = function (local_player, failed)
    if explorer.cur_pos == nil then
        explorer.set_current_pos(local_player)
    end
    if failed ~= nil then
        -- if failed at backtrack, try again
        if explorer.backtracking then
            if explorer.backtrack_node ~= utils.vec_to_string(failed) then
                explorer.backtrack_failed_time = get_time_since_inject()
                explorer.backtrack_node = utils.vec_to_string(failed)
                return failed
            -- retry the failed node for up to 5 seconds
            elseif explorer.backtrack_failed_time + explorer.backtrack_timeout >= get_time_since_inject() then
                return failed
            end
        end
        failed = utils.normalize_node(failed)
        local failed_str = utils.vec_to_string(failed)
        add_visited(failed_str)
        add_retry(failed_str)
    end

    if explorer.priority == 'distance' then
        return select_node_distance()
    end

    -- default priority explorer.priority == 'direction'
    return select_node_direction(failed)
end

return explorer