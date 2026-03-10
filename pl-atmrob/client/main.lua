if GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
end

local cashObjects = {}
local ropeAttachedATMs = {}
local robbedATMCoords = {}

local atmModels = {
    ["prop_atm_01"] = vector3(0.072237, 0.50293, 0.779063),
    ["prop_atm_02"] = vector3(0.01, 0.11, 0.92),
    ["prop_atm_03"] = vector3(-0.14, -0.01, 0.88),
    ["prop_fleeca_atm"] = vector3(0.127, 0.017, 1.0)
}

function IsATMAlreadyRobbed(atmCoords)
    for _, robbedCoords in pairs(robbedATMCoords) do
        if #(atmCoords - robbedCoords) < 1.0 then
            return true
        end
    end
    return false
end

function MarkATMAsRobbed(atmCoords)
    table.insert(robbedATMCoords, atmCoords)
end

local targetResource
local targetsRegistered = false

local function RegisterAtmTargets()
    if targetsRegistered then return true end

    targetResource = Utils.GetTarget()
    if not targetResource then
        return false
    end

    for _, model in ipairs(Config.AtmModels) do
        if targetResource == 'ox_target' then
        local options = {}

        local function canInteractGeneric(entity, action)
            for _, st in pairs(ropeAttachedATMs) do
                local atmEnt = Utils.NetToEnt(st.atmNetId)
                if atmEnt ~= 0 and atmEnt == entity then
                    if action == 'rope' then return false end
                    if action == 'hack' or action == 'drill' then
                        if st.detached or st.ropeAttached then return false end
                    end
                end
            end

            local coords = GetEntityCoords(entity)
            return not IsATMAlreadyRobbed(coords)
        end

        if Config.EnableHacking then
            table.insert(options, {
                event = 'pl_atmrobbery_hack',
                label = Locale('hack_atm_label'),
                icon = 'fas fa-laptop-code',
                model = model,
                distance = 2,
                items = Config.HackingItem,
                canInteract = function(entity) return canInteractGeneric(entity, 'hack') end
            })
        end

        if Config.EnableDrilling then
            table.insert(options, {
                event = 'pl_atmrobbery_drill',
                label = Locale('drill_atm_label'),
                icon = 'fas fa-tools',
                model = model,
                distance = 2,
                items = Config.DrillItem,
                canInteract = function(entity) return canInteractGeneric(entity, 'drill') end
            })
        end

        if Config.EnableRopeRobbery and (model == 'prop_fleeca_atm' or model == 'prop_atm_02' or model == 'prop_atm_03') then
            table.insert(options, {
                event = 'pl_atmrobbery_rope',
                label = Locale('rope_atm_label'),
                icon = 'fas fa-link',
                model = model,
                distance = 2,
                items = Config.RopeItem,
                canInteract = function(entity) return canInteractGeneric(entity, 'rope') end
            })
        end

            exports.ox_target:addModel(model, options)

        elseif targetResource == 'qb-target' then
            local options = {}

        local function canInteractGeneric(entity, action)
            for _, st in pairs(ropeAttachedATMs) do
                local atmEnt = Utils.NetToEnt(st.atmNetId)
                if atmEnt ~= 0 and atmEnt == entity then
                    if action == 'rope' then return false end
                    if action == 'hack' or action == 'drill' then
                        if st.detached or st.ropeAttached then return false end
                    end
                end
            end

            local coords = GetEntityCoords(entity)
            return not IsATMAlreadyRobbed(coords)
        end

        if Config.EnableHacking then
            table.insert(options, {
                type = "client",
                event = 'pl_atmrobbery_hack',
                icon = 'fas fa-laptop-code',
                label = Locale('hack_atm_label'),
                model = model,
                item = Config.HackingItem,
                canInteract = function(entity) return canInteractGeneric(entity, 'hack') end
            })
        end

        if Config.EnableDrilling then
            table.insert(options, {
                type = "client",
                event = 'pl_atmrobbery_drill',
                icon = 'fas fa-tools',
                label = Locale('drill_atm_label'),
                model = model,
                item = Config.DrillItem,
                canInteract = function(entity) return canInteractGeneric(entity, 'drill') end
            })
        end

        if Config.EnableRopeRobbery and (model == 'prop_fleeca_atm' or model == 'prop_atm_02' or model == 'prop_atm_03') then
            table.insert(options, {
                type = "client",
                event = 'pl_atmrobbery_rope',
                icon = 'fas fa-link',
                label = Locale('rope_atm_label'),
                model = model,
                item = Config.RopeItem,
                canInteract = function(entity) return canInteractGeneric(entity, 'rope') end
            })
        end

            exports['qb-target']:AddTargetModel(model, {
                options = options,
                distance = 1.0
            })
        end
    end

    targetsRegistered = true
    return true
