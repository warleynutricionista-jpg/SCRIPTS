local statusInterval = require 'config.client'.statusIntervalSeconds

CreateThread(function()
    local timeout = 1000 * statusInterval
    while true do
        Wait(timeout)

        if not QBX.IsLoggedIn then goto continue end

        local playerState = LocalPlayer.state
        if not playerState then goto continue end

        local hunger = playerState.hunger
        local thirst = playerState.thirst
        if type(hunger) ~= 'number' or type(thirst) ~= 'number' then goto continue end

        if (hunger <= 0 or thirst <= 0) and not playerState.isDead then
            local currentHealth = GetEntityHealth(cache.ped)
            local decreaseThreshold = math.random(5, 10)
            SetEntityHealth(cache.ped, currentHealth - decreaseThreshold)
        end

        ::continue::
    end
end)
