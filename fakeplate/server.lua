local QBX = exports.qbx_core
local activeFakePlates = {} -- [vehicleNetId] = {originalPlate, fakePlate, owner}

-- Create database table on resource start
CreateThread(function()
    MySQL.query([[
        CREATE TABLE IF NOT EXISTS fake_plates (
            id INT AUTO_INCREMENT PRIMARY KEY,
            vehicle_plate VARCHAR(10) NOT NULL UNIQUE,
            original_plate VARCHAR(10) NOT NULL,
            fake_plate VARCHAR(10) NOT NULL,
            owner VARCHAR(50) NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ]])
end)

-- Load all fake plates from database on startup
CreateThread(function()
    Wait(1000) -- Wait for database
    local result = MySQL.query.await('SELECT * FROM fake_plates')
    if result then
        for _, row in ipairs(result) do
            activeFakePlates[row.vehicle_plate] = {
                originalPlate = row.original_plate,
                fakePlate = row.fake_plate,
                owner = row.owner
            }
        end
        print('[FakePlate] Loaded ' .. #result .. ' fake plates from database')
    end
end)

-- Generate random plate
local function GenerateRandomPlate()
    local plate = ''
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    
    for i = 1, 8 do
        local rand = math.random(1, #chars)
        plate = plate .. chars:sub(rand, rand)
    end
    
    return plate
end

-- Get or create fake plate for a vehicle
local function GetFakePlate(originalPlate)
    -- Check if this vehicle already has a fake plate assigned
    if activeFakePlates[originalPlate] then
        return activeFakePlates[originalPlate].fakePlate
    end
    
    -- Generate new unique fake plate
    local fakePlate = GenerateRandomPlate()
    local attempts = 0
    
    -- Ensure it's unique
    while true do
        local exists = false
        for _, data in pairs(activeFakePlates) do
            if data.fakePlate == fakePlate then
                exists = true
                break
            end
        end
        
        if not exists then
            break
        end
        
        fakePlate = GenerateRandomPlate()
        attempts = attempts + 1
        
        if attempts > 100 then
            print('[FakePlate] ERROR: Could not generate unique plate')
            return nil
        end
    end
    
    return fakePlate
end

-- Update inventory storage keys
local function UpdateInventoryKeys(oldPlate, newPlate)
    -- Trim whitespace
    oldPlate = string.gsub(oldPlate, '^%s*(.-)%s*$', '%1')
    newPlate = string.gsub(newPlate, '^%s*(.-)%s*$', '%1')
    
    -- ox_inventory support
    if GetResourceState('ox_inventory') == 'started' then
        local oldStashId = 'trunk_' .. oldPlate
        local newStashId = 'trunk_' .. newPlate
        
        MySQL.update('UPDATE ox_inventory SET name = ? WHERE name = ?', {
            newStashId,
            oldStashId
        })
        
        local oldGloveboxId = 'glovebox_' .. oldPlate
        local newGloveboxId = 'glovebox_' .. newPlate
        
        MySQL.update('UPDATE ox_inventory SET name = ? WHERE name = ?', {
            newGloveboxId,
            oldGloveboxId
        })
        
        print('[FakePlate] Updated ox_inventory storage from ' .. oldPlate .. ' to ' .. newPlate)
    end
    
    -- qb-inventory / qs-inventory support
    if GetResourceState('qb-inventory') == 'started' or GetResourceState('qs-inventory') == 'started' then
        MySQL.update('UPDATE trunkitems SET plate = ? WHERE plate = ?', {
            newPlate,
            oldPlate
        })
        
        MySQL.update('UPDATE gloveboxitems SET plate = ? WHERE plate = ?', {
            newPlate,
            oldPlate
        })
        
        print('[FakePlate] Updated qb/qs-inventory storage from ' .. oldPlate .. ' to ' .. newPlate)
    end
    
    -- ps-inventory support
    if GetResourceState('ps-inventory') == 'started' then
        MySQL.update('UPDATE trunkitems SET plate = ? WHERE plate = ?', {
            newPlate,
            oldPlate
        })
        
        MySQL.update('UPDATE gloveboxitems SET plate = ? WHERE plate = ?', {
            newPlate,
            oldPlate
        })
        
        print('[FakePlate] Updated ps-inventory storage from ' .. oldPlate .. ' to ' .. newPlate)
    end
end

-- Apply fake plate
RegisterNetEvent('fakeplate:server:applyPlate', function(netId, originalPlate)
    local src = source
    local Player = QBX:GetPlayer(src)
    
    if not Player then return end
    
    originalPlate = string.gsub(originalPlate, '^%s*(.-)%s*$', '%1') -- Trim whitespace
    
    print('[FakePlate] Attempting to apply fake plate to: ' .. originalPlate .. ' (NetID: ' .. netId .. ')')
    
    -- Check if player has fake plate item
    local item = Player.Functions.GetItemByName(Config.FakePlateItem)
    if not item or item.amount < 1 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Fake Plates',
            description = 'You do not have a fake plate',
            type = 'error'
        })
        return
    end
    
    -- Check if already has fake plate
    if activeFakePlates[originalPlate] then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Fake Plates',
            description = 'This vehicle already has a fake plate',
            type = 'error'
        })
        return
    end
    
    -- Generate fake plate
    local fakePlate = GetFakePlate(originalPlate)
    if not fakePlate then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Fake Plates',
            description = 'Failed to generate fake plate',
            type = 'error'
        })
        return
    end
    
    print('[FakePlate] Generated fake plate: ' .. fakePlate)
    
    -- Remove item
    if not Player.Functions.RemoveItem(Config.FakePlateItem, 1) then
        return
    end
    
    -- Store in memory and database
    activeFakePlates[originalPlate] = {
        originalPlate = originalPlate,
        fakePlate = fakePlate,
        owner = Player.PlayerData.citizenid
    }
    
    MySQL.insert('INSERT INTO fake_plates (vehicle_plate, original_plate, fake_plate, owner) VALUES (?, ?, ?, ?)', {
        originalPlate,
        originalPlate,
        fakePlate,
        Player.PlayerData.citizenid
    })
    
    print('[FakePlate] Updating vehicle plate to: ' .. fakePlate)
    
    -- Get the vehicle entity server-side and update it
    local veh = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(veh) then
        SetVehicleNumberPlateText(veh, fakePlate)
        print('[FakePlate] Server-side plate updated')
    end
    
    -- Update the vehicle's plate for all clients
    TriggerClientEvent('fakeplate:client:updatePlate', -1, netId, fakePlate)
    
    -- Update plate in player_vehicles table if it exists
    MySQL.update('UPDATE player_vehicles SET plate = ? WHERE plate = ?', {
        fakePlate,
        originalPlate
    })
    
    -- Update inventory storage keys
    UpdateInventoryKeys(originalPlate, fakePlate)
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Fake Plates',
        description = 'Fake plate applied: ' .. fakePlate,
        type = 'success'
    })
