-- client/client.lua
local client = client
local reloadSkinTimer = GetGameTimer()

-- Client-side outfit cache so OpenMenu doesn't block on a server round trip
-- every time the player presses E. Invalidated on save/update/delete.
local cachedOutfits = nil

local function getOutfitsCached(cb)
    if cachedOutfits then
        cb(cachedOutfits)
        return
    end
    lib.callback('illenium-appearance:server:getOutfits', false, function(outfits)
        cachedOutfits = outfits
        cb(outfits)
    end)
end

local function invalidateOutfitCache()
    cachedOutfits = nil
end

-- ── Uniform persistence ───────────────────────────────────────────────────────

local function LoadPlayerUniform(reset)
    if reset then
        TriggerServerEvent('illenium-appearance:server:syncUniform', nil)
        return
    end
    lib.callback('illenium-appearance:server:getUniform', false, function(uniformData)
        if not uniformData then return end
        if Config.BossManagedOutfits then
            local result = lib.callback.await('illenium-appearance:server:getManagementOutfits', false, uniformData.type, Framework.GetGender())
            if not result then return end
            for i = 1, #result do
                if result[i].name == uniformData.name then
                    TriggerEvent('illenium-appearance:client:changeOutfit', {
                        type       = uniformData.type,
                        name       = result[i].name,
                        model      = result[i].model,
                        components = result[i].components,
                        props      = result[i].props,
                        disableSave = true,
                    })
                    return
                end
            end
            TriggerServerEvent('illenium-appearance:server:syncUniform', nil)
        else
            if not (uniformData.jobName and Config.Outfits[uniformData.jobName] and Config.Outfits[uniformData.jobName][uniformData.gender]) then
                TriggerServerEvent('illenium-appearance:server:syncUniform', nil)
                return
            end
            local jobOutfits = Config.Outfits[uniformData.jobName][uniformData.gender]
            for i = 1, #jobOutfits do
                if jobOutfits[i].name == uniformData.label then
                    local uniform = jobOutfits[i]
                    uniform.jobName = uniformData.jobName
                    uniform.gender  = uniformData.gender
                    TriggerEvent('illenium-appearance:client:loadJobOutfit', uniform)
                    return
                end
            end
            TriggerServerEvent('illenium-appearance:server:syncUniform', nil)
        end
    end)
end

-- ── Core init ─────────────────────────────────────────────────────────────────

function InitAppearance()
    Framework.UpdatePlayerData()
    lib.callback('illenium-appearance:server:getAppearance', false, function(appearance)
        if not appearance then return end
        -- setPlayerAppearance is the full pipeline:
        -- model change (if needed) + applyAppearanceToPed
        client.setPlayerAppearance(appearance)
        if Config.PersistUniforms then LoadPlayerUniform() end
        RestorePlayerStats()
    end)
    ResetBlips()
    if Config.BossManagedOutfits then Management.AddItems() end
end

-- Hot restart
AddEventHandler('onResourceStart', function(resource)
    if resource == GetCurrentResourceName() then
        InitAppearance()
    end
end)

-- ── Character creation ────────────────────────────────────────────────────────

local function getNewCharacterConfig()
    local config        = GetDefaultConfig()
    config.enableExit   = false
    config.ped          = Config.NewCharacterSections.Ped
    config.headBlend    = Config.NewCharacterSections.HeadBlend
    config.faceFeatures = Config.NewCharacterSections.FaceFeatures
    config.headOverlays = Config.NewCharacterSections.HeadOverlays
    config.components   = Config.NewCharacterSections.Components
    config.props        = Config.NewCharacterSections.Props
    config.tattoos      = not Config.RCoreTattoosCompatibility and Config.NewCharacterSections.Tattoos
    return config
end

function SetInitialClothes(initial)
    client.setPlayerModel(initial.Model)
    local ped = cache.ped
    client.setPedTattoos(ped, {})
    client.setPedComponents(ped, initial.Components)
    client.setPedProps(ped, initial.Props)
    client.setPedHair(ped, initial.Hair, {})
    ClearPedDecorations(ped)
end

function InitializeCharacter(gender, onSubmit, onCancel)
    SetInitialClothes(Config.InitialPlayerClothes[gender])
    TriggerServerEvent('illenium-appearance:server:ChangeRoutingBucket')
    client.startPlayerCustomization(function(appearance)
        if appearance then
            TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
            if onSubmit then onSubmit() end
        elseif onCancel then
            onCancel()
        end
        Framework.CachePed()
        TriggerServerEvent('illenium-appearance:server:ResetRoutingBucket')
    end, getNewCharacterConfig())
