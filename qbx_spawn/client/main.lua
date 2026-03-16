local config = require 'config.client'

-- tenta obter o core (qbx_core primeiro, se não, qb-core) sem explodir se não existir
local QBCore
do
    local ok1, obj1 = pcall(function()
        return exports['qbx_core']:GetCoreObject()
    end)
    if ok1 and obj1 then
        QBCore = obj1
    else
        local ok2, obj2 = pcall(function()
            return exports['qb-core']:GetCoreObject()
        end)
        if ok2 and obj2 then
            QBCore = obj2
        end
    end
end

-- fallback seguro pra locale(), porque em outros recursos vimos erro "attempt to call a nil value (global 'locale')"
local function L(key)
    if locale then
        local ok, out = pcall(locale, key)
        if ok and out ~= nil then
            return out
        end
    end
    return key -- se não tiver locale, usa a própria chave
end

-- helper pra pegar metadata "inside" do player (pra spawnar dentro da casa se for o caso)
local function getInsideMeta()
    if QBCore and QBCore.Functions and QBCore.Functions.GetPlayerData then
        local pdata = QBCore.Functions.GetPlayerData()
        if pdata and pdata.metadata and pdata.metadata["inside"] then
            return pdata.metadata["inside"]
        end
    end
    -- fallback seguro caso QBCore ainda não esteja pronto
    return {}
end

local previewCam, scaleform, buttonsScaleform
local currentButtonID, previousButtonID = 1, 1

local arrowStart = {
    vec2(-3150.25, -1427.83),
    vec2(4173.08, 1338.72),
    vec2(-2390.23, 6262.24)
}

local spawns

-------------------------------------------------
-- CAMERA
-------------------------------------------------
local function setupCamera()
    previewCam = CreateCamWithParams(
        'DEFAULT_SCRIPTED_CAMERA',
        -24.77, -590.35, 90.8,   -- pos
        -2.0, 0.0, 160.0,        -- rot
        45.0,                    -- fov
        false, 2
    )

    SetCamActive(previewCam, true)
    RenderScriptCams(true, false, 1, true, true)
end

local function stopCamera()
    if previewCam and DoesCamExist(previewCam) then
        SetCamActive(previewCam, false)
        DestroyCam(previewCam, true)
    end

    RenderScriptCams(false, false, 1, true, true)

    if scaleform then
        BeginScaleformMovieMethod(scaleform, 'CLEANUP')
        EndScaleformMovieMethod()
    end
end

-------------------------------------------------
-- PLAYER SETUP (pré-spawn)
-------------------------------------------------
local function managePlayer()
    -- coloca o jogador numa "sala de espera" acima do mapa
    SetEntityCoords(cache.ped, -21.58, -583.76, 86.31, false, false, false, false)
    FreezeEntityPosition(cache.ped, true)

    SetTimeout(500, function()
        DoScreenFadeIn(5000)
    end)
end

-------------------------------------------------
-- SCALEFORM: MAPA DE SPAWN
-------------------------------------------------
local function createSpawnArea()
    -- desenha círculos das áreas no scaleform
    for i = 1, #spawns do
        local spawn = spawns[i]
        if spawn.coords then
            BeginScaleformMovieMethod(scaleform, 'ADD_AREA')
            ScaleformMovieMethodAddParamInt(i)
            ScaleformMovieMethodAddParamFloat(spawn.coords.x)
            ScaleformMovieMethodAddParamFloat(spawn.coords.y)
            ScaleformMovieMethodAddParamFloat(500.0)
            ScaleformMovieMethodAddParamInt(255)
            ScaleformMovieMethodAddParamInt(0)
            ScaleformMovieMethodAddParamInt(0)
            ScaleformMovieMethodAddParamInt(100)
            EndScaleformMovieMethod()
        end
    end
end

