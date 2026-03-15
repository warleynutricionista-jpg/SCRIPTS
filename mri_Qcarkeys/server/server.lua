local Bridge = require 'server.bridge'

local VehicleList = {}
local getItemInfo = Shared.Inventory == 'qb' and function(item) return item.info end or function(item) return item.metadata end

local function isValidPlate(plate)
    if type(plate) ~= 'string' then return false end
    if #plate == 0 or #plate > 10 then return false end
    return plate:match('^[%w%s]+$') ~= nil
end

local function RemoveSpecialCharacter(txt)
    return txt:gsub("%W", "")
end

function GiveTempKeys(id, plate)
    local citizenid = Bridge:GetPlayerCitizenId(id)
    if not VehicleList[citizenid] then VehicleList[citizenid] = {} end
    plate = RemoveSpecialCharacter(plate)
    if Shared.keepKeysInVehicle then
        local info = {}
		info.label = "CHAVE-"..plate
        info.plate = plate
		Bridge:AddItem(id, 'vehiclekey', info)
    end

    VehicleList[citizenid][plate] = true
    local ndata = {
        title = 'Recebido',
        description = 'Você recebeu a chave temporária para o veículo',
        type = 'success'
    }
    TriggerClientEvent('ox_lib:notify', id, ndata)
    TriggerClientEvent('mm_carkeys:client:addtempkeys', id, plate)
end

function RemoveTempKeys(id, plate)
    local citizenid = Bridge:GetPlayerCitizenId(id)
    plate = RemoveSpecialCharacter(plate)
    if VehicleList[citizenid] and VehicleList[citizenid][plate] then
        VehicleList[citizenid][plate] = nil
    end
    TriggerClientEvent('mm_carkeys:client:removetempkeys', id, plate)
end

exports('GiveTempKeys', function(src, plate)
    if not plate then
        local nData = {
            title = 'Falha',
            description = 'Nenhuma placa de veículo encontrada',
            type = 'error'
        }
        TriggerClientEvent('ox_lib:notify', src, nData)
        return
    end
    GiveTempKeys(src, plate)
end)

exports('RemoveTempKeys', function(src, plate)
    if not plate then
        local nData = {
            title = 'Falha',
            description = 'Nenhuma placa de veículo encontrada',
            type = 'error'
        }
        TriggerClientEvent('ox_lib:notify', src, nData)
        return
    end
    RemoveTempKeys(src, plate)
end)

exports('GiveKeyItem', function(src, plate, netId)
    if not plate or not netId then
        local nData = {
            title = 'Falha',
            description = 'Nenhum dado de veículo encontrado',
            type = 'error'
        }
        TriggerClientEvent('ox_lib:notify', src, nData)
        return
    end
    TriggerClientEvent('mm_carkeys:client:setplayerkey', src, plate, netId)
end)

exports('RemoveKeyItem', function(src, plate)
    if not plate then
        local nData = {
            title = 'Falha',
            description = 'Nenhum dado de veículo encontrado',
            type = 'error'
        }
        TriggerClientEvent('ox_lib:notify', src, nData)
        return
    end
    TriggerClientEvent('mm_carkeys:client:removeplayerkey', src, plate)
end)

exports('HaveTemporaryKey', function(src, plate)
    if not plate then
        return 
    end
    return lib.callback.await('mm_carkeys:client:havekey', src, 'temp', plate)
end)

exports('HavePermanentKey', function(src, plate)
    if not plate then
        return
    end
    return lib.callback.await('mm_carkeys:client:havekey', src, 'perma', plate)
end)

lib.callback.register('mm_carkeys:server:getvehiclekeys', function(source)
    local citizenid = Bridge:GetPlayerCitizenId(source)
    return VehicleList[citizenid] or {}
end)

RegisterNetEvent('mm_carkeys:server:setVehLockState', function(vehNetId, state)
    local src = source
    if not src or src <= 0 then return end
    SetVehicleDoorsLocked(NetworkGetEntityFromNetworkId(vehNetId), state)
end)