end

CreateThread(function()
    while not RegisterAtmTargets() do
        Wait(1000)
    end
end)

AddEventHandler('onClientResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        RegisterAtmTargets()
        return
    end

    if not targetsRegistered and (resourceName == 'ox_target' or resourceName == 'qb-target') then
        RegisterAtmTargets()
    end
end)

function AddCashToTarget(cash, atmCoords)
    if targetResource == 'qb-target' then
        exports['qb-target']:AddTargetEntity(cash, {
            options = {
                {
                    type = "client",
                    event = "pl_atmrobbery:pickupCash",
                    icon = "fas fa-money-bill-wave",
                    label = Locale('pick_up_cash'),
                    atmCoords = atmCoords
                }
            },
            distance = 1.5
        })
    elseif targetResource == 'ox_target' then
        exports.ox_target:addLocalEntity(cash, {
            {
                event = "pl_atmrobbery:pickupCash",
                icon = "fas fa-money-bill-wave",
                label = Locale('pick_up_cash'),
                args = atmCoords
            }
        })
    end
end

RegisterNetEvent('pl_atmrobbery:notification')
AddEventHandler('pl_atmrobbery:notification', function(message, type)
    if Config.Notify == 'ox' then
        lib.notify({
            title = 'Pulse Scripts ATM',
            description = message,
            type = type
        })
    elseif Config.Notify == 'esx' then
        TriggerEvent("esx:showNotification", message)
    elseif Config.Notify == 'okok' then
        exports['okokNotify']:Alert("Informação", message, 5000, 'info')
    elseif Config.Notify == 'qb' then
        QBCore.Functions.Notify(message, type, 5000)
    elseif Config.Notify == 'wasabi' then
        exports.wasabi_notify:notify("Pulse Scripts - ROUBO A CAIXA ELETRÔNICO", message, 6000, type, false, 'fas fa-ghost')
    elseif Config.Notify == 'brutal_notify' then
        exports['brutal_notify']:SendAlert('Notificação', message, 6000, type, false)
    elseif Config.Notify == 'custom' then
        -- custom
    end
end)

function DispatchAlert()
    if Config.Dispatch == 'ps' then
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local street1name = GetStreetNameFromHashKey(street1)
        local street2name = GetStreetNameFromHashKey(street2)

        local alert = {
            coords = coords,
            message = locale('dispatch_message') .. street1name .. ' ' .. street2name,
            dispatchCode = '10-90',
            description = 'Roubo a caixa eletrônico',
            radius = 0,
            sprite = 431,
            color = 1,
            scale = 1.0,
            length = 3
        }

        exports["ps-dispatch"]:CustomAlert(alert)

    elseif Config.Dispatch == 'aty' then
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local street1name = GetStreetNameFromHashKey(street1)
        local street2name = GetStreetNameFromHashKey(street2)

        TriggerServerEvent("aty_dispatch:server:customDispatch",
            "Roubo a caixa eletrônico", -- título
            "10-90", -- código
            street1name .. ' ' .. street2name, -- localização
            coords, -- coords (vector3)
            nil, -- gender
            nil, -- vehicle name
            nil, -- vehicle object (optional)
            nil, -- weapon
            431, -- blip sprite
            Config.Police.Job -- jobs to notify
        )

    elseif Config.Dispatch == 'rcore' then
        local playerData = exports['rcore_dispatch']:GetPlayerData()
        exports['screenshot-basic']:requestScreenshotUpload('InsertWebhookLinkHERE', "files[]", function(val)
            local image = json.decode(val)
            local alert = {
                code = '10-90 - Roubo a caixa eletrônico',
                default_priority = 'low',
                coords = playerData.coords,
                job = Config.Police.Job,
                text = 'Roubo a caixa eletrônico em andamento em ' .. playerData.street_1,
                type = 'alerts',
                blip_time = 30,
                image = image.attachments[1].proxy_url,
                blip = {
                    sprite = 431,
                    colour = 1,
                    scale = 1.0,
                    text = '10-90 - Roubo a caixa eletrônico',
                    flashes = false,
                    radius = 0,
                }
            }
            TriggerServerEvent('rcore_dispatch:server:sendAlert', alert)
        end)

    elseif Config.Dispatch == 'cd_dispatch' then
        local data = exports['cd_dispatch']:GetPlayerInfo()
        TriggerServerEvent('cd_dispatch:AddNotification', {
            job_table = {'police'},
            coords = data.coords,
            title = '10-90 - Roubo a caixa eletrônico',
            message = 'Um(a) ' .. data.sex .. ' está roubando um caixa eletrônico em ' .. data.street,
            flash = 0,
            unique_id = data.unique_id,
            sound = 1,
            blip = {
                sprite = 431,
                scale = 1.2,
                colour = 3,
                flashes = false,
                text = '911 - Roubo a caixa eletrônico',
                time = 5,
                radius = 0,
            }
        })

    elseif Config.Dispatch == 'op' then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local street1, street2 = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local street1name = GetStreetNameFromHashKey(street1)
        local street2name = GetStreetNameFromHashKey(street2)

        local job = Config.Police.Job
        local title = "Roubo a caixa eletrônico"
        local id = GetPlayerServerId(PlayerId())
        local panic = false

        local locationText = street2name and (street1name .. " e " .. street2name) or street1name
        local text = "Roubo a caixa eletrônico em andamento em " .. locationText

        TriggerServerEvent('Opto_dispatch:Server:SendAlert', job, title, text, coords, panic, id)

    elseif Config.Dispatch == 'custom' then
        -- Add your custom dispatch code here
    end
