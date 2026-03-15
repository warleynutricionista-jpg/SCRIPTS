-- server/main.lua
-- Server-authoritative. Client sends intent only, server decides what to do.

local outfitCache  = {} -- [citizenid] = array of outfit rows
local uniformCache = {} -- [citizenid] = uniform data or nil

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function isValidSource(src)
    return src and src > 0 and GetPlayerName(src) ~= nil
end

local function getCitizenID(src)
    if not isValidSource(src) then return nil end
    return Framework.GetPlayerID(src)
end

local function getMoneyForShop(shopType)
    local costs = {
        clothing = Config.ClothingCost,
        barber   = Config.BarberCost,
        tattoo   = Config.TattooCost,
        surgeon  = Config.SurgeonCost,
    }
    return costs[shopType] or 0
end

local function loadOutfitsForPlayer(citizenID)
    outfitCache[citizenID] = {}
    local rows = Database.PlayerOutfits.GetAllByCitizenID(citizenID)
    if not rows then return end
    for i = 1, #rows do
        local row = rows[i]
        local ok1, components = pcall(json.decode, row.components or '[]')
        local ok2, props      = pcall(json.decode, row.props or '[]')
        if ok1 and ok2 then
            outfitCache[citizenID][#outfitCache[citizenID] + 1] = {
                id = row.id, name = row.outfitname, model = row.model,
                components = components, props = props,
            }
        end
    end
end

local function getPlayerOutfits(citizenID)
    if outfitCache[citizenID] == nil then loadOutfitsForPlayer(citizenID) end
    return outfitCache[citizenID]
end

local function ownsOutfit(citizenID, outfitID)
    for _, v in ipairs(getPlayerOutfits(citizenID)) do
        if v.id == outfitID then return true end
    end
    return false
end

local function isValidAppearance(appearance)
    return type(appearance) == 'table'
        and type(appearance.model) == 'string'
        and #appearance.model > 0
end

-- ── Callbacks ─────────────────────────────────────────────────────────────────

lib.callback.register('illenium-appearance:server:getAppearance', function(source, model)
    local src = source
    if not isValidSource(src) then return nil end
    local citizenID = getCitizenID(src)
    if not citizenID then return nil end
    return Framework.GetAppearance(citizenID, model)
end)

lib.callback.register('illenium-appearance:server:payForTattoo', function(source, tattoo)
    local src = source
    if not isValidSource(src) then return false end
    if type(tattoo) ~= 'table' then return false end
    local cost = Config.TattooCost
    if Config.ChargePerTattoo and type(tattoo.cost) == 'number' and tattoo.cost > 0 then
        cost = tattoo.cost
    end
    if Framework.RemoveMoney(src, 'cash', cost) then
        lib.notify(src, { title = _L('purchase.tattoo.success.title'), description = string.format(_L('purchase.tattoo.success.description'), tostring(tattoo.label), cost), type = 'success', position = Config.NotifyOptions.position })
        return true
    end
    lib.notify(src, { title = _L('purchase.tattoo.failure.title'), description = _L('purchase.tattoo.failure.description'), type = 'error', position = Config.NotifyOptions.position })
    return false
end)

lib.callback.register('illenium-appearance:server:getOutfits', function(source)
    local src = source
    if not isValidSource(src) then return {} end
    local citizenID = getCitizenID(src)
    if not citizenID then return {} end
    return getPlayerOutfits(citizenID)
end)

lib.callback.register('illenium-appearance:server:getManagementOutfits', function(source, mType, gender)
    local src = source
    if not isValidSource(src) then return {} end
    if mType ~= 'Job' and mType ~= 'Gang' then return {} end
    local job   = mType == 'Gang' and Framework.GetGang(src) or Framework.GetJob(src)
    local grade = tonumber(job.grade.level) or 0
    local rows  = Database.ManagementOutfits.GetAllByJob(mType, job.name, gender)
    local result = {}
    for i = 1, #rows do
        local row = rows[i]
        if grade >= (row.minrank or 0) then
            local ok1, comps = pcall(json.decode, row.components or '[]')
            local ok2, props = pcall(json.decode, row.props or '[]')
            if ok1 and ok2 then
                result[#result + 1] = {
                    id = row.id, name = row.name, model = row.model,
                    gender = row.gender, components = comps, props = props,
                }
            end
        end
    end
    return result
end)

lib.callback.register('illenium-appearance:server:getUniform', function(source)
    local citizenID = getCitizenID(source)
    if not citizenID then return nil end
    return uniformCache[citizenID]
end)