local function setupInstructionalButton(index, control, text)
    BeginScaleformMovieMethod(buttonsScaleform, 'SET_DATA_SLOT')

    ScaleformMovieMethodAddParamInt(index)
    ScaleformMovieMethodAddParamPlayerNameString(GetControlInstructionalButton(2, control, true))

    BeginTextCommandScaleformString('STRING')
    AddTextComponentSubstringKeyboardDisplay(text)
    EndTextCommandScaleformString()

    EndScaleformMovieMethod()
end

local function setupInstructionalScaleform()
    DrawScaleformMovieFullscreen(buttonsScaleform, 255, 255, 255, 0, 0)

    BeginScaleformMovieMethod(buttonsScaleform, 'CLEAR_ALL')
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(buttonsScaleform, 'SET_CLEAR_SPACE')
    ScaleformMovieMethodAddParamInt(200)
    EndScaleformMovieMethod()

    -- 191 = ENTER/SELECT, 187 = seta baixo, 188 = seta cima
    setupInstructionalButton(0, 191, 'Submit')
    setupInstructionalButton(1, 187, 'Down')
    setupInstructionalButton(2, 188, 'Up')

    BeginScaleformMovieMethod(buttonsScaleform, 'DRAW_INSTRUCTIONAL_BUTTONS')
    EndScaleformMovieMethod()
end

local function setupMap()
    scaleform = lib.requestScaleformMovie('HEISTMAP_MP', 5000) or 0
    buttonsScaleform = lib.requestScaleformMovie('INSTRUCTIONAL_BUTTONS', 5000) or 0

    CreateThread(function()
        setupInstructionalScaleform()
        createSpawnArea()

        -- loop de renderização do mapa/legendinhas enquanto a câmera estiver ativa
        while previewCam and DoesCamExist(previewCam) do
            DrawScaleformMovie_3d(
                scaleform,
                -24.86, -593.38, 91.8, -- draw origin
                -180.0, -180.0, -20.0, -- rot
                0.0, 2.0, 0.0,
                3.815, 2.27, 1.0, 2
            )

            -- esconder hud vanilla
            HideHudComponentThisFrame(6)
            HideHudComponentThisFrame(7)
            HideHudComponentThisFrame(9)

            -- desenha os botões "Submit / Up / Down"
            DrawScaleformMovieFullscreen(buttonsScaleform, 255, 255, 255, 255, 0)

            Wait(0)
        end

        SetScaleformMovieAsNoLongerNeeded(scaleform)
        SetScaleformMovieAsNoLongerNeeded(buttonsScaleform)
    end)
end