end

RegisterNetEvent('pl_atmrobbery_drill')
AddEventHandler('pl_atmrobbery_drill', function(data)
    local entity = data.entity
    local atmModel = GetEntityModel(entity)

    if entity and DoesEntityExist(entity) then
        local atmCoords = GetEntityCoords(entity)
        if not IsPedHeadingTowardsPosition(PlayerPedId(), atmCoords.x, atmCoords.y, atmCoords.z, 10.0) then
            TaskTurnPedToFaceCoord(PlayerPedId(), atmCoords.x, atmCoords.y, atmCoords.z, 1500)
        end

        local enoughpolice = lib.callback.await('pl_atmrobbery:checkforpolice', false)
        if enoughpolice then
            local checktime = lib.callback.await('pl_atmrobbery:checktime', false)
            if checktime then
                Wait(1000)
                if Config.Police.notify then
                    DispatchAlert()
                end

                TriggerServerEvent('pl_atmrobbery:server:removeDrill')

                if GetResourceState('M-drilling') ~= 'started' then
                    print("^1[ATM Robbery]^0 Recurso do minigame de furadeira não encontrado ou não iniciado: M-drilling")
                end

                TriggerEvent("Drilling:Start", function(success)
                    if success then
                        TriggerServerEvent('pl_atmrobbery:MinigameResult', true, 'drill')
                        if not Config.MoneyDrop then
                            LootATM(atmCoords)
                        else
                            TriggerEvent('pl_atmrobbery_drill:success', entity, atmCoords, atmModel)
                        end
                    else
                        TriggerServerEvent('pl_atmrobbery:MinigameResult', false, 'drill')
                    end
                end)
            else
                TriggerEvent('pl_atmrobbery:notification', Locale('wait_robbery'), 'error')
            end
        else
            TriggerEvent('pl_atmrobbery:notification', Locale('not_enough_police'), 'error')
        end
    end
end)

RegisterNetEvent('pl_atmrobbery_hack')
AddEventHandler('pl_atmrobbery_hack', function(data)
    local entity = data.entity
    local atmModel = GetEntityModel(entity)

    if entity and DoesEntityExist(entity) then
        local atmCoords = GetEntityCoords(entity)
        if not IsPedHeadingTowardsPosition(PlayerPedId(), atmCoords.x, atmCoords.y, atmCoords.z, 10.0) then
            TaskTurnPedToFaceCoord(PlayerPedId(), atmCoords.x, atmCoords.y, atmCoords.z, 1500)
        end

        local enoughpolice = lib.callback.await('pl_atmrobbery:checkforpolice', false)
        if enoughpolice then
            local checktime = lib.callback.await('pl_atmrobbery:checktime', false)
            if checktime then
                Wait(1000)
                if Config.Police.notify then
                    DispatchAlert()
                end

                lib.progressBar({
                    duration = Config.Hacking.InitialHackDuration,
                    label = 'Iniciando invasão',
                    useWhileDead = false,
                    canCancel = false,
                    disable = { car = true, move = true, combat = true },
                    anim = { dict = 'missheist_jewel@hacking', clip = 'hack_loop' }
                })

                TriggerEvent('pl_atmrobbery:StartMinigame', entity, atmCoords, atmModel)
                TriggerServerEvent('pl_atmrobbery:server:removeHackingDevice')
            else
                TriggerEvent('pl_atmrobbery:notification', Locale('wait_robbery'), 'error')
            end
        else
            TriggerEvent('pl_atmrobbery:notification', Locale('not_enough_police'), 'error')
        end
    end
end)

