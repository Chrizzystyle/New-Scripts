Config = {}

Config.Debug = false

Config.PoliceJobs = {
    'police',
    'sheriff',
    'statepolice',
    'lspd',
    'bcso',
    'sasp'
}

Config.PoliceVehicles = {
    'nkstx',
    'nkcypher',
    'nkballer7',
    'nkbuffalos',
    'nkcruiser',
    'nkdominator',
    'nkpanto',
}

Config.RequireMinimumRank = false -- Set to true to require minimum rank --
Config.MinimumRanks = {
    ['police'] = 0,     -- Minimum grade level for police
    ['sheriff'] = 1,    
    ['statepolice'] = 1 
}

Config.DetectionDistance = 2.0  -- Distance to detect nearby vehicles
Config.AccessDistance = 2.0     -- Distance to access gun rack

Config.MaxSlots = 5        -- Maximum slots in gun rack
Config.MaxWeight = 10000    -- Maximum weight in gun rack (50kg)


Config.DefaultItems = { -- Default items to add to new gun racks (optional) Uncomment and modify as needed. --
    -- {name = 'weapon_pistol', count = 1, metadata = {durability = 100}},
    -- {name = 'weapon_nightstick', count = 1},
    -- {name = 'weapon_flashlight', count = 1},
    -- {name = 'weapon_stungun', count = 1},
    -- {name = 'ammo-9', count = 50}
}

Config.PreRegisterStashes = { -- Pre-register stashes for specific vehicle plates (RECOMMENDED for persistence), This helps ensure items don't disappear by registering stashes on server start --
    -- Uncomment and add your police vehicle plates here
    -- {plate = 'POLICE1', model = 'Police Cruiser'},
    -- {plate = 'POLICE2', model = 'Police SUV'},
    -- {plate = 'SHERIFF1', model = 'Sheriff Cruiser'},
    -- {plate = 'BCSO01', model = 'Sheriff SUV'},
}