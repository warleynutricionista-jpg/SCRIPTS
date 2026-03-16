local Bridge = require 'server.bridge'
local Guard = require 'server.modules.action_guard'

local VehicleList = {}
local VehicleData = {}
local getItemInfo = Shared.Inventory == 'qb' and function(item) return item.info end or function(item) return item.metadata end

local function isValidPlate(plate)
    if type(plate) ~= 'string' then return false end
    if #plate == 0 or #plate > 10 then return false end
    return plate:match('^[%w%s]+$') ~= nil
end

local function normPlate(plate)
    return (plate or ''):gsub('%W', '')
end

local function ensureVehicleData(plate)
    plate = normPlate(plate)
    if plate == '' then return nil end
    if not VehicleData[plate] then
        VehicleData[plate] = {
            has_key = false,
            key_taken = false,
            key_location = nil,
            searched_glovebox = false,
            searched_trunk = false,
            assigned_key_holder = nil,
            ignition_damaged = false,
            electrical_failure_permanent = false,
            lockpick_in_progress = false,
            hotwire_in_progress = false,
            vehicle_net = nil
        }
    end
    return VehicleData[plate]
end

local function pickKeyLocation()
    local glove = Config.SearchKey.GloveboxChance or 0
    local trunk = Config.SearchKey.TrunkChance or 0
    local npc = (Config.NPCSearch.Enabled and Config.NPCSearch.KeyChance) or 0
    local none = Config.SearchKey.NoKeyChance or 0
    local total = glove + trunk + npc + none
    if total <= 0 then return 'none' end

    local roll = math.random() * total
    if roll <= glove then return 'glovebox' end
    if roll <= glove + trunk then return 'trunk' end
    if roll <= glove + trunk + npc then return 'npc' end
    return 'none'
end

local function syncEntityState(vehicle, data)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end
    Guard:SetEntityStates(vehicle, {
        has_key = data.has_key,
        key_taken = data.key_taken,
        key_location = data.key_location,
        searched_glovebox = data.searched_glovebox,
        searched_trunk = data.searched_trunk,
        assigned_key_holder = data.assigned_key_holder,
        ignition_damaged = data.ignition_damaged,
        electrical_failure_permanent = data.electrical_failure_permanent,
        lockpick_in_progress = data.lockpick_in_progress,
        hotwire_in_progress = data.hotwire_in_progress
    })
end

local function getVehicleFromNetId(netId)
    if type(netId) ~= 'number' then return 0 end
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return 0 end
    return vehicle
end

local function resolveVehicleAndState(netId)
    local vehicle = getVehicleFromNetId(netId)
    if vehicle == 0 then return 0 end
    local plate = normPlate(GetVehicleNumberPlateText(vehicle))
    if not isValidPlate(plate) then return 0 end
    local data = ensureVehicleData(plate)
    if not data.key_location then
        data.key_location = pickKeyLocation()
    end
    data.vehicle_net = netId
    syncEntityState(vehicle, data)
    return vehicle, plate, data
end

function GiveTempKeys(id, plate)
    local citizenid = Bridge:GetPlayerCitizenId(id)
    if not citizenid then return end
    if not VehicleList[citizenid] then VehicleList[citizenid] = {} end
    plate = normPlate(plate)
    if plate == '' then return end

    VehicleList[citizenid][plate] = true
    local ndata = {
        title = 'Recebido',
        description = 'Você recebeu a chave temporária para o veículo',
        type = 'success'
    }
    TriggerClientEvent('ox_lib:notify', id, ndata)
    TriggerClientEvent('mm_carkeys:client:addtempkeys', id, plate)
end

local function grantVehicleKey(source, vehicle, plate, data)
    if data.key_taken then return false end
    data.key_taken = true
    data.has_key = true
    syncEntityState(vehicle, data)
    Guard:Debug('key granted src=%s plate=%s', source, plate)
    GiveTempKeys(source, plate)
    return true
end

function RemoveTempKeys(id, plate)
    local citizenid = Bridge:GetPlayerCitizenId(id)
    if not citizenid then return end
    plate = normPlate(plate)
    if VehicleList[citizenid] and VehicleList[citizenid][plate] then
        VehicleList[citizenid][plate] = nil
    end
    TriggerClientEvent('mm_carkeys:client:removetempkeys', id, plate)
end

lib.callback.register('mm_carkeys:server:getvehiclekeys', function(source)
    local citizenid = Bridge:GetPlayerCitizenId(source)
    return VehicleList[citizenid] or {}
end)

