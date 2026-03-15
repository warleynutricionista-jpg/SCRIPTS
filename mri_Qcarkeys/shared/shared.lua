Shared = {
    ignition = {
        failDamageMin = 30.0, -- minimum engine damage on failed lockpick/hotwire
        failDamageMax = 80.0, -- maximum engine damage on failed lockpick/hotwire
        jammedThreshold = 200.0 -- if engine health goes below this value, ignition is jammed
    },
    dispatch = {
        event = 'dispatch:server:notify', -- server event used when silent alarms are triggered
    },
    luxuryClasses = {
        [6] = true, -- Sports
        [7] = true -- Super
    },
    NPCHasGunChance = 0.35, -- chance of carjacked NPC reacting with firearm
    GrabKeysOnDriverChance = 0.45, -- chance keys are on the driver
    LockNPCVehicle = false, -- lock all npc vehicles
    playerDraggable = true, -- allow players to drag other players
    toggleLightsOnlyRemote = true, -- true if you want the vehicle lights to toggle only when not in the vehicle
    keepVehicleEngineOn = true, -- keep the engine on when exiting a vehicle
    keepKeysInVehicle = true, -- keep keys in vehicle
    steal = {
        available = true, -- allow players to carjack vehicles
        getKey = "permanent", -- "temporary", "permanent", "none"
        label = "Assaltando...",
        minTime = 5000,
        maxTime = 7000,
        stressIncrease = math.random(1, 3),
        chance = {
            ["2685387236"] = 0.0, -- melee
            ["416676503"] = 0.5, -- handguns
            ["-957766203"] = 0.75, -- SMG
            ["860033945"] = 0.90, -- shotgun
            ["970310034"] = 0.90, -- assault
            ["1159398588"] = 0.99, -- LMG
            ["3082541095"] = 0.99, -- sniper
            ["2725924767"] = 0.99, -- heavy
            ["1548507267"] = 0.0, -- throwable
            ["4257178988"] = 0.0 -- misc
        },
        npcGunWeapons = {
            'WEAPON_PISTOL',
            'WEAPON_COMBATPISTOL',
            'WEAPON_APPISTOL',
            'WEAPON_MICROSMG'
        }
    },
    lockpick = {
        minigameScript = "ox_lib", -- "ox_lib", "inside-lockpicking"
        stressIncrease = math.random(1, 3),
        breakChance = 0.5,
        advancedBreakChance = 0.1
    },
    blacklistedClasses = {
        [13] = true, -- Bicicletas
        [14] = true, -- Barcos
        [15] = true, -- Helicópteros
        [16] = true, -- Aviões
        [21] = true -- Trens
    },
    grab = {
        -- grab a dead npc out of a vehicle
        alive = true,
        leaveKeysOnVehicle = true, -- leave keys on vehicle
        label = "Roubando veículo...",
        searchLabel = "Procurando chaves no interior...",
        minTime = 5000,
        maxTime = 7000,
        searchMinTime = 6000,
        searchMaxTime = 9000
    },
    hotwire = {
        -- hotwire a vehicle
        available = true,
        label = "Fazendo ligação direta...",
        stageOneLabel = "Removendo proteção da ignição...",
        stageTwoLabel = "Conectando fios da ignição...",
        chance = 0.1,
        minTime = 5500,
        maxTime = 8500,
        stressIncrease = math.random(1, 3)
    },
    BlackListedWeapon = {
        "WEAPON_UNARMED",
        "WEAPON_Knife",
        "WEAPON_Nightstick",
        "WEAPON_HAMMER",
        "WEAPON_Bat",
        "WEAPON_Crowbar",
        "WEAPON_Golfclub",
        "WEAPON_Bottle",
        "WEAPON_Dagger",
        "WEAPON_Hatchet",
        "WEAPON_KnuckleDuster",
        "WEAPON_Machete",
        "WEAPON_Flashlight",
        "WEAPON_SwitchBlade",
        "WEAPON_Poolcue",
        "WEAPON_Wrench",
        "WEAPON_Battleaxe",
        "WEAPON_Grenade",
        "WEAPON_StickyBomb",
        "WEAPON_ProximityMine",
        "WEAPON_BZGas",
        "WEAPON_Molotov",
        "WEAPON_FireExtinguisher",
        "WEAPON_PetrolCan",
        "WEAPON_Flare",
        "WEAPON_Ball",
        "WEAPON_Snowball",
        "WEAPON_SmokeGrenade"
    }
}
