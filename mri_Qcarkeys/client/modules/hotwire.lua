local VehicleKeys = require 'client.interface'

local Hotwire = {
    isHotwiring = false
}

function Hotwire:IsIgnitionJammed(vehicle)
    return GetVehicleEngineHealth(vehicle) <= Shared.ignition.jammedThreshold
end

function Hotwire:ApplyIgnitionFailureDamage(vehicle)
    local damage = math.random() * (Shared.ignition.failDamageMax - Shared.ignition.failDamageMin) + Shared.ignition.failDamageMin
    local newHealth = math.max(0.0, GetVehicleEngineHealth(vehicle) - damage)
    SetVehicleEngineHealth(vehicle, newHealth)

    if newHealth <= Shared.ignition.jammedThreshold then
        lib.notify({
            title = 'Ignição encravada',
            description = 'A ignição encravou e precisa de reparo mecânico.',
            type = 'error'
        })
    end
end

function Hotwire:TriggerVehicleAlarm(vehicle, alarmTime)
    local vehClass = GetVehicleClass(vehicle)
    if Shared.luxuryClasses[vehClass] then
        TriggerServerEvent(Shared.dispatch.event, {
            code = '10-60',
            title = 'Alarme silencioso',
            description = ('Tentativa de ligação direta em %s'):format(GetVehicleNumberPlateText(vehicle)),
            coords = GetEntityCoords(vehicle)
        })
        return
    end

    SetVehicleAlarm(vehicle, true)
    SetVehicleAlarmTimeLeft(vehicle, alarmTime)
end

function Hotwire:CanContinueHotwire(vehicle)
    return VehicleKeys.currentVehicle ~= 0
        and VehicleKeys.currentVehicle == vehicle
        and IsPedInVehicle(cache.ped, vehicle, false)
        and GetPedInVehicleSeat(vehicle, -1) == cache.ped
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

function Hotwire:HotwireHandler()
    if self.isHotwiring then return end
    if VehicleKeys.currentVehicle == 0 then return end

    if self:IsIgnitionJammed(VehicleKeys.currentVehicle) then
        lib.notify({
            description = 'A ignição está encravada. Chame um mecânico para reparar.',
            type = 'error'
        })
        return
    end

    local enginewire = nil
    if GetResourceState('rep-enginewire') == 'started' then
        enginewire = exports['rep-enginewire']:MiniGame()
    end

    self.isHotwiring = true
    local vehicle = VehicleKeys.currentVehicle
    local hotwireTime = math.random(Shared.hotwire.minTime, Shared.hotwire.maxTime)
    local stageOneTime = math.floor(hotwireTime * 0.45)
    local stageTwoTime = hotwireTime - stageOneTime
    local success = false

    self:TriggerVehicleAlarm(vehicle, hotwireTime)
    lib.hideTextUI()
    VehicleKeys.showTextUi = false

    local firstStage = self:RunHotwireStage(Shared.hotwire.stageOneLabel, stageOneTime, vehicle)
    local secondStage = firstStage and self:RunHotwireStage(Shared.hotwire.stageTwoLabel, stageTwoTime, vehicle)

    if secondStage and (enginewire == nil or enginewire) then
        TriggerServerEvent('hud:server:GainStress', Shared.hotwire.stressIncrease)
        local level = exports['cw-rep']:getCurrentLevel('hotwiring')
        if level > 8 then level = 8 end
        if level == 0 then level = 1 end

        if math.random() <= Shared.hotwire.chance * level then
            exports['cw-rep']:updateSkill('hotwiring', 1)
            TriggerServerEvent('mm_carkeys:server:acquiretempvehiclekeys', VehicleKeys.currentVehiclePlate)
            SetVehicleEngineOn(vehicle, true, false, true)
            VehicleKeys.isEngineRunning = true
            success = true
        else
            self:ApplyIgnitionFailureDamage(vehicle)
            local description
            if level <= 1 then
                description = 'Isso parece impossível para você!'
            elseif level <= 2 then
                description = 'Isso parece muito complicado para você!'
            elseif level <= 3 then
                description = 'Isso parece complicado pra você!'
            elseif level <= 4 then
                description = 'Isso parece difícil pra você!'
            elseif level <= 5 then
                description = 'Isso parece normal para você!'
            else
                description = 'Erros? Mas você não erra...'
            end

            lib.notify({
                title = 'Falhou',
                description = description,
                type = 'error'
            })
        end
    else
        self:ApplyIgnitionFailureDamage(vehicle)
        lib.notify({
            title = 'Falhou',
            description = 'Ligação direta interrompida ou falhou!',
            type = 'error'
        })
    end

    if VehicleKeys.currentVehicle ~= 0 and VehicleKeys.isInDrivingSeat and not success and not VehicleKeys.showTextUi then
        lib.showTextUI('Ligação direta', {
            position = 'right-center',
            icon = 'h',
        })
        VehicleKeys.showTextUi = true
    end

    self.isHotwiring = false
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