lib.callback.register('mm_carkeys:server:getVehicleState', function(_, plate)
    if not isValidPlate(plate) then return false end
    return ensureVehicleData(plate)
end)

lib.callback.register('mm_carkeys:server:hasItem', function(source, item, amount)
    if type(item) ~= 'string' or item == '' then return false end
    return Bridge:HasItem(source, item, amount)
end)

lib.callback.register('mm_carkeys:server:consumeItem', function(source, item, amount)
    if type(item) ~= 'string' or item == '' then return false end
    return Bridge:TryRemoveItem(source, item, amount)
end)

lib.callback.register('mm_carkeys:server:beginCompartmentSearch', function(source, vehNetId, compartment)
    if not Config.SearchKey.Enabled then return false, 'disabled' end
    if compartment ~= 'glovebox' and compartment ~= 'trunk' then return false, 'invalid' end

    local vehicle, plate, data = resolveVehicleAndState(vehNetId)
    if vehicle == 0 then return false, 'invalid_vehicle' end
    if not Guard:ValidateDistance(source, vehicle, Shared.security.maxInteractDistance) then return false, 'too_far' end
    if not Guard:CheckCooldown(source, 'search', plate) then return false, 'cooldown' end

    local searched = compartment == 'glovebox' and data.searched_glovebox or data.searched_trunk
    if searched then return false, 'already_searched' end
    if data.key_taken then return false, 'taken' end
    if not Guard:CanSearchCompartment(vehicle, compartment) then return false, 'closed' end

    local ok, lockKey = Guard:TryVehicleLock(plate, 'search', source)
    if not ok then return false, 'busy' end

    local token = Guard:OpenAction(source, 'search', {
        plate = plate,
        vehicle = vehicle,
        compartment = compartment,
        duration = Config.SearchKey.Duration,
        lockKey = lockKey
    })

    return true, { token = token, duration = Config.SearchKey.Duration }
end)

lib.callback.register('mm_carkeys:server:completeCompartmentSearch', function(source, token, success)
    local action = Guard:GetAction(token, source, 'search')
    if not action then return false, 'invalid_action' end

    local data = action.data
    local vehicle = data.vehicle
    local plate = data.plate
    local vehicleData = ensureVehicleData(plate)

    if not success then
        Guard:CloseAction(token)
        return false, 'cancelled'
    end

    if GetGameTimer() - action.startedAt < (data.duration - 300) then
        Guard:Debug('exploit: fast search src=%s plate=%s', source, plate)
        Guard:CloseAction(token)
        return false, 'blocked'
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        Guard:CloseAction(token)
        return false, 'invalid_vehicle'
    end

    if not Guard:ValidateDistance(source, vehicle, Shared.security.maxInteractDistance) then
        Guard:CloseAction(token)
        return false, 'too_far'
    end

    if data.compartment == 'glovebox' then vehicleData.searched_glovebox = true else vehicleData.searched_trunk = true end

    local found = vehicleData.key_location == data.compartment and grantVehicleKey(source, vehicle, plate, vehicleData)
    syncEntityState(vehicle, vehicleData)
    Guard:CloseAction(token)

    return found, found and 'found' or 'empty'
end)

lib.callback.register('mm_carkeys:server:beginNpcSearch', function(source, vehNetId, pedNetId)
    if not Config.NPCSearch.Enabled then return false, 'disabled' end

    local vehicle, plate, data = resolveVehicleAndState(vehNetId)
    if vehicle == 0 then return false, 'invalid_vehicle' end
    local npc = NetworkGetEntityFromNetworkId(pedNetId)
    if npc == 0 or not DoesEntityExist(npc) or IsPedAPlayer(npc) then return false, 'invalid_npc' end

    if not Guard:ValidateDistance(source, npc, Config.NPCSearch.MaxDistance) then return false, 'too_far' end
    if not Guard:CheckCooldown(source, 'npc', plate) then return false, 'cooldown' end
    if data.key_taken then return false, 'taken' end

    if not data.assigned_key_holder then
        data.assigned_key_holder = pedNetId
    end

    if data.assigned_key_holder ~= pedNetId then
        return false, 'invalid_holder'
    end

    if data.key_location ~= 'npc' then
        return false, 'no_key'
    end

    local ok, lockKey = Guard:TryVehicleLock(plate, 'npc', source)
    if not ok then return false, 'busy' end

    local token = Guard:OpenAction(source, 'npc_search', {
        plate = plate,
        vehicle = vehicle,
        npc = npc,
        npcNet = pedNetId,
        duration = Config.NPCSearch.Duration,
        lockKey = lockKey
    })

    data.has_key = false
    syncEntityState(vehicle, data)

    return true, { token = token, duration = Config.NPCSearch.Duration }
end)

