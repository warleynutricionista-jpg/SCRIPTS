local cfg = Config or {}

Shared = {
    debug = {
        ignition = false,
        hotwire = false
    },
    text = cfg.Text or {},
    features = cfg.Features or {},
    items = cfg.Items or {},
    ignition = {
        lockpickFailDamage = 45.0,
        hotwireFailDamage = 60.0,
        jammedThreshold = 200.0,
        blockEngineOnIrreversible = true,
        requiresMechanicOnIrreversible = true
    },
    alert = {
        silentClasses = {
            [6] = true,
            [7] = true
        },
        dispatchEvent = 'dispatch:server:notify'
    },
    reputation = {
        enabled = true,
        resource = 'cw-rep',
        maxLevel = 8
    },
    LockNPCVehicle = false,
    playerDraggable = true,
    toggleLightsOnlyRemote = true,
    keepVehicleEngineOn = true,
    keepKeysInVehicle = true,
    steal = {
        available = true,
        getKey = 'permanent',
        label = 'Assaltando...',
        minTime = 5000,
        maxTime = 7000,
        stressIncrease = math.random(1, 3),
        chance = {
            ['2685387236'] = 0.0,
            ['416676503'] = 0.5,
            ['-957766203'] = 0.75,
            ['860033945'] = 0.90,
            ['970310034'] = 0.90,
            ['1159398588'] = 0.99,
            ['3082541095'] = 0.99,
            ['2725924767'] = 0.99,
            ['1548507267'] = 0.0,
            ['4257178988'] = 0.0
        },
        armedNpcChance = 0.35,
        npcGunWeapons = {
            'WEAPON_PISTOL',
            'WEAPON_COMBATPISTOL',
            'WEAPON_APPISTOL',
            'WEAPON_MICROSMG'
        },
        npcAccuracy = 40,
        npcAggressiveness = 2,
        npcSearch = {
            label = 'Revistando NPC...',
            duration = 5000,
            maxDistance = 4.0
        }
    },
    lockpick = {
        minigameScript = 'ox_lib',
        stressIncrease = math.random(1, 3),
        breakChance = 0.5,
        advancedBreakChance = 0.1,
        sequence = {
            requiredStages = 6,
            regressOnFail = false,
            regressAmount = 1,
            failEndsAttempt = true
        }
    },
    blacklistedClasses = {
        [13] = true,
        [14] = true,
        [15] = true,
        [16] = true,
        [21] = true
    },
    grab = {
        alive = true,
        leaveKeysOnVehicle = true,
        label = 'Roubando veículo...',
        searchMinTime = 6000,
        searchMaxTime = 9000,
        searchCompartments = {
            glovebox = {
                label = 'Revistando porta-luvas...',
                requiresDoorOpen = true,
                doorIndex = 4,
                chance = 0.35
            },
            trunk = {
                label = 'Revistando porta-malas...',
                requiresDoorOpen = true,
                doorIndex = 5,
                chance = 0.35
            },
            noneChance = 0.30
        }
    },
    hotwire = {
        available = true,
        stageOneLabel = 'Removendo proteção da ignição...',
        stageTwoLabel = 'Conectando fios da ignição...',
        chance = 0.1,
        minTime = 8500,
        maxTime = 12000,
        stressIncrease = math.random(1, 3),
        minigame = 'ox_lib',
        skillDifficulty = { 'easy', 'medium', 'medium' },
        requiredItem = (cfg.Items and cfg.Items.hotwireTool) or 'screwdriver',
        consumeItem = true,
        severeDamageChance = 0.65,
        irreversibleDamageChance = 0.35
    },
    BlackListedWeapon = {
        'WEAPON_UNARMED', 'WEAPON_Knife', 'WEAPON_Nightstick', 'WEAPON_HAMMER', 'WEAPON_Bat',
        'WEAPON_Crowbar', 'WEAPON_Golfclub', 'WEAPON_Bottle', 'WEAPON_Dagger', 'WEAPON_Hatchet',
        'WEAPON_KnuckleDuster', 'WEAPON_Machete', 'WEAPON_Flashlight', 'WEAPON_SwitchBlade',
        'WEAPON_Poolcue', 'WEAPON_Wrench', 'WEAPON_Battleaxe', 'WEAPON_Grenade', 'WEAPON_StickyBomb',
        'WEAPON_ProximityMine', 'WEAPON_BZGas', 'WEAPON_Molotov', 'WEAPON_FireExtinguisher',
        'WEAPON_PetrolCan', 'WEAPON_Flare', 'WEAPON_Ball', 'WEAPON_Snowball', 'WEAPON_SmokeGrenade'
    },
    vehicleState = {
        states = {
            normal = 'normal',
            breached = 'breached',
            ignitionDamaged = 'ignition_damaged',
            irreversible = 'irreversible_electrical_damage',
            repaired = 'repaired'
        }
    }
}

