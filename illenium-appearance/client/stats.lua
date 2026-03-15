-- client/stats.lua
local savedStats = nil

local function resetRechargeMultipliers()
    SetPlayerHealthRechargeMultiplier(cache.playerId, 0.0)
    SetPlayerHealthRechargeLimit(cache.playerId, 0.0)
end

function BackupPlayerStats()
    savedStats = {
        health = GetEntityHealth(cache.ped),
        armour = GetPedArmour(cache.ped),
    }
end

function RestorePlayerStats()
    if not savedStats then
        Framework.RestorePlayerArmour()
        return
    end
    local health = savedStats.health
    local armour = savedStats.armour
    savedStats = nil
    SetEntityMaxHealth(cache.ped, 200)
    -- Poll until health sticks - ped may not be fully ready yet
    local attempts = 0
    repeat
        Wait(100)
        SetEntityHealth(cache.ped, health)
        attempts = attempts + 1
    until GetEntityHealth(cache.ped) == health or attempts >= 15
    SetPedArmour(cache.ped, armour)
    resetRechargeMultipliers()
end