lib.callback.register('mm_carkeys:server:completeNpcSearch', function(source, token, success)
    local action = Guard:GetAction(token, source, 'npc_search')
    if not action then return false, 'invalid_action' end

    local data = action.data
    local vehicle, npc = data.vehicle, data.npc
    local state = ensureVehicleData(data.plate)

    if not success then
        Guard:CloseAction(token)
        return false, 'cancelled'
    end

    if GetGameTimer() - action.startedAt < (data.duration - 300) then
        Guard:CloseAction(token)
        return false, 'blocked'
    end

    if vehicle == 0 or not DoesEntityExist(vehicle) or npc == 0 or not DoesEntityExist(npc) then
        state.key_location = 'none'
        state.key_taken = true
        Guard:CloseAction(token)
        return false, 'escaped'
    end

    if IsEntityDead(npc) or IsPedInAnyVehicle(npc, false) or not Guard:ValidateDistance(source, npc, Config.NPCSearch.MaxDistance) then
        state.key_location = 'none'
        state.key_taken = true
        syncEntityState(vehicle, state)
        Guard:CloseAction(token)
        return false, 'escaped'
    end

    local found = grantVehicleKey(source, vehicle, data.plate, state)
    Guard:CloseAction(token)
    return found, found and 'found' or 'no_key'
end)

lib.callback.register('mm_carkeys:server:beginHotwire', function(source, vehNetId)
    if not Config.Hotwire.Enabled then return false, 'disabled' end

    local vehicle, plate, data = resolveVehicleAndState(vehNetId)
    if vehicle == 0 then return false, 'invalid_vehicle' end
    if not Guard:ValidateDistance(source, vehicle, Shared.security.maxInteractDistance) then return false, 'too_far' end
    if not Guard:CheckCooldown(source, 'hotwire', plate) then return false, 'cooldown' end

    if data.electrical_failure_permanent and Config.Hotwire.BlockIfPermanentDamage then
        return false, 'permanent_damage'
    end

    local ok, lockKey = Guard:TryVehicleLock(plate, 'hotwire', source)
    if not ok then return false, 'busy' end

    if Config.Hotwire.ConsumeItem then
        if not Bridge:HasItem(source, Config.Hotwire.RequiredItem, 1) then
            Guard:ReleaseVehicleLock(lockKey)
            return false, 'missing_item'
        end
        if not Bridge:TryRemoveItem(source, Config.Hotwire.RequiredItem, 1) then
            Guard:ReleaseVehicleLock(lockKey)
            return false, 'missing_item'
        end
        Guard:Debug('item consumed src=%s item=%s', source, Config.Hotwire.RequiredItem)
    end

    data.hotwire_in_progress = true
    syncEntityState(vehicle, data)

    local token = Guard:OpenAction(source, 'hotwire', {
        plate = plate,
        vehicle = vehicle,
        duration = Config.Hotwire.Duration,
        lockKey = lockKey
    })

    return true, { token = token, duration = Config.Hotwire.Duration }
end)

lib.callback.register('mm_carkeys:server:completeHotwire', function(source, token, minigameSuccess)
    local action = Guard:GetAction(token, source, 'hotwire')
    if not action then return false, 'invalid_action' end

    local data = action.data
    local vehicle, plate = data.vehicle, data.plate
    local state = ensureVehicleData(plate)
    state.hotwire_in_progress = false

    if vehicle == 0 or not DoesEntityExist(vehicle) then
        Guard:CloseAction(token)
        return false, 'invalid_vehicle'
    end

    if not minigameSuccess then
        state.ignition_damaged = true
        if math.random() <= Config.Hotwire.PermanentElectricalDamageChance then
            state.electrical_failure_permanent = true
        end
        syncEntityState(vehicle, state)
        Guard:CloseAction(token)
        return false, state.electrical_failure_permanent and 'permanent_damage' or 'failed'
    end

    if GetGameTimer() - action.startedAt < (data.duration - 300) then
        Guard:CloseAction(token)
        return false, 'blocked'
    end

    if not Guard:ValidateDistance(source, vehicle, Shared.security.maxInteractDistance) then
        Guard:CloseAction(token)
        return false, 'too_far'
    end

    if math.random() <= Config.Hotwire.SuccessChance then
        local granted = grantVehicleKey(source, vehicle, plate, state)
        state.hotwire_in_progress = false
        syncEntityState(vehicle, state)
        Guard:CloseAction(token)
        return granted, granted and 'success' or 'failed'
    end

    state.ignition_damaged = true
    if math.random() <= Config.Hotwire.PermanentElectricalDamageChance then
        state.electrical_failure_permanent = true
    end
    syncEntityState(vehicle, state)
    Guard:CloseAction(token)
    return false, state.electrical_failure_permanent and 'permanent_damage' or 'failed'
end)