function LootATM(atmCoords)
    lib.progressBar({
        duration = Config.Hacking.LootAtmDuration,
        label = 'Coletando dinheiro',
        useWhileDead = false,
        canCancel = false,
        disable = { car = true, move = true, combat = true },
        anim = { dict = 'oddjobs@shop_robbery@rob_till', clip = 'loop' }
    })

    TriggerServerEvent('pl_atmrobbery:server:completed', atmCoords)
end

RegisterNetEvent('pl_atmrobbery:StartMinigame', function(entity, atmCoords, atmModel)
    local function handleResult(success)
        if success then
            TriggerServerEvent('pl_atmrobbery:MinigameResult', true, 'hack')
            if Config.MoneyDrop then
                TriggerEvent("pl_atmrobbery:spitCash", entity, atmCoords, atmModel)
            else
                LootATM(atmCoords)
            end
        else
            TriggerServerEvent('pl_atmrobbery:MinigameResult', false)
            TriggerEvent('pl_atmrobbery:notification', Locale('failed_robbery'), 'error')
        end
    end

    local minigame = Config.Hacking.Minigame
    if GetResourceState(minigame) ~= 'started' then
        print("^1[ATM Robbery]^0 Recurso do minigame não encontrado ou não iniciado: " .. minigame)
    end

    if minigame == 'utk_fingerprint' then
        TriggerEvent("utk_fingerprint:Start", 1, 6, 1, function(outcome, _)
            handleResult(outcome == true)
        end)
    elseif minigame == 'ox_lib' then
        local outcome = lib.skillCheck({ 'easy', 'easy', { areaSize = 60, speedMultiplier = 1 }, 'easy' }, { 'w', 'a', 's', 'd' })
        handleResult(outcome == true)
    elseif minigame == 'ps-ui-circle' then
        exports['ps-ui']:Circle(function(success) handleResult(success) end, 4, 60)
    elseif minigame == 'ps-ui-maze' then
        exports['ps-ui']:Maze(function(success) handleResult(success) end, 120)
    elseif minigame == 'ps-ui-scrambler' then
        exports['ps-ui']:Scrambler(function(success) handleResult(success) end, 'numeric', 120, 1)
    else
        TriggerEvent('pl_atmrobbery:notification', 'Configuração de minigame inválida.', 'error')
    end
end)

RegisterNetEvent("pl_atmrobbery:pickupCash")
AddEventHandler("pl_atmrobbery:pickupCash", function(data)
    local entity = data.entity
    local playerPed = PlayerPedId()
    local atmCoords

    if targetResource == 'ox_target' then
        atmCoords = data.args
    elseif targetResource == 'qb-target' then
        atmCoords = data.atmCoords
    end

    Utils.EnsureAnimDict("pickup_object")
    TaskPlayAnim(playerPed, "pickup_object", "pickup_low", 8.0, -8.0, -1, 48, 0, false, false, false)
    Wait(1000)

    if DoesEntityExist(entity) then
        DeleteEntity(entity)
        TriggerServerEvent('pl_atmrobbery:server:completed', atmCoords)
    end

    ClearPedTasks(playerPed)
end)

local function getModelNameFromHash(hash)
    for modelName, _ in pairs(atmModels) do
        if GetHashKey(modelName) == hash then
            return modelName
        end
    end
    return nil
end

RegisterNetEvent("pl_atmrobbery_drill:success")
AddEventHandler("pl_atmrobbery_drill:success", function(atmEntity, atmCoords, atmModel)
    local cashModel = "hei_prop_heist_cash_pile"
    if not Utils.EnsureModel(cashModel) then return end

    local atmForward = GetEntityForwardVector(atmEntity)
    local atmHeading = GetEntityHeading(atmEntity)

    local dropOffset
    local atmModelName = getModelNameFromHash(atmModel)
    if atmModels[atmModelName] then
        dropOffset = atmModels[atmModelName]
    end

    local dropPosition = atmCoords + dropOffset

    for i = 1, Config.Reward.drill_cash_pile do
        Wait(150)
        local cash = CreateObject(GetHashKey(cashModel), dropPosition.x, dropPosition.y, dropPosition.z, true, true, true)
        SetEntityHeading(cash, atmHeading)

        local forceX = atmForward.x * 2
        local forceY = atmForward.y * 2
        local forceZ = 0.2

        if atmModelName ~= "prop_atm_01" then
            SetEntityNoCollisionEntity(cash, atmEntity, false)
            SetEntityNoCollisionEntity(atmEntity, cash, false)
        end

        SetEntityVelocity(cash, forceX, forceY, forceZ)
        AddCashToTarget(cash, atmCoords)
        table.insert(cashObjects, cash)
    end
end)