end

-- ── Shops ─────────────────────────────────────────────────────────────────────

function OpenShop(config, isPedMenu, shopType)
    -- Open immediately - no pre-check round trip on E press.
    -- On save: server charges and saves atomically in one event.
    -- If player has no money, server rejects and does not save.
    client.startPlayerCustomization(function(appearance)
        if appearance then
            if isPedMenu then
                -- Admin ped menu - save without charging
                TriggerServerEvent('illenium-appearance:server:saveAppearance', appearance)
            else
                -- Normal shop - server charges then saves if successful
                TriggerServerEvent('illenium-appearance:server:chargeAndSave', shopType, appearance)
            end
        else
            lib.notify({ title = _L('cancelled.title'), description = _L('cancelled.description'), type = 'inform', position = Config.NotifyOptions.position })
        end
        Framework.CachePed()
    end, config)
end

local function OpenClothingShop(isPedMenu)
    local config = GetDefaultConfig()
    config.components = true; config.props = true
    if isPedMenu then
        config.ped = true; config.headBlend = true; config.faceFeatures = true
        config.headOverlays = true; config.tattoos = not Config.RCoreTattoosCompatibility and true
    end
    OpenShop(config, isPedMenu, 'clothing')
end

RegisterNetEvent('illenium-appearance:client:openClothingShop', OpenClothingShop)

-- ── Outfit code import/export ─────────────────────────────────────────────────

RegisterNetEvent('illenium-appearance:client:importOutfitCode', function()
    local response = lib.inputDialog(_L('outfits.import.title'), {
        { type = 'input', label = _L('outfits.import.name.label'), placeholder = _L('outfits.import.name.placeholder'), default = _L('outfits.import.name.default'), required = true },
        { type = 'input', label = _L('outfits.import.code.label'), placeholder = 'XXXXXXXXXXXX', required = true },
    })
    if not response then return end
    local outfitName, outfitCode = response[1], response[2]
    if not outfitCode then return end
    Wait(500)
    lib.callback('illenium-appearance:server:importOutfitCode', false, function(success)
        if success then
            lib.notify({ title = _L('outfits.import.success.title'), description = _L('outfits.import.success.description'), type = 'success', position = Config.NotifyOptions.position })
        else
            lib.notify({ title = _L('outfits.import.failure.title'), description = _L('outfits.import.failure.description'), type = 'error', position = Config.NotifyOptions.position })
        end
    end, outfitName, outfitCode)
end)

RegisterNetEvent('illenium-appearance:client:generateOutfitCode', function(id)
    lib.callback('illenium-appearance:server:generateOutfitCode', false, function(code)
        if not code then
            lib.notify({ title = _L('outfits.generate.failure.title'), description = _L('outfits.generate.failure.description'), type = 'error', position = Config.NotifyOptions.position })
            return
        end
        lib.setClipboard(code)
        lib.inputDialog(_L('outfits.generate.success.title'), {
            { type = 'input', label = _L('outfits.generate.success.description'), default = code, disabled = true }
        })
    end, id)
end)

-- ── Outfit save/update/delete ─────────────────────────────────────────────────

RegisterNetEvent('illenium-appearance:client:saveOutfit', function()
    local response = lib.inputDialog(_L('outfits.save.title'), {
        { type = 'input', label = _L('outfits.save.name.label'), placeholder = _L('outfits.save.name.placeholder'), required = true }
    })
    if not response then return end
    local outfitName = response[1]
    if not outfitName then return end
    Wait(500)
    lib.callback('illenium-appearance:server:getOutfits', false, function(outfits)
        for i = 1, #outfits do
            if outfits[i].name:lower() == outfitName:lower() then
                lib.notify({ title = _L('outfits.save.failure.title'), description = _L('outfits.save.failure.description'), type = 'error', position = Config.NotifyOptions.position })
                return
            end
        end
        -- Read ped state directly for components and props
        invalidateOutfitCache()
        TriggerServerEvent('illenium-appearance:server:saveOutfit', outfitName,
            client.getPedModel(cache.ped),
            client.getPedComponents(cache.ped),
            client.getPedProps(cache.ped))
    end)
end)

