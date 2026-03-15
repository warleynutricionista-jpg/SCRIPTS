-- client/outfits.lua

local function typeof(var)
    local t = type(var)
    if t ~= 'table' and t ~= 'userdata' then return t end
    local m = getmetatable(var)
    if m and m._NAME then return m._NAME end
    return t
end

function LoadJobOutfit(oData)
    local ped  = cache.ped
    local data = oData.outfitData
    if typeof(data) ~= 'table' then
        data = json.decode(data)
    end

    if data['pants']   then SetPedComponentVariation(ped, 4,  data['pants'].item,    data['pants'].texture,    0) end
    if data['arms']    then SetPedComponentVariation(ped, 3,  data['arms'].item,     data['arms'].texture,     0) end
    if data['t-shirt'] then SetPedComponentVariation(ped, 8,  data['t-shirt'].item,  data['t-shirt'].texture,  0) end
    if data['vest']    then SetPedComponentVariation(ped, 9,  data['vest'].item,     data['vest'].texture,     0) end
    if data['torso2']  then SetPedComponentVariation(ped, 11, data['torso2'].item,   data['torso2'].texture,   0) end
    if data['shoes']   then SetPedComponentVariation(ped, 6,  data['shoes'].item,    data['shoes'].texture,    0) end
    if data['decals']  then SetPedComponentVariation(ped, 10, data['decals'].item,   data['decals'].texture,   0) end
    if data['mask']    then SetPedComponentVariation(ped, 1,  data['mask'].item,     data['mask'].texture,     0) end
    if data['bag']     then SetPedComponentVariation(ped, 5,  data['bag'].item,      data['bag'].texture,      0) end

    local tracker    = Config.TrackerClothingOptions
    local hasTracker = Config.PreventTrackerRemoval and Framework.HasTracker()
    if data['accessory'] then
        if hasTracker then
            SetPedComponentVariation(ped, 7, tracker.drawable, tracker.texture, 0)
        else
            SetPedComponentVariation(ped, 7, data['accessory'].item, data['accessory'].texture, 0)
        end
    elseif hasTracker then
        SetPedComponentVariation(ped, 7, tracker.drawable, tracker.texture, 0)
    end

    if data['hat'] then
        if data['hat'].item ~= -1 and data['hat'].item ~= 0 then
            SetPedPropIndex(ped, 0, data['hat'].item, data['hat'].texture, true)
        else
            ClearPedProp(ped, 0)
        end
    end
    if data['glass'] then
        if data['glass'].item ~= -1 and data['glass'].item ~= 0 then
            SetPedPropIndex(ped, 1, data['glass'].item, data['glass'].texture, true)
        else
            ClearPedProp(ped, 1)
        end
    end
    if data['ear'] then
        if data['ear'].item ~= -1 and data['ear'].item ~= 0 then
            SetPedPropIndex(ped, 2, data['ear'].item, data['ear'].texture, true)
        else
            ClearPedProp(ped, 2)
        end
    end

    local count = 0
    for _ in pairs(data) do count = count + 1 end
    if Config.PersistUniforms and count > 1 then
        TriggerServerEvent('illenium-appearance:server:syncUniform', {
            jobName = oData.jobName,
            gender  = oData.gender,
            label   = oData.name,
        })
    end
end

RegisterNetEvent('illenium-appearance:client:loadJobOutfit', LoadJobOutfit)

RegisterNetEvent('illenium-appearance:client:openOutfitMenu', function()
    OpenMenu(nil, 'outfit')
end)

RegisterNetEvent('illenium-appearance:client:outfitsCommand', function(isJob)
    local outfits = GetPlayerJobOutfits(isJob)
    TriggerEvent('illenium-appearance:client:openJobOutfitsMenu', outfits)
end)