RegisterNetEvent("pl_atmrobbery:spitCash")
AddEventHandler("pl_atmrobbery:spitCash", function(atmEntity, atmCoords, atmModel)
    local cashModel = "prop_anim_cash_pile_01"
    if not Utils.EnsureModel(cashModel) then return end

    local atmForward = GetEntityForwardVector(atmEntity)
    local atmHeading = GetEntityHeading(atmEntity)

    local dropOffset
    local atmModelName = getModelNameFromHash(atmModel)
    if atmModels[atmModelName] then
        dropOffset = atmModels[atmModelName]
    end

    local dropPosition = atmCoords + dropOffset

    for i = 1, Config.Reward.hack_cash_pile do
        Wait(150)
        local cash = CreateObject(GetHashKey(cashModel), dropPosition.x, dropPosition.y, dropPosition.z, true, true, true)
        SetEntityHeading(cash, atmHeading)

        local forceX = atmForward.x * 2
        local forceY = atmForward.y * 2
        local forceZ = 0.2

        if atmModelName ~= "prop_atm_01" then
            SetEntityNoCollisionEntity(cash, atmEntity, false)
            SetEntityNoCollisionEntity(atmEntity, cash, false)
        end

        SetEntityVelocity(cash, forceX, forceY, forceZ)
        AddCashToTarget(cash, atmCoords)
        table.insert(cashObjects, cash)
    end
end)

local function BuildAtmAttachmentPoint(atmEntity)
    local atmCoords = GetEntityCoords(atmEntity)
    local atmForward = GetEntityForwardVector(atmEntity)
    return atmCoords + (atmForward * 0.5) + vector3(0, 0, 0.5)
end

local function GetVehicleAttachPoint(vehicle)
    return GetOffsetFromEntityInWorldCoords(vehicle, 0, -2.0, 0.5)
end

RegisterNetEvent('pl_atmrobbery:rope:create', function(payload)
    local atmEntity = Utils.NetToEnt(payload.atmNetId)
    local vehicle = Utils.NetToEnt(payload.vehicleNetId)
    if atmEntity == 0 or vehicle == 0 then return end

    if ropeAttachedATMs[payload.atmNetId] and ropeAttachedATMs[payload.atmNetId].rope then
        return
    end

    local atmAttachmentPoint = BuildAtmAttachmentPoint(atmEntity)
    local vehicleBack = GetVehicleAttachPoint(vehicle)
    local ropeLength = #(atmAttachmentPoint - vehicleBack)

    Utils.EnsureRopeTexturesLoaded()

    local rope = AddRope(
        atmAttachmentPoint.x, atmAttachmentPoint.y, atmAttachmentPoint.z,
        0.0, 0.0, 0.0,
        ropeLength,
        0,
        ropeLength,
        ropeLength * 0.8,
        1.0,
        false,
        true,
        false,
        1.0,
        true
    )

    if not DoesRopeExist(rope) then
        Utils.CleanupRopeTexturesIfUnused()
        return
    end

    AttachEntitiesToRope(
        rope, atmEntity, vehicle,
        atmAttachmentPoint.x, atmAttachmentPoint.y, atmAttachmentPoint.z - 0.2,
        vehicleBack.x, vehicleBack.y, vehicleBack.z - 0.2,
        ropeLength, false, false, "", ""
    )

    ropeAttachedATMs[payload.atmNetId] = ropeAttachedATMs[payload.atmNetId] or {}
    local st = ropeAttachedATMs[payload.atmNetId]
    st.atmNetId = payload.atmNetId
    st.vehicleNetId = payload.vehicleNetId
    st.rope = rope
    st.ropeAttached = true
    st.detached = st.detached or false
    st.atmAttachmentPoint = atmAttachmentPoint
    st.vehicleAttachmentPoint = vehicleBack
end)

RegisterNetEvent('pl_atmrobbery:rope:detachATM', function(payload)
    local atmEntity = Utils.NetToEnt(payload.atmNetId)
    local vehicle = Utils.NetToEnt(payload.vehicleNetId)
    if atmEntity == 0 then return end

    Utils.TryRequestControl(atmEntity, 500)

    local atmCoords = GetEntityCoords(atmEntity)

    DetachEntity(atmEntity, true, true)
    SetEntityDynamic(atmEntity, true)
    SetEntityHasGravity(atmEntity, true)
    SetEntityCollision(atmEntity, true, true)

    FreezeEntityPosition(atmEntity, true)
    Wait(250)
    FreezeEntityPosition(atmEntity, false)

    if vehicle ~= 0 then
        local vehicleCoords = GetEntityCoords(vehicle)
        local pullDirection = vehicleCoords - atmCoords
        local pullForce = 8.0

        SetEntityVelocity(atmEntity,
            pullDirection.x * pullForce,
            pullDirection.y * pullForce,
            -5.0
        )
    end

    SetEntityAngularVelocity(atmEntity, 3.0, 3.0, 10.0)

    ropeAttachedATMs[payload.atmNetId] = ropeAttachedATMs[payload.atmNetId] or {}
    ropeAttachedATMs[payload.atmNetId].detached = true
    ropeAttachedATMs[payload.atmNetId].ropeAttached = false

    local atmCoordsNow = GetEntityCoords(atmEntity)
    RemoveGlobalATMOptions(atmEntity)
    AddDetachedATMTarget(atmEntity, atmCoordsNow, GetEntityModel(atmEntity))

    TriggerEvent('pl_atmrobbery:notification', Locale('atm_detached'), 'success')
end)

