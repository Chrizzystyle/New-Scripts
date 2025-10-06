Config = {}

-- Item names from your inventory
Config.ZipTieItem = 'zipties'
Config.BoltCutterItem = 'boltcutter'

-- Police jobs that can cut zip ties without bolt cutters
Config.PoliceJobs = {
    'police',
    'sheriff',
    'statepolice'
}

-- Maximum distance to interact with players
Config.MaxDistance = 2.5

-- Animation settings
Config.Animation = {
    dict = 'mp_arresting',
    anim = 'a_uncuff',
    time = 5000 -- 5 seconds
}

-- Sound settings
Config.Sounds = {
    apply = 'Cuff_Detain',
    remove = 'Uncuff'
}