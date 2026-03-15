-- game/util.lua
-- All ped appearance get/set functions.
-- SAVE path: reads ped state -> stores collection name + local index (DLC-stable)
-- LOAD path: if collection present uses SetPedCollectionComponentVariation,
--            otherwise falls back to SetPedComponentVariation (legacy saves)
-- PREVIEW path (NUI callbacks): uses legacy natives since NUI sends no collection data

local PED_TATTOOS     = {}
local pedModelsByHash = {}
local hashesComputed  = false

-- ── Helpers ───────────────────────────────────────────────────────────────────

local function tofloat(v)
    return (v or 0) + 0.0
end

local function round(n, dec)
    return tonumber(string.format('%.' .. (dec or 0) .. 'f', n))
end

local function isPedFreemodeModel(ped)
    local m = GetEntityModel(ped)
    return m == `mp_m_freemode_01` or m == `mp_f_freemode_01`
end

local function computeHashes()
    for i = 1, #Config.Peds.pedConfig do
        local peds = Config.Peds.pedConfig[i].peds
        for j = 1, #peds do
            pedModelsByHash[joaat(peds[j])] = peds[j]
        end
    end
    hashesComputed = true
end

local function getPedModel(ped)
    if not hashesComputed then computeHashes() end
    return pedModelsByHash[GetEntityModel(ped)]
end

local function getPedDecorationType()
    local m = GetEntityModel(cache.ped)
    if m == `mp_m_freemode_01` then return 'male' end
    if m == `mp_f_freemode_01` then return 'female' end
    return IsPedMale(cache.ped) and 'male' or 'female'
end

-- ── Collection helpers ────────────────────────────────────────────────────────
-- Returns nil collection for base-game items (empty string name from native)
-- so legacy SetPedComponentVariation path is used on load.

local function getComponentCollection(ped, cid, drawable)
    local name  = GetPedCollectionNameFromDrawable(ped, cid, drawable)
    local index = GetPedCollectionLocalIndexFromDrawable(ped, cid, drawable)
    if not name or #name == 0 or not index or index < 0 then
        return nil, drawable
    end
    return name, index
end

local function getPropCollection(ped, pid, drawable)
    local name  = GetPedCollectionNameFromProp(ped, pid, drawable)
    local index = GetPedCollectionLocalIndexFromProp(ped, pid, drawable)
    if not name or #name == 0 or not index or index < 0 then
        return nil, drawable
    end
    return name, index
end

-- ── GET: read current ped state ───────────────────────────────────────────────

local function getPedComponents(ped)
    local out = {}
    for i = 1, #constants.PED_COMPONENTS_IDS do
        local cid  = constants.PED_COMPONENTS_IDS[i]
        local draw = GetPedDrawableVariation(ped, cid)
        local tex  = GetPedTextureVariation(ped, cid)
        local col, localDraw = getComponentCollection(ped, cid, draw)
        out[i] = {
            component_id  = cid,
            drawable      = draw,
            texture       = tex,
            collection    = col,       -- nil for base-game items
            localDrawable = localDraw,
        }
    end
    return out
end

local function getPedProps(ped)
    local out = {}
    for i = 1, #constants.PED_PROPS_IDS do
        local pid  = constants.PED_PROPS_IDS[i]
        local draw = GetPedPropIndex(ped, pid)
        local tex  = GetPedPropTextureIndex(ped, pid)
        local col, localDraw = nil, draw
        if draw ~= -1 then
            col, localDraw = getPropCollection(ped, pid, draw)
        end
        out[i] = {
            prop_id       = pid,
            drawable      = draw,     -- -1 means no prop
            texture       = tex,
            collection    = col,      -- nil for base-game items or no prop
            localDrawable = localDraw,
        }
    end
    return out
end

local function getPedHeadBlend(ped)
    local sf, ss, st, kf, ks, kt, sm, km, tm =
        Citizen.InvokeNative(0x2746BD9D88C5C5D0, ped,
            Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0),
            Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0),
            Citizen.PointerValueIntInitialized(0), Citizen.PointerValueIntInitialized(0),
            Citizen.PointerValueFloatInitialized(0), Citizen.PointerValueFloatInitialized(0),
            Citizen.PointerValueFloatInitialized(0))
    local function clamp(v)
        return round(math.min(math.max(tonumber(v) or 0, 0.0), 1.0), 1)
    end
    return {
        shapeFirst = sf or 0, shapeSecond = ss or 0, shapeThird = st or 0,
        skinFirst  = kf or 0, skinSecond  = ks or 0, skinThird  = kt or 0,
        shapeMix   = clamp(sm), skinMix = clamp(km), thirdMix = clamp(tm),
    }
