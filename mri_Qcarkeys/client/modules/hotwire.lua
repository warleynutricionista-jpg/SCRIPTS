local VehicleKeys = require 'client.interface'
local VehicleSecurity = require 'client.modules.vehicle_security'

local Hotwire = {
    isHotwiring = false,
    activeVehicle = 0
}

function Hotwire:ResetState(showCancelledMessage)
    self.isHotwiring = false
    self.activeVehicle = 0

    if lib.progressActive() then
        lib.cancelProgress()
    end

    if showCancelledMessage then
        lib.notify({
            title = 'Ligação direta',
            description = 'Processo interrompido.',
            type = 'error'
        })
    end
end

function Hotwire:CanContinueHotwire(vehicle)
    return vehicle ~= 0
        and DoesEntityExist(vehicle)
        and VehicleKeys.currentVehicle ~= 0
        and VehicleKeys.currentVehicle == vehicle
        and IsPedInVehicle(cache.ped, vehicle, false)
        and GetPedInVehicleSeat(vehicle, -1) == cache.ped
        and not IsEntityDead(cache.ped)
end

function Hotwire:WatchInterruption(vehicle)
    CreateThread(function()
        while self.isHotwiring and self.activeVehicle == vehicle do
            if not self:CanContinueHotwire(vehicle) then
                self:ResetState(true)
                return
            end
            Wait(100)
        end
    end)
end

function Hotwire:RunHotwireStage(label, duration, vehicle)
    local completed = lib.progressBar({
        label = label,
        duration = duration,
        position = 'bottom',
        allowCuffed = false,
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            clip = 'machinic_loop_mechandplayer'
        }
    })

    return completed and self:CanContinueHotwire(vehicle)
end

function Hotwire:RunSequence(vehicle)
    local hotwireTime = math.random(Shared.hotwire.minTime, Shared.hotwire.maxTime)
    local stageOneTime = math.floor(hotwireTime * 0.45)
    local stageTwoTime = hotwireTime - stageOneTime

    VehicleSecurity:TriggerTheftAlert(vehicle, ('Tentativa de ligação direta em %s'):format(GetVehicleNumberPlateText(vehicle)), hotwireTime)

    local firstStage = self:RunHotwireStage(Shared.hotwire.stageOneLabel, stageOneTime, vehicle)
    if not firstStage then return false, 'cancelled' end

    local secondStage = self:RunHotwireStage(Shared.hotwire.stageTwoLabel, stageTwoTime, vehicle)
    if not secondStage then return false, 'cancelled' end

    local minigameResult = VehicleSecurity:RunHotwireMinigame()
    if not minigameResult then
        return false, 'minigame_failed'
    end

    if not self:CanContinueHotwire(vehicle) then
        return false, 'cancelled'
    end

    local level = VehicleSecurity:GetReputationLevel('hotwiring')
    local successChance = Shared.hotwire.chance * level

    if math.random() <= successChance then
        VehicleSecurity:UpdateReputation('hotwiring', 1)
        TriggerServerEvent('mm_carkeys:server:acquiretempvehiclekeys', VehicleKeys.currentVehiclePlate)
        SetVehicleEngineOn(vehicle, true, false, true)
        VehicleKeys.isEngineRunning = true
        return true
    end

    return false, 'chance_failed'
end

function Hotwire:HotwireHandler()
    if self.isHotwiring then return end
    if VehicleKeys.currentVehicle == 0 then return end
    if not VehicleKeys.isInDrivingSeat then return end

    local vehicle = VehicleKeys.currentVehicle

    if VehicleSecurity:IsIgnitionJammed(vehicle) then
        VehicleSecurity:NotifyIgnitionJammed()
        return
    end

    self.isHotwiring = true
    self.activeVehicle = vehicle

    lib.hideTextUI()
    VehicleKeys.showTextUi = false
    self:WatchInterruption(vehicle)

    local success, reason = self:RunSequence(vehicle)
    TriggerServerEvent('hud:server:GainStress', Shared.hotwire.stressIncrease)

    if self.activeVehicle == vehicle then
        self.isHotwiring = false
        self.activeVehicle = 0
    end

    if success then
        return
    end

    VehicleSecurity:ApplyIgnitionFailureDamage(vehicle, Shared.ignition.hotwireFailDamage)

    if reason == 'chance_failed' then
        lib.notify({ title = 'Falhou', description = 'Você não conseguiu ligar a ignição.', type = 'error' })
    elseif reason == 'minigame_failed' then
        lib.notify({ title = 'Falhou', description = 'Você errou a ligação direta.', type = 'error' })
    end

    if VehicleKeys.currentVehicle ~= 0 and VehicleKeys.isInDrivingSeat and not VehicleKeys.showTextUi then
        lib.showTextUI('Ligação direta', { position = 'right-center', icon = 'h' })
        VehicleKeys.showTextUi = true
    end
end

function Hotwire:SetupHotwire()
    CreateThread(function()
        while VehicleKeys.currentVehicle ~= 0 and not VehicleKeys.hasKey do
            SetVehicleEngineOn(VehicleKeys.currentVehicle, false, false, true)
            VehicleKeys.isEngineRunning = false
            if IsControlJustPressed(0, 74) then
                self:HotwireHandler()
            end
            Wait(5)
        end
    end)
end

return Hotwire
