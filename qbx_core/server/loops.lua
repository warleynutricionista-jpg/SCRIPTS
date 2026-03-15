local config = require 'config.server'

local function removeHungerAndThirst(src, player)
    local playerState = Player(src).state
    if not playerState or not playerState.isLoggedIn then return end

    local currentHunger = playerState.hunger
    local currentThirst = playerState.thirst
    if type(currentHunger) ~= 'number' or type(currentThirst) ~= 'number' then return end

    local newHunger = currentHunger - config.player.hungerRate
    local newThirst = currentThirst - config.player.thirstRate

    player.Functions.SetMetaData('thirst', math.max(0, newThirst))
    player.Functions.SetMetaData('hunger', math.max(0, newHunger))

    player.Functions.Save()
end

CreateThread(function()
    local interval = 60000 * config.updateInterval
    while true do
        Wait(interval)
        for src, player in pairs(QBX.Players) do
            local ok, err = pcall(removeHungerAndThirst, src, player)
            if not ok then
                lib.print.error(('Error updating hunger/thirst for player %s: %s'):format(src, err))
            end
        end
    end
end)

local function pay(player)
    local job = player.PlayerData.job
    if not job or not job.name then return end

    local jobData = GetJob(job.name)
    if not jobData then return end

    if not jobData.offDutyPay and not job.onduty then return end

    local gradeLevel = job.grade and job.grade.level
    local gradeData = gradeLevel and jobData.grades[gradeLevel]
    local payment = (gradeData and gradeData.payment) or job.payment or 0
    if payment <= 0 then return end

    if not config.money.paycheckSociety then
        config.sendPaycheck(player, payment)
        return
    end

    local account = config.getSocietyAccount(job.name)
    if not account then
        config.sendPaycheck(player, payment)
        return
    end

    if account < payment then
        Notify(player.PlayerData.source, locale('error.company_too_poor'), 'error')
        return
    end

    config.removeSocietyMoney(job.name, payment)
    config.sendPaycheck(player, payment)
end

CreateThread(function()
    local interval = 60000 * config.money.paycheckTimeout
    while true do
        Wait(interval)
        for _, player in pairs(QBX.Players) do
            local ok, err = pcall(pay, player)
            if not ok then
                lib.print.error(('Error processing paycheck for player: %s'):format(err))
            end
        end
    end
end)
