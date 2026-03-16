-- qbx_spawn/server/main.lua
-- Versão revisada com melhores práticas de segurança/estabilidade.

local config = require 'config.server'

-- Ponto(s) inicial(is) padrão caso o jogador não tenha casa / nada salvo
-- ps_starters é usado como fallback pra spawn inicial manual
local ps_starters = {
    -- ["Nome do Apartamento Inicial"] = vector3(x, y, z)
    ["Motel"] = vector3(325.14, -229.54, 54.21),
}

--------------------------------------------------------------------------------
-- Helpers internos
--------------------------------------------------------------------------------

---Espera até conseguir os dados do player carregado pelo qbx_core
---@param src number
---@return table player
local function getPlayerSafe(src)
    local player = exports.qbx_core:GetPlayer(src)
    local attempts = 0

    -- às vezes o spawn roda milissegundos antes do qbx_core terminar load
    -- tentamos por ~2s e depois desistimos pra não travar o servidor
    while not player and attempts < 20 do
        Wait(100)
        attempts += 1
        player = exports.qbx_core:GetPlayer(src)
    end

    return player
end

---Faz uma query e garante pelo menos uma tabela vazia, pra não quebrar ipairs/#len
---@param citizenId string
---@return table houses
local function fetchOwnedHouses(citizenId)
    if not citizenId then return {} end

    local ok, result = pcall(function()
        return MySQL.query.await(
            'SELECT * FROM properties WHERE owner_citizenid = ?',
            { citizenId }
        )
    end)

    if not ok then
        -- Falha na query (ex.: tabela 'properties' não existe ainda)
        -- Evita crash no spawn
        return {}
    end

    -- MySQL.query.await pode devolver nil se nada encontrado
    return result or {}
end

---Tenta extrair coords da porta principal da casa usando ps-housing
---Sempre retorna vector3 ou nil
---@param propertyId any
---@return vector3|nil coords
local function getHouseDoorCoords(propertyId)
    if not propertyId then return nil end

    local ok, doorData = pcall(function()
        -- getMainDoor(propertyId, unitId, minimal)
        -- unitId = 1 (padrão)
        -- minimal=true pra tentar vir só o essencial e evitar payload gigante
        return exports['ps-housing']:getMainDoor(propertyId, 1, true)
    end)

    if not ok or not doorData then
        return nil
    end

    -- ps-housing varia MUITO de server pra server.
    -- Vamos tentar achar coords no que existir:
    local d = doorData
    local c =
        d.objCoords or
        d.coords or
        (d.doors and d.doors[1] and (d.doors[1].coords or d.doors[1].objCoords))

    -- Garante que o retorno seja vector3 de verdade
    if c and c.x and c.y and c.z then
        return vector3(c.x, c.y, c.z)
    end

    return nil
end

---Retorna a última posição salva do jogador no banco.
---Se der erro, devolve nil pra UI lidar.
---@param citizenId string
---@return vector3|nil lastPos, any insidePropertyId
local function fetchLastLocationAndInterior(citizenId, metadata)
    if not citizenId then return nil, nil end

    -- Busca posição salva na tabela players
    local ok, row = pcall(function()
        return MySQL.single.await(
            'SELECT position FROM players WHERE citizenid = ?',
            { citizenId }
        )
    end)

    local lastPos = nil

    if ok and row and row.position then
        -- position no Qbox geralmente é JSON {"x":..,"y":..,"z":..,"heading":..}
        local okDecode, stored = pcall(function()
            return json.decode(row.position)
        end)

        if okDecode and stored and stored.x and stored.y and stored.z then
            lastPos = vector3(stored.x, stored.y, stored.z)
        end
    end

    -- Se o player estava "dentro de uma casa" no último logout, qbx_core salva em metadata.inside
    -- Vamos tentar retornar esse propertyId também, se existir.
    local insidePropertyId = nil
    if metadata
        and metadata.inside
        and metadata.inside.propertyId
    then
        insidePropertyId = metadata.inside.propertyId
    end

    return lastPos, insidePropertyId
end

--------------------------------------------------------------------------------
-- Callbacks expostos pro client
--------------------------------------------------------------------------------

-- Última posição do jogador (pra "Spawnar na Última Localização" no menu)
lib.callback.register('qbx_spawn:server:getLastLocation', function(source)
    local player = getPlayerSafe(source)
    if not player then
        -- se por algum motivo o player não carregou ainda, devolve nil
        return nil, nil
    end

    local citizenId = player.PlayerData.citizenid
    local metadata  = player.PlayerData.metadata or {}

    local lastPos, insidePropertyId = fetchLastLocationAndInterior(citizenId, metadata)
    return lastPos, insidePropertyId
end)

-- Todas as casas que o jogador possui (pra opção "Spawnar na Casa X")
lib.callback.register('qbx_spawn:server:getHouses', function(source)
    local player = getPlayerSafe(source)
    if not player then
        return {}
    end

    local citizenId = player.PlayerData.citizenid
    local ownedHouses = fetchOwnedHouses(citizenId)

    if #ownedHouses == 0 then
        return {}
    end

    local houseData = {}

    for i = 1, #ownedHouses do
        local house = ownedHouses[i]

        -- alguns sistemas salvam apartamentos em outra tabela/flag
        -- se existir house.apartment == true, você pode pular se não quer listar
        if not house.apartment then
            local coords = getHouseDoorCoords(house.property_id)

            -- rotulo bonitinho (rua / label / etc.)
            local label = house.street or house.label or ('Imóvel #' .. tostring(house.id or i))

            if coords then
                houseData[#houseData + 1] = {
                    label  = label,
                    coords = coords
                }
            end
        end
    end

    return houseData
end)

-- O client pergunta "já spawnou nessa sessão?"
-- Isso impede abrir o menu de spawn toda vez que você revive/respawna ou dá /fix
lib.callback.register('qbx_spawn:server:alreadySpawned', function(source)
    -- Se não for pra selecionar spawn no primeiro login, sempre responde "já spawnou"
    if not config.selectOnFirstSpawn then
        return false
    end

    local player = getPlayerSafe(source)
    if not player then
        return false
    end

    local citizenId = player.PlayerData.citizenid
    local spawnedPlayers = GlobalState.SpawnedPlayers or {}

    return spawnedPlayers[citizenId] == true
end)

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------

-- Marca o jogador como "spawnado" pra essa sessão.
-- Chamado depois que ele escolhe onde quer nascer no menu.
RegisterNetEvent('qbx_spawn:server:spawn', function()
    if not config.selectOnFirstSpawn then
        return
    end

    local src = source
    local player = getPlayerSafe(src)
    if not player then
        return
    end

    local citizenId = player.PlayerData.citizenid

    -- Garante tabela
    local spawnedPlayers = GlobalState.SpawnedPlayers or {}

    spawnedPlayers[citizenId] = true

    -- true = replicado (todo mundo no servidor enxerga esse GlobalState)
    GlobalState:set('SpawnedPlayers', spawnedPlayers, true)
end)