RegisterNetEvent('illenium-appearance:client:updateOutfit', function(outfitID)
    if not outfitID then return end
    lib.callback('illenium-appearance:server:getOutfits', false, function(outfits)
        local found = false
        for i = 1, #outfits do
            if outfits[i].id == outfitID then found = true; break end
        end
        if not found then
            lib.notify({ title = _L('outfits.update.failure.title'), description = _L('outfits.update.failure.description'), type = 'error', position = Config.NotifyOptions.position })
            return
        end
        invalidateOutfitCache()
        TriggerServerEvent('illenium-appearance:server:updateOutfit', outfitID,
            client.getPedModel(cache.ped),
            client.getPedComponents(cache.ped),
            client.getPedProps(cache.ped))
    end)
end)

-- ── Outfit menus ──────────────────────────────────────────────────────────────

local function RegisterChangeOutfitMenu(id, parent, outfits, mType)
    local menu = { id = id, title = _L('outfits.change.title'), menu = parent, options = {} }
    for i = 1, #outfits do
        menu.options[#menu.options + 1] = {
            title = outfits[i].name, description = outfits[i].model,
            event = 'illenium-appearance:client:changeOutfit',
            args  = { type = mType, name = outfits[i].name, model = outfits[i].model,
                      components = outfits[i].components, props = outfits[i].props,
                      disableSave = mType and true or false },
        }
    end
    table.sort(menu.options, function(a, b) return a.title < b.title end)
    lib.registerContext(menu)
end

