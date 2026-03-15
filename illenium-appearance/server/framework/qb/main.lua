-- server/framework/qb/main.lua
-- Qbox native server patterns. Uses exports.qbx_core throughout.

if not Framework.QBCore() then return end

local function getPlayer(src)
    if not src or src <= 0 then return nil end
    return exports.qbx_core:GetPlayer(src)
end

function Framework.GetPlayerID(src)
    local player = getPlayer(src)
    if not player then return nil end
    return player.PlayerData.citizenid
end

function Framework.HasMoney(src, moneyType, amount)
    local player = getPlayer(src)
    if not player then return false end
    local balance = player.PlayerData.money[moneyType]
    return type(balance) == 'number' and balance >= amount
end

function Framework.RemoveMoney(src, moneyType, amount)
    local player = getPlayer(src)
    if not player then return false end
    return player.Functions.RemoveMoney(moneyType, amount, 'illenium-appearance')
end

function Framework.GetJob(src)
    local player = getPlayer(src)
    if not player then return { name = 'unemployed', grade = { level = 0 } } end
    return player.PlayerData.job
end

function Framework.GetGang(src)
    local player = getPlayer(src)
    if not player then return { name = 'none', grade = { level = 0 } } end
    return player.PlayerData.gang
end

-- Save: upsert pattern - one query to update, insert if nothing updated.
-- No delete/insert race condition. Always saves the latest appearance.
function Framework.SaveAppearance(appearance, citizenID)
    if type(appearance) ~= 'table' then return end
    if type(appearance.model) ~= 'string' or #appearance.model == 0 then return end
    local encoded = json.encode(appearance)
    -- Mark all other models as inactive
    MySQL.update.await(
        'UPDATE playerskins SET active = 0 WHERE citizenid = ? AND model != ?',
        { citizenID, appearance.model }
    )
    -- Try to update the existing row for this model
    local updated = MySQL.update.await(
        'UPDATE playerskins SET skin = ?, active = 1 WHERE citizenid = ? AND model = ?',
        { encoded, citizenID, appearance.model }
    )
    if updated == 0 then
        -- No existing row - insert fresh
        MySQL.insert.await(
            'INSERT INTO playerskins (citizenid, model, skin, active) VALUES (?, ?, ?, 1)',
            { citizenID, appearance.model, encoded }
        )
    end
end

-- Load: get the most recently saved active skin.
-- ORDER BY id DESC ensures we always get the newest save, not a stale row.
function Framework.GetAppearance(citizenID, model)
    local raw = Database.PlayerSkins.GetByCitizenID(citizenID, model)
    if not raw then return nil end
    local ok, decoded = pcall(json.decode, raw)
    if not ok or type(decoded) ~= 'table' then return nil end
    return decoded
end