RegisterNetEvent('pl_atmrobbery:rope:cleanup', function(payload)
    local st = ropeAttachedATMs[payload.atmNetId]
    if st and st.rope and DoesRopeExist(st.rope) then
        DeleteRope(st.rope)
    end
    ropeAttachedATMs[payload.atmNetId] = nil
    Utils.CleanupRopeTexturesIfUnused()
end)

RegisterNetEvent('pl_atmrobbery_rope')
AddEventHandler('pl_atmrobbery_rope', function(data)
    local entity = data.entity
    local atmModel = GetEntityModel(entity)

    if entity and DoesEntityExist(entity) then
        local atmCoords = GetEntityCoords(entity)
        if not IsPedHeadingTowardsPosition(PlayerPedId(), atmCoords.x, atmCoords.y, atmCoords.z, 10.0) then
            TaskTurnPedToFaceCoord(PlayerPedId(), atmCoords.x, atmCoords.y, atmCoords.z, 1500)
        end

        local enoughpolice = lib.callback.await('pl_atmrobbery:checkforpolice', false)
        if enoughpolice then
            local checktime = lib.callback.await('pl_atmrobbery:checktime', false)
            if checktime then
                Wait(1000)
                if Config.Police.notify then
                    DispatchAlert()
                end
                StartRopeAttachment(entity, atmCoords, atmModel)
            else
                TriggerEvent('pl_atmrobbery:notification', Locale('wait_robbery'), 'error')
            end
        else
            TriggerEvent('pl_atmrobbery:notification', Locale('not_enough_police'), 'error')
        end
    end
end)