local function RegisterUpdateOutfitMenu(id, parent, outfits)
    local menu = { id = id, title = _L('outfits.update.title'), menu = parent, options = {} }
    for i = 1, #outfits do
        menu.options[#menu.options + 1] = { title = outfits[i].name, description = outfits[i].model, event = 'illenium-appearance:client:updateOutfit', args = outfits[i].id }
    end
    table.sort(menu.options, function(a, b) return a.title < b.title end)
    lib.registerContext(menu)
end

local function RegisterGenerateOutfitCodeMenu(id, parent, outfits)
    local menu = { id = id, title = _L('outfits.generate.title'), menu = parent, options = {} }
    for i = 1, #outfits do
        menu.options[#menu.options + 1] = { title = outfits[i].name, description = outfits[i].model, event = 'illenium-appearance:client:generateOutfitCode', args = outfits[i].id }
    end
    lib.registerContext(menu)
end

local function RegisterDeleteOutfitMenu(id, parent, outfits, deleteEvent)
    local menu = { id = id, title = _L('outfits.delete.title'), menu = parent, options = {} }
    table.sort(outfits, function(a, b) return a.name < b.name end)
    for i = 1, #outfits do
        menu.options[#menu.options + 1] = {
            title       = string.format(_L('outfits.delete.item.title'), outfits[i].name),
            description = string.format(_L('outfits.delete.item.description'), outfits[i].model,
                            outfits[i].gender and (' - Gender: ' .. outfits[i].gender) or ''),
            event = deleteEvent, args = outfits[i].id,
        }
    end
    lib.registerContext(menu)
end

RegisterNetEvent('illenium-appearance:client:OutfitManagementMenu', function(args)
    local outfits  = lib.callback.await('illenium-appearance:server:getManagementOutfits', false, args.type, Framework.GetGender())
    local mainID   = 'illenium_appearance_outfit_management_menu'
    local changeID = 'illenium_appearance_change_management_outfit_menu'
    local deleteID = 'illenium_appearance_delete_management_outfit_menu'
    RegisterChangeOutfitMenu(changeID, mainID, outfits, args.type)
    RegisterDeleteOutfitMenu(deleteID, mainID, outfits, 'illenium-appearance:client:DeleteManagementOutfit')
    local menu = {
        id = mainID, title = string.format(_L('outfits.manage.title'), args.type),
        options = {
            { title = _L('outfits.change.title'),   description = string.format(_L('outfits.change.description'), args.type), menu = changeID },
            { title = _L('outfits.save.menuTitle'), description = string.format(_L('outfits.save.menuDescription'), args.type), event = 'illenium-appearance:client:SaveManagementOutfit', args = args.type },
            { title = _L('outfits.delete.title'),   description = string.format(_L('outfits.delete.description'), args.type), menu = deleteID },
        },
    }
    Management.AddBackMenuItem(menu, args)
    lib.registerContext(menu)
    lib.showContext(mainID)
end)

RegisterNetEvent('illenium-appearance:client:SaveManagementOutfit', function(mType)
    local outfitData = {
        Type       = mType,
        Model      = client.getPedModel(cache.ped),
        Components = client.getPedComponents(cache.ped),
        Props      = client.getPedProps(cache.ped),
        JobName    = mType == 'Job' and client.job.name or client.gang.name,
    }
    local rankValues = Framework.GetRankInputValues(mType == 'Job' and 'job' or 'gang')
    local resp = lib.inputDialog(_L('outfits.save.managementTitle'), {
        { label = _L('outfits.save.name.label'),   type = 'input',  required = true },
        { label = _L('outfits.save.gender.label'),  type = 'select',
          options = {{ label = _L('outfits.save.gender.male'), value = 'male' }, { label = _L('outfits.save.gender.female'), value = 'female' }}, default = 'male' },
        { label = _L('outfits.save.rank.label'), type = 'select', options = rankValues, default = '0' },
    })
    if not resp then return end
    outfitData.Name = resp[1]; outfitData.Gender = resp[2]; outfitData.MinRank = tonumber(resp[3]) or 0
    TriggerServerEvent('illenium-appearance:server:saveManagementOutfit', outfitData)
end)

local function RegisterWorkOutfitsListMenu(id, parent, menuData)
    local menu  = { id = id, menu = parent, title = _L('jobOutfits.title'), options = {} }
    local event = Config.BossManagedOutfits and 'illenium-appearance:client:changeOutfit' or 'illenium-appearance:client:loadJobOutfit'
    if menuData then
        for _, v in pairs(menuData) do
            menu.options[#menu.options + 1] = { title = v.name, event = event, args = v }
        end
    end
    lib.registerContext(menu)
end

function OpenMenu(isPedMenu, menuType, menuData)
    local mainID    = 'illenium_appearance_main_menu'
    local changeID  = 'illenium_appearance_change_outfit_menu'
    local updateID  = 'illenium_appearance_update_outfit_menu'
    local deleteID  = 'illenium_appearance_delete_outfit_menu'
    local genCodeID = 'illenium_appearance_generate_outfit_code_menu'
    -- Use cached outfits to avoid blocking the E press on a DB round trip
    local outfits = cachedOutfits or lib.callback.await('illenium-appearance:server:getOutfits', false)
    cachedOutfits = outfits

    RegisterChangeOutfitMenu(changeID, mainID, outfits)
    RegisterUpdateOutfitMenu(updateID, mainID, outfits)
    RegisterDeleteOutfitMenu(deleteID, mainID, outfits, 'illenium-appearance:client:deleteOutfit')
    RegisterGenerateOutfitCodeMenu(genCodeID, mainID, outfits)

    local outfitItems = {
        { title = _L('outfits.change.title'),     description = _L('outfits.change.pDescription'),  menu = changeID },
        { title = _L('outfits.update.title'),     description = _L('outfits.update.description'),   menu = updateID },
        { title = _L('outfits.save.menuTitle'),   description = _L('outfits.save.description'),     event = 'illenium-appearance:client:saveOutfit' },
        { title = _L('outfits.generate.title'),   description = _L('outfits.generate.description'), menu = genCodeID },
        { title = _L('outfits.delete.title'),     description = _L('outfits.delete.mDescription'),  menu = deleteID },
        { title = _L('outfits.import.menuTitle'), description = _L('outfits.import.description'),   event = 'illenium-appearance:client:importOutfitCode' },
    }

    local mainMenu = { id = mainID }
    local items    = {}

    if menuType == 'default' then
        mainMenu.title = _L('clothing.options.title')
        local header = isPedMenu and _L('clothing.titleNoPrice') or string.format(_L('clothing.title'), Config.ClothingCost)
        items[#items + 1] = { title = header, description = _L('clothing.options.description'), event = 'illenium-appearance:client:openClothingShop', args = isPedMenu }
        for i = 1, #outfitItems do items[#items + 1] = outfitItems[i] end
    elseif menuType == 'outfit' then
        mainMenu.title = _L('clothing.outfits.title')
        for i = 1, #outfitItems do items[#items + 1] = outfitItems[i] end
    elseif menuType == 'job-outfit' then
        mainMenu.title = _L('clothing.outfits.title')
        items[#items + 1] = { title = _L('clothing.outfits.civilian.title'), description = _L('clothing.outfits.civilian.description'), event = 'illenium-appearance:client:reloadSkin', args = true }
        local workMenuID = 'illenium_appearance_work_outfits_menu'
        RegisterWorkOutfitsListMenu(workMenuID, mainID, menuData)
        items[#items + 1] = { title = _L('jobOutfits.title'), description = _L('jobOutfits.description'), menu = workMenuID }
    end

    mainMenu.options = items
    lib.registerContext(mainMenu)
    lib.showContext(mainID)
end

RegisterNetEvent('illenium-appearance:client:openClothingShopMenu', function(isPedMenu)
    if type(isPedMenu) == 'table' then isPedMenu = false end
    OpenMenu(isPedMenu, 'default')
end)

RegisterNetEvent('illenium-appearance:client:OpenBarberShop',  OpenBarberShop)
RegisterNetEvent('illenium-appearance:client:OpenTattooShop',  OpenTattooShop)
RegisterNetEvent('illenium-appearance:client:OpenSurgeonShop', OpenSurgeonShop)

RegisterNetEvent('illenium-appearance:client:changeOutfit', function(data)
    if type(data) ~= 'table' then return end
    local pedModel = client.getPedModel(cache.ped)
    if pedModel ~= data.model then
        local appearance = lib.callback.await('illenium-appearance:server:getAppearance', false)
        if not appearance then
            lib.notify({ title = _L('outfits.change.failure.title'), description = _L('outfits.change.failure.description'), type = 'error', position = Config.NotifyOptions.position })
            return
        end
        BackupPlayerStats()
        client.setPlayerAppearance(appearance)
        RestorePlayerStats()
    end
    -- Apply outfit components and props on top of current appearance
    client.setPedComponents(cache.ped, data.components)
    Wait(150)
    client.setPedProps(cache.ped, data.props)
    -- Re-apply hair so tattoos render correctly
    local currentAppearance = client.getPedAppearance(cache.ped)
    if currentAppearance.hair then
        client.setPedHair(cache.ped, currentAppearance.hair, currentAppearance.tattoos)
    end
    if data.disableSave then
        TriggerServerEvent('illenium-appearance:server:syncUniform', { type = data.type, name = data.name })
    else
        -- Read from ped - not from data - for the save
        TriggerServerEvent('illenium-appearance:server:saveAppearance', client.getPedAppearance(cache.ped))
    end
    Framework.CachePed()
end)

RegisterNetEvent('illenium-appearance:client:DeleteManagementOutfit', function(id)
    TriggerServerEvent('illenium-appearance:server:deleteManagementOutfit', id)
    lib.notify({ title = _L('outfits.delete.management.success.title'), description = _L('outfits.delete.management.success.description'), type = 'success', position = Config.NotifyOptions.position })
end)

RegisterNetEvent('illenium-appearance:client:deleteOutfit', function(id)
    invalidateOutfitCache()
    TriggerServerEvent('illenium-appearance:server:deleteOutfit', id)
    lib.notify({ title = _L('outfits.delete.success.title'), description = _L('outfits.delete.success.description'), type = 'success', position = Config.NotifyOptions.position })
end)

RegisterNetEvent('illenium-appearance:client:openJobOutfitsMenu', function(outfitsToShow)
    OpenMenu(nil, 'job-outfit', outfitsToShow)
end)

-- ── reloadSkin ────────────────────────────────────────────────────────────────

local function inCooldown()
    return (GetGameTimer() - reloadSkinTimer) < Config.ReloadSkinCooldown
end

RegisterNetEvent('illenium-appearance:client:reloadSkin', function(bypassChecks)
    if not bypassChecks and (inCooldown() or Framework.CheckPlayerMeta() or cache.vehicle or IsPedFalling(cache.ped)) then
        lib.notify({ title = _L('commands.reloadskin.failure.title'), description = _L('commands.reloadskin.failure.description'), type = 'error', position = Config.NotifyOptions.position })
        return
    end
    reloadSkinTimer = GetGameTimer()
    BackupPlayerStats()
    lib.callback('illenium-appearance:server:getAppearance', false, function(appearance)
        if not appearance then return end
        client.setPlayerAppearance(appearance)
        if Config.PersistUniforms then LoadPlayerUniform(bypassChecks) end
        RestorePlayerStats()
    end)
end)

RegisterNetEvent('illenium-appearance:client:ClearStuckProps', function()
    if inCooldown() or Framework.CheckPlayerMeta() then
        lib.notify({ title = _L('commands.clearstuckprops.failure.title'), description = _L('commands.clearstuckprops.failure.description'), type = 'error', position = Config.NotifyOptions.position })
        return
    end
    reloadSkinTimer = GetGameTimer()
    for _, v in pairs(GetGamePool('CObject')) do
        if IsEntityAttachedToEntity(cache.ped, v) then
            SetEntityAsMissionEntity(v, true, true)
            DeleteObject(v)
            DeleteEntity(v)
        end
    end
end)

-- Allow other files to invalidate the outfit cache
AddEventHandler('illenium-appearance:client:invalidateOutfitCache', invalidateOutfitCache)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
        if Config.BossManagedOutfits then Management.RemoveItems() end
    end
end)
