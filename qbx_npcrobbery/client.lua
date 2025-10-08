-- QBX NPC Robbery - Client Script
local isBeingRobbed = false
local robberPed = nil
local robberyBlip = nil

-- Function to spawn robber NPC
local function SpawnRobberNPC()
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local playerHeading = GetEntityHeading(playerPed)
    
    -- Spawn NPC in front of player
    local spawnCoords = GetOffsetFromEntityInWorldCoords(playerPed, 0.0, 1.5, 0.0)
    local randomModel = Config.NPCModels[math.random(#Config.NPCModels)]
    local modelHash = GetHashKey(randomModel)
    
    RequestModel(modelHash)
    local timeout = 0
    while not HasModelLoaded(modelHash) and timeout < 500 do
        Wait(10)
        timeout = timeout + 1
    end
    
    if not HasModelLoaded(modelHash) then
        -- Try fallback model
        modelHash = GetHashKey('a_m_m_skater_01')
        RequestModel(modelHash)
        timeout = 0
        while not HasModelLoaded(modelHash) and timeout < 500 do
            Wait(10)
            timeout = timeout + 1
        end
        
        if not HasModelLoaded(modelHash) then
            return nil
        end
    end
    
    local ped = CreatePed(4, modelHash, spawnCoords.x, spawnCoords.y, spawnCoords.z, playerHeading + 180.0, true, true)
    
    if not DoesEntityExist(ped) then
        SetModelAsNoLongerNeeded(modelHash)
        return nil
    end
    
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedKeepTask(ped, true)
    
    -- Give NPC a knife
    GiveWeaponToPed(ped, GetHashKey('WEAPON_KNIFE'), 1, false, true)
    
    SetModelAsNoLongerNeeded(modelHash)
    
    return ped
end

-- Function to create blip for robber
local function CreateRobberBlip(ped)
    robberyBlip = AddBlipForEntity(ped)
    SetBlipSprite(robberyBlip, 458)
    SetBlipColour(robberyBlip, 1)
    SetBlipScale(robberyBlip, 0.8)
    SetBlipAsShortRange(robberyBlip, false)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Robber")
    EndTextCommandSetBlipName(robberyBlip)
end

-- Function to remove blip
local function RemoveRobberBlip()
    if robberyBlip then
        RemoveBlip(robberyBlip)
        robberyBlip = nil
    end
end

-- Main robbery sequence
RegisterNetEvent('qbx_npcrobbery:client:startRobbery', function()
    if isBeingRobbed then 
        return 
    end
    
    isBeingRobbed = true
    local playerPed = PlayerPedId()
    
    -- Spawn the robber
    robberPed = SpawnRobberNPC()
    
    if not robberPed or not DoesEntityExist(robberPed) then
        isBeingRobbed = false
        exports.qbx_core:Notify('Failed to spawn robber NPC. Check F8 console.', 'error')
        return
    end
    
    -- Make NPC face player and pull out knife
    TaskTurnPedToFaceEntity(robberPed, playerPed, 1000)
    Wait(1000)
    SetCurrentPedWeapon(robberPed, GetHashKey('WEAPON_KNIFE'), true)
    
    -- Show notification
    exports.qbx_core:Notify(Config.Notifications.RobberyStart, 'error', 5000)
    
    -- Create blip for the robber
    CreateRobberBlip(robberPed)
    
    -- Start countdown for hands up
    local handsUpTimer = Config.StabTimeout
    local caughtRobber = false
    local putHandsUp = false
    local robberyCompleted = false
    
    -- Thread to check if player catches robber
    CreateThread(function()
        local startTime = GetGameTimer()
        while isBeingRobbed and GetGameTimer() - startTime < Config.RobberyTimeout do
            if DoesEntityExist(robberPed) then
                -- Check if robber is dead or incapacitated
                if IsEntityDead(robberPed) or IsPedDeadOrDying(robberPed, true) then
                    if not robberyCompleted and not caughtRobber then
                        caughtRobber = true
                        robberyCompleted = true
                        TriggerServerEvent('qbx_npcrobbery:server:npcCaught')
                        RemoveRobberBlip()
                        isBeingRobbed = false
                        break
                    end
                end
                
                -- Check if player is close enough to punch/melee the robber
                local playerCoords = GetEntityCoords(playerPed)
                local robberCoords = GetEntityCoords(robberPed)
                local distance = #(playerCoords - robberCoords)
                
                -- If player is meleeing the robber
                if distance < 3.0 and IsPedInMeleeCombat(playerPed) then
                    if not robberyCompleted and not caughtRobber then
                        caughtRobber = true
                        robberyCompleted = true
                        TriggerServerEvent('qbx_npcrobbery:server:npcCaught')
                        RemoveRobberBlip()
                        
                        -- Kill the robber ped
                        SetEntityHealth(robberPed, 0)
                        
                        Wait(3000)
                        if DoesEntityExist(robberPed) then
                            DeleteEntity(robberPed)
                        end
                        isBeingRobbed = false
                        break
                    end
                end
            else
                -- Robber doesn't exist anymore
                if not robberyCompleted and not caughtRobber then
                    caughtRobber = true
                    robberyCompleted = true
                    TriggerServerEvent('qbx_npcrobbery:server:npcCaught')
                    RemoveRobberBlip()
                    isBeingRobbed = false
                    break
                end
            end
            Wait(100)
        end
    end)
    
    -- Thread to check for hands up
    CreateThread(function()
        local startTime = GetGameTimer()
        while isBeingRobbed and GetGameTimer() - startTime < handsUpTimer do
            -- Check if player has hands up
            if IsEntityPlayingAnim(playerPed, 'random@mugging3', 'handsup_standing_base', 3) then
                putHandsUp = true
                break
            end
            
            -- Check if robber was caught during this time
            if caughtRobber or robberyCompleted then
                return
            end
            
            Wait(100)
        end
        
        -- Only act if robbery is still active and robber wasn't caught
        if isBeingRobbed and not caughtRobber and not robberyCompleted then
            if not putHandsUp then
                -- Player didn't put hands up in time, NPC stabs them
                robberyCompleted = true
                TaskCombatPed(robberPed, playerPed, 0, 16)
                Wait(2000)
                
                -- Double check robbery wasn't stopped
                if not caughtRobber then
                    TriggerServerEvent('qbx_npcrobbery:server:playerStabbed')
                end
                
                TaskSmartFleePed(robberPed, playerPed, 100.0, -1, false, false)
                
                -- Keep NPC alive for the remaining chase time
                Wait(20000)
                if DoesEntityExist(robberPed) then
                    DeleteEntity(robberPed)
                end
                RemoveRobberBlip()
                isBeingRobbed = false
            else
                -- Player put hands up - NPC approaches and robs them
                
                -- Make NPC walk up to player
                TaskGoToEntity(robberPed, playerPed, -1, 1.0, 2.0, 1073741824, 0)
                
                -- Wait for NPC to get close
                local approached = false
                local approachTimeout = 0
                while not approached and approachTimeout < 50 do
                    local robberCoords = GetEntityCoords(robberPed)
                    local playerCoords = GetEntityCoords(playerPed)
                    local distance = #(robberCoords - playerCoords)
                    
                    if distance < 2.0 then
                        approached = true
                        break
                    end
                    
                    -- Check if player stopped complying or robber was caught
                    if not IsEntityPlayingAnim(playerPed, 'random@mugging3', 'handsup_standing_base', 3) or caughtRobber or robberyCompleted then
                        return
                    end
                    
                    Wait(100)
                    approachTimeout = approachTimeout + 1
                end
                
                -- Stop the NPC and face the player
                ClearPedTasks(robberPed)
                TaskTurnPedToFaceEntity(robberPed, playerPed, 2000)
                Wait(1000)
                
                -- Play a "searching" animation on the NPC
                RequestAnimDict('amb@prop_human_bum_bin@idle_b')
                while not HasAnimDictLoaded('amb@prop_human_bum_bin@idle_b') do
                    Wait(10)
                end
                TaskPlayAnim(robberPed, 'amb@prop_human_bum_bin@idle_b', 'idle_d', 8.0, 8.0, 3000, 1, 0, false, false, false)
                
                -- Show a notification that they're being robbed
                exports.qbx_core:Notify('The robber is taking your belongings...', 'error', 3000)
                
                -- Wait while "robbing"
                Wait(3000)
                
                -- Check one more time if robbery was stopped
                if caughtRobber or robberyCompleted then
                    return
                end
                
                -- Now NPC runs away
                TaskSmartFleePed(robberPed, playerPed, 100.0, -1, false, false)
                
                -- Give player full remaining time to catch the robber
                local remainingTime = Config.RobberyTimeout - handsUpTimer - 7000
                Wait(remainingTime)
                
                -- Check if robbery was already stopped
                if isBeingRobbed and not robberyCompleted and not caughtRobber then
                    robberyCompleted = true
                    TriggerServerEvent('qbx_npcrobbery:server:robberyComplete')
                end
                
                if DoesEntityExist(robberPed) then
                    DeleteEntity(robberPed)
                end
                RemoveRobberBlip()
                isBeingRobbed = false
            end
        end
    end)
    
    -- Timeout thread
    CreateThread(function()
        Wait(Config.RobberyTimeout)
        if isBeingRobbed and not robberyCompleted then
            if DoesEntityExist(robberPed) then
                TaskSmartFleePed(robberPed, playerPed, 100.0, -1, false, false)
                Wait(5000)
                DeleteEntity(robberPed)
            end
            RemoveRobberBlip()
            isBeingRobbed = false
        end
    end)
end)

-- Event to handle getting stabbed
RegisterNetEvent('qbx_npcrobbery:client:getStabbed', function()
    local playerPed = PlayerPedId()
    SetEntityHealth(playerPed, 0)
end)

-- Command to put hands up
RegisterCommand('+handsup', function()
    local playerPed = PlayerPedId()
    if not IsEntityPlayingAnim(playerPed, 'random@mugging3', 'handsup_standing_base', 3) then
        RequestAnimDict('random@mugging3')
        while not HasAnimDictLoaded('random@mugging3') do
            Wait(10)
        end
        TaskPlayAnim(playerPed, 'random@mugging3', 'handsup_standing_base', 8.0, -8.0, -1, 49, 0, false, false, false)
    end
end, false)

RegisterCommand('-handsup', function()
    local playerPed = PlayerPedId()
    ClearPedTasks(playerPed)
end, false)

RegisterKeyMapping('+handsup', 'Put Hands Up', 'keyboard', Config.HandsUpKey)