local function scaleformDetails(index)
    local spawn = spawns[index]
    if not spawn or not spawn.coords then return end

    -- highlight da área escolhida
    BeginScaleformMovieMethod(scaleform, 'ADD_HIGHLIGHT')
    ScaleformMovieMethodAddParamInt(index)

    ScaleformMovieMethodAddParamFloat(spawn.coords.x)
    ScaleformMovieMethodAddParamFloat(spawn.coords.y)
    ScaleformMovieMethodAddParamFloat(500.0)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(255)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(100)
    EndScaleformMovieMethod()

    -- muda cor da área atual pra verde
    BeginScaleformMovieMethod(scaleform, 'COLOUR_AREA')
    ScaleformMovieMethodAddParamInt(index)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(255)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(0)
    EndScaleformMovieMethod()

    -- texto/nome da área no mapa
    BeginScaleformMovieMethod(scaleform, 'ADD_TEXT')
    ScaleformMovieMethodAddParamInt(index)
    ScaleformMovieMethodAddParamTextureNameString(L(spawn.label))
    ScaleformMovieMethodAddParamFloat(spawn.coords.x)
    ScaleformMovieMethodAddParamFloat(spawn.coords.y - 500.0)
    ScaleformMovieMethodAddParamFloat(25.0 - math.random(0, 50))
    ScaleformMovieMethodAddParamInt(24)
    ScaleformMovieMethodAddParamInt(100)
    ScaleformMovieMethodAddParamInt(255)
    ScaleformMovieMethodAddParamBool(true)
    EndScaleformMovieMethod()

    -- seta (flecha) apontando pra área
    local randomCoords = arrowStart[math.random(#arrowStart)]
    BeginScaleformMovieMethod(scaleform, 'ADD_ARROW')
    ScaleformMovieMethodAddParamInt(index)
    ScaleformMovieMethodAddParamFloat(randomCoords.x)
    ScaleformMovieMethodAddParamFloat(randomCoords.y)
    ScaleformMovieMethodAddParamFloat(spawn.coords.x)
    ScaleformMovieMethodAddParamFloat(spawn.coords.y)
    ScaleformMovieMethodAddParamFloat(math.random(30, 80))
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(scaleform, 'COLOUR_ARROW')
    ScaleformMovieMethodAddParamInt(index)
    ScaleformMovieMethodAddParamInt(255)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(100)
    EndScaleformMovieMethod()
end

local function updateScaleform()
    if previousButtonID == currentButtonID then return end

    -- limpa tudo dos antigos
    for i = 1, #spawns do
        BeginScaleformMovieMethod(scaleform, 'REMOVE_HIGHLIGHT')
        ScaleformMovieMethodAddParamInt(i)
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'REMOVE_TEXT')
        ScaleformMovieMethodAddParamInt(i)
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'REMOVE_ARROW')
        ScaleformMovieMethodAddParamInt(i)
        EndScaleformMovieMethod()

        BeginScaleformMovieMethod(scaleform, 'COLOUR_AREA')
        ScaleformMovieMethodAddParamInt(i)
        ScaleformMovieMethodAddParamInt(255)
        ScaleformMovieMethodAddParamInt(0)
        ScaleformMovieMethodAddParamInt(0)
        ScaleformMovieMethodAddParamInt(100)
        EndScaleformMovieMethod()
    end

    -- aplica destaque no atual
    scaleformDetails(currentButtonID)
end

-------------------------------------------------
-- INPUT / CONFIRMAR LOCAL DE SPAWN
-------------------------------------------------
local function inputHandler()
    -- Se o jogador JÁ spawnou antes, só joga ele pra última posição e sai
    if lib.callback.await('qbx_spawn:server:alreadySpawned') then
        local spawnData = {
            coords = lib.callback.await('qbx_spawn:server:getLastLocation')
        }

        FreezeEntityPosition(cache.ped, false)
        SetEntityCoords(cache.ped, spawnData.coords.x, spawnData.coords.y, spawnData.coords.z, false, false, false, false)
        SetEntityHeading(cache.ped, spawnData.coords.w or 0.0)

        -- compat com qb-core/qbx_core: esses eventos ainda são chamados com "QBCore"
        TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
        TriggerEvent('QBCore:Client:OnPlayerLoaded')

        if config.clouds then
            Wait(5000)
            SwitchInPlayer(PlayerPedId())

            if not spawns[currentButtonID].first_time then
                lib.requestAnimDict('random@peyote@generic', 15000)
                Wait(1500)
                TaskPlayAnim(
                    cache.ped,
                    'random@peyote@generic',
                    'wakeup',
                    8.0, 8.0,
                    -1,
                    0,
                    0,
                    false,
                    false,
                    false
                )
            end
        else
            DoScreenFadeIn(1000)
        end
    else
        -- caso seja primeira vez ou o menu realmente esteja aberto
        while previewCam and DoesCamExist(previewCam) do
            -- seta ↑
            if IsControlJustReleased(0, 188) then
                previousButtonID = currentButtonID
                currentButtonID = currentButtonID - 1
                if currentButtonID < 1 then
                    currentButtonID = #spawns
                end
                updateScaleform()

            -- seta ↓
            elseif IsControlJustReleased(0, 187) then
                previousButtonID = currentButtonID
                currentButtonID = currentButtonID + 1
                if currentButtonID > #spawns then
                    currentButtonID = 1
                end
                updateScaleform()

            -- ENTER / CONFIRM
            elseif IsControlJustReleased(0, 191) then
                if not config.clouds then
                    DoScreenFadeOut(1000)
                    while not IsScreenFadedOut() do
                        Wait(0)
                    end
                else
                    SwitchOutPlayer(PlayerPedId(), 0, 1)
                    Wait(250)
                    stopCamera()
                end

                FreezeEntityPosition(cache.ped, false)

                local chosen = spawns[currentButtonID]
                local coords = chosen.coords

                -- aplica posição base
                SetEntityCoords(cache.ped, coords.x, coords.y, coords.z, false, false, false, false)
                SetEntityHeading(cache.ped, coords.w or 0.0)

                -- casas / propriedades
                if chosen.propertyId then
                    TriggerServerEvent('ps-housing:server:enterProperty', tostring(chosen.propertyId), 'spawn')

                -- "última localização" com interior salvo
                elseif coords == lib.callback.await('qbx_spawn:server:getLastLocation') then
                    local insideMeta = getInsideMeta()
                    if insideMeta and insideMeta.property_id ~= nil then
                        local property_id = insideMeta.property_id
                        TriggerServerEvent('ps-housing:server:enterProperty', tostring(property_id))
                    end
                else
                    -- fallback normal já foi feito (coords acima), repõe heading só pra garantir
                    SetEntityCoords(cache.ped, coords.x, coords.y, coords.z, false, false, false, false)
                    SetEntityHeading(cache.ped, coords.w or 0.0)
                end

                -- notificar core que player carregou
                TriggerServerEvent('QBCore:Server:OnPlayerLoaded')
                TriggerEvent('QBCore:Client:OnPlayerLoaded')

                if config.clouds then
                    Wait(5000)
                    SwitchInPlayer(PlayerPedId())

                    if not chosen.first_time then
                        lib.requestAnimDict('random@peyote@generic', 15000)
                        Wait(1500)
                        TaskPlayAnim(
                            cache.ped,
                            'random@peyote@generic',
                            'wakeup',
                            8.0, 8.0,
                            -1,
                            0,
                            0,
                            false,
                            false,
                            false
                        )
                    end
                else
                    DoScreenFadeIn(1000)
                end

                break
            end

            Wait(0)
        end
    end

    -- finalização comum
    if not config.clouds then
        stopCamera()
    end

    TriggerServerEvent('qbx_spawn:server:spawn')
