-- SERVER SIDE FIXES WITH ENHANCED SYNC

local QBX = exports.qbx_core
local baggedPlayers = {}

-- Debug system for server
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

-- Send current bagged players to requesting client with validation
RegisterNetEvent('head_bag:server:requestBaggedPlayers', function()
    local src = source
    
    -- Clean up any invalid players from the bagged list
    local validBaggedPlayers = {}
    for playerId, appliedBy in pairs(baggedPlayers) do
        local player = QBX:GetPlayer(playerId)
        if player then
            validBaggedPlayers[playerId] = appliedBy
        else
            infoPrint("Removing invalid player " .. playerId .. " from bagged list")
        end
    end
    baggedPlayers = validBaggedPlayers
    
    TriggerClientEvent('head_bag:client:updateBaggedPlayers', src, baggedPlayers)
    debugPrint("Sent bagged players list to " .. src)
end)

-- Apply head bag to target with improved validation
RegisterNetEvent('head_bag:server:applyBag', function(targetId)
    local src = source
    local player = QBX:GetPlayer(src)
    local target = QBX:GetPlayer(targetId)
    
    if not player or not target then 
        errorPrint("Invalid player or target for bag application")
        return 
    end
    
    -- Check if target is already bagged
    if baggedPlayers[targetId] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Head Bag',
            description = 'This player already has a head bag',
            type = 'error'
        })
        -- Sync the correct state back to client
        TriggerClientEvent('head_bag:client:updateBaggedPlayers', src, baggedPlayers)
        return
    end
    
    -- Check if player has head bag item
    local hasItem = exports.ox_inventory:GetItemCount(src, 'head_bag')
    if hasItem < 1 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Head Bag',
            description = 'You don\'t have a head bag',
            type = 'error'
        })
        -- Sync the correct state back to client
        TriggerClientEvent('head_bag:client:updateBaggedPlayers', src, baggedPlayers)
        return
    end
    
    -- Remove item (consumed when applied)
    if not exports.ox_inventory:RemoveItem(src, 'head_bag', 1) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Head Bag',
            description = 'Failed to remove head bag from inventory',
            type = 'error'
        })
        return
    end
    
    -- Add to bagged players
    baggedPlayers[targetId] = src -- Store who applied the bag
    
    -- Notify target to apply bag effects FIRST
    TriggerClientEvent('head_bag:client:applyBag', targetId)
    
    -- Wait a moment for client to process
    Wait(100)
    
    -- Then notify all players to show prop on target (for visual sync)
    TriggerClientEvent('head_bag:client:syncBagProp', -1, targetId, true)
    
    -- Update ALL players about bagged status
    TriggerClientEvent('head_bag:client:updateBaggedPlayers', -1, baggedPlayers)
    
    -- Notify players
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Head Bag',
        description = 'Head bag applied successfully',
        type = 'success'
    })
    
    TriggerClientEvent('ox_lib:notify', targetId, {
        title = 'Head Bag',
        description = 'A head bag has been placed over your head',
        type = 'inform'
    })
    
    infoPrint("Head bag applied to player " .. targetId .. " by player " .. src)
end)

-- Remove head bag from target with improved validation and ENHANCED SYNC
RegisterNetEvent('head_bag:server:removeBag', function(targetId)
    local src = source
    local player = QBX:GetPlayer(src)
    local target = QBX:GetPlayer(targetId)
    
    if not player or not target then 
        errorPrint("Invalid player or target for bag removal")
        return 
    end
    
    -- Check if target is actually bagged
    if not baggedPlayers[targetId] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Head Bag',
            description = 'This player doesn\'t have a head bag',
            type = 'error'
        })
        -- Sync the correct state back to client
        TriggerClientEvent('head_bag:client:updateBaggedPlayers', src, baggedPlayers)
        return
    end
    
    -- Return the bag to whoever removes it
    if not exports.ox_inventory:AddItem(src, 'head_bag', 1) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Head Bag',
            description = 'Failed to add head bag to inventory',
            type = 'error'
        })
        return
    end
    
    -- Remove from bagged players FIRST
    baggedPlayers[targetId] = nil
    
    -- ENHANCED REMOVAL SEQUENCE FOR BETTER SYNC
    
    -- 1. Notify target to remove bag effects IMMEDIATELY
    TriggerClientEvent('head_bag:client:removeBag', targetId)
    
    -- 2. Wait a moment for target client to process
    Wait(50)
    
    -- 3. Notify all players to remove prop from target (for visual sync)
    TriggerClientEvent('head_bag:client:syncBagProp', -1, targetId, false)
    
    -- 4. Wait another moment
    Wait(50)
    
    -- 5. Update ALL players about bagged status
    TriggerClientEvent('head_bag:client:updateBaggedPlayers', -1, baggedPlayers)
    
    -- 6. Final sync to target specifically (double-check)
    CreateThread(function()
        Wait(200)
        TriggerClientEvent('head_bag:client:syncBagProp', targetId, targetId, false)
        TriggerClientEvent('head_bag:client:updateBaggedPlayers', targetId, baggedPlayers)
        debugPrint("Final sync sent to target " .. targetId)
    end)
    
    -- Notify players
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Head Bag',
        description = 'Head bag removed and returned to inventory',
        type = 'success'
    })
    
    TriggerClientEvent('ox_lib:notify', targetId, {
        title = 'Head Bag',
        description = 'The head bag has been removed',
        type = 'success'
    })
    
    infoPrint("Head bag removed from player " .. targetId .. " by player " .. src)
