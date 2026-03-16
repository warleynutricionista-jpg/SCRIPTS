local renderingScriptCam = ""
local openUI = false
local SellectMode = ""
local SellectItem = ""
local colorstyp = ""
local oldcolor = 1
local oldcolorextra = 1
local oldplate = 1
local oldneon = 1
local oldwtype = 1
local vehicleMods = {}
local oldtint = 1
local oldsmoke = 1
local SellectItemPrice = 0
local typer = "main"

Citizen.CreateThread(function()
    AddMechanicsBlips()
	while true do
		local sleep = 500
		local playercoord = GetEntityCoords(PlayerPedId())
		for k,v in pairs(Config.Mechanics) do
            local dst = #(playercoord - vector3(v.Coords.x,v.Coords.y,v.Coords.z))
                if dst < Config.Distance and IsPedSittingInAnyVehicle(PlayerPedId()) and returnlogin() and checkJob(k) and not openUI then
                    sleep = 1
                    DrawText3D(playercoord.x, playercoord.y, playercoord.z, Config.Langs.OpenMenu)
                    DrawMarker(36, v.Coords.x,v.Coords.y,v.Coords.z ,0,0,0,0,0,1.0,1.0,1.0,1.0,255, 255, 255,200,0,0,0,1)
                    if IsControlJustPressed(0, 38) then 
                        OpenMenu()
                    end
                end
            end
		Citizen.Wait(sleep)
	end
end)

local customCamMain = ""
local customCamSec = ""
function OpenMenu()
    local playerPed = PlayerPedId()
    local playerVeh = GetVehiclePedIsIn(playerPed, false)
    local vehPos = GetEntityCoords(playerVeh)
    local camPos = GetOffsetFromEntityInWorldCoords(playerVeh, -2.0, 5.0, 3.0)
    local headingToObject = GetHeadingFromVector_2d(vehPos.x - camPos.x, vehPos.y - camPos.y)
    SellectItemPrice = 0
    customCamMain = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, -35.0, 0.0, headingToObject, GetGameplayCamFov(), false, 2)
    customCamSec = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, -35.0, 0.0, headingToObject, GetGameplayCamFov(), false, 2)
    SetCamActive(customCamMain, true)
    RenderScriptCams(true, true, 500, true, true)
    FreezeEntityPosition(playerVeh ,true)
    SetVehicleOnGroundProperly(playerVeh)
    DisplayHud(false)
    renderingScriptCam = true
    SetNuiFocus(1, 1)
    oldcolor = table.pack(GetVehicleColours(playerVeh))
    oldcolorextra = table.pack(GetVehicleExtraColours(playerVeh))
    FillVehicleModStatus(playerVeh)
    oldwtype = GetVehicleWheelType(playerVeh)
    oldsmoke = table.pack(GetVehicleTyreSmokeColor(playerVeh))
    oldneon = table.pack(GetVehicleNeonLightsColour(playerVeh))
    oldplate = GetVehicleNumberPlateTextIndex(playerVeh)
    oldtint = GetVehicleWindowTint(playerVeh)
    detailed(playerVeh)
    openUI = true
    SendNUIMessage({
        action = "openmenu"
    })
    ToggleVehicleParts("allclosed")
    AddMods()
    UpdatePrice()
end

function AddMods()
    local playerPed = PlayerPedId()
    local playerVeh = GetVehiclePedIsIn(playerPed, false)
    SetVehicleModKit(playerVeh,0)
    for k, v in pairs(Config.ModsList) do
        if Config.DetailMods[k] == nil then 
                SendNUIMessage({
                    action = "addMods",
                    label = v.name,
                    img = v.img,
                    id = k,
                })
        else
            local modCount = GetNumVehicleMods(playerVeh, Config.DetailMods[k].modtype)
            if modCount > 1 then
                SendNUIMessage({
                    action = "addMods",
                    label = Config.ModsList[k].name ,
                    img = Config.ModsList[k].img,
                    id = k,
                })
            end
        end
    end
end