end

local function getPedFaceFeatures(ped)
    local out = {}
    for i = 1, #constants.FACE_FEATURES do
        out[constants.FACE_FEATURES[i]] = round(GetPedFaceFeature(ped, i - 1), 1)
    end
    return out
end

local function getPedHeadOverlays(ped)
    local out = {}
    for i = 1, #constants.HEAD_OVERLAYS do
        local name = constants.HEAD_OVERLAYS[i]
        local _, value, _, c1, c2, opacity = GetPedHeadOverlayData(ped, i - 1)
        if value == 255 then value = 0; opacity = 0
        else opacity = round(opacity, 1) end
        out[name] = { style = value, opacity = opacity, color = c1, secondColor = c2 }
    end
    return out
end

local function getPedHair(ped)
    return {
        style     = GetPedDrawableVariation(ped, 2),
        color     = GetPedHairColor(ped),
        highlight = GetPedHairHighlightColor(ped),
        texture   = GetPedTextureVariation(ped, 2),
    }
end

local function getPedAppearance(ped)
    local eyeColor = GetPedEyeColor(ped)
    return {
        model        = getPedModel(ped) or 'mp_m_freemode_01',
        headBlend    = getPedHeadBlend(ped),
        faceFeatures = getPedFaceFeatures(ped),
        headOverlays = getPedHeadOverlays(ped),
        components   = getPedComponents(ped),
        props        = getPedProps(ped),
        hair         = getPedHair(ped),
        tattoos      = PED_TATTOOS,
        eyeColor     = eyeColor < #constants.EYE_COLORS and eyeColor or 0,
    }
end

-- ── Model change ──────────────────────────────────────────────────────────────

local function setPlayerModel(model)
    if type(model) == 'string' then model = joaat(model) end
    if not IsModelInCdimage(model) then return end
    if GetEntityModel(cache.ped) == model then
        SetModelAsNoLongerNeeded(model)
        return
    end
    RequestModel(model)
    local deadline = GetGameTimer() + 10000
    while not HasModelLoaded(model) do
        if GetGameTimer() > deadline then return end
        Wait(10)
    end
    local prev = cache.ped
    SetPlayerModel(cache.playerId, model)
    -- Wait for cache.ped to update
    local waited = 0
    while cache.ped == prev and waited < 100 do
        Wait(10); waited = waited + 1
    end
    SetModelAsNoLongerNeeded(model)
    if isPedFreemodeModel(cache.ped) then
        SetPedDefaultComponentVariation(cache.ped)
        if model == `mp_m_freemode_01` then
            SetPedHeadBlendData(cache.ped, 0, 0, 0, 0, 0, 0, 0, 0, 0, false)
        elseif model == `mp_f_freemode_01` then
            SetPedHeadBlendData(cache.ped, 45, 21, 0, 20, 15, 0, 0.3, 0.1, 0, false)
        end
    end
    PED_TATTOOS = {}
end

-- ── SET: apply to ped ─────────────────────────────────────────────────────────

local function setPedHeadBlend(ped, hb)
    if not hb or not isPedFreemodeModel(ped) then return end
    SetPedHeadBlendData(ped,
        hb.shapeFirst or 0, hb.shapeSecond or 0, hb.shapeThird or 0,
        hb.skinFirst  or 0, hb.skinSecond  or 0, hb.skinThird  or 0,
        tofloat(hb.shapeMix), tofloat(hb.skinMix), tofloat(hb.thirdMix), false)
end

local function setPedFaceFeatures(ped, ff)
    if not ff then return end
    for i, name in ipairs(constants.FACE_FEATURES) do
        if type(ff[name]) == 'number' then
            SetPedFaceFeature(ped, i - 1, tofloat(ff[name]))
        end
    end
end

local function setPedHeadOverlays(ped, overlays)
    if not overlays then return end
    for i, name in ipairs(constants.HEAD_OVERLAYS) do
        local o = overlays[name]
        if o then
            SetPedHeadOverlay(ped, i - 1, o.style or 0, tofloat(o.opacity or 0))
            if o.color then
                local ct = (name == 'blush' or name == 'lipstick' or name == 'makeUp') and 2 or 1
                SetPedHeadOverlayColor(ped, i - 1, ct, o.color, o.secondColor or 0)
            end
        end
    end
end

local function applyFade(ped, style)
    local dec = constants.HAIR_DECORATIONS[getPedDecorationType()][style]
    if dec then AddPedDecorationFromHashes(ped, dec[1], dec[2]) end
end

