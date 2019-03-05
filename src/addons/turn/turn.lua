
_addon.author   = 'Eleven Pies';
_addon.name     = 'Turn';
_addon.version  = '2.0.0';

require 'common'

local TURN_TOWARDS = 1;
local TURN_AWAY = 2;
local TURN_WITH = 3;

local function write_float_hack(addr, value)
    local packed = struct.pack('f', value);
    local unpacked = { struct.unpack('B', packed, 1), struct.unpack('B', packed, 2), struct.unpack('B', packed, 3), struct.unpack('B', packed, 4) };

    -- ashita.memory.write_float appears busted in ashita v3, converting to byte array
    ashita.memory.write_array(addr, unpacked);
end

local function findEntity(entityid)
    -- targid < 0x400
    --   TYPE_MOB || TYPE_NPC || TYPE_SHIP
    -- targid < 0x700
    --   TYPE_PC
    -- targid < 0x800
    --   TYPE_PET

    -- Search players
    for x = 0x400, 0x6FF do
        local ent = GetEntity(x);
        if (ent ~= nil and ent.ServerId == entityid) then
            return x;
        end
    end

    return nil;
end

local function getEntityIndex(zoneid, entityid)
    local zonemin = bit.lshift(zoneid, 12) + 0x1000000;

    local entityindex;

    -- Check if entity looks like a mobid
    if (bit.band(zonemin, entityid) == zonemin) then
        entityindex = bit.band(entityid, 0xfff);
    else
        -- Otherwise try finding player in NPC map
        entityindex = findEntity(entityid);
    end

    return entityindex;
end

local function turnAnyTarget(targetindex, direction)
    local entity = AshitaCore:GetDataManager():GetEntity();
    local party = AshitaCore:GetDataManager():GetParty();
    if (targetindex ~= nil) then
        local targetEntity = GetEntity(targetindex);

        if (targetEntity ~= nil) then
            local selfIndex = party:GetMemberTargetIndex(0);
            local selfWarp = entity:GetWarpPointer(selfIndex);
            local px = entity:GetLocalX(selfIndex);
            local py = entity:GetLocalY(selfIndex);
            local pz = entity:GetLocalZ(selfIndex);
            local pyaw = entity:GetLocalYaw(selfIndex);
            local tx = targetEntity.Movement.LocalPosition.X;
            local ty = targetEntity.Movement.LocalPosition.Y;
            local tz = targetEntity.Movement.LocalPosition.Z;
            local tyaw = targetEntity.Movement.LocalPosition.Yaw;

            local yaw;

            if (direction == TURN_TOWARDS) then
                yaw = 0 - math.atan2(tz - pz, tx - px);
            elseif (direction == TURN_AWAY) then
                yaw = 0 - math.atan2(pz - tz, px - tx);
            elseif (direction == TURN_WITH) then
                yaw = tyaw;
            end

            if (selfWarp ~= nil) then
                write_float_hack(selfWarp + 0x48, yaw);
            end
        end
    end
end

local function turnAny(serverid, direction)
    local targetindex;

    if (serverid ~= nil) then
        local zoneid = AshitaCore:GetDataManager():GetParty():GetMemberZone(0);
        targetindex = getEntityIndex(zoneid, serverid);
    else
        local target = AshitaCore:GetDataManager():GetTarget();
        targetindex = target:GetTargetIndex();
    end

    turnAnyTarget(targetindex, direction);
end

local function turnTowards(serverid)
    turnAny(serverid, TURN_TOWARDS);
end

local function turnAway(serverid)
    turnAny(serverid, TURN_AWAY);
end

local function turnWith(serverid)
    turnAny(serverid, TURN_WITH);
end

local function turnDirectWith(yaw)
    local entity = AshitaCore:GetDataManager():GetEntity();
    local party = AshitaCore:GetDataManager():GetParty();

    local selfIndex = party:GetMemberTargetIndex(0);
    local selfWarp = entity:GetWarpPointer(selfIndex);

    if (selfWarp ~= nil) then
        write_float_hack(selfWarp + 0x48, yaw);
    end
end

ashita.register_event('command', function(cmd, nType)
    local args = cmd:args();

    if (#args > 0) then
        if (args[1] == '/turn')  then
            if (#args > 1)  then
                local serverid;
                if (#args > 2) then
                    serverid = tonumber(args[3]);
                else
                    serverid = nil;
                end
    
                if (args[2] == 'to')  then
                    turnTowards(serverid);
                    return true;
                elseif (args[2] == 'away')  then
                    turnAway(serverid);
                    return true;
                elseif (args[2] == 'with')  then
                    turnWith(serverid);
                    return true;
                end
            end
        elseif (args[1] == '/turndirect')  then
            if (#args > 1)  then
                if (args[2] == 'with')  then
                    local yaw;
                    if (#args > 2) then
                        yaw = tonumber(args[3]);
                        turnDirectWith(yaw);
                        return true;
                    end
                end
            end
        end
    end

    return false;
end);
