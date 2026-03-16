Config = {}

Config.Debug = false
Config.Locale = 'pt-br'
Config.MechanicJob = 'mechanic'
Config.RequireDuty = true
Config.MaxServiceDistance = 6.0
Config.PlayerCooldownSeconds = 15
Config.RepairDurationMs = 9000
Config.CleanDurationMs = 5000
Config.EnableStash = true

Config.Stash = {
    id = 'bakitelli_mechanic_stash',
    label = 'Mechanic Storage',
    slots = 200,
    weight = 1500000,
    owner = false,
    groups = { mechanic = 0 }
}

Config.Locations = {
    {
        label = 'Bennys Downtown',
        coords = vec3(-211.55, -1324.55, 30.89),
        radius = 2.5
    }
}

Config.Services = {
    repair = {
        label = 'Repair Vehicle',
        icon = 'wrench',
        duration = 9000,
        requiresItem = { name = 'repairkit', count = 1 },
        cooldown = 20
    },
    clean = {
        label = 'Clean Vehicle',
        icon = 'soap',
        duration = 5000,
        requiresItem = nil,
        cooldown = 10
    }
}