lib.callback.register('mm_carkeys:server:beginLockpick', function(source, vehNetId, mode)
    if not Config.Lockpick.Enabled then return false, 'disabled' end

    local vehicle, plate, data = resolveVehicleAndState(vehNetId)
    if vehicle == 0 then return false, 'invalid_vehicle' end
    if not Guard:ValidateDistance(source, vehicle, Shared.security.maxInteractDistance) then return false, 'too_far' end
    if not Guard:CheckCooldown(source, 'lockpick', plate) then return false, 'cooldown' end

    if data.electrical_failure_permanent and mode == 'engine' then
        return false, 'permanent_damage'
    end

    local ok, lockKey = Guard:TryVehicleLock(plate, 'lockpick', source)
    if not ok then return false, 'busy' end

    data.lockpick_in_progress = true
    syncEntityState(vehicle, data)

    local token = Guard:OpenAction(source, 'lockpick', {
        plate = plate,
        vehicle = vehicle,
        mode = mode,
        currentStage = 1,
        requiredStages = Config.Lockpick.Stages,
        lockKey = lockKey
    })

    return true, { token = token, stage = 1, requiredStages = Config.Lockpick.Stages }
end)

lib.callback.register('mm_carkeys:server:lockpickStage', function(source, token, stageSuccess)
    local action = Guard:GetAction(token, source, 'lockpick')
    if not action then return false, 'invalid_action' end

    local data = action.data
    local vehicle = data.vehicle
    if vehicle == 0 or not DoesEntityExist(vehicle) or not Guard:ValidateDistance(source, vehicle, Shared.security.maxInteractDistance) then
        Guard:CloseAction(token)
        return false, 'too_far'
    end

    if stageSuccess then
        data.currentStage = data.currentStage + 1
        if data.currentStage > data.requiredStages then
            local state = ensureVehicleData(data.plate)
            state.lockpick_in_progress = false
            state.has_key = true
            syncEntityState(vehicle, state)
            if data.mode == 'door' then
                SetVehicleDoorsLocked(vehicle, 1)
            end
            GiveTempKeys(source, data.plate)
            Guard:CloseAction(token)
            return true, 'completed'
        end
        return true, { stage = data.currentStage, requiredStages = data.requiredStages }
    end

    if Config.Lockpick.FailMode == 'regress' then
        data.currentStage = math.max(1, data.currentStage - (Config.Lockpick.RegressAmount or 1))
        return false, { stage = data.currentStage, requiredStages = data.requiredStages, regress = true }
    end

    local state = ensureVehicleData(data.plate)
    state.lockpick_in_progress = false
    syncEntityState(vehicle, state)
    Guard:CloseAction(token)
    return false, 'failed'
end)

RegisterNetEvent('mm_carkeys:server:cancelAction', function(token)
    local src = source
    local action = Guard:GetAction(token, src)
    if not action then return end
    local data = action.data
    if data and data.plate then
        local state = ensureVehicleData(data.plate)
        state.lockpick_in_progress = false
        state.hotwire_in_progress = false
        if data.vehicle and DoesEntityExist(data.vehicle) then
            syncEntityState(data.vehicle, state)
        end
    end
    Guard:CloseAction(token)
end)

RegisterNetEvent('mm_carkeys:server:repairVehicleElectrical', function(vehNetId)
    local src = source
    local vehicle, _, data = resolveVehicleAndState(vehNetId)
    if vehicle == 0 or not Guard:ValidateDistance(src, vehicle, Shared.security.maxInteractDistance + 2.0) then return end
    data.ignition_damaged = false
    data.electrical_failure_permanent = false
    syncEntityState(vehicle, data)
end)

RegisterNetEvent('mm_carkeys:server:setVehLockState', function(vehNetId, state)
    local src = source
    local vehicle = getVehicleFromNetId(vehNetId)
    if vehicle == 0 or not Guard:ValidateDistance(src, vehicle, Shared.security.maxInteractDistance + 5.0) then return end
    SetVehicleDoorsLocked(vehicle, state)
end)