end)

-- Send bagged players list to newly connected players
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    local src = source
    Wait(2000) -- Wait for client to fully load
    TriggerClientEvent('head_bag:client:updateBaggedPlayers', src, baggedPlayers)
end)

-- Alternative event for qbx_core
RegisterNetEvent('qbx_core:client:playerLoaded', function()
    local src = source
    Wait(2000)
    TriggerClientEvent('head_bag:client:updateBaggedPlayers', src, baggedPlayers)
end)

-- Clean up on player disconnect with better logging
AddEventHandler('playerDropped', function(reason)
    local src = source
    if baggedPlayers[src] then
        infoPrint("Cleaning up head bag for disconnected player " .. src)
        baggedPlayers[src] = nil
        -- Notify all players to remove prop and update status
        TriggerClientEvent('head_bag:client:syncBagProp', -1, src, false)
        TriggerClientEvent('head_bag:client:updateBaggedPlayers', -1, baggedPlayers)
    end
end)

-- Server debug toggle command (console only)
RegisterCommand('bagdebugserver', function(source, args, rawCommand)
    if source == 0 then -- Server console only
        debugEnabled = not debugEnabled
        local status = debugEnabled and "enabled" or "disabled"
        print("[INFO] Server head bag debug mode " .. status)
        print("[INFO] Server debugEnabled = " .. tostring(debugEnabled))
    end
end, true)

-- Debug command for admins to check server state
RegisterCommand('checkbagsserver', function(source, args, rawCommand)
    if source == 0 then -- Server console only
        print("[DEBUG] Server baggedPlayers state:")
        for playerId, appliedBy in pairs(baggedPlayers) do
            print("  - Player " .. playerId .. " bagged by " .. tostring(appliedBy))
        end
        print("[DEBUG] Server debugEnabled = " .. tostring(debugEnabled))
    end
end, true)

-- Admin command to clear all bags (server console only)
RegisterCommand('clearallbags', function(source, args, rawCommand)
    if source == 0 then -- Server console only
        print("[ADMIN] Clearing all head bags")
        for playerId, appliedBy in pairs(baggedPlayers) do
            -- Notify player to remove bag effects
            TriggerClientEvent('head_bag:client:removeBag', playerId)
            -- Notify all players to remove prop
            TriggerClientEvent('head_bag:client:syncBagProp', -1, playerId, false)
            print("[ADMIN] Removed bag from player " .. playerId)
        end
        -- Clear the table
        baggedPlayers = {}
        -- Update all clients
        TriggerClientEvent('head_bag:client:updateBaggedPlayers', -1, baggedPlayers)
        print("[ADMIN] All head bags cleared")
    end
end, true)

-- ADMIN COMMAND TO FORCE REMOVE BAG FROM SPECIFIC PLAYER
RegisterCommand('forceremoverbag', function(source, args, rawCommand)
    if source == 0 then -- Server console only
        local targetId = tonumber(args[1])
        if not targetId then
            print("[ERROR] Usage: forceremoverbag <player_id>")
            return
        end
        
        local target = QBX:GetPlayer(targetId)
        if not target then
            print("[ERROR] Player " .. targetId .. " not found")
            return
        end
        
        -- Force remove from bagged players
        baggedPlayers[targetId] = nil
        
        -- Send multiple removal events to ensure sync
        TriggerClientEvent('head_bag:client:removeBag', targetId)
        Wait(100)
        TriggerClientEvent('head_bag:client:syncBagProp', -1, targetId, false)
        Wait(100)
        TriggerClientEvent('head_bag:client:updateBaggedPlayers', -1, baggedPlayers)
        
        -- Double-check with specific target sync
        CreateThread(function()
            Wait(500)
            TriggerClientEvent('head_bag:client:syncBagProp', targetId, targetId, false)
            TriggerClientEvent('head_bag:client:updateBaggedPlayers', targetId, baggedPlayers)
        end)
        
        print("[ADMIN] Force removed bag from player " .. targetId)
    end
end, true)