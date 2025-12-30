local utils    = {}
function utils.distance_to(target)
    local player_pos = get_player_position()
    local target_pos

    if target.get_position then
        target_pos = target:get_position()
    elseif target.x then
        target_pos = target
    end

    return player_pos:dist_to(target_pos)
end
function utils.is_same_position(pos1, pos2)
    return pos1:x() == pos2:x() and pos1:y() == pos2:y() and pos1:z() == pos2:z()
end
function utils.is_mounted()
    local local_player = get_local_player()
    return local_player:get_attribute(attributes.CURRENT_MOUNT) < 0
end
function utils.player_in_zone(zname)
    return get_current_world():get_current_zone_name() == zname
end
function utils.player_loading()
    return utils.player_in_zone('[sno none]')
end
function utils.player_in_town()
    if get_local_player():get_attribute(attributes.PLAYER_IN_TOWN_LEVEL_AREA) == 1 then
        return true
    else
        return false
    end
end
function utils.is_cced(local_player)
    local debuffs = {
        ['39809'] = 'GenericCrowdControlBuff',
        ['290961'] = 'GenericChillBuff',
        ['290962'] = 'GenericFrozenBuff',
    }
    local buffs = local_player:get_buffs()
    for _, buff in pairs(buffs) do
        if debuffs[buff.name_hash] then
            return true
        end
    end
    return false
end
return utils
