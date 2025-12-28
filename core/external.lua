local plugin_label = 'batmobile_explorer'
-- kept plugin label instead of waiting for update_tracker to set it
local explorer = require 'core.explorer'
local tracker = require 'core.tracker'

local external = {
    name          = plugin_label
}
external.pause = function (caller)
    tracker.external_caller = caller
    explorer.pause()
end
external.resume = function (caller)
    tracker.external_caller = caller
    explorer.unpause()
end
external.reset = function (caller)
    tracker.external_caller = caller
    explorer.reset()
end
external.move = function (caller)
    tracker.external_caller = caller
    local start_move = os.clock()
    explorer.move()
    tracker.timer_update = os.clock() - start_move
end
external.update = function (caller)
    tracker.external_caller = caller
    explorer.update()
end
external.set_target = function(caller, target)
    tracker.external_caller = caller
    explorer.set_target(target)
end
external.set_goal = function(caller, target)
    tracker.external_caller = caller
    explorer.set_goal(target)
end
external.clear_target = function (caller)
    tracker.external_caller = caller
    explorer.clear_target()
end
external.clear_goal = function (caller)
    tracker.external_caller = caller
    explorer.clear_goal()
end
external.distance = function (caller, a, b)
    tracker.external_caller = caller
    return explorer.distance(a, b)
end

return external