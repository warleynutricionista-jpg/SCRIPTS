local VehicleKeys = require 'client.interface'
local Utils = require 'client.modules.utils'
local VehicleSecurity = require 'client.modules.vehicle_security'

local Steal = {
    isCarjacking = false,
    canCarjack = true,
    isRobbingKeys = false,
    npcSearchVehicle = {}
}

function Steal:ToggleCooldown()
    CreateThread(function()
        Wait(5000)
        self.canCarjack = true
        self:CarjackInit()
    end)
end

function Steal:MakePedFlee(target, vehicle)
    local occupants = Utils:GetPedsInVehicle(vehicle)
    for p = 1, #occupants do
        local ped = occupants[p] or 0
        if ped ~= target and DoesEntityExist(ped) then
            CreateThread(function()
                TaskLeaveVehicle(ped, vehicle, 256)
                TaskReactAndFleePed(ped, cache.ped)
                PlayPain(ped, 6, 0)
            end)
        end
    end
end

function Steal:CheckStealStatus(target, vehicle)
    CreateThread(function()
        SetVehicleUndriveable(vehicle, true)
        while self.isCarjacking do
            if not DoesEntityExist(target) then break end
            TaskSetBlockingOfNonTemporaryEvents(target, true)
            local distance = #(GetEntityCoords(cache.ped) - GetEntityCoords(target))
            if IsPedDeadOrDying(target, false) or distance > 7.5 then
                SetVehicleUndriveable(vehicle, false)
                if lib.progressActive() then lib.cancelProgress() end
                break
            end
            Wait(25)
        end
    end)
end

