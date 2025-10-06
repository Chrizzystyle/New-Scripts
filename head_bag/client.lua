-- CLIENT SIDE FIXES WITH PROPER DEBUG TOGGLE

local QBX = exports.qbx_core
local lib = exports['ox_lib']
local baggedPlayers = {}
local isBagged = false
local bagOverlay = nil
local headBagProp = nil
local playerProps = {} -- Track props for all players

-- Debug system
local debugEnabled = false -- Default to false

local function debugPrint(message)
    if debugEnabled then
        print("[DEBUG] " .. message)
    end
end

local function infoPrint(message)
    if debugEnabled then -- Only print info messages when debug is enabled
        print("[INFO] " .. message)
    end
end

local function errorPrint(message)
    -- Error messages should always be shown regardless of debug mode
    print("[ERROR] " .. message)
end

-- Utility function to load animation dictionary
function loadAnimDict(dict)
    RequestAnimDict(dict)
    local timeout = 0
    while not HasAnimDictLoaded(dict) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    return HasAnimDictLoaded(dict)
end

-- Function to create and attach head bag prop
local function createHeadBagProp(targetPed)
    if not DoesEntityExist(targetPed) then
        errorPrint("Target ped doesn't exist for prop creation")
        return nil
    end
    
    -- Load the prop model
    local propHash = GetHashKey("prop_money_bag_01")
    RequestModel(propHash)
    local timeout = 0
    while not HasModelLoaded(propHash) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    
    if not HasModelLoaded(propHash) then
        errorPrint("Failed to load prop model: prop_money_bag_01")
        return nil
    end
    
    -- Create the prop
    local coords = GetEntityCoords(targetPed)
    local prop = CreateObject(propHash, coords.x, coords.y, coords.z, true, true, true)
    
    if not DoesEntityExist(prop) then
        errorPrint("Failed to create head bag prop")
        return nil
    end
    
    -- Mark as mission entity immediately for better control
    SetEntityAsMissionEntity(prop, true, true)
    
    -- Attach to head
    local headBone = GetPedBoneIndex(targetPed, 12844) -- Head bone
    AttachEntityToEntity(prop, targetPed, headBone, 0.2, 0.04, 0.0, 0.0, 270.0, 60.0, true, true, false, true, 1, true)
    
    -- Clean up model
    SetModelAsNoLongerNeeded(propHash)
    
    infoPrint("Head bag prop created and attached to ped: " .. tostring(prop))
    return prop
end

-- Enhanced function to remove head bag prop with multiple methods
local function removeHeadBagProp(prop)
    if not prop then
        debugPrint("No prop provided to removeHeadBagProp")
        return false
    end
    
    if DoesEntityExist(prop) then
        debugPrint("Attempting to remove prop: " .. tostring(prop))
        
        -- Method 1: Detach and delete with mission entity marking
        SetEntityAsMissionEntity(prop, true, true)
        DetachEntity(prop, true, true)
        Wait(50)
        
        -- Try immediate deletion
        DeleteObject(prop)
        Wait(100)
        
        -- Check if it's gone
        if not DoesEntityExist(prop) then
            infoPrint("Head bag prop successfully removed (method 1)")
            return true
        end
        
        -- Method 2: More aggressive approach with entity manipulation
        debugPrint("Method 1 failed, trying method 2")
        SetEntityCollision(prop, false, false)
        SetEntityVisible(prop, false, false)
        FreezeEntityPosition(prop, true)
        SetEntityInvincible(prop, true)
        
        -- Try multiple deletion attempts
        for i = 1, 5 do
            DeleteObject(prop)
            DeleteEntity(prop)
            Wait(50)
            if not DoesEntityExist(prop) then
                infoPrint("Head bag prop successfully removed (method 2, attempt " .. i .. ")")
                return true
            end
        end
        
        -- Method 3: Force move to underground and make invisible
        debugPrint("Method 2 failed, using method 3 (hide)")
        SetEntityVisible(prop, false, false)
        SetEntityCollision(prop, false, false)
        SetEntityCoords(prop, 0.0, 0.0, -1000.0, false, false, false, false)
        if debugEnabled then
            print("[WARN] Could not delete prop, but made it invisible and moved underground")
        end
        return false
    else
        debugPrint("Prop doesn't exist, already removed")
        return true
    end