RegisterNetEvent('mm_carkeys:server:acquiretempvehiclekeys', function(plate)
    local src = source
    if not src or src <= 0 then return end
    if not isValidPlate(plate) then return end
    GiveTempKeys(src, plate)
end)

RegisterNetEvent('mm_carkeys:server:removetempvehiclekeys', function(plate)
    local src = source
    if not src or src <= 0 then return end
    if not isValidPlate(plate) then return end
    RemoveTempKeys(src, plate)
end)

RegisterNetEvent('mm_carkeys:server:removelockpick', function(item)
    local src = source
    if not src or src <= 0 then return end
    Bridge:RemoveItem(src, item)
end)

RegisterNetEvent('mm_carkeys:server:acquirevehiclekeys', function(plate)
    local src = source
    if not src or src <= 0 then return end
    if not isValidPlate(plate) then return end
	local Player = Bridge:GetPlayer(src)
    if Player then

        local info = {}
		info.label = "CHAVE-" ..plate ---@old: model.. '-' ..plate
        info.plate = plate
		Bridge:AddItem(src, 'vehiclekey', info)
	end
end)

RegisterNetEvent('qb-vehiclekeys:server:AcquireVehicleKeys', function(plate)
    local src = source
    if not src or src <= 0 then return end
    if not isValidPlate(plate) then return end
	local Player = Bridge:GetPlayer(src)
    if Player then
        local info = {}
		info.label = 'Chaves -'..plate
        info.plate = plate
		Bridge:AddItem(src, 'vehiclekey', info)
	end
end)

RegisterNetEvent('mm_carkeys:server:removevehiclekeys', function(plate)
    local src = source
    if not src or src <= 0 then return end
    if not isValidPlate(plate) then return end
    local keys = Bridge:GetPlayerItemsByName(src, 'vehiclekey')
    for _, v in pairs(keys) do
        local info = getItemInfo(v)
        if info.plate == plate then
            Bridge:RemoveItem(src, 'vehiclekey', v.slot)
            break
        end
    end
end)

RegisterNetEvent('mm_carkeys:server:stackkeys', function()
    local src = source
    if not src or src <= 0 then return end
    local bagFound = Bridge:GetPlayerItemByName(src, 'keybag')
    local keys = Bridge:GetPlayerItemsByName(src, 'vehiclekey')
    local plates = {}
    local platesList = {}
    for _, v in pairs(keys) do
        local info = getItemInfo(v)
        if info.plate then
            plates[#plates+1] = {
                plate = info.plate,
                label = info.label
            }
            platesList[#platesList+1] = info.plate
            Bridge:RemoveItem(src, 'vehiclekey', v.slot)
        end
    end
    if bagFound then
        local info = getItemInfo(bagFound)
        local getplates = info.plates
        for _, v in pairs(getplates) do
            plates[#plates+1] = {
                plate = v.plate,
                label = v.label
            }
            platesList[#platesList+1] = v.plate
        end
        Bridge:RemoveItem(src, 'keybag', bagFound.slot)
    end
    local platestxt = table.concat(platesList, ', ')
    Bridge:AddItem(src, 'keybag', {plates = plates, platestxt = platestxt})
end)

RegisterNetEvent('mm_carkeys:server:unstackkeys', function()
    local src = source
    if not src or src <= 0 then return end
    local bag = Bridge:GetPlayerItemByName(src, 'keybag')
    if not bag then
        local ndata = {
            description = 'Você não tem uma bolsa de chave',
            type = 'error'
        }
        TriggerClientEvent('ox_lib:notify', src, ndata)
        return
    end
    Bridge:RemoveItem(src, 'keybag', bag.slot)
    local itemInfo = getItemInfo(bag)
    for _, v in pairs(itemInfo.plates) do
        local info = {}
		info.label = v.label
        info.plate = v.plate
        Bridge:AddItem(src, 'vehiclekey', info)
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    local citizenid = Bridge:GetPlayerCitizenId(src)
    if citizenid and VehicleList[citizenid] then
        VehicleList[citizenid] = nil
    end
end)

-- lib.versionCheck('SOH69/mm_carkeys')