-- client/zones.lua
-- Uses lib.zones (ox_lib) for zone detection.
-- Uses lib.addKeybind (ox_lib) for E press - no polling loop.

if Config.UseTarget then return end

local currentZone = nil

local Zones = {
    Store        = {},
    ClothingRoom = {},
    PlayerOutfitRoom = {}
}

-- ── Zone action handler ───────────────────────────────────────────────────────

local function triggerCurrentZone()
    if not currentZone then return end
    if currentZone.name == 'clothingRoom' then
        local clothingRoom = Config.ClothingRooms[currentZone.index]
        local outfits = GetPlayerJobOutfits(clothingRoom.job)
        TriggerEvent('illenium-appearance:client:openJobOutfitsMenu', outfits)
    elseif currentZone.name == 'playerOutfitRoom' then
        local outfitRoom = Config.PlayerOutfitRooms[currentZone.index]
        OpenOutfitRoom(outfitRoom)
    elseif currentZone.name == 'clothing' then
        TriggerEvent('illenium-appearance:client:openClothingShopMenu')
    elseif currentZone.name == 'barber' then
        OpenBarberShop()
    elseif currentZone.name == 'tattoo' then
        OpenTattooShop()
    elseif currentZone.name == 'surgeon' then
        OpenSurgeonShop()
    end
end

-- lib.addKeybind replaces the ZonesLoop polling thread.
-- Only fires when currentZone is set (player is inside a zone).
if not Config.UseRadialMenu then
    lib.addKeybind({
        name        = 'illenium_appearance_interact',
        description = 'Interact with clothing shop',
        defaultKey  = 'E',
        onPressed   = triggerCurrentZone,
    })
end

-- ── Zone enter/exit handlers ──────────────────────────────────────────────────

local function onStoreEnter(data)
    local index = data.id
    local store = Config.Stores[index]
    if not store then return end

    local jobName = (store.job and client.job.name) or (store.gang and client.gang.name)
    if jobName ~= (store.job or store.gang) then return end

    currentZone = { name = store.type, index = index }

    if not Config.UseRadialMenu then
        local label = ''
        if store.type == 'clothing' then
            label = string.format(_L('textUI.clothing'), Config.ClothingCost)
        elseif store.type == 'barber' then
            label = string.format(_L('textUI.barber'), Config.BarberCost)
        elseif store.type == 'tattoo' then
            label = string.format(_L('textUI.tattoo'), Config.TattooCost)
        elseif store.type == 'surgeon' then
            label = string.format(_L('textUI.surgeon'), Config.SurgeonCost)
        end
        lib.showTextUI('[E] ' .. label, Config.TextUIOptions)
    end

    Radial.AddOption(currentZone)
end

local function onClothingRoomEnter(data)
    local index = data.id
    local clothingRoom = Config.ClothingRooms[index]
    if not clothingRoom then return end

    local jobName = clothingRoom.job and client.job.name or client.gang.name
    if jobName ~= (clothingRoom.job or clothingRoom.gang) then return end
    if not CheckDuty() and not clothingRoom.gang then return end

    currentZone = { name = 'clothingRoom', index = index }

    if not Config.UseRadialMenu then
        lib.showTextUI('[E] ' .. _L('textUI.clothingRoom'), Config.TextUIOptions)
    end

    Radial.AddOption(currentZone)
end

local function onPlayerOutfitRoomEnter(data)
    local index = data.id
    local playerOutfitRoom = Config.PlayerOutfitRooms[index]
    if not playerOutfitRoom then return end
    if not IsPlayerAllowedForOutfitRoom(playerOutfitRoom) then return end

    currentZone = { name = 'playerOutfitRoom', index = index }

    if not Config.UseRadialMenu then
        lib.showTextUI('[E] ' .. _L('textUI.playerOutfitRoom'), Config.TextUIOptions)
    end

    Radial.AddOption(currentZone)
end

local function onZoneExit()
    currentZone = nil
    Radial.RemoveOption()
    lib.hideTextUI()
end

-- ── Zone setup ────────────────────────────────────────────────────────────────

local function SetupZone(store, index, onEnter, onExit)
    if Config.RCoreTattoosCompatibility and store.type == 'tattoo' then
        return {}
    end

    local opts = {
        debug   = Config.Debug,
        onEnter = function() onEnter({ id = index }) end,
        onExit  = onExit,
    }

    if Config.UseRadialMenu or store.usePoly then
        opts.points = store.points
        return lib.zones.poly(opts)
    end

    opts.coords   = store.coords
    opts.size     = store.size
    opts.rotation = store.rotation
    return lib.zones.box(opts)
end

local function SetupZones()
    for i, v in ipairs(Config.Stores) do
        Zones.Store[#Zones.Store + 1] = SetupZone(v, i, onStoreEnter, onZoneExit)
    end
    for i, v in ipairs(Config.ClothingRooms) do
        Zones.ClothingRoom[#Zones.ClothingRoom + 1] = SetupZone(v, i, onClothingRoomEnter, onZoneExit)
    end
    for i, v in ipairs(Config.PlayerOutfitRooms) do
        Zones.PlayerOutfitRoom[#Zones.PlayerOutfitRoom + 1] = SetupZone(v, i, onPlayerOutfitRoomEnter, onZoneExit)
    end
end

local function RemoveZones()
    for _, z in ipairs(Zones.Store) do if z.remove then z:remove() end end
    for _, z in ipairs(Zones.ClothingRoom) do if z.remove then z:remove() end end
    for _, z in ipairs(Zones.PlayerOutfitRoom) do if z.remove then z:remove() end end
end

CreateThread(SetupZones)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        RemoveZones()
    end
end)

RegisterNetEvent('illenium-appearance:client:OpenClothingRoom', function()
    if not currentZone then return end
    local clothingRoom = Config.ClothingRooms[currentZone.index]
    local outfits = GetPlayerJobOutfits(clothingRoom.job)
    TriggerEvent('illenium-appearance:client:openJobOutfitsMenu', outfits)
end)

RegisterNetEvent('illenium-appearance:client:OpenPlayerOutfitRoom', function()
    if not currentZone then return end
    local outfitRoom = Config.PlayerOutfitRooms[currentZone.index]
    OpenOutfitRoom(outfitRoom)
end)
