local plugin_label = 'batmobile_explorer'
-- kept plugin label instead of waiting for update_tracker to set it

local tracker = {
    name        = plugin_label,
    external_caller = nil,
    timer_update = 0,
    timer_move = 0,
    timer_draw = 0,
    debug_pos = nil,
    debug_node = nil,
    debug_actor = nil,
    paused = false,
    done = false
}

return tracker