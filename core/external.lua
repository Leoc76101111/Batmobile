local plugin_label = 'batmobile'
-- kept plugin label instead of waiting for update_tracker to set it
local navigator = require 'core.navigator'
local tracker = require 'core.tracker'
local utils = require 'core.utils'

local external = {
    name          = plugin_label
}
external.is_done = function ()
    return navigator.is_done()
end
external.is_paused = function ()
    return navigator.paused
end
external.pause = function (caller)
    tracker.external_caller = caller
    -- console.print('pause called by ' .. caller)
    navigator.pause()
end
external.resume = function (caller)
    tracker.external_caller = caller
    -- console.print('resume called by ' .. caller)
    navigator.unpause()
end
external.reset = function (caller)
    tracker.external_caller = caller
    -- console.print('reset called by ' .. caller)
    navigator.reset()
end
external.move = function (caller)
    tracker.external_caller = caller
    -- console.print('move called by ' .. caller)
    local start_move = os.clock()
    navigator.move()
    tracker.timer_update = os.clock() - start_move
end
external.update = function (caller)
    tracker.external_caller = caller
    -- console.print('update called by ' .. caller)
    navigator.update()
end
external.set_target = function(caller, target)
    tracker.external_caller = caller
    -- console.print('set_target called by ' .. caller)
    navigator.set_target(target)
end
external.set_goal = function(caller, target)
    tracker.external_caller = caller
    -- console.print('set_goal called by ' .. caller)
    navigator.set_goal(target)
end
external.clear_target = function (caller)
    tracker.external_caller = caller
    -- console.print('clear_target called by ' .. caller)
    navigator.clear_target()
end
external.clear_goal = function (caller)
    tracker.external_caller = caller
    -- console.print('clear_goal called by ' .. caller)
    navigator.clear_goal()
end
external.distance = function (caller, a, b)
    tracker.external_caller = caller
    return utils.distance(a, b)
end

return external