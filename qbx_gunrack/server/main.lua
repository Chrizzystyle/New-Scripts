local QBX = exports.qbx_core

Config = Config or {}
Config.PoliceJobs = Config.PoliceJobs or {'police', 'sheriff', 'statepolice'}
Config.RequireMinimumRank = Config.RequireMinimumRank or false
Config.MinimumRanks = Config.MinimumRanks or {}
Config.MaxSlots = Config.MaxSlots or 20
Config.MaxWeight = Config.MaxWeight or 50000
Config.DefaultItems = Config.DefaultItems or {}
Config.PreRegisterStashes = Config.PreRegisterStashes or {}
Config.Debug = Config.Debug or false

local registeredStashes = {}

local function IsPolice(source)
    local player = QBX:GetPlayer(source)
    if not player or not player.PlayerData.job then return false end
    
    for _, job in pairs(Config.PoliceJobs) do
        if player.PlayerData.job.name == job then
            return true
        end
    end
    return false
end

local function HasMinimumRank(source)
    if not Config.RequireMinimumRank then return true end
    
    local player = QBX:GetPlayer(source)
    if not player or not player.PlayerData.job then return false end
    
    local jobName = player.PlayerData.job.name
    local playerGrade = player.PlayerData.job.grade.level or 0
    local requiredGrade = Config.MinimumRanks[jobName] or 0
    
    return playerGrade >= requiredGrade
end

local function CreateStashId(plate)
    local cleanPlate = plate:gsub("%s+", ""):upper():gsub("[^%w]", "")
    local stashId = 'gunrack_' .. cleanPlate
    
    if Config.Debug then
        print("^3[Gun Rack DEBUG] Created stash ID: " .. stashId .. " from plate: '" .. plate .. "'")
    end
    
    return stashId
end

local function RegisterGunRackStash(stashId, plate, vehicleModel)
    if registeredStashes[stashId] then
        if Config.Debug then
            print("^3[Gun Rack DEBUG] Stash already registered: " .. stashId)
        end
        return true
    end
    
    if Config.Debug then
        print("^2[Gun Rack DEBUG] Registering new stash: " .. stashId .. " for vehicle: " .. (vehicleModel or "unknown"))
    end

    local success, result = pcall(function()
        exports.ox_inventory:RegisterStash(stashId, 'Gun Rack - ' .. plate, Config.MaxSlots, Config.MaxWeight, nil, nil, nil)
    end)
    
    if success then
        registeredStashes[stashId] = {
            plate = plate,
            model = vehicleModel,
            registered = os.time()
        }
        if Config.Debug then
            print("^2[Gun Rack DEBUG] Successfully registered stash: " .. stashId)
        end
        return true
    else
        if Config.Debug then
            print("^1[Gun Rack DEBUG] Failed to register stash: " .. stashId)
            print("^1[Gun Rack DEBUG] Error: " .. tostring(result))
        end
        return false
    end
end

local function AddDefaultItems(stashId)
    if not Config.DefaultItems or #Config.DefaultItems == 0 then
        return
    end
    
    CreateThread(function()

        local inventory = exports.ox_inventory:GetInventory(stashId)
        
        if not inventory or not inventory.items or next(inventory.items) == nil then
            if Config.Debug then
                print("^3[Gun Rack DEBUG] Adding default items to stash: " .. stashId)
            end
            
            for _, item in pairs(Config.DefaultItems) do
                local success, result = pcall(function()
                    return exports.ox_inventory:AddItem(stashId, item.name, item.count or 1, item.metadata or {})
                end)
                
                if success and result then
                    if Config.Debug then
                        print("^2[Gun Rack DEBUG] Added default item: " .. item.name .. " x" .. (item.count or 1))
                    end
                else
                    if Config.Debug then
                        print("^1[Gun Rack DEBUG] Failed to add default item: " .. item.name)
                    end
                end
                
                Wait(100)
            end
        else
            if Config.Debug then
                print("^3[Gun Rack DEBUG] Stash " .. stashId .. " already has items, skipping defaults")
            end
        end
    end)
end

RegisterNetEvent('gunrack:server:openStash', function(plate, vehicleModel)
    local source = source
    
    if Config.Debug then
        print("^2[Gun Rack DEBUG] Server received openStash request from player: " .. source)
        print("^3[Gun Rack DEBUG] Plate: '" .. plate .. "'")
        print("^3[Gun Rack DEBUG] Vehicle Model: " .. (vehicleModel or "unknown"))
    end

    if not source or source == 0 then
        if Config.Debug then
            print("^1[Gun Rack DEBUG] Invalid source")
        end
        return
    end

    if not IsPolice(source) then
        if Config.Debug then
            print("^1[Gun Rack DEBUG] Player " .. source .. " is not police")
        end
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Gun Rack',
            description = 'Access denied - Police only',
            type = 'error'
        })
        return
    end

    if not HasMinimumRank(source) then
        if Config.Debug then
            print("^1[Gun Rack DEBUG] Player " .. source .. " doesn't have minimum rank")
        end
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Gun Rack',
            description = 'Insufficient rank',
            type = 'error'
        })
        return
    end

    local stashId = CreateStashId(plate)
    
    if Config.Debug then
        print("^3[Gun Rack DEBUG] Final stash ID: " .. stashId)
    end

    local stashExists = RegisterGunRackStash(stashId, plate, vehicleModel)
    
    if not stashExists then
        if Config.Debug then
            print("^1[Gun Rack DEBUG] Failed to register stash")
        end
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'Gun Rack',
            description = 'Failed to access gun rack. Please try again.',
            type = 'error'
        })
        return
    end

    if not registeredStashes[stashId].hasDefaultItems and Config.DefaultItems and #Config.DefaultItems > 0 then
        registeredStashes[stashId].hasDefaultItems = true
        AddDefaultItems(stashId)
    end

    if Config.Debug then
        print("^2[Gun Rack DEBUG] Sending openStash event to client with ID: " .. stashId)
    end
    TriggerClientEvent('gunrack:client:openStash', source, stashId)
