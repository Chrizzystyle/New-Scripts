local QBX = exports.qbx_core
local isApplyingPlate = false
local isRemovingPlate = false

-- Notification function
local function Notify(msg, type)
    if Config.UseOxLib then
        lib.notify({
            title = 'Fake Plates',
            description = msg,
            type = type or 'info'
        })
    else
        lib.notify({
            title = 'Fake Plates',
            description = msg,
            type = type or 'info'
        })
    end
end

-- Progress bar function
local function ProgressBar(time, label)
    if lib.progressBar then
        return lib.progressBar({
            duration = time,
            label = label,
            useWhileDead = false,
            canCancel = true,
            disable = {
                car = true,
                move = true,
                combat = true
            },
            anim = {
                dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
                clip = 'machinic_loop_mechandplayer'
            }
        })
    else
        -- Fallback if ox_lib not available
        local promise = promise.new()
        RequestAnimDict('anim@amb@clubhouse@tutorial@bkr_tut_ig3@')
        while not HasAnimDictLoaded('anim@amb@clubhouse@tutorial@bkr_tut_ig3@') do
            Wait(0)
        end
        TaskPlayAnim(cache.ped, 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', 'machinic_loop_mechandplayer', 8.0, 8.0, -1, 1, 0, false, false, false)
        
        SetTimeout(time, function()
            ClearPedTasks(cache.ped)
            promise:resolve(true)
        end)
        
        return Citizen.Await(promise)
    end
end

-- Get closest vehicle
local function GetClosestVehicle(coords)
    local vehicles = GetGamePool('CVehicle')
    local closestVehicle = nil
    local closestDistance = 3.0
    
    for i = 1, #vehicles do
        local vehicle = vehicles[i]
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(coords - vehicleCoords)
        
        if distance < closestDistance then
            closestDistance = distance
            closestVehicle = vehicle
        end
    end
    
    return closestVehicle
end

-- Apply fake plate
RegisterNetEvent('fakeplate:client:applyPlate', function()
    if isApplyingPlate then return end
    
    local ped = cache.ped
    local veh = GetVehiclePedIsIn(ped, false)
    
    if veh == 0 then
        local coords = GetEntityCoords(ped)
        veh = GetClosestVehicle(coords)
        
        if not veh then
            Notify('No vehicle nearby', 'error')
            return
        end
    end
    
    local plate = GetVehicleNumberPlateText(veh)
    local netId = NetworkGetNetworkIdFromEntity(veh)
    
    isApplyingPlate = true
    
    -- Check if already has fake plate
    lib.callback('fakeplate:server:hasActiveFakePlate', false, function(hasPlate)
        if hasPlate then
            Notify('This vehicle already has a fake plate', 'error')
            isApplyingPlate = false
            return
        end
        
        -- Animation
        TaskTurnPedToFaceEntity(ped, veh, 1000)
        Wait(1000)
        
        local success = ProgressBar(Config.ApplyTime, 'Applying fake plate...')
        
        if success then
            TriggerServerEvent('fakeplate:server:applyPlate', netId, plate)
        else
            Notify('Cancelled', 'error')
        end
        
        isApplyingPlate = false
    end, netId)
end)

-- Remove fake plate
RegisterNetEvent('fakeplate:client:removePlate', function()
    if isRemovingPlate then return end
    
    local ped = cache.ped
    local veh = GetVehiclePedIsIn(ped, false)
    
    if veh == 0 then
        local coords = GetEntityCoords(ped)
        veh = GetClosestVehicle(coords)
        
        if not veh then
            Notify('No vehicle nearby', 'error')
            return
        end
    end
    
    local netId = NetworkGetNetworkIdFromEntity(veh)
    
    isRemovingPlate = true
    
    -- Check if has fake plate
    lib.callback('fakeplate:server:hasActiveFakePlate', false, function(hasPlate)
        if not hasPlate then
            Notify('This vehicle does not have a fake plate', 'error')
            isRemovingPlate = false
            return
        end
        
        -- Animation
        TaskTurnPedToFaceEntity(ped, veh, 1000)
        Wait(1000)
        
        local success = ProgressBar(Config.RemoveTime, 'Removing fake plate...')
        
        if success then
            TriggerServerEvent('fakeplate:server:removePlate', netId)
        else
            Notify('Cancelled', 'error')
        end
        
        isRemovingPlate = false
    end, netId)
end)

-- Update plate visually
RegisterNetEvent('fakeplate:client:updatePlate', function(netId, newPlate)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(veh) then
        SetVehicleNumberPlateText(veh, newPlate)
        if Config.Debug then
            print('[FakePlate Client] Updated plate to: ' .. newPlate .. ' for NetID: ' .. netId)
        end
    else
        if Config.Debug then
            print('[FakePlate Client] Vehicle does not exist for NetID: ' .. netId)
        end
    end
end)

-- Debug command
if Config.Debug then
    RegisterCommand('checkplate', function()
        local ped = cache.ped
        local veh = GetVehiclePedIsIn(ped, false)
        
        if veh == 0 then
            local coords = GetEntityCoords(ped)
            veh = GetClosestVehicle(coords)
        end
        
        if veh then
            local plate = GetVehicleNumberPlateText(veh)
            local netId = NetworkGetNetworkIdFromEntity(veh)
            print('Plate: ' .. plate)
            print('NetID: ' .. netId)
        end
    end)
end