end

-------------------------------------------------
-- EVENTO PRINCIPAL: abrir tela de spawn
-------------------------------------------------
AddEventHandler('qb-spawn:client:setupSpawns', function(cData, new, apps)
    spawns = {}

    if new then
        -- novo personagem: pega "apps" (provavelmente apartamentos iniciais)
        if type(apps) == 'table' then
            for k, v in pairs(apps) do
                if v and v.door then
                    spawns[#spawns+1] = {
                        first_time = true,
                        key        = k,
                        label      = v.label,
                        coords     = vector3(v.door.x, v.door.y, v.door.z)
                        -- note: sem heading aqui, se quiser add v.door.w
                    }
                end
            end
        end

        if #spawns == 0 then
            spawns[#spawns+1] = {
                first_time = true,
                label = 'last_location',
                coords = lib.callback.await('qbx_spawn:server:getLastLocation')
            }

            for i = 1, #config.spawns do
                local spawn = config.spawns[i]
                spawns[#spawns+1] = {
                    first_time = true,
                    label = spawn.label,
                    coords = spawn.coords,
                    propertyId = spawn.propertyId
                }
            end
        end
    else
        -- opção "última localização"
        spawns[#spawns+1] = {
            label  = 'last_location',
            coords = lib.callback.await('qbx_spawn:server:getLastLocation')
        }

        -- spawns padrão do config
        for i = 1, #config.spawns do
            spawns[#spawns+1] = config.spawns[i]
        end

        -- casas do jogador
        local houses = lib.callback.await('qbx_spawn:server:getHouses')
        for i = 1, #houses do
            spawns[#spawns+1] = houses[i]
        end
    end

    Wait(400)

    managePlayer()
    setupCamera()
    setupMap()

    Wait(400)

    scaleformDetails(currentButtonID)
    inputHandler()
end)