function detailed(veh)
	local pmult, tmult, handling, brake = 1000,800,GetPerformanceStats(veh).handling,GetPerformanceStats(veh).brakes
	topspeed = math.ceil(GetVehicleModelEstimatedMaxSpeed(GetEntityModel(veh))*4.605936)
	power = math.ceil(GetVehicleModelAcceleration(GetEntityModel(veh))*pmult)
	torque = math.ceil(GetVehicleModelAcceleration(GetEntityModel(veh))*tmult)
	brakes = GetVehicleModelMaxBraking(GetEntityModel(veh)) * 80
    health =  math.floor(GetVehicleEngineHealth(veh) / 10)
    fuel = getfuel(veh)
    SendNUIMessage({
		action = "update",
		topspeed = topspeed,
		power = power,
		torque = torque,
		brakes = brakes,
        health = health,
        fuel = fuel
	})
end

function GetPerformanceStats(vehicle)
    local data = {}
    data.brakes = GetVehicleModelMaxBraking(vehicle)
    local handling1 = GetVehicleModelMaxBraking(vehicle)
    local handling2 = GetVehicleModelMaxBrakingMaxMods(vehicle)
    local handling3 = GetVehicleModelMaxTraction(vehicle)
    data.handling = (handling1+handling2) * handling3
    return data
end

function toboolean(str, str2)
    local bool = false
    if all_trim(str) == all_trim(str2) then
        bool = true
    end
    return bool
end

function all_trim(s)
	str = s:gsub("%s+", "")
    str = string.gsub(s, "%s+", "")
   return str
end

RegisterNUICallback("close", function ()
    typerChange()
end)

RegisterNUICallback('rightClick', function(data, cb)
	SetNuiFocus(false, false)
    RenderScriptCams(false, true, 500, true, true)
    renderingScriptCam = false
    DestroyCam(customCamMain, true)
    DestroyCam(customCamSec, true)
    ClearFocus()
	while true do
		Citizen.Wait(1)
		if IsDisabledControlJustPressed(0, 91) or not openUI then
			break
		end
	end

	SetNuiFocus(true, true)
	cb("")
end)

RegisterNUICallback("changecam", function ()
    local playerVeh = GetVehiclePedIsIn(PlayerPedId(), false)
    local vehPos = GetEntityCoords(playerVeh)
    local camPos = GetOffsetFromEntityInWorldCoords(playerVeh, -2.0, 5.0, 3.0)
    local headingToObject = GetHeadingFromVector_2d(vehPos.x - camPos.x, vehPos.y - camPos.y)
    customCamMain = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, -35.0, 0.0, headingToObject, GetGameplayCamFov(), false, 2)
    customCamSec = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, -35.0, 0.0, headingToObject, GetGameplayCamFov(), false, 2)
    SetCamActive(customCamMain, true)
    RenderScriptCams(true, true, 500, true, true)
    FreezeEntityPosition(playerVeh ,true)
    SetVehicleOnGroundProperly(playerVeh)
    RenderScriptCams(not renderingScriptCam, true, 500, true, true)
    renderingScriptCam = not renderingScriptCam
end)

