local QBX = exports.qbx_core
local isZipTied = false
local zipTiedBy = nil
local zipTiedPlayers = {} -- Track other players' zip tie status

-- Function to check if player has zip ties
local function hasZipTies()
    return exports.ox_inventory:Search('count', Config.ZipTieItem) > 0
end

-- Function to check if player has bolt cutters
local function hasBoltCutters()
    return exports.ox_inventory:Search('count', Config.BoltCutterItem) > 0
end

-- Function to check if player is police
local function isPolice()
    local playerData = QBX:GetPlayerData()
    if not playerData or not playerData.job then return false end
    
    for _, job in pairs(Config.PoliceJobs) do
        if playerData.job.name == job then
            return true
        end
    end
    return false
end

-- Function to check if player can cut zip ties
local function canCutZipTies()
    return isPolice() or hasBoltCutters()
end

-- Function to check if target is zip tied
local function isTargetZipTied(targetId)
    local targetServerId = GetPlayerServerId(targetId)
    return zipTiedPlayers[targetServerId] == true
end

-- Function to apply zip ties
local function applyZipTies(targetId)
    local ped = PlayerPedId()
    local targetPed = GetPlayerPed(targetId)
    
    if not targetPed or targetPed == 0 then return end
    
    -- Check distance
    local playerCoords = GetEntityCoords(ped)
    local targetCoords = GetEntityCoords(targetPed)
    local distance = #(playerCoords - targetCoords)
    
    if distance > Config.MaxDistance then
        lib.notify({
            title = 'Too Far',
            description = 'You are too far from the target',
            type = 'error'
        })
        return
    end
    
    -- Check if player has zip ties
    if not hasZipTies() then
        lib.notify({
            title = 'No Zip Ties',
            description = 'You don\'t have any zip ties',
            type = 'error'
        })
        return
    end
    
    -- Start animation
    if lib.progressBar({
        duration = Config.Animation.time,
        label = 'Applying zip ties...',
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = Config.Animation.dict,
            clip = Config.Animation.anim
        }
    }) then
        -- Remove zip tie from inventory
        TriggerServerEvent('qbx_zipties:server:removeZipTie')
        
        -- Apply zip ties to target
        TriggerServerEvent('qbx_zipties:server:applyZipTies', GetPlayerServerId(targetId))
        
        lib.notify({
            title = 'Success',
            description = 'Zip ties applied successfully',
            type = 'success'
        })
    end
end

-- Function to cut zip ties
local function cutZipTies(targetId)
    local hasPoliceAccess = isPolice()
    local hasBoltCutter = hasBoltCutters()
    
    if not hasPoliceAccess and not hasBoltCutter then
        lib.notify({
            title = 'No Tools',
            description = 'You need bolt cutters to cut zip ties',
            type = 'error'
        })
        return
    end
    
    local ped = PlayerPedId()
    local targetPed = GetPlayerPed(targetId)
    
    if not targetPed or targetPed == 0 then return end
    
    -- Check distance
    local playerCoords = GetEntityCoords(ped)
    local targetCoords = GetEntityCoords(targetPed)
    local distance = #(playerCoords - targetCoords)
    
    if distance > Config.MaxDistance then
        lib.notify({
            title = 'Too Far',
            description = 'You are too far from the target',
            type = 'error'
        })
        return
    end
    
    local progressLabel = hasPoliceAccess and 'Cutting zip ties...' or 'Using bolt cutters...'
    local progressTime = hasPoliceAccess and 3000 or 5000
    
    -- Start animation
    if lib.progressBar({
        duration = progressTime,
        label = progressLabel,
        useWhileDead = false,
        canCancel = true,
        disable = {
            car = true,
            move = true,
            combat = true
        },
        anim = {
            dict = 'anim@gangops@facility@servers@bodysearch@',
            clip = 'player_search'
        }
    }) then
        -- Remove bolt cutter if not police
        if not hasPoliceAccess and hasBoltCutter then
            TriggerServerEvent('qbx_zipties:server:removeBoltCutter')
        end
        
        TriggerServerEvent('qbx_zipties:server:removeZipTies', GetPlayerServerId(targetId))
        
        lib.notify({
            title = 'Success',
            description = 'Zip ties cut successfully',
            type = 'success'
        })
    end
