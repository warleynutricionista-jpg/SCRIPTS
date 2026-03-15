local VehicleKeys = require 'client.interface'
local Utils = require 'client.modules.utils'
local VehicleSecurity = require 'client.modules.vehicle_security'

local Steal = {
    isCarjacking = false,
    canCarjack = true,
    isRobbingKeys = false
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
                if lib.progressActive() then
                    lib.cancelProgress()
                end
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

        local plate = GetVehicleNumberPlateText(vehicle)
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

function Steal:GetKeyLocation()
    local roll = math.random()
    local chances = Shared.grab.keyLocationChance

    if roll <= chances.driver then
        return 'driver'
    end

    if roll <= chances.driver + chances.glovebox then
        return 'glovebox'
    end

    return 'sunvisor'
end

function Steal:RunInteriorSearch(vehicle)
    local searchTime = math.random(Shared.grab.searchMinTime, Shared.grab.searchMaxTime)
    local location = self:GetKeyLocation()
    local locationLabel = location == 'glovebox' and 'porta-luvas' or 'quebra-sol'

    lib.notify({ description = ('As chaves não estavam com o condutor. Vasculhe o %s.'):format(locationLabel), type = 'inform' })

    if not IsPedInVehicle(cache.ped, vehicle, false) then
        TaskEnterVehicle(cache.ped, vehicle, 4000, -1, 1.0, 1, 0)
        Wait(1500)
    end

    if not IsPedInVehicle(cache.ped, vehicle, false) then
        return false
    end

    CreateThread(function()
        while lib.progressActive() do
            if not IsPedInVehicle(cache.ped, vehicle, false) or IsEntityDead(cache.ped) then
                lib.cancelProgress()
                break
            end
            Wait(100)
        end
    end)

    return lib.progressBar({
        label = Shared.grab.searchLabel,
        duration = searchTime,
        position = 'bottom',
        allowCuffed = false,
        useWhileDead = false,
        canCancel = true,
        disable = {
            move = true,
            combat = true
        },
        anim = {
            dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
            clip = 'machinic_loop_mechandplayer'
        }
    })
end

function Steal:GrabKey(vehicle)
    if self.isRobbingKeys then return end
    if vehicle == 0 or not DoesEntityExist(vehicle) then return end

    self.isRobbingKeys = true
    local robTime = math.random(Shared.grab.minTime, Shared.grab.maxTime)

    local robbed = lib.progressBar({
        label = Shared.grab.label,
        duration = robTime,
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

    local keyLocation = self:GetKeyLocation()
    local hasKeys = keyLocation == 'driver' or self:RunInteriorSearch(vehicle)

    if hasKeys and Shared.grab.leaveKeysOnVehicle then
        TriggerServerEvent('mm_carkeys:server:acquiretempvehiclekeys', GetVehicleNumberPlateText(vehicle))
    else
        lib.notify({
            title = 'Falhou',
            description = 'Você não encontrou as chaves no interior.',
            type = 'error'
        })
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