Shared.text.vehicleLocked = Shared.text.vehicleLocked or 'Veículo trancado'
Shared.text.vehicleUnlocked = Shared.text.vehicleUnlocked or 'Veículo destrancado'
Shared.text.actionCancelled = Shared.text.actionCancelled or 'Ação cancelada!'
Shared.text.keyNotFound = Shared.text.keyNotFound or 'Você não encontrou as chaves no interior.'
Shared.text.keyFound = Shared.text.keyFound or 'Você encontrou a chave do veículo!'
Shared.text.emptyCompartment = Shared.text.emptyCompartment or 'Nada foi encontrado neste compartimento.'
Shared.text.compartmentClosed = Shared.text.compartmentClosed or 'Abra o compartimento antes de revistar.'
Shared.text.alreadySearched = Shared.text.alreadySearched or 'Esse compartimento já foi revistado.'
Shared.text.npcNoKeys = Shared.text.npcNoKeys or 'O NPC não estava com a chave.'
Shared.text.npcEscapedWithKeys = Shared.text.npcEscapedWithKeys or 'Você perdeu o NPC e a chave foi embora com ele.'
Shared.text.missingHotwireTool = Shared.text.missingHotwireTool or 'Você precisa de uma chave de fenda para fazer ligação direta.'
Shared.text.hotwireToolConsumed = Shared.text.hotwireToolConsumed or 'Você usou uma chave de fenda.'
Shared.text.irreversibleElectricalDamage = Shared.text.irreversibleElectricalDamage or 'A ignição sofreu dano elétrico irreversível.'
Shared.text.mechanicRequired = Shared.text.mechanicRequired or 'A ignição está comprometida e precisa de um mecânico.'
Shared.text.lockpickProgress = Shared.text.lockpickProgress or 'Destravamento %s/6'
Shared.text.lockpickFailed = Shared.text.lockpickFailed or 'Falhou em destrancar a porta!'
Shared.text.hotwireFailed = Shared.text.hotwireFailed or 'Você não conseguiu ligar a ignição.'
Shared.text.hotwireMinigameFailed = Shared.text.hotwireMinigameFailed or 'Você errou a ligação direta.'

Shared.features.enableVehicleSearch = Shared.features.enableVehicleSearch ~= false
Shared.features.enableNpcSearch = Shared.features.enableNpcSearch ~= false
Shared.features.enableHotwireDamageStates = Shared.features.enableHotwireDamageStates ~= false
Shared.features.enableLockpickSequence = Shared.features.enableLockpickSequence ~= false

Shared.dispatch = { event = Shared.alert.dispatchEvent }
Shared.luxuryClasses = Shared.alert.silentClasses
Shared.NPCHasGunChance = Shared.steal.armedNpcChance
Shared.GrabKeysOnDriverChance = 0.45
Shared.ignition.failDamageMin = Shared.ignition.lockpickFailDamage
Shared.ignition.failDamageMax = Shared.ignition.hotwireFailDamage