local function setTattoos(ped, tattoos, hairStyle)
    local isMale = getPedDecorationType() == 'male'
    ClearPedDecorations(ped)
    if Config.AutomaticFade then
        if tattoos then tattoos['ZONE_HAIR'] = {} end
        if PED_TATTOOS then PED_TATTOOS['ZONE_HAIR'] = {} end
        applyFade(ped, hairStyle or GetPedDrawableVariation(ped, 2))
    end
    if not tattoos then return end
    for _, zone in pairs(tattoos) do
        for i = 1, #zone do
            local t    = zone[i]
            local hash = isMale and t.hashMale or t.hashFemale
            if type(hash) == 'string' and #hash > 0 then
                local reps = math.max(1, math.floor((t.opacity or 0.1) * 10))
                for _ = 1, reps do
                    AddPedDecorationFromHashes(ped, joaat(t.collection), joaat(hash))
                end
            end
        end
    end
    if Config.RCoreTattoosCompatibility then
        TriggerEvent('rcore_tattoos:applyOwnedTattoos')
    end
end

local function setPedHair(ped, hair, tattoos)
    if not hair then return end
    SetPedComponentVariation(ped, 2, hair.style or 0, hair.texture or 0, 0)
    SetPedHairColor(ped, hair.color or 0, hair.highlight or 0)
    if isPedFreemodeModel(ped) then
        setTattoos(ped, tattoos or PED_TATTOOS, hair.style)
    end
end

local function setPedEyeColor(ped, eyeColor)
    if type(eyeColor) == 'number' then SetPedEyeColor(ped, eyeColor) end
end

-- Component: use collection native if collection is a valid non-empty string,
-- otherwise fall back to global-index legacy native.
local function setPedComponent(ped, component)
    if not component then return end
    local cid = component.component_id
    -- Skip head (0) and hair (2) for freemode - managed separately
    if isPedFreemodeModel(ped) and (cid == 0 or cid == 2) then return end
    if type(component.collection) == 'string' and #component.collection > 0 then
        SetPedCollectionComponentVariation(ped, cid,
            component.collection, component.localDrawable, component.texture or 0, 0)
    else
        SetPedComponentVariation(ped, cid, component.drawable or 0, component.texture or 0, 0)
    end
end

local function setPedComponents(ped, components)
    if not components then return end
    for _, v in pairs(components) do setPedComponent(ped, v) end
end

-- Prop: same collection vs legacy logic.
-- If GTA rejects the prop (returns -1 after set), clear it.
local function setPedProp(ped, prop)
    if not prop then return end
    if prop.drawable == nil or prop.drawable == -1 then
        ClearPedProp(ped, prop.prop_id)
        return
    end
    if type(prop.collection) == 'string' and #prop.collection > 0 then
        SetPedCollectionPropIndex(ped, prop.prop_id,
            prop.collection, prop.localDrawable, prop.texture or 0, false)
    else
        SetPedPropIndex(ped, prop.prop_id, prop.drawable, prop.texture or 0, false)
    end
    -- Verify it applied - GTA silently rejects out-of-range indexes
    if GetPedPropIndex(ped, prop.prop_id) == -1 then
        ClearPedProp(ped, prop.prop_id)
    end
end

local function setPedProps(ped, props)
    if not props then return end
    for _, v in pairs(props) do setPedProp(ped, v) end
end

local function setPedTattoos(ped, tattoos)
    PED_TATTOOS = tattoos or {}
    setTattoos(ped, PED_TATTOOS)
end

local function getPedTattoos()
    return PED_TATTOOS
end

local function addPedTattoo(ped, tattoos)
    setTattoos(ped, tattoos)
end

local function removePedTattoo(ped, tattoos)
    setTattoos(ped, tattoos)
end

local function setPreviewTattoo(ped, tattoos, tattoo)
    local isMale = getPedDecorationType() == 'male'
    local hash   = isMale and tattoo.hashMale or tattoo.hashFemale
    ClearPedDecorations(ped)
    if type(hash) == 'string' and #hash > 0 then
        AddPedDecorationFromHashes(ped, joaat(tattoo.collection), joaat(hash))
    end
    if not tattoos then return end
    for _, zone in pairs(tattoos) do
        for i = 1, #zone do
            local t = zone[i]
            if t.name ~= tattoo.name then
                local tHash = isMale and t.hashMale or t.hashFemale
                if type(tHash) == 'string' and #tHash > 0 then
                    local reps = math.max(1, math.floor((t.opacity or 0.1) * 10))
                    for _ = 1, reps do
                        AddPedDecorationFromHashes(ped, joaat(t.collection), joaat(tHash))
                    end
                end
            end
        end
    end
    if Config.AutomaticFade then applyFade(ped, GetPedDrawableVariation(ped, 2)) end
