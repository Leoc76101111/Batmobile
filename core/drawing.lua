local node_selector = require 'core.node_selector_dfs'
local explorer = require 'core.explorer'
local settings = require 'core.settings'
local tracker = require 'core.tracker'

local distance = function (a, b)
    local dx = math.abs(a:x() - b:x())
    local dy = math.abs(a:y() - b:y())
    return math.max(dx, dy) + (math.sqrt(2) - 1) * math.min(dx, dy)
end
local vec_to_string = function (node)
    return tostring(node:x()) .. ',' .. tostring(node:y())
end
local get_set_count = function (set)
    local counter = 0
    for _, item in pairs(set) do
        counter = counter + 1
    end
    return counter
end
local drawing = {}

drawing.draw_nodes = function ()
    local local_player = get_local_player()
    if local_player == nil then return end
    if settings.draw ~= 1 then return end
    local start_draw = os.clock()
    local max_dist = 50

    local visited = node_selector.visited
    local frontier = node_selector.frontier
    local backtrack = node_selector.backtrack

    local cur_pos = explorer.last_pos
    local valid_cur_pos = utility.set_height_of_valid_position(local_player:get_position())

    if cur_pos ~= nil then
        local perimeter = node_selector.get_perimeter(local_player)
        local path = explorer.path

        -- for _, node in pairs(frontier) do
        --     local valid = vec3:new(node:x(), node:y(), valid_cur_pos:z())
        --     -- valid = utility.set_height_of_valid_position(node)
        --     if distance(cur_pos, node) <= max_dist then
        --         graphics.circle_3d(valid, 0.05, color_green(255))
        --     end
        -- end
        -- for _, node in pairs(visited) do
        --     local valid = vec3:new(node:x(), node:y(), valid_cur_pos:z())
        --     -- valid = utility.set_height_of_valid_position(node)
        --     if distance(cur_pos, node) <= max_dist then
        --         graphics.circle_3d(valid, 0.05, color_white(255))
        --     end
        -- end
        -- for _, node in pairs(perimeter) do
        --     local valid = vec3:new(node:x(), node:y(), valid_cur_pos:z())
        --     -- valid = utility.set_height_of_valid_position(node)
        --     if distance(cur_pos, node) <= max_dist then
        --         graphics.circle_3d(valid, 0.05, color_blue(255))
        --     end
        -- end
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

    if tracker.debug_pos ~= nil then
        local valid = utility.set_height_of_valid_position(tracker.debug_pos)
        graphics.circle_3d(valid, 5, color_white(255))
        graphics.line(valid_cur_pos, valid, color_white(255), 1)
    end
    if tracker.debug_node ~= nil then
        local valid = vec3:new(tracker.debug_node:x(),tracker.debug_node:y(), valid_cur_pos:z())
        graphics.circle_3d(valid, 5, color_white(255))
        graphics.line(valid_cur_pos, valid, color_white(255), 1)
    end
    if tracker.debug_actor ~= nil then
        local valid = tracker.debug_actor:get_position()
        graphics.circle_3d(valid, 5, color_white(255))
        graphics.line(valid_cur_pos, valid, color_white(255), 1)
    end

    local visited_count = get_set_count(visited)
    local visited_length = #tostring(visited_count)
    if visited_length < 5 then visited_length = 5 end
    tracker.timer_draw = os.clock() - start_draw
    local messages = {
        'visited   ' .. tostring(visited_count),
        'frontier  ' .. tostring(get_set_count(frontier)),
        'backtrack ' .. tostring(#backtrack),
        'u_time    ' .. string.format("%.3f",tracker.timer_update),
        'm_time    ' .. string.format("%.3f",tracker.timer_move),
        'd_time    ' .. string.format("%.3f",tracker.timer_draw),
    }
    -- local x_offset = 130 + (#tostring(visited_count) * 11)
    local x_offset = 130 + (visited_length * 11)
    local x_pos = get_screen_width() - x_offset
    local y_pos = get_screen_height() - 140
    for _, msg in ipairs(messages) do
        graphics.text_2d(msg, vec2:new(x_pos, y_pos), 20, color_white(255))
        y_pos = y_pos + 20
    end
end

return drawing
