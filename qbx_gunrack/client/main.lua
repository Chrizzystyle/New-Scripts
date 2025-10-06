local QBX = exports.qbx_core
local radialMenuId = nil

local function IsPolice()
    local playerData = QBX:GetPlayerData()
    if not playerData or not playerData.job then return false end
    
    for _, job in pairs(Config.PoliceJobs) do
        if playerData.job.name == job then
            return true
        end
    end
    return false
end

local function HasMinimumRank()
    if not Config.RequireMinimumRank then return true end
    
    local playerData = QBX:GetPlayerData()
    if not playerData or not playerData.job then return false end
    
    local jobName = playerData.job.name
    local playerGrade = playerData.job.grade.level or 0
    local requiredGrade = Config.MinimumRanks[jobName] or 0
    
    return playerGrade >= requiredGrade
end

local function IsPoliceVehicle(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        return false
    end
    
    local model = GetEntityModel(vehicle)
    local modelName = GetDisplayNameFromVehicleModel(model):lower()
    
    for _, policeModel in pairs(Config.PoliceVehicles) do
        if policeModel:lower() == modelName then
            if Config.Debug then
                print("^2[Gun Rack DEBUG] Vehicle model '" .. modelName .. "' is a police vehicle")
            end
            return true
        end
    end
    
    if Config.Debug then
        print("^1[Gun Rack DEBUG] Vehicle model '" .. modelName .. "' is NOT a police vehicle")
    end
    
    return false
end

local function GetAccessibleVehicle()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    local vehicle = nil
    
    if IsPedInAnyVehicle(playerPed, false) then
        vehicle = GetVehiclePedIsIn(playerPed, false)
        if Config.Debug then
            print("^3[Gun Rack DEBUG] Player is in vehicle: " .. tostring(vehicle))
        end
    else

        vehicle = GetClosestVehicle(coords, Config.DetectionDistance, 0, 70)
        if vehicle and vehicle ~= 0 then
            local vehCoords = GetEntityCoords(vehicle)
            local distance = #(coords - vehCoords)
            
            if distance <= Config.AccessDistance then
                if Config.Debug then
                    print("^3[Gun Rack DEBUG] Nearby vehicle found: " .. tostring(vehicle) .. " at distance: " .. tostring(distance))
                end
            else
                vehicle = nil 
            end
        end
    end

    if vehicle and not IsPoliceVehicle(vehicle) then
        if Config.Debug then
            print("^1[Gun Rack DEBUG] Vehicle is not a police vehicle, returning nil")
        end
        return nil
    end
    
    return vehicle
end

local function GetVehiclePlate(vehicle)
    local plate = GetVehicleNumberPlateText(vehicle)
    plate = plate:gsub("%s+", ""):upper()
    
    if Config.Debug then
        print("^3[Gun Rack DEBUG] Normalized plate: '" .. plate .. "'")
    end
    
    return plate
end

local function OpenGunRack()
    if Config.Debug then
        print("^2[Gun Rack DEBUG] OpenGunRack() called")
    end
    
    if not IsPolice() then
        if Config.Debug then
            print("^1[Gun Rack DEBUG] Player is not police")
        end
        lib.notify({
            title = 'Gun Rack',
            description = 'You must be a police officer to access the gun rack',
            type = 'error'
        })
        return
    end
    
    if not HasMinimumRank() then
        if Config.Debug then
            print("^1[Gun Rack DEBUG] Player doesn't have minimum rank")
        end
        lib.notify({
            title = 'Gun Rack',
            description = 'Insufficient rank to access gun rack',
            type = 'error'
        })
        return
    end
    
    local vehicle = GetAccessibleVehicle()
    
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        if Config.Debug then
            print("^1[Gun Rack DEBUG] No accessible police vehicle found")
        end
        lib.notify({
            title = 'Gun Rack',
            description = 'No police vehicle found nearby. You must be in or near a police vehicle to access the gun rack',
            type = 'error'
        })
        return
    end
    
    local plate = GetVehiclePlate(vehicle)
    local vehicleModel = GetDisplayNameFromVehicleModel(GetEntityModel(vehicle))
    
    if Config.Debug then
        print("^2[Gun Rack DEBUG] All checks passed!")
        print("^3[Gun Rack DEBUG] Opening gun rack for plate: '" .. plate .. "'")
        print("^3[Gun Rack DEBUG] Vehicle model: " .. vehicleModel)
        print("^3[Gun Rack DEBUG] Vehicle: " .. tostring(vehicle))
        print("^3[Gun Rack DEBUG] Triggering server event: gunrack:server:openStash")
    end
    
    lib.notify({
        title = 'Gun Rack',
        description = 'Opening gun rack...',
        type = 'inform'
    })
    
    TriggerServerEvent('gunrack:server:openStash', plate, vehicleModel)
end

-- EXPORT: Manual radial menu item (for adding to job-specific menus)
-- Use this in your qbx_radialmenu config or other scripts
function GetGunRackRadialItem()
    return {
        id = 'gunrack_access',
        label = 'Gun Rack',
        icon = 'fas fa-gun',
        onSelect = function()
            OpenGunRack()
        end
    }
end
exports('GetGunRackRadialItem', GetGunRackRadialItem)

function CanAccessGunRack()
    return IsPolice() and HasMinimumRank()
end
exports('CanAccessGunRack', CanAccessGunRack)

function AccessGunRack()
    OpenGunRack()
end
exports('AccessGunRack', AccessGunRack)

RegisterNetEvent('gunrack:client:access', function()
    OpenGunRack()
end)

RegisterNetEvent('gunrack:client:openStash', function(stashId)
    if Config.Debug then
        print("^2[Gun Rack DEBUG] Received gunrack:client:openStash event")
        print("^3[Gun Rack DEBUG] Stash ID received: " .. tostring(stashId))
    end
    
    Wait(500) 
    
    local success = pcall(function()
        exports.ox_inventory:openInventory('stash', stashId)
    end)
    
    if success then
        if Config.Debug then
            print("^2[Gun Rack DEBUG] Successfully opened inventory!")
        end
        lib.notify({
            title = 'Gun Rack',
            description = 'Gun rack opened successfully',
            type = 'success'
        })
    else
        if Config.Debug then
            print("^1[Gun Rack DEBUG] Failed to open inventory!")
        end
        lib.notify({
            title = 'Gun Rack',
            description = 'Failed to open gun rack. Please try again.',
            type = 'error'
        })
    end
end)

RegisterNetEvent('QBCore:Client:OnJobUpdate', function(JobInfo)
    if Config.Debug then
        print("^3[Gun Rack DEBUG] Job updated - Use manual integration for radial menu")
    end
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    if Config.Debug then
        print("^3[Gun Rack DEBUG] Player loaded - Use manual integration for radial menu")
    end
end)

CreateThread(function()
    Wait(5000)
    
    if Config.Debug then
        print("^2[Gun Rack DEBUG] Gun rack system initialized")
        print("^3[Gun Rack DEBUG] Manual integration mode - Use exports for radial menu")
        print("^3[Gun Rack DEBUG] Available commands: /gunrack or F6 keybind")
    end
end)

RegisterCommand('gunrack', function()
    OpenGunRack()
end, false)

RegisterKeyMapping('gunrack', 'Access Gun Rack', 'keyboard', 'F6')

if Config.Debug then
    RegisterCommand('gunrack_debug', function()
        local playerPed = PlayerPedId()
        local coords = GetEntityCoords(playerPed)
        local playerData = QBX:GetPlayerData()
        
        print("^3[DEBUG] === Gun Rack Debug Info ===")
        print("^3[DEBUG] Player is police: " .. tostring(IsPolice()))
        print("^3[DEBUG] Has minimum rank: " .. tostring(HasMinimumRank()))
        print("^3[DEBUG] Radial menu ID: " .. tostring(radialMenuId))
        
        local oxAvailable = pcall(function()
            return exports.ox_inventory ~= nil
        end)
        print("^3[DEBUG] ox_inventory available: " .. tostring(oxAvailable))
        
        if playerData and playerData.job then
            print("^3[DEBUG] Current job: " .. tostring(playerData.job.name))
            print("^3[DEBUG] Job grade level: " .. tostring(playerData.job.grade.level or 'unknown'))
            print("^3[DEBUG] Job grade name: " .. tostring(playerData.job.grade.name or 'unknown'))
        else
            print("^3[DEBUG] No job data found")
        end
        
        local vehicle = GetAccessibleVehicle()
        if vehicle and vehicle ~= 0 then
            local plate = GetVehiclePlate(vehicle)
            local stashId = 'gunrack_' .. plate
            local model = GetEntityModel(vehicle)
            local modelName = GetDisplayNameFromVehicleModel(model)
            
            print("^3[DEBUG] Accessible vehicle: " .. tostring(vehicle))
            print("^3[DEBUG] Vehicle model: " .. modelName)
            print("^3[DEBUG] Is police vehicle: " .. tostring(IsPoliceVehicle(vehicle)))
            print("^3[DEBUG] Vehicle plate: '" .. plate .. "'")
            print("^3[DEBUG] Stash ID: " .. stashId)
            
            if IsPedInAnyVehicle(playerPed, false) then
                print("^3[DEBUG] Player is IN the vehicle")
            else
                local vehCoords = GetEntityCoords(vehicle)
                local distance = #(coords - vehCoords)
                print("^3[DEBUG] Player is NEAR vehicle (distance: " .. tostring(distance) .. ")")
            end
        else
            print("^3[DEBUG] No accessible vehicle found")
        end
        
        print("^3[DEBUG] Configured police vehicles:")
        for i, model in ipairs(Config.PoliceVehicles) do
            print("^3[DEBUG]   " .. i .. ". " .. model)
        end
        
        print("^3[DEBUG] === End Debug Info ===")
    end, false)
    
    RegisterCommand('test_gunrack_job', function()
        local isPoliceOfficer = IsPolice()
        local hasRank = HasMinimumRank()
        
        lib.notify({
            title = 'Gun Rack Job Test',
            description = string.format('Police: %s | Rank: %s', 
                isPoliceOfficer and 'YES' or 'NO',
                hasRank and 'OK' or 'LOW'
            ),
            type = (isPoliceOfficer and hasRank) and 'success' or 'error'
        })
    end, false)
    
    RegisterCommand('gunrack_refresh', function()
        lib.notify({
            title = 'Gun Rack',
            description = 'Use manual integration with exports',
            type = 'inform'
        })
    end, false)
end

AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        if Config.Debug then
            print("^3[Gun Rack DEBUG] Resource stopped")
        end
    end
end)