local lastRobberyTime = 0
local resourceName = 'pl-atmrob'
lib.versionCheck('pulsepk/pl-atmrob')

local atmRobberyState = {}
local ropeRobberyState = {}

local isEsExtendedStarted = GetResourceState('es_extended') == 'started'
local isQbCoreStarted = GetResourceState('qb-core') == 'started'

--credits to Lation for checkforpolice
--https://github.com/IamLation/lation_247robbery
lib.callback.register('pl_atmrobbery:checkforpolice', function()
    local copCount, jobs = 0, {}
    for _, job in pairs(Config.Police.Job) do
        jobs[job] = true
    end
    local requiredCount = Config.Police.required

    if isEsExtendedStarted then
        for _, player in pairs(getPlayers()) do
            if jobs[player.getJob().name] then
                copCount = copCount + 1
            end
        end
    elseif isQbCoreStarted then
        for _, playerId in pairs(getPlayers()) do
            local player = getPlayer(playerId)
            if jobs[player.PlayerData.job.name] and player.PlayerData.job.onduty then
                copCount = copCount + 1
            end
        end
    end
    return copCount >= requiredCount
end)

lib.callback.register('pl_atmrobbery:checktime', function()
    local timePassed = os.time() - lastRobberyTime

    if lastRobberyTime ~= 0 and timePassed < Config.CooldownTimer then
        return false, Config.CooldownTimer - timePassed
    end

    lastRobberyTime = os.time()
    return true
end)

RegisterServerEvent('pl_atmrobbery:MinigameResult')
AddEventHandler('pl_atmrobbery:MinigameResult', function(success, method)
    local src = source
    if success and (method == 'drill' or method == 'hack') then
        atmRobberyState[src] = {
            minigamePassed = true,
            pickupcash = 0,
            method = method
        }
    else
        atmRobberyState[src] = nil
    end
end)

RegisterNetEvent('pl_atmrobbery:server:completed')
AddEventHandler('pl_atmrobbery:server:completed', function(atmCoords)
    local src = source
    local Player = getPlayer(src)
    local Identifier = getPlayerIdentifier(src)
    local PlayerName = getPlayerName(src)
    local ped = GetPlayerPed(src)
    local distance = GetEntityCoords(ped)

    if #(distance - atmCoords) <= 5 then
        if Player then
            local state = atmRobberyState[src]
            if state and state.minigamePassed then
                local method = state.method or 'drill'
                local maxCashPiles = method == 'hack' and Config.Reward.hack_cash_pile or Config.Reward.drill_cash_pile

                state.pickupcash = state.pickupcash + 1
                AddPlayerMoney(Player, Config.Reward.account, Config.Reward.cash_prop_value)

                TriggerClientEvent('pl_atmrobbery:notification', src, Locale('server_pickup_cash', Config.Reward.cash_prop_value), 'success')

                if state.pickupcash >= maxCashPiles then
                    atmRobberyState[src] = nil
                else
                    atmRobberyState[src] = state
                end
            else
                print(('^1[Exploit Attempt]^0 %s (%s) tried to rob ATM without completing the minigame.'):format(PlayerName, Identifier))
            end
        end
    else
        print(('^1[Exploit Attempt]^0 %s (%s) triggered robbery too far from ATM.'):format(PlayerName, Identifier))
    end
end)

RegisterNetEvent('pl_atmrobbery:rope_robbery_completed')
AddEventHandler('pl_atmrobbery:rope_robbery_completed', function(atmCoords)
    local src = source
    local Player = getPlayer(src)
    local Identifier = getPlayerIdentifier(src)
    local PlayerName = getPlayerName(src)
    local ped = GetPlayerPed(src)
    local playerCoords = GetEntityCoords(ped)

    local state = ropeRobberyState[src]

    if #(playerCoords - atmCoords) > 15.0 then
        print(('^1[Exploit Attempt]^0 %s (%s) triggered rope robbery too far from ATM.'):format(PlayerName, Identifier))
        return
    end

    if not state or not state.started then
        print(('^1[Exploit Attempt]^0 %s (%s) triggered rope robbery without valid state.'):format(PlayerName, Identifier))
        return
    end

    if os.time() - state.time > 300 then
        ropeRobberyState[src] = nil
        print(('^1[Exploit Attempt]^0 %s (%s) rope robbery expired.'):format(PlayerName, Identifier))
        return
    end

    if Player then
        local totalReward = Config.Reward.reward
        AddPlayerMoney(Player, Config.Reward.account, totalReward)

        TriggerClientEvent(
            'pl_atmrobbery:notification',
            src,
            string.format(Locale('server_pickup_cash'), totalReward),
            'success'
        )
        TriggerClientEvent('pl_atmrobbery:rope:requestCleanup', -1)
    end

    ropeRobberyState[src] = nil
end)

RegisterNetEvent('pl_atmrobbery:rope:requestAttachVehicle', function(payload)
    local src = source
    if type(payload) ~= 'table' then return end
    if not payload.atmNetId or not payload.vehicleNetId then return end

    ropeRobberyState[src] = {
        started = true,
        atmNetId = payload.atmNetId,
        vehicleNetId = payload.vehicleNetId,
        time = os.time()
    }

    TriggerClientEvent('pl_atmrobbery:rope:create', -1, {
        atmNetId = payload.atmNetId,
        vehicleNetId = payload.vehicleNetId,
        owner = src
    })
end)


RegisterNetEvent('pl_atmrobbery:rope:requestDetach', function(payload)
    if type(payload) ~= 'table' then return end
    if not payload.atmNetId or not payload.vehicleNetId then return end

    TriggerClientEvent('pl_atmrobbery:rope:detachATM', -1, {
        atmNetId = payload.atmNetId,
        vehicleNetId = payload.vehicleNetId
    })
end)

RegisterNetEvent('pl_atmrobbery:server:removeRope', function()
    local src = source
    local player = getPlayer(src)
    if not player then return end
    RemoveItem(src, Config.RopeItem, 1)
end)

RegisterNetEvent('pl_atmrobbery:server:removeDrill', function()
    local src = source
    local player = getPlayer(src)
    if not player then return end
    RemoveItem(src, Config.DrillItem, 1)
end)

RegisterNetEvent('pl_atmrobbery:server:removeHackingDevice', function()
    local src = source
    local player = getPlayer(src)
    if not player then return end
    RemoveItem(src, Config.HackingItem, 1)
end)

local WaterMark = function()
    SetTimeout(1500, function()
        print('^1['..resourceName..'] ^2Thank you for Downloading the Script^0')
        print('^1['..resourceName..'] ^2If you encounter any issues please Join the discord https://discord.gg/c6gXmtEf3H to get support..^0')
        print('^1['..resourceName..'] ^2Enjoy a secret 20% OFF any script of your choice on https://pulsescripts.com/^0')
        print('^1['..resourceName..'] ^2Using the coupon code: SPECIAL20 (one-time use coupon, choose wisely)^0')
    end)
end

AddEventHandler('onServerResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if Config.DebugPrints then
            print('M-drilling' .. " Minigame → " .. (GetResourceState('M-drilling') == 'started' and "^2Found^7" or "^1Not Found^7"))
            print(Config.Hacking.Minigame .. " Minigame → " .. (GetResourceState(Config.Hacking.Minigame) == 'started' and "^2Found^7" or "^1Not Found^7"))
            print('')
        end
        if Config.WaterMark then
            WaterMark()
        end
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    atmRobberyState[src] = nil
    ropeRobberyState[src] = nil
end)

