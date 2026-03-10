Utils = {}

function Utils.GetTarget()
    if Config.Target ~= 'autodetect' then
        return Config.Target
    end

    if GetResourceState('ox_target') == 'started' then
        return 'ox_target'
    elseif GetResourceState('qb-target') == 'started' then
        return 'qb-target'
    end

    print('^1[Aviso] Nenhum recurso de Target compatível foi detectado.^0')
    return nil
end

function Utils.EnsureModel(model)
    local hash = type(model) == 'string' and GetHashKey(model) or model
    if not IsModelInCdimage(hash) then return false end
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
    end
    return true
end

function Utils.EnsureAnimDict(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(10)
    end
end

function Utils.EnsureRopeTexturesLoaded()
    if not RopeAreTexturesLoaded() then
        RopeLoadTextures()
        while not RopeAreTexturesLoaded() do
            Wait(0)
        end
    end
end

function Utils.CleanupRopeTexturesIfUnused()
    local ropes = GetAllRopes()
    if type(ropes) == "table" and #ropes == 0 then
        RopeUnloadTextures()
    end
end

function Utils.NetToEnt(netId)
    if not netId then return 0 end
    local ent = NetworkGetEntityFromNetworkId(netId)
    if ent and ent ~= 0 and DoesEntityExist(ent) then
        return ent
    end
    return 0
end

function Utils.TryRequestControl(entity, timeoutMs)
    timeoutMs = timeoutMs or 1000
    if not entity or entity == 0 or not DoesEntityExist(entity) then return false end

    if NetworkHasControlOfEntity(entity) then return true end
    NetworkRequestControlOfEntity(entity)

    local started = GetGameTimer()
    while not NetworkHasControlOfEntity(entity) and (GetGameTimer() - started) < timeoutMs do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end

    return NetworkHasControlOfEntity(entity)
end