lib.callback.register('illenium-appearance:server:generateOutfitCode', function(source, outfitID)
    local src = source
    if not isValidSource(src) then return nil end
    local citizenID = getCitizenID(src)
    if not citizenID then return nil end
    if not ownsOutfit(citizenID, outfitID) then return nil end
    local existing = Database.PlayerOutfitCodes.GetByOutfitID(outfitID)
    if existing then return existing.code end
    local code, exists
    repeat
        code   = GenerateNanoID(Config.OutfitCodeLength)
        exists = Database.PlayerOutfitCodes.GetByCode(code)
    until not exists
    local id = Database.PlayerOutfitCodes.Add(outfitID, code)
    if not id then return nil end
    return code
end)

lib.callback.register('illenium-appearance:server:importOutfitCode', function(source, outfitName, outfitCode)
    local src = source
    if not isValidSource(src) then return nil end
    if type(outfitName) ~= 'string' or #outfitName == 0 or #outfitName > 64 then return nil end
    if type(outfitCode) ~= 'string' or #outfitCode == 0 then return nil end
    local citizenID = getCitizenID(src)
    if not citizenID then return nil end
    local codeRow = Database.PlayerOutfitCodes.GetByCode(outfitCode)
    if not codeRow then return nil end
    local sourceOutfit = Database.PlayerOutfits.GetByID(codeRow.outfitid)
    if not sourceOutfit then return nil end
    if sourceOutfit.citizenid == citizenID then return nil end
    if Database.PlayerOutfits.GetByOutfit(outfitName, citizenID) then return nil end
    local ok1, components = pcall(json.decode, sourceOutfit.components or '[]')
    local ok2, props      = pcall(json.decode, sourceOutfit.props or '[]')
    if not ok1 or not ok2 then return nil end
    local id = Database.PlayerOutfits.Add(citizenID, outfitName, sourceOutfit.model, sourceOutfit.components, sourceOutfit.props)
    if not id then return nil end
    local outfits = getPlayerOutfits(citizenID)
    outfits[#outfits + 1] = { id = id, name = outfitName, model = sourceOutfit.model, components = components, props = props }
    return true
end)

-- ── Net Events ────────────────────────────────────────────────────────────────

RegisterNetEvent('illenium-appearance:server:saveAppearance', function(appearance)
    local src = source
    if not isValidSource(src) then return end
    local citizenID = getCitizenID(src)
    if not citizenID then return end
    if not isValidAppearance(appearance) then return end
    Framework.SaveAppearance(appearance, citizenID)
end)

-- Atomic charge + save: charge first, only save if successful.
-- Prevents players with no money from saving appearance for free.
RegisterNetEvent('illenium-appearance:server:chargeAndSave', function(shopType, appearance)
    local src = source
    if not isValidSource(src) then return end
    local citizenID = getCitizenID(src)
    if not citizenID then return end
    if not isValidAppearance(appearance) then return end
    local money = getMoneyForShop(shopType)
    if not Framework.RemoveMoney(src, 'cash', money) then
        lib.notify(src, { title = _L('purchase.store.failure.title'), description = _L('purchase.store.failure.description'), type = 'error', position = Config.NotifyOptions.position })
        return
    end
    lib.notify(src, { title = _L('purchase.store.success.title'), description = string.format(_L('purchase.store.success.description'), money, shopType), type = 'success', position = Config.NotifyOptions.position })
    Framework.SaveAppearance(appearance, citizenID)
end)

RegisterNetEvent('illenium-appearance:server:saveOutfit', function(name, model, components, props)
    local src = source
    if not isValidSource(src) then return end
    if type(name) ~= 'string' or #name == 0 or #name > 64 then return end
    if type(model) ~= 'string' or #model == 0 then return end
    if type(components) ~= 'table' or type(props) ~= 'table' then return end
    local citizenID = getCitizenID(src)
    if not citizenID then return end
    local id = Database.PlayerOutfits.Add(citizenID, name, model, json.encode(components), json.encode(props))
    if not id then return end
    local outfits = getPlayerOutfits(citizenID)
    outfits[#outfits + 1] = { id = id, name = name, model = model, components = components, props = props }
    lib.notify(src, { title = _L('outfits.save.success.title'), description = string.format(_L('outfits.save.success.description'), name), type = 'success', position = Config.NotifyOptions.position })
end)

RegisterNetEvent('illenium-appearance:server:updateOutfit', function(id, model, components, props)
    local src = source
    if not isValidSource(src) then return end
    if type(model) ~= 'string' or #model == 0 then return end
    if type(components) ~= 'table' or type(props) ~= 'table' then return end
    local citizenID = getCitizenID(src)
    if not citizenID then return end
    if not ownsOutfit(citizenID, id) then return end
    Database.PlayerOutfits.Update(id, model, json.encode(components), json.encode(props))
    local outfitName = ''
    for _, outfit in ipairs(outfitCache[citizenID] or {}) do
        if outfit.id == id then
            outfit.model = model; outfit.components = components; outfit.props = props
            outfitName = outfit.name; break
        end
    end
    lib.notify(src, { title = _L('outfits.update.success.title'), description = string.format(_L('outfits.update.success.description'), outfitName), type = 'success', position = Config.NotifyOptions.position })
end)

RegisterNetEvent('illenium-appearance:server:deleteOutfit', function(id)
    local src = source
    if not isValidSource(src) then return end
    if type(id) ~= 'number' then return end
    local citizenID = getCitizenID(src)
    if not citizenID then return end
    if not ownsOutfit(citizenID, id) then return end
    Database.PlayerOutfitCodes.DeleteByOutfitID(id)
    Database.PlayerOutfits.DeleteByID(id)
    for k, v in ipairs(outfitCache[citizenID] or {}) do
        if v.id == id then table.remove(outfitCache[citizenID], k); break end
    end
end)

RegisterNetEvent('illenium-appearance:server:saveManagementOutfit', function(outfitData)
    local src = source
    if not isValidSource(src) then return end
    if type(outfitData) ~= 'table' then return end
    if outfitData.Type ~= 'Job' and outfitData.Type ~= 'Gang' then return end
    local job = outfitData.Type == 'Gang' and Framework.GetGang(src) or Framework.GetJob(src)
    if job.name ~= outfitData.JobName then return end
    Database.ManagementOutfits.Add(outfitData)
    lib.notify(src, { title = _L('outfits.save.success.title'), description = string.format(_L('outfits.save.success.description'), tostring(outfitData.Name)), type = 'success', position = Config.NotifyOptions.position })
end)

RegisterNetEvent('illenium-appearance:server:deleteManagementOutfit', function(id)
    local src = source
    if not isValidSource(src) then return end
    if type(id) ~= 'number' then return end
    Database.ManagementOutfits.DeleteByID(id)
end)

RegisterNetEvent('illenium-appearance:server:syncUniform', function(uniform)
    local src = source
    if not isValidSource(src) then return end
    if uniform ~= nil and type(uniform) ~= 'table' then return end
    local citizenID = getCitizenID(src)
    if not citizenID then return end
    uniformCache[citizenID] = uniform
end)

RegisterNetEvent('illenium-appearance:server:resetOutfitCache', function()
    local src = source
    local citizenID = getCitizenID(src)
    if citizenID then outfitCache[citizenID] = nil end
end)

RegisterNetEvent('illenium-appearance:server:ChangeRoutingBucket', function()
    local src = source
    if not isValidSource(src) then return end
    SetPlayerRoutingBucket(src, src)
end)

RegisterNetEvent('illenium-appearance:server:ResetRoutingBucket', function()
    local src = source
    if not isValidSource(src) then return end
    SetPlayerRoutingBucket(src, 0)
end)

AddEventHandler('playerDropped', function()
    local src    = source
    local citizenID = Framework.GetPlayerID(src)
    if citizenID then
        outfitCache[citizenID]  = nil
        uniformCache[citizenID] = nil
    end
end)

-- ── Commands ──────────────────────────────────────────────────────────────────

if Config.EnablePedMenu then
    lib.addCommand('pedmenu', {
        help       = _L('commands.pedmenu.title'),
        params     = {{ name = 'playerID', type = 'number', help = 'Target player server id', optional = true }},
        restricted = Config.PedMenuGroup,
    }, function(source, args)
        local target = source
        if args.playerID and getCitizenID(args.playerID) then
            target = args.playerID
        elseif args.playerID then
            lib.notify(source, { title = _L('commands.pedmenu.failure.title'), description = _L('commands.pedmenu.failure.description'), type = 'error', position = Config.NotifyOptions.position })
            return
        end
        TriggerClientEvent('illenium-appearance:client:openClothingShopMenu', target, true)
    end)
end

if Config.EnableJobOutfitsCommand then
    lib.addCommand('joboutfits',  { help = _L('commands.joboutfits.title')  }, function(source) TriggerClientEvent('illenium-appearance:client:outfitsCommand', source, true) end)
    lib.addCommand('gangoutfits', { help = _L('commands.gangoutfits.title') }, function(source) TriggerClientEvent('illenium-appearance:client:outfitsCommand', source) end)
end

lib.addCommand('reloadskin',      { help = _L('commands.reloadskin.title')      }, function(source) TriggerClientEvent('illenium-appearance:client:reloadSkin', source) end)
lib.addCommand('clearstuckprops', { help = _L('commands.clearstuckprops.title') }, function(source) TriggerClientEvent('illenium-appearance:client:ClearStuckProps', source) end)

lib.versionCheck('iLLeniumStudios/illenium-appearance')
