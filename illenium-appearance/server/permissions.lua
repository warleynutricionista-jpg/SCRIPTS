-- server/permissions.lua
lib.callback.register('illenium-appearance:server:GetPlayerAces', function()
    local src = source
    local allowedAces = {}
    local aces = Config.Aces or {}
    for i = 1, #aces do
        if IsPlayerAceAllowed(src, aces[i]) then
            allowedAces[#allowedAces + 1] = aces[i]
        end
    end
    return allowedAces
end)