RegisterNUICallback("SellectId", function (data)
    id = data.id
    SellectMode = id
    SendNUIMessage({action = "emptyitem"})
    typer = "main"
    CehckCarParts()
    if Config.SoundEffect then 
        PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    end
    DefaultCar()
    if id == "Colors" then 
        SendNUIMessage({action = "emptyall"})
        for k, v in pairs(Config.ColorsType) do
            typer = "alt"
            SendNUIMessage({
                action = "addMods",
                label = v.label,
                img = v.img,
                id = k,
            })
        end
    elseif id == "Plates" then 
        for k, v in pairs(Config.Plates) do
                select = false 
            if v.plateindex == oldplate then 
                select = true
            end
                SendNUIMessage({
                    action = "addItems",
                    label = v.name,
                    img = Config.ModsList["Plates"].img,
                    price = v.price,
                    id = k,
                    select = select,
                })
        end
    elseif id == "Horns" then
        for k, v in pairs(Config.Horns) do
            select = false 
            if v.mod == GetModStatus(14) then 
                select = true
            end
            SendNUIMessage({
                action = "addItems",
                label = v.name,
                img = Config.ModsList["Horns"].img,
                price = v.price,
                id = k,
                select = select,
            })
        end
    elseif id == "PrimaryColor" or id == "SecondaryColor" or id == "PearlColor" then 
        colorstyp = id
        typer = "altalt"
        SendNUIMessage({action = "emptyall"})
        for k, v in pairs(Config.ColorsMenu) do
            SendNUIMessage({
                action = "addMods",
                label = v.label,
                img = v.img,
                id = k,
            })
        end
    elseif id == "ColorsC" then 
        typer = "altaltalt"
        for k, v in pairs(Config.Colors) do
            SendNUIMessage({
                action = "addItems",
                label = v.name,
                img = Config.ColorsMenu["ColorsC"].img,
                price = Config.ColorsMenu["ColorsC"].price,
                id = k,
            })
        end
    elseif id == "MetalColors" then 
        typer = "altaltalt"
        for k, v in pairs(Config.MetalColors) do
            SendNUIMessage({
                action = "addItems",
                label = v.name,
                img = Config.ColorsMenu["MetalColors"].img,
                price = Config.ColorsMenu["MetalColors"].price,
                id = k,
            })
        end
    elseif id == "MatteColors" then 
        typer = "altaltalt"
        for k, v in pairs(Config.MatteColors) do
            SendNUIMessage({
                action = "addItems",
                label = v.name,
                img = Config.ColorsMenu["MatteColors"].img,
                price = Config.ColorsMenu["MatteColors"].price,
                id = k,
            })
        end
    elseif id == "RepairMenu" then
        for k, v in pairs(Config.RepairMenu) do
            SendNUIMessage({
                action = "addItems",
                label = v.name,
                img = v.img,
                price = v.price,
                id = k,
            })
        end
    elseif id == "Neons" then
        for k, v in pairs(Config.Neons) do
            select = false 
            if json.encode(v.neon) == "[" .. oldneon[1] .. "," .. oldneon[2] .. "," .. oldneon[3] .. "]" then 
                select = true
            end
            SendNUIMessage({
                action = "addItems",
                label = v.name,
                img = Config.ModsList["Neons"].img,
                price = v.price,
                id = k,
                select = select,
            })
        end
    elseif id == "WindowTint" then
        for k, v in pairs(Config.Windowtint) do
            select = false 
            if v.tint == oldtint or (oldtint == -1 and v.tint == 4) then 
                select = true
            end
            SendNUIMessage({
                action = "addItems",
                label = v.name,
                img = Config.ModsList["WindowTint"].img,
                price = v.price,
                id = k,
                select = select,
            })
        end
    elseif id == "Suspension" then
        for k, v in pairs(Config.Suspensions) do
            select = false 
            if v.mod == GetModStatus(15) or (GetModStatus(15) == -1 and v.mod == 0) then 
                select = true
            end
            SendNUIMessage({
                action = "addItems",
                label = v.name,
                img = Config.ModsList["Suspension"].img,
                price = v.price,
                id = k,
                select = select,
            })
        end
    elseif id == "Brakes" then 
        for k, v in pairs(Config.Brakes) do
            select = false 
            if v.mod == GetModStatus(12) or (GetModStatus(12) == -1 and v.mod == 0) then 
                select = true
            end
            SendNUIMessage({
                action = "addItems",
                label = v.name,
                img = Config.ModsList["Brakes"].img,
                price = v.price,
                id = k,
                select = select,
            })
        end
    elseif id == "Engine" then 
        for k, v in pairs(Config.Engine) do
            select = false 
            if v.mod == GetModStatus(11) or (GetModStatus(11) == 3 and v.mod == 0) or (GetModStatus(11) == -1 and v.mod == 0) then 
                select = true
            end
            SendNUIMessage({
                action = "addItems",
                label = v.name,
                img = Config.ModsList["Engine"].img,
                price = v.price,
                id = k,
                select = select,
            })
        end
    elseif id == "Transmission"  then
        for k, v in pairs(Config.Transmission) do
            select = false 
            if v.mod == GetModStatus(13) or (GetModStatus(13) == -1 and v.mod == 0) then 
                select = true
            end
            SendNUIMessage({
                action = "addItems",
                label = v.name,
                img = Config.ModsList["Transmission"].img,
                price = v.price,
                id = k,
                select = select,
            })
        end
    elseif id == "Wheels" then
        typer = "main"
        SendNUIMessage({action = "emptyall"})
        for k, v in pairs(Config.WheelsType) do
            typer = "alt"
            SendNUIMessage({
                action = "addMods",
                label = v.name,
                img = v.img,
                id = k,
            })
        end
    elseif id == "wheelSmoke" then 
    typer = "alt"
        for k, v in pairs(Config.Wheel.wheelaccessories) do
            select = false 
                if json.encode(v.smokecolor) == "[" .. oldsmoke[1] .. "," .. oldsmoke[2] .. "," .. oldsmoke[3] .. "]" then 
                select = true
            end
            SendNUIMessage({
                action = "addItems",
                label = v.name,
                img = Config.ModsList["Wheels"].img,
                price = v.price,
                id = k,
                select = select,
            })
        end
    elseif id == "accessories" then 
    typer = "alt"
        SendNUIMessage({action = "emptyall"})
        for k, v in pairs(Config.Wheel_whType) do
            typer = "altalt"
            SendNUIMessage({
                action = "addMods",
                label = v.name,
                img = v.img,
                id = k,
            })
        end
    elseif id == "frontwheel" or id == "backwheel" or id == "sportwheels" or id == "suvwheels" or id == "offroadwheels" or id == "tunerwheels" or id == "highendwheels" or id == "lowriderwheels" or id == "musclewheels" then
    typer = "altalt"
        for k, v in pairs(Config.Wheel.Wheel[id]) do
            select = false 
            if v.mod == GetModStatus(23) and v.wtype == oldwtype then 
                select = true
            end
            SendNUIMessage({
                action = "addItems",
                label = v.name,
                img = Config.Wheel_whType[id].img,
                price = v.price,
                id = k,
                select = select,
            })
        end
    elseif id == "wheelcolor" then
    typer = "alt"
    for k, v in pairs(Config.Colors) do
            SendNUIMessage({
                action = "addItems",
                label = v.name,
                img = Config.ColorsMenu["ColorsC"].img,
                price = Config.ColorsMenu["ColorsC"].price,
                id = k,
            })
        end
    elseif Config.DetailMods[id] then
        local playerPed = PlayerPedId()
        local playerVeh = GetVehiclePedIsIn(playerPed, false)
        local modCount = GetNumVehicleMods(playerVeh, Config.DetailMods[id].modtype)
        for i = modCount, 0, -1 do
            select = false 
            if i == GetModStatus(Config.DetailMods[id].modtype) or (GetModStatus(Config.DetailMods[id].modtype) == -1 and i == modCount) then 
                select = true
            end
            if i == modCount then
            else
                SendNUIMessage({
                    action = "addItems",
                    label = Config.ModsList[id].name.. " ".. i + 1,
                    img = Config.ModsList[id].img,
                    price = Config.DetailMods[id].startprice + (i * Config.DetailMods[id].increaseby),
                    select = select,
                    id = i,
                })
            end
        end
        select = false 
        if modCount == GetModStatus(Config.DetailMods[id].modtype) or (GetModStatus(Config.DetailMods[id].modtype) == -1) then 
            select = true
        end
            SendNUIMessage({
                    action = "addItems",
                    label = Config.ModsList[id].name.. " ".. Config.Langs["Stock"],
                    img = Config.ModsList[id].img,
                    price = Config.DetailMods[id].startprice + (modCount * Config.DetailMods[id].increaseby),
                    select = select,
                    id = modCount,
                })
        -- end
    end
end)

