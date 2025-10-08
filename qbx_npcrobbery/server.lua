-- QBX NPC Robbery - Server Script
local activeRobberies = {}

-- Function to rob items from player
local function RobPlayer(source)
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then return {} end
    
    local robbedItems = {}
    local inventory = exports.ox_inventory:GetInventory(source)
    
    if not inventory then return {} end
    
    -- Check for cash first
    local cash = Player.Functions.GetMoney('cash')
    if cash > 0 then
        local amountToRob = math.random(Config.MinCashAmount, math.min(Config.MaxCashAmount, cash))
        Player.Functions.RemoveMoney('cash', amountToRob)
        table.insert(robbedItems, {name = 'Cash', amount = amountToRob, itemName = 'cash'})
    end
    
    -- Rob random items from the player's inventory
    for _, itemName in ipairs(Config.RobbableItems) do
        if itemName ~= 'money' then
            local itemCount = exports.ox_inventory:GetItem(source, itemName, nil, true)
            if itemCount and itemCount > 0 then
                local amountToRob = math.random(1, itemCount)
                local success = exports.ox_inventory:RemoveItem(source, itemName, amountToRob)
                if success then
                    -- Get item data for the label
                    local itemData = exports.ox_inventory:Items(itemName)
                    local itemLabel = itemData and itemData.label or itemName
                    table.insert(robbedItems, {name = itemLabel, amount = amountToRob, itemName = itemName})
                end
            end
        end
    end
    
    return robbedItems
end

-- Event to initiate robbery
RegisterNetEvent('qbx_npcrobbery:server:initiateRobbery', function()
    local source = source
    local Player = exports.qbx_core:GetPlayer(source)
    
    if not Player then return end
    
    -- Check if player is already being robbed
    if activeRobberies[source] then
        return
    end
    
    -- Check if player's job is exempt from robberies
    if Player.PlayerData.job and Player.PlayerData.job.name then
        for _, job in ipairs(Config.ExemptJobs) do
            if Player.PlayerData.job.name == job then
                return
            end
        end
    end
    
    -- Roll for robbery chance
    local roll = math.random(1, 100)
    if roll > Config.RobberyChance then
        return
    end
    
    -- Mark player as being robbed
    activeRobberies[source] = {
        startTime = os.time(),
        completed = false,
        stolenItems = {}
    }
    
    -- Trigger client-side robbery sequence
    TriggerClientEvent('qbx_npcrobbery:client:startRobbery', source)
end)

-- Event when player catches the NPC
RegisterNetEvent('qbx_npcrobbery:server:npcCaught', function()
    local source = source
    
    if not activeRobberies[source] then 
        return 
    end
    
    -- Check if items were already stolen
    local stolenItems = activeRobberies[source].stolenItems or {}
    
    -- Player caught the NPC
    local Player = exports.qbx_core:GetPlayer(source)
    if Player then
        -- Return stolen items if any
        if #stolenItems > 0 then
            for _, item in ipairs(stolenItems) do
                if item.itemName == 'cash' or item.name == 'Cash' then
                    Player.Functions.AddMoney('cash', item.amount)
                else
                    exports.ox_inventory:AddItem(source, item.itemName, item.amount)
                end
            end
            
            -- Build item list for notification
            local itemList = ''
            for i, item in ipairs(stolenItems) do
                itemList = itemList .. item.amount .. 'x ' .. item.name
                if i < #stolenItems then
                    itemList = itemList .. ', '
                end
            end
            
            local message = string.format('%s You got your items back: %s', Config.Notifications.RobberyCaught, itemList)
            exports.qbx_core:Notify(source, message, 'success')
        else
            -- No items stolen yet, just give bonus
            local rewardAmount = math.random(Config.MinRewardAmount, Config.MaxRewardAmount)
            Player.Functions.AddMoney('cash', rewardAmount)
            local message = string.format('%s You found $%d on them!', Config.Notifications.RobberyCaught, rewardAmount)
            exports.qbx_core:Notify(source, message, 'success')
        end
    end
    
    activeRobberies[source] = nil
end)

-- Event when NPC successfully robs player (during the animation)
RegisterNetEvent('qbx_npcrobbery:server:robberyInProgress', function()
    local source = source
    
    if not activeRobberies[source] then 
        return 
    end
    
    -- Rob the player now (during the robbery animation)
    local robbedItems = RobPlayer(source)
    activeRobberies[source].stolenItems = robbedItems
    
    if #robbedItems > 0 then
        local itemList = ''
        for i, item in ipairs(robbedItems) do
            itemList = itemList .. item.amount .. 'x ' .. item.name
            if i < #robbedItems then
                itemList = itemList .. ', '
            end
        end
        exports.qbx_core:Notify(source, 'The robber stole: ' .. itemList, 'error')
    else
        exports.qbx_core:Notify(source, Config.Notifications.NoValuables, 'error')
    end
end)

-- Event when NPC successfully robs player and escapes
RegisterNetEvent('qbx_npcrobbery:server:robberyComplete', function()
    local source = source
    
    if not activeRobberies[source] then 
        return 
    end
    
    -- Just clean up - items were already taken during robberyInProgress
    activeRobberies[source] = nil
end)

-- Event when player gets stabbed
RegisterNetEvent('qbx_npcrobbery:server:playerStabbed', function()
    local source = source
    
    if not activeRobberies[source] then return end
    
    -- Rob the player now (when they get stabbed)
    local robbedItems = RobPlayer(source)
    activeRobberies[source] = nil
    
    -- Trigger client to handle the down mechanic
    TriggerClientEvent('qbx_npcrobbery:client:getStabbed', source)
    
    if #robbedItems > 0 then
        local itemList = ''
        for i, item in ipairs(robbedItems) do
            itemList = itemList .. item.amount .. 'x ' .. item.name
            if i < #robbedItems then
                itemList = itemList .. ', '
            end
        end
        exports.qbx_core:Notify(source, Config.Notifications.RobberyStabbed .. itemList, 'error')
    end
end)

-- Admin command to test robbery
lib.addCommand('testrobbery', {
    help = 'Test the NPC robbery system (Admin Only)',
    restricted = 'group.admin'
}, function(source, args, raw)
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then 
        return 
    end
    
    -- Don't rob yet - just mark as being robbed
    activeRobberies[source] = {
        startTime = os.time(),
        completed = false,
        stolenItems = {}
    }
    
    TriggerClientEvent('qbx_npcrobbery:client:startRobbery', source)
end)

-- Backup command using RegisterCommand
RegisterCommand('forcerobbery', function(source, args, rawCommand)
    if source == 0 then
        return
    end
    
    -- Check if player has admin permission via ACE
    if not IsPlayerAceAllowed(source, 'command.forcerobbery') then
        exports.qbx_core:Notify(source, 'You do not have permission to use this command', 'error')
        return
    end
    
    local Player = exports.qbx_core:GetPlayer(source)
    if not Player then 
        return 
    end
    
    -- Don't rob yet - just mark as being robbed
    activeRobberies[source] = {
        startTime = os.time(),
        completed = false,
        stolenItems = {}
    }
    
    TriggerClientEvent('qbx_npcrobbery:client:startRobbery', source)
end, false)