local QBCore = GetResourceState('qb-core'):find('start') and exports['qb-core']:GetCoreObject() or nil

if not QBCore then return end

function getPlayer(target)
    local xPlayer = QBCore.Functions.GetPlayer(target)
    return xPlayer
end

function getPlayers()
    return QBCore.Functions.GetPlayers()
end

function getPlayerName(target)
    local xPlayer = QBCore.Functions.GetPlayer(target)

    return xPlayer.PlayerData.charinfo.firstname .. " " .. xPlayer.PlayerData.charinfo.lastname
end

function getPlayerIdentifier(target)
    local xPlayer = QBCore.Functions.GetPlayer(target)

    return xPlayer.PlayerData.citizenid
end

function GetJob(target)
    local xPlayer = QBCore.Functions.GetPlayer(target)
    if xPlayer then
        return xPlayer.PlayerData.job.name
    else
        return nil
    end
end

function AddPlayerMoney(Player,account,TotalBill)
    local source = Player.PlayerData.source
    if account == 'bank' then
        Player.Functions.AddMoney('bank', TotalBill)
    elseif account == 'cash' then
        Player.Functions.AddMoney('cash', TotalBill)
    elseif account == 'dirty' then
        if GetResourceState("ox_inventory") == "started" then
            exports.ox_inventory:AddItem(source, Config.Reward.account, TotalBill, false)
        elseif lib.checkDependency('qb-inventory', '2.0.0') then
            local info = {worth = TotalBill}
            exports['qb-inventory']:AddItem(source, 'markedbills', 1, false, info)
            TriggerClientEvent('qb-inventory:client:ItemBox', source, QBCore.Shared.Items['markedbills'], "add", info)
        else
            local info = {worth = TotalBill}
            Player.Functions.AddItem('markedbills', 1, false, info)
            TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items['markedbills'], "add", info)
        end
    end
end

function RemoveItem(src, item, amount)
    if type(item) == "boolean" then return end
    local xPlayer = getPlayer(src)
    if GetResourceState("ox_inventory") == "started" then
        exports.ox_inventory:RemoveItem(src, item, amount)
    else
        exports['qb-inventory']:RemoveItem(src, item, amount, false)
    end
end