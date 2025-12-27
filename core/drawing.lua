local node_selector = require 'core.node_selector_dfs'
local path_finder = require 'core.pathfinder_astar'
local explorer = require 'core.explorer'

local distance = function (a, b)
    local dx = math.abs(a:x() - b:x())
    local dy = math.abs(a:y() - b:y())
    return math.max(dx, dy) + (math.sqrt(2) - 1) * math.min(dx, dy)
end

local drawing = {}

drawing.draw_nodes = function ()
    local local_player = get_local_player()
    if not local_player then return end

    local max_dist = 15

    local cur_pos = explorer.last_pos
    if cur_pos == nil then return end
    local valid_cur_pos = utility.set_height_of_valid_position(cur_pos)
    local perimeter = node_selector.get_perimeter(local_player)
    local visited = node_selector.visited
    local frontier = node_selector.frontier
    local backtrack = node_selector.backtrack
    local path = explorer.path

    for _, node in pairs(frontier) do
        local valid = vec3:new(node:x(), node:y(), valid_cur_pos:z())
        -- valid = utility.set_height_of_valid_position(node)
        if distance(cur_pos, node) <= max_dist then
            graphics.circle_3d(valid, 0.05, color_green(255))
        end
    end
    for _, node in pairs(visited) do
        local valid = vec3:new(node:x(), node:y(), valid_cur_pos:z())
        -- valid = utility.set_height_of_valid_position(node)
        if distance(cur_pos, node) <= max_dist then
            graphics.circle_3d(valid, 0.05, color_white(255))
        end
    end
    for _, node in pairs(perimeter) do
        local valid = vec3:new(node:x(), node:y(), valid_cur_pos:z())
        -- valid = utility.set_height_of_valid_position(node)
        if distance(cur_pos, node) <= max_dist then
            graphics.circle_3d(valid, 0.05, color_blue(255))
        end
    end
    local prev_node = nil
    local counter = 0

    for index = #backtrack, 1, -1 do
        if counter < 50 then
            local node = backtrack[index]
            local valid = vec3:new(node:x(), node:y(), valid_cur_pos:z())
            -- valid = utility.set_height_of_valid_position(node)
            graphics.circle_3d(valid, 0.05, color_yellow(255))
            if prev_node ~= nil then
                graphics.line(valid, prev_node, color_yellow(255), 1)
            else
                graphics.line(valid_cur_pos, valid, color_yellow(255), 1)
            end
            prev_node = valid
            counter = counter + 1
        end
    end
    prev_node = nil
    for _, node in pairs(path) do
        local valid = vec3:new(node:x(), node:y(), valid_cur_pos:z())
        -- valid = utility.set_height_of_valid_position(node)
        if distance(cur_pos, node) <= max_dist then
            graphics.circle_3d(valid, 0.05, color_red(255))
            if prev_node ~= nil then
                graphics.line(valid, prev_node, color_red(255), 1)
            else
                graphics.line(valid_cur_pos, valid, color_red(255), 1)
            end
            prev_node = valid
        end
    end
end

return drawing