end)

-- Remove fake plate
RegisterNetEvent('fakeplate:server:removePlate', function(netId)
    local src = source
    local Player = QBX:GetPlayer(src)
    
    if not Player then return end
    
    -- Check if player has remover item
    local item = Player.Functions.GetItemByName(Config.FakePlateRemoverItem)
    if not item or item.amount < 1 then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Fake Plates',
            description = 'You do not have a fake plate remover',
            type = 'error'
        })
        return
    end
    
    local veh = NetworkGetEntityFromNetworkId(netId)
    local currentPlate = GetVehicleNumberPlateText(veh)
    currentPlate = string.gsub(currentPlate, '^%s*(.-)%s*$', '%1')
    
    -- Find the original plate
    local originalPlate = nil
    for plate, data in pairs(activeFakePlates) do
        if data.fakePlate == currentPlate then
            originalPlate = plate
            break
        end
    end
    
    if not originalPlate then
        TriggerClientEvent('ox_lib:notify', src, {
            title = 'Fake Plates',
            description = 'This vehicle does not have a fake plate',
            type = 'error'
        })
        return
    end
    
    -- Remove item
    if not Player.Functions.RemoveItem(Config.FakePlateRemoverItem, 1) then
        return
    end
    
    -- Remove from memory and database
    activeFakePlates[originalPlate] = nil
    MySQL.query('DELETE FROM fake_plates WHERE vehicle_plate = ?', {originalPlate})
    
    -- Update the vehicle's plate back to original for all clients
    TriggerClientEvent('fakeplate:client:updatePlate', -1, netId, originalPlate)
    
    -- Restore original plate in player_vehicles table
    MySQL.update('UPDATE player_vehicles SET plate = ? WHERE plate = ?', {
        originalPlate,
        currentPlate
    })
    
    -- Restore inventory storage keys
    UpdateInventoryKeys(currentPlate, originalPlate)
    
    TriggerClientEvent('ox_lib:notify', src, {
        title = 'Fake Plates',
        description = 'Fake plate removed successfully',
        type = 'success'
    })