end

-- Full appearance apply.
-- Components first, then Wait(150) before props so GTA settles ped state.
-- Hair applies tattoos at the correct style index.
local function applyAppearanceToPed(ped, appearance)
    if not appearance then return end
    if appearance.headBlend    then setPedHeadBlend(ped, appearance.headBlend) end
    if appearance.faceFeatures then setPedFaceFeatures(ped, appearance.faceFeatures) end
    if appearance.headOverlays then setPedHeadOverlays(ped, appearance.headOverlays) end
    if appearance.tattoos      then setPedTattoos(ped, appearance.tattoos) end
    -- Hair also re-applies tattoos at the correct hair style
    if appearance.hair         then setPedHair(ped, appearance.hair, appearance.tattoos) end
    setPedComponents(ped, appearance.components)
    if appearance.eyeColor     then setPedEyeColor(ped, appearance.eyeColor) end
    -- Wait for GTA to settle component/model state before applying props
    Wait(150)
    setPedProps(ped, appearance.props)
end

-- Full player appearance: change model if needed, then apply appearance.
local function setPlayerAppearance(appearance)
    if not appearance then return end
    setPlayerModel(appearance.model)
    applyAppearanceToPed(cache.ped, appearance)
end

-- ── Exports & client table ────────────────────────────────────────────────────

exports('getPedModel',           getPedModel)
exports('getPedComponents',      getPedComponents)
exports('getPedProps',           getPedProps)
exports('getPedHeadBlend',       getPedHeadBlend)
exports('getPedFaceFeatures',    getPedFaceFeatures)
exports('getPedHeadOverlays',    getPedHeadOverlays)
exports('getPedHair',            getPedHair)
exports('getPedAppearance',      getPedAppearance)
exports('setPlayerModel',        setPlayerModel)
exports('setPedHeadBlend',       setPedHeadBlend)
exports('setPedFaceFeatures',    setPedFaceFeatures)
exports('setPedHeadOverlays',    setPedHeadOverlays)
exports('setPedHair',            setPedHair)
exports('setPedEyeColor',        setPedEyeColor)
exports('setPedComponent',       setPedComponent)
exports('setPedComponents',      setPedComponents)
exports('setPedProp',            setPedProp)
exports('setPedProps',           setPedProps)
exports('setPlayerAppearance',   setPlayerAppearance)
exports('setPedAppearance',      applyAppearanceToPed)
exports('setPedTattoos',         setPedTattoos)

client = {
    -- Getters
    getPedAppearance     = getPedAppearance,
    getPedComponents     = getPedComponents,
    getPedProps          = getPedProps,
    getPedModel          = getPedModel,
    getPedTattoos        = getPedTattoos,
    getPedDecorationType = getPedDecorationType,
    isPedFreemodeModel   = isPedFreemodeModel,
    -- Setters
    setPlayerModel       = setPlayerModel,
    setPlayerAppearance  = setPlayerAppearance,
    setPedAppearance     = applyAppearanceToPed,
    setPedHeadBlend      = setPedHeadBlend,
    setPedFaceFeatures   = setPedFaceFeatures,
    setPedHeadOverlays   = setPedHeadOverlays,
    setPedHair           = setPedHair,
    setPedEyeColor       = setPedEyeColor,
    setPedComponent      = setPedComponent,
    setPedComponents     = setPedComponents,
    setPedProp           = setPedProp,
    setPedProps          = setPedProps,
    setPedTattoos        = setPedTattoos,
    addPedTattoo         = addPedTattoo,
    removePedTattoo      = removePedTattoo,
    setPreviewTattoo     = setPreviewTattoo,
    -- Helpers
    getComponentSettings = nil, -- set by customization.lua
    getPropSettings      = nil, -- set by customization.lua
    getHairSettings      = nil, -- set by customization.lua
    getAppearanceSettings= nil, -- set by customization.lua
    getAppearance        = nil, -- set by customization.lua
    getHeading           = nil, -- set by customization.lua
    getConfig            = nil, -- set by customization.lua
    startPlayerCustomization = nil, -- set by customization.lua
    exitPlayerCustomization  = nil, -- set by customization.lua
    setCamera            = nil, -- set by customization.lua
    rotateCamera         = nil, -- set by customization.lua
    pedTurn              = nil, -- set by customization.lua
    wearClothes          = nil, -- set by customization.lua
    removeClothes        = nil, -- set by customization.lua
}
