-- client/framework/qb/main.lua
-- QBX.PlayerData provided by @qbx_core/modules/playerdata.lua
-- Event: QBCore:Client:OnPlayerLoaded per docs.qbox.re/resources/qbx_core/events/client

if not Framework.QBCore() then return end

local client = client

local function pd()
    return QBX and QBX.PlayerData or nil
end

local function setClientParams()
    local data = pd()
    if not data then return end
    client.job       = data.job
    client.gang      = data.gang
    client.citizenid = data.citizenid
end

function Framework.GetPlayerGender()
    local data = pd()
    if data and data.charinfo and data.charinfo.gender == 1 then return 'Female' end
    return 'Male'
end

function Framework.UpdatePlayerData()
    setClientParams()
end

function Framework.HasTracker()
    local data = pd()
    if not data or not data.metadata then return false end
    return data.metadata['tracker'] or false
end

function Framework.CheckPlayerMeta()
    local data = pd()
    if not data or not data.metadata then return false end
    local m = data.metadata
    return m['isdead'] or m['inlaststand'] or m['ishandcuffed'] or false
end

function Framework.IsPlayerAllowed(citizenid)
    local data = pd()
    if not data then return false end
    return data.citizenid == citizenid
end

function Framework.GetRankInputValues(rankType)
    local data = pd()
    if not data then return {{ label = 'Grade 0', value = '0' }} end
    local ok, grades
    if rankType == 'gang' then
        ok, grades = pcall(function()
            local gangs = exports.qbx_core:GetGangs()
            return gangs[data.gang.name] and gangs[data.gang.name].grades
        end)
    else
        ok, grades = pcall(function()
            local jobs = exports.qbx_core:GetJobs()
            return jobs[data.job.name] and jobs[data.job.name].grades
        end)
    end
    if not ok or not grades then return {{ label = 'Grade 0', value = '0' }} end
    local result = {}
    for k, v in pairs(grades) do
        result[#result + 1] = { label = v.name, value = k }
    end
    return result
end

function Framework.GetJobGrade()
    local data = pd()
    return data and data.job and data.job.grade and data.job.grade.level or 0
end

function Framework.GetGangGrade()
    local data = pd()
    return data and data.gang and data.gang.grade and data.gang.grade.level or 0
end

function Framework.CachePed()
    return nil
end

function Framework.RestorePlayerArmour()
    local data = pd()
    if data and data.metadata then
        Wait(1000)
        SetPedArmour(cache.ped, data.metadata['armor'] or 0)
    end
end

-- Events
AddEventHandler('QBCore:Client:OnJobUpdate', function(jobInfo)
    if client then client.job = jobInfo end
    ResetBlips()
end)

AddEventHandler('QBCore:Client:OnGangUpdate', function(gangInfo)
    if client then client.gang = gangInfo end
    ResetBlips()
end)

RegisterNetEvent('QBCore:Client:SetDuty', function(duty)
    if client and client.job then client.job.onduty = duty end
end)

-- QBCore:Client:OnPlayerLoaded fires when the player finishes spawning
-- per docs.qbox.re/resources/qbx_core/events/client
AddEventHandler('QBCore:Client:OnPlayerLoaded', function()
    setClientParams()
    InitAppearance()
end)

RegisterNetEvent('qb-clothes:client:CreateFirstCharacter', function()
    setClientParams()
    InitializeCharacter(Framework.GetGender(true))
end)

RegisterNetEvent('qb-multicharacter:client:chooseChar', function()
    client.setPedTattoos(cache.ped, {})
    ClearPedDecorations(cache.ped)
    -- Reset both server outfit cache and client outfit cache
    TriggerServerEvent('illenium-appearance:server:resetOutfitCache')
    TriggerEvent('illenium-appearance:client:invalidateOutfitCache')
end)

setClientParams()