end)

-- Check if vehicle has active fake plate
lib.callback.register('fakeplate:server:hasActiveFakePlate', function(source, netId)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if not DoesEntityExist(veh) then return false end
    
    local plate = GetVehicleNumberPlateText(veh)
    plate = string.gsub(plate, '^%s*(.-)%s*$', '%1')
    
    -- Check if this is an original plate with fake plate applied
    if activeFakePlates[plate] then
        return true
    end
    
    -- Check if this is a fake plate
    for _, data in pairs(activeFakePlates) do
        if data.fakePlate == plate then
            return true
        end
    end
    
    return false
end)

-- Get original plate from fake plate (for police/ANPR bypass)
lib.callback.register('fakeplate:server:getOriginalPlate', function(source, plate)
    plate = string.gsub(plate, '^%s*(.-)%s*$', '%1')
    
    -- If it's an original plate with fake applied
    if activeFakePlates[plate] then
        return activeFakePlates[plate].fakePlate
    end
    
    -- If it's a fake plate, return nothing (ANPR won't find it)
    for _, data in pairs(activeFakePlates) do
        if data.fakePlate == plate then
            return nil -- Return nil so ANPR doesn't find the vehicle
        end
    end
    
    return plate -- Return original if no fake plate
end)

-- Export for other resources to check fake plates
exports('GetOriginalPlate', function(plate)
    plate = string.gsub(plate, '^%s*(.-)%s*$', '%1')
    
    for originalPlate, data in pairs(activeFakePlates) do
        if data.fakePlate == plate then
            return originalPlate
        end
    end
    
    return plate
end)

exports('IsFakePlate', function(plate)
    plate = string.gsub(plate, '^%s*(.-)%s*$', '%1')
    
    for _, data in pairs(activeFakePlates) do
        if data.fakePlate == plate then
            return true
        end
    end
    
    return false
end)

-- When vehicle spawns, check if it should have fake plate
AddEventHandler('entityCreated', function(entity)
    if GetEntityType(entity) ~= 2 then return end -- Only vehicles
    
    Wait(500) -- Wait for vehicle to be fully spawned
    
    -- Check if entity still exists after wait
    if not DoesEntityExist(entity) then return end
    
    local plate = GetVehicleNumberPlateText(entity)
    if not plate then return end
    
    plate = string.gsub(plate, '^%s*(.-)%s*$', '%1')
    
    -- Check if this vehicle should have a fake plate
    if activeFakePlates[plate] then
        local netId = NetworkGetNetworkIdFromEntity(entity)
        if netId and netId ~= 0 then
            TriggerClientEvent('fakeplate:client:updatePlate', -1, netId, activeFakePlates[plate].fakePlate)
        end
    end
end)

-- Register useable items
QBX:CreateUseableItem(Config.FakePlateItem, function(source, item)
    local src = source
    TriggerClientEvent('fakeplate:client:applyPlate', src)
end)

QBX:CreateUseableItem(Config.FakePlateRemoverItem, function(source, item)
    local src = source
    TriggerClientEvent('fakeplate:client:removePlate', src)
end)