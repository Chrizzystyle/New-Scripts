Config = {}

-- General Settings
Config.RobberyChance = 25 -- Percentage chance (1-100) for a robbery to occur
Config.RobberyTimeout = 30000 -- Time in milliseconds (30 seconds) total time player has to catch the NPC before they escape
Config.StabTimeout = 10000 -- Time in milliseconds (10 seconds) player has to put hands up before being stabbed
Config.RobberyDistance = 50.0 -- Distance NPC will run before despawning
Config.RobberyBlipTime = 30000 -- How long the robber blip stays on map (milliseconds)

-- Job Exemptions
-- Players with these jobs will NOT be robbed by NPCs
Config.ExemptJobs = {
    'police',
    'ambulance',
    'sheriff',
    'doctor',
    -- Add more jobs below that should be exempt
    -- 'admin',
    -- 'fire',
    -- 'mechanic',
}

-- Cash Robbery Settings
Config.MinCashAmount = 50 -- Minimum amount of cash to steal
Config.MaxCashAmount = 500 -- Maximum amount of cash to steal

-- Items that can be robbed from players
-- Add or remove items based on your server's inventory
Config.RobbableItems = {
    'money', -- Cash (handled separately)
    'phone',
    'wallet',
    'watch',
    'chain',
    'ring',
    'lockpick',
    'advancedlockpick',
    -- Add more items below as needed
    -- 'gold_bar',
    -- 'diamond',
    -- 'rolex',
    -- 'casino_chips',
}

-- NPC Models that can spawn as robbers
-- You can add more ped models here
Config.NPCModels = {
    'a_m_m_skater_01',
    'a_m_y_skater_01',
    'a_m_y_skater_02',
    'a_m_m_beach_01',
    'a_m_y_street_01',
    'a_m_y_street_02',
    'a_m_m_afriamer_01',
    'a_m_y_downtown_01',
    'a_m_y_stbla_01',
    'a_m_y_stbla_02',
    -- Add more models below
    -- 'g_m_m_armboss_01',
    -- 'g_m_m_armgoon_01',
}

-- Keybind Settings
Config.HandsUpKey = 'X' -- Default key to put hands up (can be changed in FiveM keybinds)

-- Notification Settings
Config.Notifications = {
    RobberyStart = 'Someone is trying to rob you! Put your hands up or catch them!',
    RobberyCaught = 'You stopped the robbery!',
    RobberyComplete = 'You were robbed! Stolen: ',
    RobberyStabbed = 'You were stabbed and robbed! Stolen: ',
    NoValuables = 'The robber didn\'t find anything valuable!',
    NoPermission = 'You don\'t have permission to use this command',
}

-- Reward Settings
Config.MinRewardAmount = 100 -- Minimum cash reward for catching robber
Config.MaxRewardAmount = 250 -- Maximum cash reward for catching robber

-- Debug Settings
Config.Debug = false -- Set to true to enable debug prints in console