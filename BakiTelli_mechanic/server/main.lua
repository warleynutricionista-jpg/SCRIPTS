local activeServices = {}
local playerCooldowns = {}

local function getPlayer(source)
    return exports.qbx_core:GetPlayer(source)
end

local function getJobData(player)
    return player and player.PlayerData and player.PlayerData.job or nil
end

local function isMechanic(source)
    local player = getPlayer(source)
    local job = getJobData(player)
    return job and job.name == Config.MechanicJob, job, player
end

local function isOnDuty(job)
    if not Config.RequireDuty then return true end
    return job and job.onduty == true
end

local function getCooldownKey(source, serviceType)
    return ('%s:%s'):format(source, serviceType)
end

local function hasCooldown(source, serviceType)
    local key = getCooldownKey(source, serviceType)
    local untilTs = playerCooldowns[key]
    if not untilTs then return false end
    return untilTs > os.time()
end

local function setCooldown(source, serviceType, seconds)
    local key = getCooldownKey(source, serviceType)
    playerCooldowns[key] = os.time() + seconds
end

local function hasRequiredItem(source, service)
    if not service.requiresItem then return true end
    local count = exports.ox_inventory:Search(source, 'count', service.requiresItem.name)
    return count >= service.requiresItem.count
end

local function consumeRequiredItem(source, service)
    if not service.requiresItem then return true end
    return exports.ox_inventory:RemoveItem(source, service.requiresItem.name, service.requiresItem.count)
end

local function validateVehicleAndDistance(source, netId)
    if type(netId) ~= 'number' or netId <= 0 then
        return false
    end

    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then
        return false
    end

    local ped = GetPlayerPed(source)
    if ped == 0 then return false end

    local pCoords = GetEntityCoords(ped)
    local vCoords = GetEntityCoords(vehicle)
    local distance = #(pCoords - vCoords)

    return distance <= Config.MaxServiceDistance, vehicle
end

if Config.EnableStash then
    local stash = Config.Stash
    exports.ox_inventory:RegisterStash(stash.id, stash.label, stash.slots, stash.weight, stash.owner, stash.groups)
end

lib.callback.register('bakitelli_mechanic:server:getDutyState', function(source)
    local allowed, job = isMechanic(source)
    if not allowed then return false, false end
    return true, job.onduty == true
end)

RegisterNetEvent('bakitelli_mechanic:server:toggleDuty', function()
    local src = source
    local allowed, job, player = isMechanic(src)
    if not allowed then
        TriggerClientEvent('ox_lib:notify', src, { type = 'error', description = L('no_permission') })
        return
    end

    local newDuty = not (job.onduty == true)
    player.Functions.SetJobDuty(newDuty)
    TriggerClientEvent('ox_lib:notify', src, {
        type = 'success',
        description = newDuty and L('duty_on') or L('duty_off')
    })
end)

lib.callback.register('bakitelli_mechanic:server:canService', function(source, netId, serviceType)
    local service = Config.Services[serviceType]
    if not service then
        return false, L('service_failed')
    end

    local allowed, job = isMechanic(source)
    if not allowed or not isOnDuty(job) then
        return false, L('no_permission')
    end

    if hasCooldown(source, serviceType) then
        return false, L('service_failed')
    end

    local valid = validateVehicleAndDistance(source, netId)
    if not valid then
        return false, L('too_far')
    end

    if activeServices[netId] then
        return false, L('service_locked')
    end

    if not hasRequiredItem(source, service) then
        local req = service.requiresItem
        return false, L('item_missing', req.name, req.count)
    end

    return true
end)

lib.callback.register('bakitelli_mechanic:server:performService', function(source, netId, serviceType)
    local service = Config.Services[serviceType]
    if not service then
        return false, L('service_failed')
    end

    local allowed, job = isMechanic(source)
    if not allowed or not isOnDuty(job) then
        return false, L('no_permission')
    end

    local valid, vehicle = validateVehicleAndDistance(source, netId)
    if not valid then
        return false, L('too_far')
    end

    if activeServices[netId] then
        return false, L('service_locked')
    end

    if not hasRequiredItem(source, service) then
        local req = service.requiresItem
        return false, L('item_missing', req.name, req.count)
    end

    activeServices[netId] = source

    local removed = consumeRequiredItem(source, service)
    if not removed then
        activeServices[netId] = nil
        return false, L('service_failed')
    end

    local cooldown = service.cooldown or Config.PlayerCooldownSeconds
    setCooldown(source, serviceType, cooldown)

    TriggerClientEvent('bakitelli_mechanic:client:applyService', source, netId, serviceType)

    local plate = GetVehicleNumberPlateText(vehicle) or 'UNKNOWN'
    MySQL.insert.await('INSERT INTO mechanic_service_logs (plate, service_type, mechanic_license) VALUES (?, ?, ?)', {
        plate,
        serviceType,
        getPlayer(source).PlayerData.license
    })

    activeServices[netId] = nil

    return true, L('service_success', service.label)
end)

AddEventHandler('playerDropped', function()
    local src = source
    for netId, owner in pairs(activeServices) do
        if owner == src then
            activeServices[netId] = nil
        end
    end
end)
