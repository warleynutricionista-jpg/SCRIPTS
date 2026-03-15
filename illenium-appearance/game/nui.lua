-- game/nui.lua
-- NUI callbacks bridge between the UI and the game.
-- CRITICAL RULE: on appearance_save, always read the ped state directly
-- via getPedAppearance(cache.ped) rather than trusting the NUI's internal
-- appearance object. The ped is the ground truth.

local client = client

RegisterNUICallback('appearance_get_locales', function(_, cb)
    cb(Locales[GetConvar('illenium-appearance:locale', 'en')].UI)
end)

RegisterNUICallback('appearance_get_settings', function(_, cb)
    cb({ appearanceSettings = client.getAppearanceSettings() })
end)

RegisterNUICallback('appearance_get_data', function(_, cb)
    -- No Wait() here - Config.AsynchronousLoading handles UI timing
    local appearanceData = client.getAppearance()
    if appearanceData.tattoos then
        client.setPedTattoos(cache.ped, appearanceData.tattoos)
    end
    cb({ config = client.getConfig(), appearanceData = appearanceData })
end)

RegisterNUICallback('appearance_set_camera', function(camera, cb)
    cb(1)
    client.setCamera(camera)
end)

RegisterNUICallback('appearance_turn_around', function(_, cb)
    cb(1)
    client.pedTurn(cache.ped, 180.0)
end)

RegisterNUICallback('appearance_rotate_camera', function(direction, cb)
    cb(1)
    client.rotateCamera(direction)
end)

RegisterNUICallback('appearance_change_model', function(model, cb)
    local playerPed = client.setPlayerModel(model)
    SetEntityHeading(cache.ped, client.getHeading())
    SetEntityInvincible(cache.ped, true)
    TaskStandStill(cache.ped, -1)
    cb({
        appearanceSettings = client.getAppearanceSettings(),
        appearanceData     = client.getPedAppearance(cache.ped),
    })
end)

-- Preview callbacks use legacy natives - NUI sends no collection data
RegisterNUICallback('appearance_change_component', function(component, cb)
    local cid = component.component_id
    if not (client.isPedFreemodeModel(cache.ped) and (cid == 0 or cid == 2)) then
        SetPedComponentVariation(cache.ped, cid, component.drawable or 0, component.texture or 0, 0)
    end
    cb(client.getComponentSettings(cache.ped, cid))
end)

RegisterNUICallback('appearance_change_prop', function(prop, cb)
    if prop.drawable == nil or prop.drawable == -1 then
        ClearPedProp(cache.ped, prop.prop_id)
    else
        SetPedPropIndex(cache.ped, prop.prop_id, prop.drawable, prop.texture or 0, false)
        if GetPedPropIndex(cache.ped, prop.prop_id) == -1 then
            ClearPedProp(cache.ped, prop.prop_id)
        end
    end
    cb(client.getPropSettings(cache.ped, prop.prop_id))
end)

RegisterNUICallback('appearance_change_head_blend', function(headBlend, cb)
    cb(1)
    client.setPedHeadBlend(cache.ped, headBlend)
end)

RegisterNUICallback('appearance_change_face_feature', function(faceFeatures, cb)
    cb(1)
    client.setPedFaceFeatures(cache.ped, faceFeatures)
end)

RegisterNUICallback('appearance_change_head_overlay', function(headOverlays, cb)
    cb(1)
    client.setPedHeadOverlays(cache.ped, headOverlays)
end)

RegisterNUICallback('appearance_change_hair', function(hair, cb)
    client.setPedHair(cache.ped, hair)
    cb(client.getHairSettings(cache.ped))
end)

RegisterNUICallback('appearance_change_eye_color', function(eyeColor, cb)
    cb(1)
    client.setPedEyeColor(cache.ped, eyeColor)
end)

RegisterNUICallback('appearance_apply_tattoo', function(data, cb)
    local paid = not data.tattoo or not Config.ChargePerTattoo
        or lib.callback.await('illenium-appearance:server:payForTattoo', false, data.tattoo)
    if paid then
        client.addPedTattoo(cache.ped, data.updatedTattoos or data)
    end
    cb(paid)
end)

RegisterNUICallback('appearance_preview_tattoo', function(previewTattoo, cb)
    cb(1)
    client.setPreviewTattoo(cache.ped, previewTattoo.data, previewTattoo.tattoo)
end)

RegisterNUICallback('appearance_delete_tattoo', function(data, cb)
    cb(1)
    client.removePedTattoo(cache.ped, data)
end)

RegisterNUICallback('appearance_wear_clothes', function(dataWearClothes, cb)
    cb(1)
    client.wearClothes(dataWearClothes.data, dataWearClothes.key)
end)

RegisterNUICallback('appearance_remove_clothes', function(clothes, cb)
    cb(1)
    client.removeClothes(clothes)
end)

RegisterNUICallback('appearance_save', function(nuiAppearance, cb)
    cb(1)
    -- Apply the dress-up animations first
    client.wearClothes(nuiAppearance, 'head')
    client.wearClothes(nuiAppearance, 'body')
    client.wearClothes(nuiAppearance, 'bottom')
    -- Read the ACTUAL ped state after clothes are applied.
    -- This is the ground truth - not the NUI's internal tracking.
    -- Components and props are replaced with what is physically on the ped.
    -- Hair, face, overlays, tattoos come from the NUI object since those
    -- are not affected by wearClothes and are tracked correctly there.
    local pedState = client.getPedAppearance(cache.ped)
    nuiAppearance.components = pedState.components
    nuiAppearance.props      = pedState.props
    client.exitPlayerCustomization(nuiAppearance)
end)

RegisterNUICallback('appearance_exit', function(_, cb)
    cb(1)
    client.exitPlayerCustomization()
end)

RegisterNUICallback('rotate_left', function(_, cb)
    cb(1)
    client.pedTurn(cache.ped, 10.0)
end)

RegisterNUICallback('rotate_right', function(_, cb)
    cb(1)
    client.pedTurn(cache.ped, -10.0)
end)

RegisterNUICallback('get_theme_configuration', function(_, cb)
    cb(Config.Theme)
end)
