local explorer_dfs = require 'core.explorer_dfs'
local navigator = require 'core.navigator'
local settings = require 'core.settings'
local utils = require 'core.utils'
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
local get_max_length = function(messages)
    local max = 0
    for _, msg in ipairs(messages) do
        if #msg > max then max = #msg end
    end
    return max
end
local drawing = {}

drawing.draw_nodes = function ()
    local local_player = get_local_player()
    if local_player == nil then return end
    if settings.draw ~= 1 then return end
    local start_draw = os.clock()
    local max_dist = 50

    local visited = explorer_dfs.visited
    local frontier = explorer_dfs.frontier
    local backtrack = explorer_dfs.backtrack
    local retry = explorer_dfs.retry

    local cur_pos = navigator.last_pos
    local valid_cur_pos = utility.set_height_of_valid_position(local_player:get_position())

    if cur_pos ~= nil then
        local perimeter = explorer_dfs.get_perimeter(local_player)
        local path = navigator.path

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
    local active_spell = local_player:get_active_spell_id()
    local in_combat =  active_spell ~= nil and active_spell ~= -1 and active_spell ~= 186139
    local is_cced = utils.is_cced(local_player)
    local speed = local_player:get_current_speed()
    local speed_str = string.format("%.3f",local_player:get_current_speed())
    if speed < 10 then
        speed_str = speed_str .. ' '
    else
    end
    local messages_left = {
        ' speed     ' .. speed_str,
        ' visited   ' .. tostring(visited_count),
        ' frontier  ' .. tostring(get_set_count(frontier)),
        ' backtrack ' .. tostring(#backtrack),
        ' retry     ' .. tostring(get_set_count(retry)),
    }
    local messages_right = {
        ' in_combat ' .. tostring(in_combat),
        ' is_cc\'ed  ' .. tostring(is_cced),
        ' u_time    ' .. string.format("%.3f",tracker.timer_update),
        ' m_time    ' .. string.format("%.3f",tracker.timer_move),
    }
    local max_left = get_max_length(messages_left)
    local max_right = get_max_length(messages_right)
    local x_pos = get_screen_width() - 20 - (max_left * 11) - (max_right * 11)
    local y_pos = get_screen_height() - 20 - (#messages_left * 20)
    for _, msg in ipairs(messages_left) do
        graphics.text_2d(msg, vec2:new(x_pos, y_pos), 20, color_white(255))
        y_pos = y_pos + 20
    end
    x_pos = get_screen_width() - 20 - (max_right * 11)
    y_pos = get_screen_height() - 40 - (#messages_right * 20)
    for _, msg in ipairs(messages_right) do
        graphics.text_2d(msg, vec2:new(x_pos, y_pos), 20, color_white(255))
        y_pos = y_pos + 20
    end
    tracker.timer_draw = os.clock() - start_draw
    local msg = ' d_time    ' .. string.format("%.3f",tracker.timer_draw)
    graphics.text_2d(msg, vec2:new(x_pos, y_pos), 20, color_white(255))
end

return drawing
