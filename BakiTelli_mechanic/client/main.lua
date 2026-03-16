local isMenuOpen = false

local function notify(type, description)
    lib.notify({ type = type, description = description })
end

local function getClosestVehicleWithinDistance(maxDistance)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local vehicle = lib.getClosestVehicle(coords, maxDistance, false)

    if vehicle == 0 then
        return nil
    end

    local distance = #(coords - GetEntityCoords(vehicle))
    if distance > maxDistance then
        return nil
    end

    return vehicle
end

local function openServiceMenu()
    local options = {}

    for serviceType, serviceData in pairs(Config.Services) do
        options[#options + 1] = {
            title = serviceData.label,
            icon = serviceData.icon,
            onSelect = function()
                local vehicle = getClosestVehicleWithinDistance(Config.MaxServiceDistance)
                if not vehicle then
                    notify('error', L('no_vehicle'))
                    return
                end

                local netId = NetworkGetNetworkIdFromEntity(vehicle)
                local canService, reason = lib.callback.await('bakitelli_mechanic:server:canService', false, netId, serviceType)
                if not canService then
                    notify('error', reason or L('service_failed'))
                    return
                end

                local duration = serviceData.duration or Config.RepairDurationMs
                local completed = lib.progressCircle({
                    duration = duration,
                    position = 'bottom',
                    canCancel = true,
                    disable = { move = true, car = true, combat = true }
                })

                if not completed then
                    return
                end

                local success, message = lib.callback.await('bakitelli_mechanic:server:performService', false, netId, serviceType)
                if not success then
                    notify('error', message or L('service_failed'))
                    return
                end

                notify('success', message)
            end
        }
    end

    lib.registerContext({
        id = 'bakitelli_mechanic_services',
        title = L('service_menu'),
        options = options
    })

    lib.showContext('bakitelli_mechanic_services')
end

local function openMechanicMenu()
    if isMenuOpen then return end
    isMenuOpen = true

    local hasAccess, onDuty = lib.callback.await('bakitelli_mechanic:server:getDutyState', false)
    if not hasAccess then
        notify('error', L('no_permission'))
        isMenuOpen = false
        return
    end

    lib.registerContext({
        id = 'bakitelli_mechanic_main',
        title = L('menu_title'),
        options = {
            {
                title = L('toggle_duty'),
                description = onDuty and 'ON' or 'OFF',
                icon = 'user-gear',
                onSelect = function()
                    TriggerServerEvent('bakitelli_mechanic:server:toggleDuty')
                end
            },
            {
                title = L('service_menu'),
                description = L('menu_desc'),
                icon = 'screwdriver-wrench',
                onSelect = openServiceMenu
            }
        }
    })

    lib.showContext('bakitelli_mechanic_main')
    isMenuOpen = false
end

CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        local playerCoords = GetEntityCoords(ped)

        for i = 1, #Config.Locations do
            local location = Config.Locations[i]
            local distance = #(playerCoords - location.coords)

            if distance <= location.radius + 10.0 then
                sleep = 0
                DrawMarker(2, location.coords.x, location.coords.y, location.coords.z + 0.15, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.25, 0.25, 0.2, 35, 153, 255, 180, false, false, false, true)

                if distance <= location.radius then
                    lib.showTextUI(L('use_station'))
                    if IsControlJustReleased(0, 38) then
                        openMechanicMenu()
                    end
                else
                    lib.hideTextUI()
                end
            end
        end

        Wait(sleep)
    end
end)

RegisterNetEvent('bakitelli_mechanic:client:applyService', function(netId, serviceType)
    local vehicle = NetworkGetEntityFromNetworkId(netId)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    if serviceType == 'repair' then
        SetVehicleEngineHealth(vehicle, 1000.0)
        SetVehicleBodyHealth(vehicle, 1000.0)
        SetVehiclePetrolTankHealth(vehicle, 1000.0)
        SetVehicleFixed(vehicle)
    elseif serviceType == 'clean' then
        SetVehicleDirtLevel(vehicle, 0.0)
        WashDecalsFromVehicle(vehicle, 1.0)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    lib.hideTextUI()
end)
