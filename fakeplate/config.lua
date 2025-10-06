Config = {}

-- Item names (must match your items in qbx_core)
Config.FakePlateItem = 'fakeplate'
Config.FakePlateRemoverItem = 'fakeplate_remover'

-- Notification settings
Config.UseOxLib = false -- Set to true if using ox_lib for notifications

-- Time to apply/remove plate (in milliseconds)
Config.ApplyTime = 5000
Config.RemoveTime = 3000

-- Fake plate format (generates random plates)
Config.PlateFormat = '########' -- # = random letter or number

-- Debug mode
Config.Debug = false