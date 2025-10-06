local QBX = exports.qbx_core
local zipTiedPlayers = {}

-- Function to sync zip tied players to all clients
local function syncZipTiedPlayers()
    local simplifiedData = {}
    for playerId, _ in pairs(zipTiedPlayers) do
        simplifiedData[playerId] = true
    end
    TriggerClientEvent('qbx_zipties:client:syncZipTiedPlayers', -1, simplifiedData)
end

-- Function to check if player has zip ties
local function hasZipTies(source)
    return exports.ox_inventory:Search(source, 'count', Config.ZipTieItem) > 0
end

-- Function to check if player has bolt cutters
local function hasBoltCutters(source)
    return exports.ox_inventory:Search(source, 'count', Config.BoltCutterItem) > 0
end

-- Function to check if player is police
local function isPolice(source)
    local player = QBX:GetPlayer(source)
    if not player or not player.PlayerData.job then return false end
    
    for _, job in pairs(Config.PoliceJobs) do
        if player.PlayerData.job.name == job then
            return true
        end
    end
    return false
end

-- Function to check if player can cut zip ties
local function canCutZipTies(source)
    return isPolice(source) or hasBoltCutters(source)
end

-- Apply zip ties event
RegisterNetEvent('qbx_zipties:server:applyZipTies', function(targetId)
    local src = source
    local target = tonumber(targetId)
    
    if not target or target == src then return end
    
    -- Validate player has zip ties
    if not hasZipTies(src) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'You don\'t have zip ties',
            type = 'error'
        })
        return
    end
    
    -- Check if target is already zip tied
    if zipTiedPlayers[target] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Target is already zip tied',
            type = 'error'
        })
        return
    end
    
    -- Apply zip ties
    zipTiedPlayers[target] = {
        appliedBy = src,
        timestamp = os.time()
    }
    
    TriggerClientEvent('qbx_zipties:client:setZipTied', target, true, src)
    syncZipTiedPlayers()
    
    -- Log the action
    local srcPlayer = QBX:GetPlayer(src)
    local targetPlayer = QBX:GetPlayer(target)
    
    if srcPlayer and targetPlayer then
        print(string.format('[ZIP TIES] %s (%s) applied zip ties to %s (%s)', 
            srcPlayer.PlayerData.charinfo.firstname .. ' ' .. srcPlayer.PlayerData.charinfo.lastname,
            srcPlayer.PlayerData.citizenid,
            targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname,
            targetPlayer.PlayerData.citizenid
        ))
    end
end)

-- Remove zip ties event
RegisterNetEvent('qbx_zipties:server:removeZipTies', function(targetId)
    local src = source
    local target = tonumber(targetId)
    
    if not target then return end
    
    -- Check if player can cut zip ties (police or has bolt cutters)
    if not canCutZipTies(src) then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'You cannot cut zip ties without proper tools',
            type = 'error'
        })
        return
    end
    
    -- Check if target is zip tied
    if not zipTiedPlayers[target] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Error',
            description = 'Target is not zip tied',
            type = 'error'
        })
        return
    end
    
    -- Remove zip ties
    zipTiedPlayers[target] = nil
    TriggerClientEvent('qbx_zipties:client:setZipTied', target, false, nil)
    syncZipTiedPlayers()
    
    -- Log the action
    local srcPlayer = QBX:GetPlayer(src)
    local targetPlayer = QBX:GetPlayer(target)
    local method = isPolice(src) and "police authority" or "bolt cutters"
    
    if srcPlayer and targetPlayer then
        print(string.format('[ZIP TIES] %s (%s) removed zip ties from %s (%s) using %s', 
            srcPlayer.PlayerData.charinfo.firstname .. ' ' .. srcPlayer.PlayerData.charinfo.lastname,
            srcPlayer.PlayerData.citizenid,
            targetPlayer.PlayerData.charinfo.firstname .. ' ' .. targetPlayer.PlayerData.charinfo.lastname,
            targetPlayer.PlayerData.citizenid,
            method
        ))
    end
end)

-- Remove zip tie item event
RegisterNetEvent('qbx_zipties:server:removeZipTie', function()
    local src = source
    exports.ox_inventory:RemoveItem(src, Config.ZipTieItem, 1)
end)

-- Remove bolt cutter item event
RegisterNetEvent('qbx_zipties:server:removeBoltCutter', function()
    local src = source
    exports.ox_inventory:RemoveItem(src, Config.BoltCutterItem, 1)
end)

-- Clean up when player leaves
AddEventHandler('playerDropped', function(reason)
    local src = source
    if zipTiedPlayers[src] then
        zipTiedPlayers[src] = nil
        syncZipTiedPlayers()
    end
end)

-- Send zip tied players list when player joins
AddEventHandler('playerJoining', function()
    local src = source
    local simplifiedData = {}
    for playerId, _ in pairs(zipTiedPlayers) do
        simplifiedData[playerId] = true
    end
    TriggerClientEvent('qbx_zipties:client:syncZipTiedPlayers', src, simplifiedData)
end)

-- Export functions
exports('isPlayerZipTied', function(playerId)
    return zipTiedPlayers[playerId] ~= nil
end)

exports('getZipTieInfo', function(playerId)
    return zipTiedPlayers[playerId]
end)

exports('removeZipTies', function(playerId)
    if zipTiedPlayers[playerId] then
        zipTiedPlayers[playerId] = nil
        TriggerClientEvent('qbx_zipties:client:setZipTied', playerId, false, nil)
        syncZipTiedPlayers()
        return true
    end
    return false
end)