BlipsTable = {}
function AddMechanicsBlips()
    for location, data in pairs(Config.Mechanics) do
        if Config.Blips.Blip then
            local blip = AddBlipForCoord(data.Coords.x, data.Coords.y, data.Coords.z)
            SetBlipSprite(blip, Config.Blips.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, Config.Blips.scale)
            SetBlipColour(blip, Config.Blips.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(Config.Blips.Name)
            EndTextCommandSetBlipName(blip)
            table.insert(BlipsTable, blip) 
        end
    end
end

RegisterNUICallback("SellectItem", function (data)
    id = data.id 
    SellectItem = id
    local playerPed = PlayerPedId()
    local playerVeh = GetVehiclePedIsIn(playerPed, false)
    oldcolorx = table.pack(GetVehicleColours(playerVeh))
    repair = "no"
    if Config.SoundEffect then 
        PlaySoundFrontend(-1, "NAV_UP_DOWN", "HUD_FRONTEND_DEFAULT_SOUNDSET", 1)
    end
    if SellectMode == "MatteColors" or SellectMode == "MetalColors" or SellectMode == "ColorsC" then 
        if colorstyp == "PrimaryColor" then 
            if SellectMode == "ColorsC" then 
                SellectItemPrice = Config.ColorsMenu["ColorsC"].price
                SetVehicleColours(playerVeh,Config["Colors"][tonumber(SellectItem)].colorindex,oldcolor[2])
            else 
                SellectItemPrice = Config.ColorsMenu[SellectMode].price
                SetVehicleColours(playerVeh,Config[SellectMode][tonumber(SellectItem)].colorindex,oldcolor[2])
            end
        elseif colorstyp == "SecondaryColor" then
            if SellectMode == "ColorsC" then 
                SellectItemPrice = Config.ColorsMenu["ColorsC"].price
                SetVehicleColours(playerVeh,oldcolorx[1] ,Config["Colors"][tonumber(SellectItem)].colorindex)
            else 
                SellectItemPrice = Config.ColorsMenu[SellectMode].price
                SetVehicleColours(playerVeh,oldcolorx[1] ,Config[SellectMode][tonumber(SellectItem)].colorindex)
            end
        else
            if SellectMode == "ColorsC" then 
                SellectItemPrice = Config.ColorsMenu["ColorsC"].price
                SetVehicleExtraColours(playerVeh, Config["Colors"][tonumber(SellectItem)].colorindex, Config["Colors"][tonumber(SellectItem)].colorindex)
            else 
                SellectItemPrice = Config.ColorsMenu[SellectMode].price
                SetVehicleExtraColours(playerVeh, Config[SellectMode][tonumber(SellectItem)].colorindex, Config[SellectMode][tonumber(SellectItem)].colorindex)
            end
        end
    elseif SellectMode == "Horns" then
        SellectItemPrice = Config.Horns[tonumber(id)].price
        SetVehicleMod(playerVeh, 14, Config.Horns[tonumber(id)].mod) 
        OverrideVehHorn(playerVeh,false,Config.Horns[tonumber(id)].mod)
        StartVehicleHorn(playerVeh, 3000, GetHashKey("HELDDOWN"), true)
        notify(Config.Langs["ChangeHorns"])
    elseif SellectItem == "Repair" or SellectItem == "AdvancedRepair" or SellectItem == "Clean" then 
        SellectItemPrice = Config.RepairMenu[SellectItem].price 
    elseif SellectMode == "Plates" then
        SellectItemPrice = Config.Plates[tonumber(id)].price
        SetVehicleNumberPlateTextIndex(playerVeh, Config.Plates[tonumber(id)].plateindex)
    elseif SellectMode == "Neons" then 
        SellectItemPrice = Config.Neons[tonumber(id)].price
        for i = 0, 3 do
            SetVehicleNeonLightEnabled(playerVeh, i, true)
        end
        if json.encode(Config.Neons[tonumber(id)].neon) == "[0,0,0]" then 
            SetVehicleNeonLightsColour(playerVeh,255,255,255)
            for i = 0, 3 do
                SetVehicleNeonLightEnabled(playerVeh, i, false)
            end
        else 
            SetVehicleNeonLightsColour(playerVeh,Config.Neons[tonumber(id)].neon[1],Config.Neons[tonumber(id)].neon[2],Config.Neons[tonumber(id)].neon[3])
        end
    elseif SellectMode == "WindowTint" then
        SellectItemPrice = Config.Windowtint[tonumber(id)].price
        SetVehicleWindowTint(playerVeh, Config.Windowtint[tonumber(id)].tint)
    elseif SellectMode == "Suspension" then 
        SellectItemPrice = Config.Suspensions[tonumber(id)].price 
        SetVehicleMod(playerVeh, 15, Config.Suspensions[tonumber(id)].mod)
    elseif SellectMode == "Brakes" then 
        SellectItemPrice = Config.Brakes[tonumber(id)].price 
        SetVehicleMod(playerVeh, 12, Config.Brakes[tonumber(id)].mod)
    elseif SellectMode == "Engine" then
        SellectItemPrice = Config.Engine[tonumber(id)].price 
        SetVehicleMod(playerVeh, 11, Config.Engine[tonumber(id)].mod)
    elseif SellectMode == "Transmission" then
        SellectItemPrice = Config.Transmission[tonumber(id)].price 
        SetVehicleMod(playerVeh, 13, Config.Transmission[tonumber(id)].mod)
    elseif SellectMode == "wheelSmoke" then 
        SellectItemPrice = Config.Wheel.wheelaccessories[tonumber(id)].price 
        ToggleVehicleMod(playerVeh,20,true)
        SetVehicleTyreSmokeColor(playerVeh, Config.Wheel.wheelaccessories[tonumber(id)].smokecolor[1], Config.Wheel.wheelaccessories[tonumber(id)].smokecolor[2], Config.Wheel.wheelaccessories[tonumber(id)].smokecolor[3])
    elseif SellectMode == "frontwheel" or SellectMode == "backwheel" or SellectMode == "sportwheels" or SellectMode == "suvwheels" or SellectMode == "offroadwheels" or SellectMode == "tunerwheels" or SellectMode == "highendwheels" or SellectMode == "lowriderwheels" or SellectMode == "musclewheels" then
        SellectItemPrice = Config.Wheel.Wheel[SellectMode][tonumber(id)].price 
        SetVehicleWheelType(playerVeh,Config.Wheel.Wheel[SellectMode][tonumber(id)].wtype)
        SetVehicleMod(playerVeh,23,Config.Wheel.Wheel[SellectMode][tonumber(id)].mod)
    elseif Config.DetailMods[SellectMode] then 
        SellectItemPrice = Config.DetailMods[SellectMode].startprice + (tonumber(id) * Config.DetailMods[SellectMode].increaseby)
        SetVehicleMod(playerVeh, Config.DetailMods[SellectMode].modtype, tonumber(id))
    end
    UpdatePrice()
end)


RegisterNUICallback("BuyItem", function ()
    TriggerServerEvent("BakiTelli_mechanic:buyitem", SellectItemPrice)
end)

AddEventHandler("BakiTelli_mechanic:cl:buyitem")
RegisterNetEvent("BakiTelli_mechanic:cl:buyitem", function ()
    local playerPed = PlayerPedId()
    local playerVeh = GetVehiclePedIsIn(playerPed, false)
    if Config.SoundEffect then 
        SendNUIMessage({action="sound"})
    end
    if SellectItem == "Repair" then
        local fullEngineHealth = 1000.0 
        SetVehicleEngineHealth(playerVeh, fullEngineHealth)
        detailed(playerVeh)
        notify(Config.Langs["Repair"])
    elseif SellectItem == "AdvancedRepair" then 
        local fullEngineHealth = 1000.0 
        SetVehicleEngineHealth(playerVeh, fullEngineHealth)
        SetVehicleFixed(playerVeh)
        detailed(playerVeh)
        notify(Config.Langs["AdvancedRepair"])
    elseif SellectItem == "Clean" then
        notify(Config.Langs["Clean"])
        WashDecalsFromVehicle(playerVeh, 1.0)
		SetVehicleDirtLevel(playerVeh)
    else
        SaveCar()
    end
    TriggerServerEvent("BakiTelli_mechanic:SaveVehicleProps", getvehiclepropx(playerVeh))
end)

function UpdatePrice()
    SendNUIMessage({
        action = "updateprice",
        price = SellectItemPrice    
    })
end

local PartsAll = {
    ["Trim"] = true,
    ["DoorSpeaker"] = true, 
    ["Seats"] = true, 
    ["Trunk"] = true, 
    ["Hydraulics"] = true,
    ["EngineBlock"] = true, 
    ["AirFilter"] = true, 
    ["Struts"] = true,
}

function CehckCarParts()
    ToggleVehicleParts("allclosed")
    if PartsAll[SellectMode] == nil then else
        ToggleVehicleParts("doors")
    end
end

function ToggleVehicleParts(typ)
    local playerPed = PlayerPedId()
    local playerVeh = GetVehiclePedIsIn(playerPed, false)
    if typ == "doors" then
        for i = 0, 5 do
            SetVehicleDoorOpen(playerVeh, i, false, false)
        end
    elseif typ == "allclosed" then
        for i = 0, 5 do
            SetVehicleDoorShut(playerVeh, i, false)
        end
    end
end

function DefaultCar()
    local playerPed = PlayerPedId()
    local playerVeh = GetVehiclePedIsIn(playerPed, false)
    SetVehicleColours(playerVeh,oldcolor[1] ,oldcolor[2])
    SetVehicleNeonLightsColour(playerVeh,oldneon[1], oldneon[2], oldneon[3])
    SetVehicleNumberPlateTextIndex(playerVeh, oldplate)
    SetVehicleExtraColours(playerVeh, oldcolorextra[1], oldcolorextra[2])
    SetVehicleWindowTint(playerVeh, oldtint)
    SetVehicleWheelType(playerVeh,oldwtype)
    SaveAllMod(playerVeh)
    SetVehicleTyreSmokeColor(playerVeh, oldsmoke[1], oldsmoke[2], oldsmoke[3])
end

function SaveCar()
    local playerPed = PlayerPedId()
    local playerVeh = GetVehiclePedIsIn(playerPed, false)
    oldcolor = table.pack(GetVehicleColours(playerVeh))
    oldcolorextra = table.pack(GetVehicleExtraColours(playerVeh))
    oldneon = table.pack(GetVehicleNeonLightsColour(playerVeh))
    oldplate = GetVehicleNumberPlateTextIndex(playerVeh)
    oldtint = GetVehicleWindowTint(playerVeh)
    oldwtype = GetVehicleWheelType(playerVeh)
    oldsmoke = table.pack(GetVehicleTyreSmokeColor(playerVeh))
    notify(Config.Langs["BuyItem"])
    SetVehicleNumberPlateTextIndex(playerVeh, oldplate)
    SetVehicleNeonLightsColour(playerVeh,oldneon[1], oldneon[2], oldneon[3])
    SetVehicleWheelType(playerVeh,oldwtype)
    FillVehicleModStatus(playerVeh)
    SaveAllMod(playerVeh)
    SetVehicleColours(playerVeh,oldcolor[1] ,oldcolor[2])
    SetVehicleExtraColours(playerVeh, oldcolorextra[1], oldcolorextra[2])
    SetVehicleWindowTint(playerVeh, oldtint)
    SetVehicleTyreSmokeColor(playerVeh, oldsmoke[1], oldsmoke[2], oldsmoke[3])
end


function closeMenu()
    SetNuiFocus(0, 0)
    local playerPed = PlayerPedId()
    local playerVeh = GetVehiclePedIsIn(playerPed, false)
    FreezeEntityPosition(playerVeh,false)
    RenderScriptCams(false, true, 500, true, true)
    renderingScriptCam = false
    DestroyCam(customCamMain, true)
    DestroyCam(customCamSec, true)
    DisplayHud(true)
    ClearFocus()
    openUI = false
    SendNUIMessage({
        action = "close"
    })
    ToggleVehicleParts("allclosed")
    DefaultCar()    
end

function altMenu()
    DefaultCar()
    if SellectMode == "Colors" then 
    local playerPed = PlayerPedId()
    local playerVeh = GetVehiclePedIsIn(playerPed, false)
    ClearFocus()
    SendNUIMessage({
            action = "close"
    })    
    SetVehicleOnGroundProperly(playerVeh)
    oldcolor = table.pack(GetVehicleColours(playerVeh))
    oldcolorextra = table.pack(GetVehicleExtraColours(playerVeh))
    detailed(playerVeh)
    DefaultCar()
    SendNUIMessage({
        action = "openmenu"
    })
    AddMods()
    elseif SellectMode == "PrimaryColor" or SellectMode == "SecondaryColor" or SellectMode == "PearlColor"  then
        SellectMode = "Colors"
        typer = "main"
        local playerPed = PlayerPedId()
        local playerVeh = GetVehiclePedIsIn(playerPed, false)
        ClearFocus()
        SendNUIMessage({
                action = "close"
        })    
        SetVehicleOnGroundProperly(playerVeh)
        oldcolor = table.pack(GetVehicleColours(playerVeh))
        oldcolorextra = table.pack(GetVehicleExtraColours(playerVeh))
        detailed(playerVeh)
        DefaultCar()
        SendNUIMessage({
            action = "openmenu"
        })
        AddMods()
    elseif SellectMode == "MetalColors" or SellectMode == "MatteColors" or SellectMode == "ColorsC" then 
        colorstyp = id
        typer = "altalt"
        SellectMode = "PrimaryColor"
        SendNUIMessage({action = "emptyall"})
        SendNUIMessage({action = "emptyitem"})
        for k, v in pairs(Config.ColorsType) do
            SendNUIMessage({
                action = "addMods",
                label = v.label,
                img = v.img,
                id = k,
            })
        end
    elseif SellectMode == "frontwheel" or SellectMode == "backwheel" or SellectMode == "sportwheels" or SellectMode == "suvwheels" or SellectMode == "offroadwheels" or id == "tunerwheels" or id == "highendwheels" or SellectMode == "lowriderwheels" or SellectMode == "musclewheels" or SellectMode == "wheelSmoke" or SellectMode == "Wheels" or SellectMode == "accessories" then
        if SellectMode == "wheelSmoke" or SellectMode == "Wheels" then 
            typer = "main"
            local playerPed = PlayerPedId()
            local playerVeh = GetVehiclePedIsIn(playerPed, false)
            ClearFocus()
            SendNUIMessage({
                    action = "close"
            })    
            SetVehicleOnGroundProperly(playerVeh)
            oldcolor = table.pack(GetVehicleColours(playerVeh))
            oldcolorextra = table.pack(GetVehicleExtraColours(playerVeh))
            detailed(playerVeh)
            DefaultCar()
            SendNUIMessage({
                action = "openmenu"
            })
            AddMods()
        elseif SellectMode == "backwheel" or SellectMode == "sportwheels" or SellectMode == "suvwheels" or SellectMode == "offroadwheels" or id == "tunerwheels" or id == "highendwheels" or SellectMode == "lowriderwheels" or SellectMode == "musclewheels" or SellectMode == "accessories" then
            typer = "alt"
            SellectMode = "Wheels"
            SendNUIMessage({action = "emptyitem"})
            SendNUIMessage({action = "emptyall"})
            for k, v in pairs(Config.WheelsType) do
                SendNUIMessage({
                    action = "addMods",
                    label = v.name,
                    img = v.img,
                    id = k,
                })
            end
        end
    end
end

function FillVehicleModStatus(veh)
    vehicleMods = {}
    for modType = 0, 49 do
        local modStatus = GetVehicleMod(veh, modType)
        vehicleMods[modType] = modStatus
    end
end

function GetModStatus(modType)
    return vehicleMods[modType]
end

function SaveAllMod(veh)
    for modType, modStatus in pairs(vehicleMods) do
        SetVehicleMod(veh, modType, modStatus)
    end
end

function typerChange()
    if typer == "main" then
        closeMenu() 
    elseif typer == "alt" then
        typer = "main"
        altMenu()
    elseif typer == "altalt" then
        typer = "alt"
        altMenu()
    elseif typer == "altaltalt" then
        typer = "altalt"
        altMenu()
    end
end

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(0)

		if openUI then
			DisableAllControlActions(0)
			EnableControlAction(0, 1, true)
			EnableControlAction(0, 2, true)
			EnableControlAction(0, 4, true)
			EnableControlAction(0, 6, true)
			EnableControlAction(0, 86, true)
		else
			Citizen.Wait(500)
		end
	end
end)
