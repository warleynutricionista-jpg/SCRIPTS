local ESX = GetResourceState('es_extended'):find('start') and exports['es_extended']:getSharedObject() or nil

if not ESX then return end

function getPlayer(target)
    local xPlayer = ESX.GetPlayerFromId(target)
    return xPlayer
end

function getPlayers()
    return ESX.GetExtendedPlayers()
end

function getPlayerName(target)
    local xPlayer = ESX.GetPlayerFromId(target)
    return xPlayer.getName()
end

function getPlayerIdentifier(target)
    local xPlayer = ESX.GetPlayerFromId(target)
    return xPlayer.getIdentifier()
end

function GetJob(target)
    local xPlayer = ESX.GetPlayerFromId(target)
    return xPlayer.getJob().name
end

function AddPlayerMoney(Player,account,TotalBill)
    if account == 'bank' then
        Player.addAccountMoney('bank', TotalBill)
    elseif account == 'dirty' then
        Player.addAccountMoney('black_money', TotalBill)
    elseif account == 'cash' then
        Player.addAccountMoney('money', TotalBill)
    end
end

function RemoveItem(src, item, amount)
    if type(item) == "boolean" then return end
    local xPlayer = getPlayer(src)
    if GetResourceState("ox_inventory") == "started" then
        exports.ox_inventory:RemoveItem(src, item, amount)
    else
        xPlayer.removeInventoryItem(item, amount)
    end
end