function Steal:ArmPedAndAttack(target, vehicle)
    if not DoesEntityExist(target) or IsEntityDead(target) then return false end

    local weaponList = Shared.steal.npcGunWeapons
    if not weaponList or #weaponList == 0 then return false end

    local weapon = weaponList[math.random(1, #weaponList)]
    GiveWeaponToPed(target, joaat(weapon), 120, false, true)
    SetCurrentPedWeapon(target, joaat(weapon), true)
    SetPedAccuracy(target, Shared.steal.npcAccuracy)
    SetPedCombatAttributes(target, 46, true)
    SetPedCombatAbility(target, Shared.steal.npcAggressiveness)
    SetPedAsEnemy(target, true)
    TaskLeaveVehicle(target, vehicle, 256)
    Wait(800)
    TaskCombatPed(target, cache.ped, 0, 16)

    lib.notify({
        title = 'Perigo',
        description = 'O condutor estava armado e reagiu ao assalto!',
        type = 'error'
    })

    return true
end

function Steal:CarjackVehicle(target)
    if self.isCarjacking or not self.canCarjack then return end
    if not DoesEntityExist(target) or IsPedAPlayer(target) then return end

    local vehicle = GetVehiclePedIsUsing(target)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    self.isCarjacking = true
    self.canCarjack = false

    local carjackChance = Shared.steal.chance[tostring(GetWeapontypeGroup(cache.weapon))] or 0.5
    VehicleSecurity:TriggerTheftAlert(vehicle, ('Tentativa de carjack em %s'):format(GetVehicleNumberPlateText(vehicle)), 45000)

    if math.random() <= Shared.steal.armedNpcChance then
        if self:ArmPedAndAttack(target, vehicle) then
            self.isCarjacking = false
            self:ToggleCooldown()
            return
        end
    end

    if math.random() > carjackChance then
        TriggerServerEvent('mm_carkeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(vehicle), 2)
        TaskReactAndFleePed(target, cache.ped)
        self.isCarjacking = false
        self:ToggleCooldown()
        return
    end

    lib.requestAnimDict('missminuteman_1ig_2')
    local stealTime = math.random(Shared.steal.minTime, Shared.steal.maxTime)

    TaskLeaveVehicle(target, vehicle, 256)
    self:MakePedFlee(target, vehicle)

    CreateThread(function()
        Wait(350)
        self:CheckStealStatus(target, vehicle)
        TaskTurnPedToFaceEntity(target, cache.ped, -1)
        TaskPlayAnim(target, 'missminuteman_1ig_2', 'handsup_base', 8.0, -8.0, -1, 49, 0, false, false, false)
    end)

    if lib.progressBar({
        label = Shared.steal.label,
        duration = stealTime,
        position = 'bottom',
        allowCuffed = false,
        useWhileDead = false,
        canCancel = true
    }) then
        self.isCarjacking = false
        StopAnimTask(target, 'missminuteman_1ig_2', 'handsup_base', 1.0)
        lib.requestAnimDict('mp_common')
        TaskPlayAnim(cache.ped, 'mp_common', 'givetake1_b', 8.0, -8, -1, 12, 1, false, false, false)
        TaskPlayAnim(target, 'mp_common', 'givetake1_b', 8.0, -8, -1, 12, 1, false, false, false)
        TaskSmartFleePed(target, cache.ped, 50, -1, false, false)
        TriggerServerEvent('hud:server:GainStress', Shared.steal.stressIncrease)
        TriggerServerEvent('mm_carkeys:server:setVehLockState', NetworkGetNetworkIdFromEntity(vehicle), 1)

        local plate = Utils:RemoveSpecialCharacter(GetVehicleNumberPlateText(vehicle))
        local modelName = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
        if Shared.steal.getKey == 'permanent' then
            TriggerServerEvent('mm_carkeys:server:acquirevehiclekeys', plate, modelName)
        elseif Shared.steal.getKey == 'temporary' then
            TriggerServerEvent('mm_carkeys:server:acquiretempvehiclekeys', plate)
        end
    else
        StopAnimTask(target, 'missminuteman_1ig_2', 'handsup_base', 1.0)
        self.isCarjacking = false
        local targetPos = GetEntityCoords(target)
        TaskWanderInArea(target, targetPos.x, targetPos.y, targetPos.z, 5.0, 5.0, 5.0)
        TriggerServerEvent('hud:server:GainStress', Shared.steal.stressIncrease)
    end

    self:ToggleCooldown()
    SetVehicleUndriveable(vehicle, false)
end

function Steal:IsCompartmentOpen(vehicle, compartment)
    local cfg = Shared.grab.searchCompartments[compartment]
    if not cfg then return false end
    if not cfg.requiresDoorOpen then return true end
    return GetVehicleDoorAngleRatio(vehicle, cfg.doorIndex) > 0.05
end

function Steal:SearchCompartment(vehicle, plate, compartment)
    local state = VehicleSecurity:GetVehicleState(plate)
    local config = Shared.grab.searchCompartments[compartment]
    if not state or not config then return false end

    if state.searched and state.searched[compartment] then
        lib.notify({ description = Shared.text.alreadySearched, type = 'error' })
        return false
    end

    if not self:IsCompartmentOpen(vehicle, compartment) then
        lib.notify({ description = Shared.text.compartmentClosed, type = 'error' })
        return false
    end

    local completed = lib.progressBar({
        label = config.label,
        duration = math.random(Shared.grab.searchMinTime, Shared.grab.searchMaxTime),
        position = 'bottom',
        canCancel = true,
        useWhileDead = false,
        disable = { move = true, combat = true },
        anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' }
    })

    if not completed then
        lib.notify({ description = Shared.text.actionCancelled, type = 'error' })
        return false
    end

    TriggerServerEvent('mm_carkeys:server:markVehicleCompartmentSearched', plate, compartment)
    local found, reason = lib.callback.await('mm_carkeys:server:finishVehicleCompartmentSearch', false, plate, compartment)
    if found then
        lib.notify({ description = Shared.text.keyFound, type = 'success' })
        return true
    end

    if reason == 'empty' then
        lib.notify({ description = Shared.text.emptyCompartment, type = 'inform' })
    end

    return false
end

function Steal:SearchNpcForKey(vehicle, driver)
    if not DoesEntityExist(driver) or IsPedAPlayer(driver) then return false end
    local plate = Utils:RemoveSpecialCharacter(GetVehicleNumberPlateText(vehicle))
    local npcNetId = PedToNet(driver)

    if not self.npcSearchVehicle[npcNetId] then
        self.npcSearchVehicle[npcNetId] = plate
        TriggerServerEvent('mm_carkeys:server:assignNpcVehicleKey', plate, npcNetId)
    end

    local escaped = false
    CreateThread(function()
        while lib.progressActive() do
            if not DoesEntityExist(driver) or IsEntityDead(driver) then
                escaped = true
                lib.cancelProgress()
                break
            end
            if #(GetEntityCoords(cache.ped) - GetEntityCoords(driver)) > Shared.steal.npcSearch.maxDistance then
                escaped = true
                lib.cancelProgress()
                break
            end
            if IsPedInAnyVehicle(driver, false) then
                escaped = true
                lib.cancelProgress()
                break
            end
            Wait(100)
        end
    end)

    local completed = lib.progressBar({
        label = Shared.steal.npcSearch.label,
        duration = Shared.steal.npcSearch.duration,
        canCancel = true,
        useWhileDead = false,
        disable = { move = true, combat = true },
        anim = { dict = 'amb@prop_human_bum_bin@base', clip = 'base' }
    })

    if not completed then
        if escaped then
            TriggerServerEvent('mm_carkeys:server:markNpcEscapedWithKey', plate, npcNetId)
            lib.notify({ description = Shared.text.npcEscapedWithKeys, type = 'error' })
        else
            lib.notify({ description = Shared.text.actionCancelled, type = 'error' })
        end
        return false
    end

    local found, reason = lib.callback.await('mm_carkeys:server:searchNpcForVehicleKey', false, plate, npcNetId)
    if found then
        lib.notify({ description = Shared.text.keyFound, type = 'success' })
        return true
    end

    if reason == 'no_key' then
        lib.notify({ description = Shared.text.npcNoKeys, type = 'inform' })
    end

    return false
end

function Steal:GrabKey(vehicle)
    if self.isRobbingKeys then return end
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    self.isRobbingKeys = true
    local driver = GetPedInVehicleSeat(vehicle, -1)

    local robbed = lib.progressBar({
        label = Shared.grab.label,
        duration = math.random(Shared.steal.minTime, Shared.steal.maxTime),
        position = 'bottom',
        allowCuffed = false,
        useWhileDead = false,
        canCancel = true
    })

    if not robbed then
        lib.notify({ title = 'Falhou', description = 'Não foi possível pegar as chaves.', type = 'error' })
        self.isRobbingKeys = false
        return
    end

    local foundOnNpc = false
    if Shared.features.enableNpcSearch and driver ~= 0 then
        foundOnNpc = self:SearchNpcForKey(vehicle, driver)
    end

    if foundOnNpc then
        self.isRobbingKeys = false
        return
    end

    if Shared.features.enableVehicleSearch then
        local plate = Utils:RemoveSpecialCharacter(GetVehicleNumberPlateText(vehicle))
        local foundGlove = self:SearchCompartment(vehicle, plate, 'glovebox')
        if not foundGlove then
            self:SearchCompartment(vehicle, plate, 'trunk')
        end
    end

    self.isRobbingKeys = false
end

function Steal:CarjackInit()
    CreateThread(function()
        while VehicleKeys.currentWeapon and VehicleKeys.currentVehicle == 0 do
            local aiming, target = GetEntityPlayerIsFreeAimingAt(cache.playerId)
            if aiming and target and target ~= 0 then
                if DoesEntityExist(target) and IsPedInAnyVehicle(target, false) and not IsEntityDead(target) and not IsPedAPlayer(target) then
                    local targetveh = GetVehiclePedIsIn(target, false)
                    if targetveh ~= 0 and GetPedInVehicleSeat(targetveh, -1) == target and not Utils:IsBlacklistedWeapon() then
                        local pos = GetEntityCoords(cache.ped, true)
                        local targetpos = GetEntityCoords(target, true)
                        if #(pos - targetpos) < 5.0 then
                            self:CarjackVehicle(target)
                            break
                        end
                    end
                end
            end
            Wait(200)
        end
    end)
end

return Steal