RegisterNetEvent('mm_carkeys:server:acquiretempvehiclekeys', function(plate)
    local src = source
    if not isValidPlate(plate) then return end
    GiveTempKeys(src, plate)
end)

RegisterNetEvent('mm_carkeys:server:removetempvehiclekeys', function(plate)
    local src = source
    if not isValidPlate(plate) then return end
    RemoveTempKeys(src, plate)
end)

RegisterNetEvent('mm_carkeys:server:removelockpick', function(item)
    local src = source
    Bridge:RemoveItem(src, item)
end)

RegisterNetEvent('mm_carkeys:server:acquirevehiclekeys', function(plate)
    local src = source
    if not isValidPlate(plate) then return end
    local Player = Bridge:GetPlayer(src)
    if Player then
        Bridge:AddItem(src, 'vehiclekey', { label = 'CHAVE-' .. plate, plate = plate })
    end
end)

RegisterNetEvent('qb-vehiclekeys:server:AcquireVehicleKeys', function(plate)
    local src = source
    if not isValidPlate(plate) then return end
    local Player = Bridge:GetPlayer(src)
    if Player then
        Bridge:AddItem(src, 'vehiclekey', { label = 'Chaves -' .. plate, plate = plate })
    end
end)

RegisterNetEvent('mm_carkeys:server:removevehiclekeys', function(plate)
    local src = source
    if not isValidPlate(plate) then return end
    local keys = Bridge:GetPlayerItemsByName(src, 'vehiclekey')
    for _, v in pairs(keys) do
        local info = getItemInfo(v)
        if info and info.plate == plate then
            Bridge:RemoveItem(src, 'vehiclekey', v.slot)
            break
        end
    end
end)

RegisterNetEvent('mm_carkeys:server:stackkeys', function()
    local src = source
    local bagFound = Bridge:GetPlayerItemByName(src, 'keybag')
    local keys = Bridge:GetPlayerItemsByName(src, 'vehiclekey')
    local plates, platesList = {}, {}
    for _, v in pairs(keys) do
        local info = getItemInfo(v)
        if info and info.plate then
            plates[#plates + 1] = { plate = info.plate, label = info.label }
            platesList[#platesList + 1] = info.plate
            Bridge:RemoveItem(src, 'vehiclekey', v.slot)
        end
    end
    if bagFound then
        local info = getItemInfo(bagFound)
        for _, v in pairs(info.plates or {}) do
            plates[#plates + 1] = { plate = v.plate, label = v.label }
            platesList[#platesList + 1] = v.plate
        end
        Bridge:RemoveItem(src, 'keybag', bagFound.slot)
    end
    Bridge:AddItem(src, 'keybag', { plates = plates, platestxt = table.concat(platesList, ', ') })
end)

RegisterNetEvent('mm_carkeys:server:unstackkeys', function()
    local src = source
    local bag = Bridge:GetPlayerItemByName(src, 'keybag')
    if not bag then
        return TriggerClientEvent('ox_lib:notify', src, { description = 'Você não tem uma bolsa de chave', type = 'error' })
    end
    Bridge:RemoveItem(src, 'keybag', bag.slot)
    local itemInfo = getItemInfo(bag)
    for _, v in pairs(itemInfo.plates or {}) do
        Bridge:AddItem(src, 'vehiclekey', { label = v.label, plate = v.plate })
    end
end)

exports('GiveTempKeys', GiveTempKeys)
exports('RemoveTempKeys', RemoveTempKeys)

exports('GiveKeyItem', function(src, plate, netId)
    if not plate or not netId then return end
    TriggerClientEvent('mm_carkeys:client:setplayerkey', src, plate, netId)
end)

exports('RemoveKeyItem', function(src, plate)
    if not plate then return end
    TriggerClientEvent('mm_carkeys:client:removeplayerkey', src, plate)
end)

exports('HaveTemporaryKey', function(src, plate)
    if not plate then return end
    return lib.callback.await('mm_carkeys:client:havekey', src, 'temp', plate)
end)

exports('HavePermanentKey', function(src, plate)
    if not plate then return end
    return lib.callback.await('mm_carkeys:client:havekey', src, 'perma', plate)
end)

AddEventHandler('playerDropped', function()
    local src = source
    local citizenid = Bridge:GetPlayerCitizenId(src)
    if citizenid and VehicleList[citizenid] then
        VehicleList[citizenid] = nil
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for plate, data in pairs(VehicleData) do
        data.lockpick_in_progress = false
        data.hotwire_in_progress = false
    end
end)