end

-- Register ox_target for players
exports.ox_target:addGlobalPlayer({
    {
        name = 'apply_zipties',
        icon = 'fas fa-link',
        label = 'Apply Zip Ties',
        canInteract = function(entity, distance, coords, name, bone)
            if isZipTied then return false end -- Can't apply if you're zip tied
            local targetId = NetworkGetPlayerIndexFromPed(entity)
            if targetId == PlayerId() then return false end -- Can't zip tie yourself
            if isTargetZipTied(targetId) then return false end -- Target already zip tied
            return hasZipTies() and distance <= Config.MaxDistance
        end,
        onSelect = function(data)
            local targetId = NetworkGetPlayerIndexFromPed(data.entity)
            applyZipTies(targetId)
        end
    },
    {
        name = 'cut_zipties',
        icon = 'fas fa-cut',
        label = 'Cut Zip Ties',
        canInteract = function(entity, distance, coords, name, bone)
            local targetId = NetworkGetPlayerIndexFromPed(entity)
            if targetId == PlayerId() then return false end -- Can't cut your own zip ties
            if not isTargetZipTied(targetId) then return false end -- Target not zip tied
            return canCutZipTies() and distance <= Config.MaxDistance
        end,
        onSelect = function(data)
            local targetId = NetworkGetPlayerIndexFromPed(data.entity)
            cutZipTies(targetId)
        end
    }
})

-- Handle being zip tied
RegisterNetEvent('qbx_zipties:client:setZipTied', function(state, appliedBy)
    isZipTied = state
    zipTiedBy = appliedBy
    
    local ped = PlayerPedId()
    
    if state then
        -- Apply zip tie effects
        SetEnableHandcuffs(ped, true)
        DisablePlayerFiring(ped, true)
        SetCurrentPedWeapon(ped, GetHashKey('WEAPON_UNARMED'), true)
        
        -- Play sound
        PlaySoundFrontend(-1, Config.Sounds.apply, 'DLC_PRISON_BREAK_HEIST_SOUNDS', 1)
        
        lib.notify({
            title = 'Zip Tied',
            description = 'You have been zip tied',
            type = 'inform'
        })
        
        -- Start zip tie loop
        CreateThread(function()
            while isZipTied do
                DisableControlAction(0, 24, true) -- Attack
                DisableControlAction(0, 257, true) -- Attack 2
                DisableControlAction(0, 25, true) -- Aim
                DisableControlAction(0, 263, true) -- Melee Attack 1
                DisableControlAction(0, 32, true) -- Move Up
                DisableControlAction(0, 33, true) -- Move Down
                DisableControlAction(0, 34, true) -- Move Left
                DisableControlAction(0, 35, true) -- Move Right
                DisableControlAction(0, 75, true) -- Exit Vehicle
                Wait(0)
            end
        end)
    else
        -- Remove zip tie effects
        SetEnableHandcuffs(ped, false)
        DisablePlayerFiring(ped, false)
        
        -- Play sound
        PlaySoundFrontend(-1, Config.Sounds.remove, 'DLC_PRISON_BREAK_HEIST_SOUNDS', 1)
        
        lib.notify({
            title = 'Released',
            description = 'Your zip ties have been removed',
            type = 'success'
        })
    end
end)

-- Sync zip tied players for target checks
RegisterNetEvent('qbx_zipties:client:syncZipTiedPlayers', function(players)
    zipTiedPlayers = players
end)

-- Export functions
exports('isZipTied', function()
    return isZipTied
end)

exports('getZipTiedBy', function()
    return zipTiedBy
end)
