

-- OX Inventory Shop
local function CreateOXShop()
    exports.ox_inventory:RegisterShop(Config.Shop.id, {
        name = Config.Shop.name,
        inventory = Config.Shop.items,
        locations = { Config.Shop.coords }
    })
    print("^2[Shop] OX Inventory shop created: ^7" .. Config.Shop.name)
end

-- QB Inventory Shop
local function CreateQBShop()
    exports['qb-inventory']:CreateShop({
        name = Config.Shop.id,
        label = Config.Shop.name,
        coords = Config.Shop.coords,
        slots = #Config.Shop.items,
        items = Config.Shop.items
    })
    print("^2[Shop] QB Inventory shop created: ^7" .. Config.Shop.name)
end

local function OpenQBShop()
    exports['qb-inventory']:OpenShop(source, Config.Shop.id)
end

RegisterNetEvent('pl-atmrob:server:OpenShopQB', function()
    OpenQBShop()
end)

-- On Resource Start
AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    if not Config.Shop.Enable then return end

    if GetResourceState('ox_inventory') == 'started' then
        CreateOXShop()
    elseif GetResourceState('qb-inventory') == 'started' then
        CreateQBShop()
    end
end)