end)

CreateThread(function()
    while true do
        Wait(300000) 
        
        if Config.Debug then
            print("^3[Gun Rack DEBUG] Periodic stash data save...")
            print("^3[Gun Rack DEBUG] Total registered stashes: " .. table.count(registeredStashes))
        end

        for stashId, data in pairs(registeredStashes) do
            local success, inventory = pcall(function()
                return exports.ox_inventory:GetInventory(stashId)
            end)
            
            if success and inventory and Config.Debug then
                local itemCount = inventory.items and #inventory.items or 0
                print("^3[Gun Rack DEBUG] Stash " .. stashId .. " has " .. itemCount .. " items")
            end
        end
    end
end)

CreateThread(function()
    Wait(15000) 
    
    if Config.Debug then
        print("^2[Gun Rack DEBUG] Initializing gun rack system...")
    end

    local oxAvailable = pcall(function()
        return exports.ox_inventory ~= nil
    end)
    
    if not oxAvailable then
        print("^1[Gun Rack ERROR] ox_inventory not available! Gun racks will not work.")
        return
    end
    
    if Config.Debug then
        print("^2[Gun Rack DEBUG] ox_inventory is available")
    end

    if Config.PreRegisterStashes and #Config.PreRegisterStashes > 0 then
        if Config.Debug then
            print("^2[Gun Rack DEBUG] Pre-registering " .. #Config.PreRegisterStashes .. " stashes...")
        end
        
        for _, plateData in pairs(Config.PreRegisterStashes) do
            local stashId = CreateStashId(plateData.plate)
            local success = RegisterGunRackStash(stashId, plateData.plate, plateData.model or "Police Vehicle")
            
            if success then
                if Config.Debug then
                    print("^2[Gun Rack DEBUG] Pre-registered stash for plate: " .. plateData.plate)
                end

                if Config.DefaultItems and #Config.DefaultItems > 0 then
                    registeredStashes[stashId].hasDefaultItems = true
                    AddDefaultItems(stashId)
                end
            else
                if Config.Debug then
                    print("^1[Gun Rack DEBUG] Failed to pre-register stash for plate: " .. plateData.plate)
                end
            end
            
            Wait(500) 
        end
        
        if Config.Debug then
            print("^2[Gun Rack DEBUG] Pre-registration complete")
        end
    end
    
    if Config.Debug then
        print("^2[Gun Rack DEBUG] Gun rack system initialized")
    end
end)

if Config.Debug then
    RegisterCommand('gunrack_server_debug', function(source, args)
        if source == 0 then 
            print("^3[Gun Rack SERVER DEBUG] === Server Debug Info ===")
            print("^3[Gun Rack SERVER DEBUG] Registered stashes count: " .. table.count(registeredStashes))
            
            for stashId, data in pairs(registeredStashes) do
                print("^3[Gun Rack SERVER DEBUG] - " .. stashId)
                print("^3[Gun Rack SERVER DEBUG]   Plate: " .. (data.plate or "unknown"))
                print("^3[Gun Rack SERVER DEBUG]   Model: " .. (data.model or "unknown"))
                print("^3[Gun Rack SERVER DEBUG]   Registered: " .. os.date("%Y-%m-%d %H:%M:%S", data.registered or 0))

                local success, inventory = pcall(function()
                    return exports.ox_inventory:GetInventory(stashId)
                end)
                
                if success and inventory then
                    local itemCount = 0
                    if inventory.items then
                        for slot, item in pairs(inventory.items) do
                            if item then
                                itemCount = itemCount + 1
                                print("^3[Gun Rack SERVER DEBUG]     Item " .. slot .. ": " .. item.name .. " x" .. item.count)
                            end
                        end
                    end
                    print("^3[Gun Rack SERVER DEBUG]   Total items: " .. itemCount)
                else
                    print("^3[Gun Rack SERVER DEBUG]   Could not retrieve inventory")
                end
            end

            local oxAvailable = pcall(function()
                return exports.ox_inventory ~= nil
            end)
            print("^3[Gun Rack SERVER DEBUG] ox_inventory available: " .. tostring(oxAvailable))
            
            print("^3[Gun Rack SERVER DEBUG] === End Server Debug ===")
        end
    end, true)
    
    RegisterCommand('gunrack_list_stashes', function(source, args)
        if source == 0 then
            print("^3[Gun Rack DEBUG] === Registered Stashes ===")
            for stashId, data in pairs(registeredStashes) do
                print("^3[Gun Rack DEBUG] " .. stashId .. " - Plate: " .. (data.plate or "unknown"))
            end
            print("^3[Gun Rack DEBUG] Total: " .. table.count(registeredStashes))
        end
    end, true)
    
    RegisterCommand('gunrack_clear_cache', function(source, args)
        if source == 0 then 
            registeredStashes = {}
            print("^2[Gun Rack DEBUG] Cleared stash registration cache")
        end
    end, true)
end

function table.count(t)
    local count = 0
    for _ in pairs(t) do count = count + 1 end
    return count
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if Config.Debug then
            print("^3[Gun Rack DEBUG] Resource stopping, saving stash data...")
        end

        for stashId, data in pairs(registeredStashes) do
            pcall(function()
                exports.ox_inventory:GetInventory(stashId) 
            end)
        end
        
        if Config.Debug then
            print("^3[Gun Rack DEBUG] Cleanup complete")
        end
    end
end)