function StartRopeAttachment(atmEntity, atmCoords, atmModel)
    NetworkRegisterEntityAsNetworked(atmEntity)
    local atmNetId = NetworkGetNetworkIdFromEntity(atmEntity)

    SetEntityDynamic(atmEntity, true)
    SetEntityHasGravity(atmEntity, false)
    SetEntityCollision(atmEntity, true, true)

    if lib.progressBar({
        duration = 3000,
        label = 'Prendendo corda no caixa eletrônico',
        useWhileDead = false,
        canCancel = false,
        disable = { car = true, move = true, combat = true },
        anim = { dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer' }
    }) then
        TriggerServerEvent('pl_atmrobbery:server:removeRope')
    end

    ropeAttachedATMs[atmNetId] = {
        atmNetId = atmNetId,
        initialAtmCoords = atmCoords,
        model = atmModel,
        ropeAttached = false,
        detached = false
    }

    TriggerEvent('pl_atmrobbery:notification', Locale('rope_attached'), 'success')
    AddVehicleRopeTarget(atmNetId, atmEntity)
end

function AddVehicleRopeTarget(atmNetId, atmEntity)
    local vehicles = GetGamePool('CVehicle')
    local atmCoords = GetEntityCoords(atmEntity)
    local nearbyVehicles = {}

    for _, vehicle in pairs(vehicles) do
        if DoesEntityExist(vehicle) then
            local vehicleCoords = GetEntityCoords(vehicle)
            if #(atmCoords - vehicleCoords) <= 20.0 then
                table.insert(nearbyVehicles, vehicle)
            end
        end
    end

    for _, vehicle in pairs(nearbyVehicles) do
        if targetResource == 'ox_target' then
            exports.ox_target:addLocalEntity(vehicle, {
                {
                    event = 'pl_atmrobbery_attach_vehicle_rope',
                    icon = 'fas fa-link',
                    label = Locale('attach_rope_to_vehicle'),
                    args = { atmNetId = atmNetId },
                    distance = 3.0
                }
            })
        elseif targetResource == 'qb-target' then
            exports['qb-target']:AddTargetEntity(vehicle, {
                options = {
                    {
                        type = "client",
                        event = 'pl_atmrobbery_attach_vehicle_rope',
                        icon = 'fas fa-link',
                        label = Locale('attach_rope_to_vehicle'),
                        atmNetId = atmNetId
                    }
                },
                distance = 3.0
            })
        end
    end

    ropeAttachedATMs[atmNetId].targetedVehicles = nearbyVehicles
end

function RemoveVehicleRopeTargetByNetId(atmNetId)
    local st = ropeAttachedATMs[atmNetId]
    if st and st.targetedVehicles then
        for _, vehicle in pairs(st.targetedVehicles) do
            if DoesEntityExist(vehicle) then
                if targetResource == 'ox_target' then
                    exports.ox_target:removeEntity(vehicle)
                elseif targetResource == 'qb-target' then
                    exports['qb-target']:RemoveTargetEntity(vehicle)
                end
            end
        end
        st.targetedVehicles = nil
    end
end

RegisterNetEvent('pl_atmrobbery_attach_vehicle_rope')
AddEventHandler('pl_atmrobbery_attach_vehicle_rope', function(data)
    local vehicle
    local atmNetId

    if targetResource == 'ox_target' then
        vehicle = data.entity
        atmNetId = data.args.atmNetId
    elseif targetResource == 'qb-target' then
        vehicle = data.entity
        atmNetId = data.atmNetId
    end

    if not vehicle or not atmNetId then return end
    if not DoesEntityExist(vehicle) then return end

    local st = ropeAttachedATMs[atmNetId]
    if not st or st.ropeAttached then
        TriggerEvent('pl_atmrobbery:notification', 'A corda já está presa ou o caixa eletrônico não está pronto.', 'error')
        return
    end

    NetworkRegisterEntityAsNetworked(vehicle)
    local vehicleNetId = NetworkGetNetworkIdFromEntity(vehicle)

    st.ropeAttached = true
    st.vehicleNetId = vehicleNetId

    TriggerServerEvent('pl_atmrobbery:rope:requestAttachVehicle', {
        atmNetId = atmNetId,
        vehicleNetId = vehicleNetId
    })

    TriggerEvent('pl_atmrobbery:notification', Locale('rope_vehicle_attached'), 'success')
    RemoveVehicleRopeTargetByNetId(atmNetId)

    MonitorVehicleMovement(atmNetId)
end)

function MonitorVehicleMovement(atmNetId)
    CreateThread(function()
        local st = ropeAttachedATMs[atmNetId]
        if not st or not st.vehicleNetId then return end

        local atmEntity = Utils.NetToEnt(atmNetId)
        local vehicle = Utils.NetToEnt(st.vehicleNetId)
        if atmEntity == 0 or vehicle == 0 then return end

        local initialVehicleCoords = GetEntityCoords(vehicle)
        local initialAtmCoords = GetEntityCoords(atmEntity)

        while ropeAttachedATMs[atmNetId] and ropeAttachedATMs[atmNetId].ropeAttached and not ropeAttachedATMs[atmNetId].detached do
            Wait(100)

            atmEntity = Utils.NetToEnt(atmNetId)
            vehicle = Utils.NetToEnt(st.vehicleNetId)
            if atmEntity == 0 or vehicle == 0 then break end

            local currentVehicleCoords = GetEntityCoords(vehicle)
            local currentAtmCoords = GetEntityCoords(atmEntity)

            local vehicleDistance = #(currentVehicleCoords - initialVehicleCoords)
            local atmDisplacement = #(currentAtmCoords - initialAtmCoords)

            local ropeLength = #(currentVehicleCoords - currentAtmCoords)
            if ropeLength > Config.RopeRobbery.TautRopeLength then
                local vehicleVelocity = GetEntityVelocity(vehicle)
                local dragForce = Config.RopeRobbery.DragForce
                SetEntityVelocity(vehicle, vehicleVelocity.x * (1 - dragForce), vehicleVelocity.y * (1 - dragForce), vehicleVelocity.z)

                if atmDisplacement < 2.0 then
                    local pullDirection = currentVehicleCoords - currentAtmCoords
                    local pullForce = Config.RopeRobbery.ResistanceForce * 0.1
                    local atmVelocity = GetEntityVelocity(atmEntity)
                    SetEntityVelocity(atmEntity,
                        atmVelocity.x + pullDirection.x * pullForce,
                        atmVelocity.y + pullDirection.y * pullForce,
                        atmVelocity.z
                    )
                end
            end

            if vehicleDistance >= Config.RopeRobbery.RequiredDistance or atmDisplacement >= 3.0 then
                TriggerServerEvent('pl_atmrobbery:rope:requestDetach', {
                    atmNetId = atmNetId,
                    vehicleNetId = st.vehicleNetId
                })
                break
            end

            if ropeLength > Config.RopeRobbery.MaxRopeLength then
                TriggerEvent('pl_atmrobbery:notification', Locale('rope_robbery_failed'), 'error')
                break
            end
        end
    end)
end

function RemoveGlobalATMOptions(atmEntity)
    if targetResource == 'ox_target' then
        exports.ox_target:removeEntity(atmEntity)
    elseif targetResource == 'qb-target' then
        exports['qb-target']:RemoveTargetEntity(atmEntity)
    end
end

function AddDetachedATMTarget(atmEntity, atmCoords, atmModel)
    if targetResource == 'ox_target' then
        exports.ox_target:addLocalEntity(atmEntity, {
            {
                event = 'pl_atmrobbery_rob_detached',
                icon = 'fas fa-money-bill-wave',
                label = Locale('rob_detached_atm'),
                args = { entity = atmEntity, coords = atmCoords, model = atmModel }
            }
        })
    elseif targetResource == 'qb-target' then
        exports['qb-target']:AddTargetEntity(atmEntity, {
            options = {
                {
                    type = "client",
                    event = 'pl_atmrobbery_rob_detached',
                    icon = 'fas fa-money-bill-wave',
                    label = Locale('rob_detached_atm'),
                    entity = atmEntity,
                    coords = atmCoords,
                    model = atmModel
                }
            },
            distance = 1.5
        })
    end
end

RegisterNetEvent('pl_atmrobbery_rob_detached')
AddEventHandler('pl_atmrobbery_rob_detached', function(data)
    local entity, atmCoords, atmModel

    if targetResource == 'ox_target' then
        entity = data.args.entity
        atmCoords = data.args.coords
        atmModel = data.args.model
    elseif targetResource == 'qb-target' then
        entity = data.entity
        atmCoords = data.coords
        atmModel = data.model
    end

    if not entity or not DoesEntityExist(entity) then return end

    local atmNetId = NetworkGetNetworkIdFromEntity(entity)
    local st = ropeAttachedATMs[atmNetId]

    if st and st.rope and DoesRopeExist(st.rope) then
        DeleteRope(st.rope)
    end

    ropeAttachedATMs[atmNetId] = nil
    Utils.CleanupRopeTexturesIfUnused()

    if targetResource == 'ox_target' then
        exports.ox_target:removeEntity(entity)
    elseif targetResource == 'qb-target' then
        exports['qb-target']:RemoveTargetEntity(entity)
    end

    local currentAtmCoords = GetEntityCoords(entity)
    local originalAtmCoords = st.initialAtmCoords
    MarkATMAsRobbed(originalAtmCoords)

    TriggerServerEvent('pl_atmrobbery:rope_robbery_completed', currentAtmCoords)

    ropeAttachedATMs[atmNetId] = nil
end)

RegisterNetEvent('pl_atmrobbery:rope:requestCleanup', function()
    ForceDeleteRopes()
end)

RegisterNetEvent('pl_atmrobbery:rope:cleanup', function(payload)
    local st = ropeAttachedATMs[payload.atmNetId]
    if st and st.rope and DoesRopeExist(st.rope) then
        DeleteRope(st.rope)
    end
    ropeAttachedATMs[payload.atmNetId] = nil
    Utils.CleanupRopeTexturesIfUnused()
end)

function DeleteCashObjects()
    for _, cash in pairs(cashObjects) do
        if targetResource == 'ox_target' then
            exports.ox_target:removeEntity(cash)
        elseif targetResource == 'qb-target' then
            exports['qb-target']:RemoveTargetEntity(cash)
        end
        DeleteEntity(cash)
    end
    cashObjects = {}
end

CreateThread(function()
    while true do
        Wait(5000)
        local atmEntities = {}

        for _, model in ipairs(Config.AtmModels) do
            local entities = GetGamePool('CObject')
            for _, entity in pairs(entities) do
                if DoesEntityExist(entity) and GetEntityModel(entity) == GetHashKey(model) then
                    table.insert(atmEntities, entity)
                end
            end
        end

        for _, entity in pairs(atmEntities) do
            if DoesEntityExist(entity) then
                local coords = GetEntityCoords(entity)
                if IsATMAlreadyRobbed(coords) then
                    DeleteEntity(entity)
                end
            end
        end
    end
end)

function ForceDeleteRopes()
    for atmNetId, st in pairs(ropeAttachedATMs) do
        if st.rope and DoesRopeExist(st.rope) then
            DeleteRope(st.rope)
        end
    end
    ropeAttachedATMs = {}
    Utils.CleanupRopeTexturesIfUnused()
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        DeleteCashObjects()
        for atmNetId, st in pairs(ropeAttachedATMs) do
            if st.rope and DoesRopeExist(st.rope) then
                DeleteRope(st.rope)
            end
        end
        ropeAttachedATMs = {}
        Utils.CleanupRopeTexturesIfUnused()
    end
end)
