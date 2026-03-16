local VehicleKeys = require 'client.interface'
local VehicleSecurity = require 'client.modules.vehicle_security'

local LockPick = {
    lockpicking = false,
}

function LockPick:Minigame()
    if Shared.lockpick.minigameScript == 'inside-lockpicking' then
        local result = exports['inside-lockpicking']:StartLockPicking({
            difficulty = 'easy',
            requiredAmount = 2
        })
        return result == 'success'
    end

    return lib.skillCheck('easy')
end

function LockPick:BreakLockPick(isAdvanced)
    local chance = math.random()
    local canBreak = isAdvanced and chance <= Shared.lockpick.advancedBreakChance or chance <= Shared.lockpick.breakChance
    if canBreak then
        TriggerServerEvent('mm_carkeys:server:removelockpick', isAdvanced and Shared.items.advancedLockpick or Shared.items.lockpick)
    end
end

function LockPick:RunSequence(vehicle)
    local requiredStages = Shared.lockpick.sequence.requiredStages or 6
    local regressOnFail = Shared.lockpick.sequence.regressOnFail
    local regressAmount = Shared.lockpick.sequence.regressAmount or 1
    local failEndsAttempt = Shared.lockpick.sequence.failEndsAttempt
    local stage = 1

    while stage <= requiredStages do
        if not DoesEntityExist(vehicle) then
            return false, 'invalid'
        end

        local label = Shared.text.lockpickProgress:format(stage)
        local progress = lib.progressBar({
            label = label,
            duration = 1200,
            position = 'bottom',
            canCancel = true,
            useWhileDead = false,
            disable = { move = true, combat = true }
        })

        if not progress then
            return false, 'cancelled'
        end

        if self:Minigame() then
            stage = stage + 1
        else
            if failEndsAttempt then
                return false, 'failed'
            end

            if regressOnFail then
                stage = math.max(1, stage - regressAmount)
            end
        end
    end

    return true
end

function LockPick:LockPickDoor(isAdvanced)
    local playerPos = GetEntityCoords(cache.ped)
    local vehicle = lib.getClosestVehicle(playerPos, 3.0, false)
    if not vehicle or GetVehicleDoorLockStatus(vehicle) == 1 then return end

    if VehicleSecurity:IsIgnitionJammed(vehicle, GetVehicleNumberPlateText(vehicle)) then
        VehicleSecurity:NotifyIgnitionJammed()
        return
    end

    if self.lockpicking then return end
    self.lockpicking = true

    lib.requestAnimDict('anim@amb@clubhouse@tutorial@bkr_tut_ig3@')
    TaskPlayAnim(cache.ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 3.0, 3.0, -1, 49, 0, false, false, false)

    local result, reason = self:RunSequence(vehicle)
    TriggerServerEvent('hud:server:GainStress', Shared.lockpick.stressIncrease)
    self:BreakLockPick(isAdvanced)
    self.lockpicking = false

    StopAnimTask(cache.ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 1.0)

    if result then
        local plate = GetVehicleNumberPlateText(vehicle)
        TriggerServerEvent('mm_carkeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(vehicle), 1)
        TriggerServerEvent('mm_carkeys:server:setVehicleStatus', plate, Shared.vehicleState.states.breached)
        SetVehicleDoorsLockedForAllPlayers(vehicle, false)
        lib.notify({ description = Shared.text.vehicleUnlocked, type = 'success' })
        VehicleSecurity:UpdateReputation('lockpicking', 1)
        SetVehicleLights(vehicle, 2)
        Wait(250)
        SetVehicleLights(vehicle, 1)
        Wait(200)
        SetVehicleLights(vehicle, 0)
        return
    end

    if reason ~= 'cancelled' then
        VehicleSecurity:TriggerTheftAlert(vehicle, ('Tentativa de furto em %s'):format(GetVehicleNumberPlateText(vehicle)), 60000)
        VehicleSecurity:ApplyIgnitionFailureDamage(vehicle, Shared.ignition.lockpickFailDamage)
        lib.notify({ title = 'Falhou', description = Shared.text.lockpickFailed, type = 'error' })
    end
end

function LockPick:LockPickEngine(isAdvanced)
    if VehicleKeys.currentVehicle == 0 or GetIsVehicleEngineRunning(VehicleKeys.currentVehicle) then return end

    if VehicleSecurity:IsIgnitionJammed(VehicleKeys.currentVehicle, VehicleKeys.currentVehiclePlate) then
        VehicleSecurity:NotifyIgnitionJammed()
        return
    end

    local vehClass = GetVehicleClass(VehicleKeys.currentVehicle)
    if Shared.blacklistedClasses[vehClass] then
        lib.notify({ description = 'Esse veículo não pode ser ligado com lockpick.', type = 'error' })
        return
    end

    if self.lockpicking then return end
    self.lockpicking = true

    lib.requestAnimDict('anim@amb@clubhouse@tutorial@bkr_tut_ig3@')
    TaskPlayAnim(cache.ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 3.0, 3.0, -1, 49, 0, false, false, false)

    local result, reason = self:RunSequence(VehicleKeys.currentVehicle)
    TriggerServerEvent('hud:server:GainStress', Shared.lockpick.stressIncrease)
    self:BreakLockPick(isAdvanced)
    self.lockpicking = false

    StopAnimTask(cache.ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 1.0)

    if result then
        TriggerServerEvent('mm_carkeys:server:setVehicleStatus', VehicleKeys.currentVehiclePlate, Shared.vehicleState.states.breached)
        TriggerServerEvent('mm_carkeys:server:acquiretempvehiclekeys', VehicleKeys.currentVehiclePlate)
        SetVehicleEngineOn(VehicleKeys.currentVehicle, true, true, true)
        VehicleKeys.isEngineRunning = true
        return
    end

    if reason ~= 'cancelled' then
        VehicleSecurity:TriggerTheftAlert(VehicleKeys.currentVehicle, ('Tentativa de furto em %s'):format(VehicleKeys.currentVehiclePlate), 60000)
        VehicleSecurity:ApplyIgnitionFailureDamage(VehicleKeys.currentVehicle, Shared.ignition.lockpickFailDamage)
        lib.notify({ description = 'Falhou em ligar a ignição!', type = 'error' })
    end
end

return LockPick