end

-- Function to apply bag effects to local player
local function applyBagEffects()
    infoPrint("Applying bag effects to local player")
    isBagged = true
    
    -- Create screen overlay effect
    CreateThread(function()
        while isBagged do
            -- Pure black screen effect - covers entire screen
            DrawRect(0.5, 0.5, 1.0, 1.0, 0, 0, 0, 255)
            Wait(0)
        end
    end)
    
    -- Create and attach prop to self
    local playerPed = PlayerPedId()
    if not headBagProp or not DoesEntityExist(headBagProp) then
        headBagProp = createHeadBagProp(playerPed)
    end
end

-- Function to remove bag effects from local player with ENHANCED CLEANUP
local function removeBagEffects()
    infoPrint("Removing bag effects from local player")
    isBagged = false
    
    local myServerId = GetPlayerServerId(PlayerId())
    
    -- Remove local player's head bag prop with multiple attempts
    if headBagProp then
        debugPrint("Removing headBagProp: " .. tostring(headBagProp))
        removeHeadBagProp(headBagProp)
        headBagProp = nil
        debugPrint("Removed headBagProp in removeBagEffects")
    end
    
    -- Also clean up from playerProps if it somehow exists there
    if playerProps[myServerId] then
        debugPrint("Cleaning up local player from playerProps: " .. tostring(playerProps[myServerId]))
        removeHeadBagProp(playerProps[myServerId])
        playerProps[myServerId] = nil
        debugPrint("Cleaned up local player from playerProps in removeBagEffects")
    end
    
    -- ADDITIONAL CLEANUP: Force remove any bag props attached to local player
    CreateThread(function()
        Wait(100)
        local playerPed = PlayerPedId()
        local attachedObjects = {}
        
        -- Get all objects and check if they're attached to the player
        local handle, obj = FindFirstObject()
        local success
        
        repeat
            if DoesEntityExist(obj) then
                local model = GetEntityModel(obj)
                local bagModel = GetHashKey("prop_money_bag_01")
                
                if model == bagModel then
                    if IsEntityAttachedToEntity(obj, playerPed) then
                        debugPrint("Found attached bag prop to clean up: " .. tostring(obj))
                        table.insert(attachedObjects, obj)
                    end
                end
            end
            success, obj = FindNextObject(handle)
        until not success
        
        EndFindObject(handle)
        
        -- Remove all found attached bag objects
        for _, attachedObj in ipairs(attachedObjects) do
            debugPrint("Force removing attached bag object: " .. tostring(attachedObj))
            removeHeadBagProp(attachedObj)
        end
        
        if #attachedObjects > 0 then
            infoPrint("Cleaned up " .. #attachedObjects .. " additional attached bag props")
        end
    end)
    
    debugPrint("Bag effects fully removed for local player")
end

-- Apply head bag function with improved state management
function applyHeadBag(targetId)
    if not targetId or targetId == 0 then 
        errorPrint("Invalid target ID for head bag")
        return 
    end
    
    -- Check if target is already bagged
    if baggedPlayers[targetId] then
        lib.notify({
            title = 'Head Bag',
            description = 'This player already has a head bag',
            type = 'error'
        })
        return
    end
    
    local playerPed = PlayerPedId()
    local targetPlayer = GetPlayerFromServerId(targetId)
    
    if targetPlayer == -1 then
        errorPrint("Target player not found")
        return
    end
    
    local targetPed = GetPlayerPed(targetPlayer)
    if not targetPed or targetPed == 0 then 
        errorPrint("Target ped not found")
        return 
    end
    
    -- Load animation with error handling
    if not loadAnimDict('mp_arresting') then
        errorPrint("Failed to load animation for head bag application")
        return
    end
    
    -- Play animation
    TaskPlayAnim(playerPed, 'mp_arresting', 'a_uncuff', 8.0, -8.0, 3300, 0, 0, false, false, false)
    
    -- Update local state BEFORE triggering server event
    baggedPlayers[targetId] = GetPlayerServerId(PlayerId())
    debugPrint("Updated local baggedPlayers - added " .. targetId)
    
    -- Trigger server event
    TriggerServerEvent('head_bag:server:applyBag', targetId)
    
    Wait(3300)
end

-- Remove head bag function with improved state management
function removeHeadBag(targetId)
    if not targetId or targetId == 0 then 
        errorPrint("Invalid target ID for head bag removal")
        return 
    end
    
    -- Check if target is actually bagged
    if not baggedPlayers[targetId] then
        lib.notify({
            title = 'Head Bag',
            description = 'This player doesn\'t have a head bag',
            type = 'error'
        })
        return
    end
    
    local playerPed = PlayerPedId()
    local targetPlayer = GetPlayerFromServerId(targetId)
    
    if targetPlayer == -1 then
        errorPrint("Target player not found")
        return
    end
    
    local targetPed = GetPlayerPed(targetPlayer)
    if not targetPed or targetPed == 0 then 
        errorPrint("Target ped not found")
        return 
    end
    
    -- Load animation with error handling
    if not loadAnimDict('mp_arresting') then
        errorPrint("Failed to load animation for head bag removal")
        return
    end
    
    -- Play animation
    TaskPlayAnim(playerPed, 'mp_arresting', 'a_uncuff', 8.0, -8.0, 3300, 0, 0, false, false, false)
    
    -- Update local state BEFORE prop removal
    baggedPlayers[targetId] = nil
    debugPrint("Updated local baggedPlayers - removed " .. targetId)
    
    -- Remove prop if it exists with enhanced cleanup
    if playerProps[targetId] then
        debugPrint("Removing prop for player " .. targetId .. ": " .. tostring(playerProps[targetId]))
        removeHeadBagProp(playerProps[targetId])
        playerProps[targetId] = nil
        debugPrint("Cleaned up playerProps for " .. targetId)
    end
    
    -- Trigger server event
    TriggerServerEvent('head_bag:server:removeBag', targetId)
    
    Wait(3300)
    
    -- Force refresh the targeting system after removal
    CreateThread(function()
        Wait(1000) -- Give time for server sync
        TriggerServerEvent('head_bag:server:requestBaggedPlayers')
    end)
end

-- Setup ox_target for players with enhanced state checking
local function setupPlayerTargeting()
    if not exports.ox_target then
        errorPrint("ox_target not found")
        return
    end
    
    exports.ox_target:addGlobalPlayer({
        {
            name = 'apply_head_bag',
            icon = 'fas fa-mask',
            label = 'Apply Head Bag',
            items = 'head_bag',
            distance = 2.0,
            canInteract = function(entity, distance, coords, name, bone)
                if not entity then return false end
                
                local targetPlayer = NetworkGetPlayerIndexFromPed(entity)
                if targetPlayer == -1 then return false end
                
                local targetId = GetPlayerServerId(targetPlayer)
                if not targetId then return false end
                
                -- Check both local state and prop existence
                local isBagged = baggedPlayers[targetId] ~= nil
                local hasProp = playerProps[targetId] ~= nil and DoesEntityExist(playerProps[targetId])
                
                -- Debug with more info
                debugPrint("Apply bag check - TargetID: " .. targetId .. ", IsBagged: " .. tostring(isBagged) .. ", HasProp: " .. tostring(hasProp))
                
                return not isBagged and not hasProp
            end,
            onSelect = function(data)
                if not data.entity then return end
                local targetPlayer = NetworkGetPlayerIndexFromPed(data.entity)
                if targetPlayer == -1 then return end
                local targetId = GetPlayerServerId(targetPlayer)
                if targetId then
                    debugPrint("Applying bag to: " .. targetId)
                    applyHeadBag(targetId)
                end
            end
        },
        {
            name = 'remove_head_bag',
            icon = 'fas fa-hand',
            label = 'Remove Head Bag',
            distance = 2.0,
            canInteract = function(entity, distance, coords, name, bone)
                if not entity then return false end
                
                local targetPlayer = NetworkGetPlayerIndexFromPed(entity)
                if targetPlayer == -1 then return false end
                
                local targetId = GetPlayerServerId(targetPlayer)
                if not targetId then return false end
                
                -- Check both local state and prop existence
                local isBagged = baggedPlayers[targetId] ~= nil
                local hasProp = playerProps[targetId] ~= nil and DoesEntityExist(playerProps[targetId])
                
                -- Debug with more info
                debugPrint("Remove bag check - TargetID: " .. targetId .. ", IsBagged: " .. tostring(isBagged) .. ", HasProp: " .. tostring(hasProp))
                
                return isBagged or hasProp
            end,
            onSelect = function(data)
                if not data.entity then return end
                local targetPlayer = NetworkGetPlayerIndexFromPed(data.entity)
                if targetPlayer == -1 then return end
                local targetId = GetPlayerServerId(targetPlayer)
                if targetId then
                    debugPrint("Removing bag from: " .. targetId)
                    removeHeadBag(targetId)
                end
            end
        }
    })
end

-- Event handlers
RegisterNetEvent('head_bag:client:applyBag', function()
    infoPrint("Received apply bag event for local player")
    applyBagEffects()
end)

RegisterNetEvent('head_bag:client:removeBag', function()
    infoPrint("Received remove bag event for local player")
    removeBagEffects()
end)

-- Enhanced sync bag prop with better cleanup and state management
RegisterNetEvent('head_bag:client:syncBagProp', function(playerId, shouldShow)
    debugPrint("Syncing bag prop for player " .. playerId .. ", show: " .. tostring(shouldShow))
    
    local myServerId = GetPlayerServerId(PlayerId())
    
    -- Handle local player separately with ENHANCED REMOVAL
    if playerId == myServerId then
        if shouldShow then
            -- Only create if we don't already have one
            if not headBagProp or not DoesEntityExist(headBagProp) then
                local playerPed = PlayerPedId()
                headBagProp = createHeadBagProp(playerPed)
                debugPrint("Created headBagProp for local player: " .. tostring(headBagProp))
            end
        else
            -- ENHANCED LOCAL PLAYER CLEANUP
            debugPrint("Enhanced cleanup for local player")
            
            -- Remove local player's head bag prop
            if headBagProp and DoesEntityExist(headBagProp) then
                debugPrint("Removing local player's headBagProp: " .. tostring(headBagProp))
                removeHeadBagProp(headBagProp)
                headBagProp = nil
                debugPrint("Removed local player's headBagProp")
            end
            
            -- Also clean up from playerProps if somehow it exists there
            if playerProps[playerId] and DoesEntityExist(playerProps[playerId]) then
                debugPrint("Cleaning up local player from playerProps: " .. tostring(playerProps[playerId]))
                removeHeadBagProp(playerProps[playerId])
                playerProps[playerId] = nil
                debugPrint("Cleaned up local player from playerProps")
            end
            
            -- ADDITIONAL: Force scan and remove any bag props attached to local player
            CreateThread(function()
                Wait(50)
                local playerPed = PlayerPedId()
                local cleanedCount = 0
                
                -- Method 1: Check all objects in area
                local handle, obj = FindFirstObject()
                local success
                local objectsToClean = {}
                
                repeat
                    if DoesEntityExist(obj) then
                        local model = GetEntityModel(obj)
                        local bagModel = GetHashKey("prop_money_bag_01")
                        
                        if model == bagModel then
                            -- Check if it's attached to local player
                            if IsEntityAttachedToEntity(obj, playerPed) then
                                debugPrint("Found bag prop attached to local player: " .. tostring(obj))
                                table.insert(objectsToClean, obj)
                            end
                        end
                    end
                    success, obj = FindNextObject(handle)
                until not success
                
                EndFindObject(handle)
                
                -- Clean up found objects
                for _, objToClean in ipairs(objectsToClean) do
                    debugPrint("Force cleaning attached bag object: " .. tostring(objToClean))
                    removeHeadBagProp(objToClean)
                    cleanedCount = cleanedCount + 1
                end
                
                if cleanedCount > 0 then
                    infoPrint("Enhanced cleanup removed " .. cleanedCount .. " additional bag props from local player")
                end
            end)
        end
        return
    end
    
    -- Handle other players
    local targetPlayer = GetPlayerFromServerId(playerId)
    if targetPlayer == -1 then
        debugPrint("Target player " .. playerId .. " not found for prop sync")
        -- Clean up the prop if player is not found (disconnected)
        if playerProps[playerId] and DoesEntityExist(playerProps[playerId]) then
            debugPrint("Cleaning up prop for disconnected player: " .. tostring(playerProps[playerId]))
            removeHeadBagProp(playerProps[playerId])
            playerProps[playerId] = nil
            debugPrint("Cleaned up prop for disconnected player " .. playerId)
        end
        return
    end
    
    local targetPed = GetPlayerPed(targetPlayer)
    if not targetPed or targetPed == 0 then
        debugPrint("Target ped not found for player " .. playerId)
        return
    end
    
    if shouldShow then
        -- Remove existing prop first if it exists
        if playerProps[playerId] and DoesEntityExist(playerProps[playerId]) then
            debugPrint("Removing existing prop before creating new one")
            removeHeadBagProp(playerProps[playerId])
            playerProps[playerId] = nil
            Wait(100) -- Give time for cleanup
        end
        
        -- Create new prop
        playerProps[playerId] = createHeadBagProp(targetPed)
        debugPrint("Created head bag prop for player " .. playerId .. ": " .. tostring(playerProps[playerId]))
    else
        -- Remove prop if it exists
        if playerProps[playerId] and DoesEntityExist(playerProps[playerId]) then
            debugPrint("Removing head bag prop for player " .. playerId .. ": " .. tostring(playerProps[playerId]))
            removeHeadBagProp(playerProps[playerId])
            playerProps[playerId] = nil
            debugPrint("Removed head bag prop for player " .. playerId)
        else
            debugPrint("No head bag prop to remove for player " .. playerId)
        end
    end
end)

-- Enhanced event handler for updating bagged players with state validation
RegisterNetEvent('head_bag:client:updateBaggedPlayers', function(players)
    debugPrint("Updating bagged players list")
    if type(players) == 'table' then
        -- Update the table
        baggedPlayers = {}
        for playerId, appliedBy in pairs(players) do
            baggedPlayers[playerId] = appliedBy
        end
        
        debugPrint("Updated baggedPlayers:")
        for playerId, appliedBy in pairs(baggedPlayers) do
            debugPrint("  - Player " .. playerId .. " bagged by " .. tostring(appliedBy))
        end
        
        -- Clean up props for players no longer bagged
        for playerId, prop in pairs(playerProps) do
            if not baggedPlayers[playerId] and DoesEntityExist(prop) then
                debugPrint("Cleaning up orphaned prop for player " .. playerId)
                removeHeadBagProp(prop)
                playerProps[playerId] = nil
            end
        end
    else
        errorPrint("Invalid bagged players data received: " .. type(players))
    end
end)

-- FIXED DEBUG TOGGLE COMMAND
RegisterCommand('bagdebug', function(source, args, rawCommand)
    debugEnabled = not debugEnabled
    local status = debugEnabled and "enabled" or "disabled"
    lib.notify({
        title = 'Head Bag Debug',
        description = 'Debug mode ' .. status,
        type = 'inform'
    })
    print("[INFO] Head bag debug mode " .. status)
    print("[INFO] debugEnabled = " .. tostring(debugEnabled))
end, false)

-- Add debug command to check bagged players state (only works when debug is enabled)
RegisterCommand('checkbags', function()
    if not debugEnabled then
        lib.notify({
            title = 'Head Bag Debug',
            description = 'Debug mode is disabled. Use /bagdebug to enable.',
            type = 'error'
        })
        return
    end
    
    print("[DEBUG] Current baggedPlayers state:")
    for playerId, appliedBy in pairs(baggedPlayers) do
        print("  - Player " .. playerId .. " bagged by " .. tostring(appliedBy))
    end
    print("[DEBUG] My bagged state: " .. tostring(isBagged))
    print("[DEBUG] My headBagProp exists: " .. tostring(headBagProp ~= nil and DoesEntityExist(headBagProp)))
    print("[DEBUG] Current props:")
    for playerId, prop in pairs(playerProps) do
        print("  - Player " .. playerId .. " has prop: " .. tostring(DoesEntityExist(prop)) .. " (" .. tostring(prop) .. ")")
    end
    print("[DEBUG] debugEnabled = " .. tostring(debugEnabled))
end, false)

-- Enhanced cleanup command (only works when debug is enabled)
RegisterCommand('cleanbags', function()
    if not debugEnabled then
        lib.notify({
            title = 'Head Bag Debug',
            description = 'Debug mode is disabled. Use /bagdebug to enable.',
            type = 'error'
        })
        return
    end
    
    print("[DEBUG] Manually cleaning up all bag states")
    
    -- Reset local state
    isBagged = false
    if headBagProp and DoesEntityExist(headBagProp) then
        print("[DEBUG] Cleaning local headBagProp: " .. tostring(headBagProp))
        removeHeadBagProp(headBagProp)
        headBagProp = nil
    end
    
    -- Clean up all player props
    for playerId, prop in pairs(playerProps) do
        if prop and DoesEntityExist(prop) then
            print("[DEBUG] Cleaning playerProp for " .. playerId .. ": " .. tostring(prop))
            removeHeadBagProp(prop)
        end
    end
    playerProps = {}
    baggedPlayers = {}
    
    -- Request fresh state from server
    TriggerServerEvent('head_bag:server:requestBaggedPlayers')
    
    print("[DEBUG] Cleanup complete, requested fresh state from server")
end, false)

-- FORCE PROP CLEANUP COMMAND - ALWAYS AVAILABLE BUT WITH QUIETER OUTPUT
RegisterCommand('forcecleanprops', function()
    local cleanedProps = 0
    
    -- Get all objects in area and remove any bag props
    local playerCoords = GetEntityCoords(PlayerPedId())
    local handle, object = FindFirstObject()
    local success
    
    repeat
        if DoesEntityExist(object) then
            local model = GetEntityModel(object)
            local modelName = GetHashKey("prop_money_bag_01")
            
            if model == modelName then
                local objCoords = GetEntityCoords(object)
                local distance = #(playerCoords - objCoords)
                
                if distance < 50.0 then -- Within 50 units
                    if debugEnabled then
                        print("[FORCE CLEAN] Found bag prop, attempting removal: " .. tostring(object))
                    end
                    SetEntityAsMissionEntity(object, true, true)
                    DetachEntity(object, true, true)
                    DeleteObject(object)
                    DeleteEntity(object)
                    cleanedProps = cleanedProps + 1
                end
            end
        end
        success, object = FindNextObject(handle)
    until not success
    
    EndFindObject(handle)
    
    -- Reset all local state
    headBagProp = nil
    playerProps = {}
    
    -- Only print if debug is enabled or if props were actually cleaned
    if debugEnabled or cleanedProps > 0 then
        print("[FORCE CLEAN] Force prop cleanup complete - removed " .. cleanedProps .. " props")
    end
    
    lib.notify({
        title = 'Head Bag System',
        description = 'Force cleaned ' .. cleanedProps .. ' bag props',
        type = 'success'
    })
end, false)

-- Clean up props when players disconnect
AddEventHandler('playerDropped', function(reason)
    local playerId = source
    if playerProps[playerId] and DoesEntityExist(playerProps[playerId]) then
        infoPrint("Cleaning up prop for disconnected player " .. playerId)
        removeHeadBagProp(playerProps[playerId])
        playerProps[playerId] = nil
    end
    
    -- Also remove from bagged players
    if baggedPlayers[playerId] then
        baggedPlayers[playerId] = nil
        infoPrint("Removed disconnected player " .. playerId .. " from bagged players")
    end
end)

-- Enhanced resource start initialization
CreateThread(function()
    Wait(2000) -- Wait for other resources to load
    
    -- Clean up any existing state first
    if debugEnabled then
        print("[INFO] Initializing head bag system...")
    end
    
    isBagged = false
    if headBagProp and DoesEntityExist(headBagProp) then
        removeHeadBagProp(headBagProp)
        headBagProp = nil
    end
    
    -- Clean up all player props
    for playerId, prop in pairs(playerProps) do
        if prop and DoesEntityExist(prop) then
            removeHeadBagProp(prop)
        end
    end
    playerProps = {}
    baggedPlayers = {}
    
    -- Request current bagged players state from server
    TriggerServerEvent('head_bag:server:requestBaggedPlayers')
    
    -- Setup targeting after getting state
    Wait(1000)
    setupPlayerTargeting()
    
    -- Only show initialization messages if debug is enabled
    if debugEnabled then
        print("[INFO] Head bag targeting system initialized")
        print("[INFO] Debug mode is currently: enabled")
        print("[INFO] Use /bagdebug to toggle debug mode")
        print("[INFO] Use /forcecleanprops to force clean bag props (always available)")
    end
end)