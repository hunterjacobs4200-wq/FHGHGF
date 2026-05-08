--[[
    NPC Police Interactions - Arrest System
    Handles handcuffing, escorting, placing in vehicle, transport, and jail despawn.
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local isEscorting = false
local escortedPed = nil
local isTransporting = false

-- ============================================================================
-- ARREST INITIATION
-- ============================================================================

RegisterNetEvent('npc_police:beginArrest')
AddEventHandler('npc_police:beginArrest', function(npcData)
    if not npcData or not DoesEntityExist(npcData.ped) then
        TriggerEvent('npc_police:notify', '~r~Error', 'No valid suspect to arrest.')
        return
    end

    local ped = npcData.ped

    -- If NPC is still in a vehicle, order them out first
    if IsPedInAnyVehicle(ped, false) then
        TriggerEvent('npc_police:showSubtitle', 'Step out of the vehicle! You are under arrest!')
        NPCPolice.AI.TransitionState(ped, 'exiting', { force = true })

        -- Wait for them to exit
        local timeout = 0
        while IsPedInAnyVehicle(ped, false) and timeout < 10000 do
            Wait(500)
            timeout = timeout + 500
        end

        if IsPedInAnyVehicle(ped, false) then
            -- Force exit
            local vehicle = GetVehiclePedIsIn(ped, false)
            TaskLeaveVehicle(ped, vehicle, 256)
            Wait(3000)
        end
    end

    -- Determine response
    local response = NPCPolice.AI.DecideResponse(npcData, 'arrest')

    if response == 'flee' then
        TriggerEvent('npc_police:showSubtitle', NPCPolice.RandomFromArray(Config.Dialogue.Wanted.flee))
        NPCPolice.AI.TransitionState(ped, 'fleeing_foot')
        NPCPolice.AI.MonitorFlee(ped, npcData)
        return
    elseif response == 'attack' then
        NPCPolice.AI.TransitionState(ped, 'fighting')
        return
    end

    -- Compliant arrest
    PerformHandcuff(npcData)
end)

-- ============================================================================
-- HANDCUFF PROCEDURE
-- ============================================================================

function PerformHandcuff(npcData)
    local ped = npcData.ped
    local playerPed = PlayerPedId()

    if not DoesEntityExist(ped) then return end

    TriggerEvent('npc_police:showSubtitle', 'Turn around. Hands behind your back.')

    -- Make NPC face away from officer
    local playerPos = GetEntityCoords(playerPed)
    local pedPos = GetEntityCoords(ped)
    local heading = GetHeadingFromVector_2d(playerPos.x - pedPos.x, playerPos.y - pedPos.y)
    SetEntityHeading(ped, heading)

    Wait(500)

    -- Play handcuff animation with progress bar
    ShowProgressBar('Handcuffing suspect...', Config.ProgressDurations.Handcuff,
        Config.Arrest.HandcuffAnimDict, Config.Arrest.HandcuffAnimOfficer,
        function()
            -- Apply handcuff state to NPC
            NPCPolice.AI.TransitionState(ped, 'handcuffed')
            npcData.state = 'handcuffed'

            TriggerEvent('npc_police:notify', '~g~Suspect Handcuffed',
                npcData.identity.fullName .. ' is now in custody.')

            -- Dispatch notification
            local pos = GetEntityCoords(ped)
            local streetName = NPCPolice.GetStreetName(pos)
            TriggerEvent('npc_police:dispatch', 'arrest',
                string.format(Config.Immersion.DispatchMessages.arrest, streetName)
            )

            -- Notify server
            TriggerServerEvent('npc_police:suspectArrested', {
                name = npcData.identity.fullName,
                plate = npcData.plate,
                violations = npcData.violations,
                location = streetName,
            })

            -- Open post-arrest menu
            Wait(500)
            OpenPostArrestMenu(npcData)
        end,
        function()
            TriggerEvent('npc_police:notify', '~r~Cancelled', 'Handcuffing cancelled.')
        end
    )
end

-- ============================================================================
-- POST-ARREST MENU
-- ============================================================================

function OpenPostArrestMenu(npcData)
    local useOx = Config.UseOxLib and NPCPolice.HasOxLib()

    if useOx then
        local options = {
            {
                title = 'Escort Suspect',
                description = 'Walk the suspect to a location',
                icon = 'person-walking',
                onSelect = function()
                    ToggleEscort(npcData)
                end,
            },
            {
                title = 'Place in Vehicle',
                description = 'Put suspect in the nearest police vehicle',
                icon = 'car-side',
                onSelect = function()
                    PlaceInVehicle(npcData)
                end,
            },
            {
                title = 'Search Suspect',
                description = 'Search the handcuffed suspect',
                icon = 'magnifying-glass',
                onSelect = function()
                    if not npcData.frisked then
                        ActionFrisk(npcData)
                    else
                        TriggerEvent('npc_police:notify', '~y~Already Searched', 'Suspect already searched.')
                        Wait(500)
                        OpenPostArrestMenu(npcData)
                    end
                end,
            },
            {
                title = 'Transport to Jail',
                description = 'Transport suspect to Bolingbroke Penitentiary',
                icon = 'building-columns',
                onSelect = function()
                    TransportToJail(npcData)
                end,
            },
            {
                title = 'Release Suspect',
                description = 'Uncuff and release the suspect',
                icon = 'unlock',
                onSelect = function()
                    ReleaseSuspect(npcData)
                end,
            },
        }

        lib.registerContext({
            id = 'npc_police_post_arrest',
            title = '🔒 Suspect: ' .. npcData.identity.fullName,
            options = options,
        })

        lib.showContext('npc_police_post_arrest')
    else
        -- Built-in menu fallback
        local menuOpen = true
        CreateThread(function()
            while menuOpen do
                DrawRect(0.85, 0.5, 0.25, 0.35, 0, 0, 0, 180)
                DrawText2D(0.85, 0.35, '~r~Suspect in Custody', 0.45)
                DrawText2D(0.85, 0.39, npcData.identity.fullName, 0.3)
                DrawText2D(0.85, 0.44, '[1] Escort', 0.3)
                DrawText2D(0.85, 0.475, '[2] Place in Vehicle', 0.3)
                DrawText2D(0.85, 0.51, '[3] Search', 0.3)
                DrawText2D(0.85, 0.545, '[4] Transport to Jail', 0.3)
                DrawText2D(0.85, 0.58, '[5] Release', 0.3)

                if IsControlJustPressed(0, 157) then
                    menuOpen = false; ToggleEscort(npcData)
                elseif IsControlJustPressed(0, 158) then
                    menuOpen = false; PlaceInVehicle(npcData)
                elseif IsControlJustPressed(0, 160) then
                    menuOpen = false
                    if not npcData.frisked then
                        ActionFrisk(npcData)
                    else
                        TriggerEvent('npc_police:notify', '~y~Already Searched', 'Suspect already searched.')
                    end
                elseif IsControlJustPressed(0, 164) then
                    menuOpen = false; TransportToJail(npcData)
                elseif IsControlJustPressed(0, 165) then
                    menuOpen = false; ReleaseSuspect(npcData)
                elseif IsControlJustPressed(0, 200) then
                    menuOpen = false
                end

                Wait(0)
            end
        end)
    end
end

-- ============================================================================
-- ESCORT SYSTEM
-- ============================================================================

function ToggleEscort(npcData)
    local ped = npcData.ped
    if not DoesEntityExist(ped) then return end

    if isEscorting then
        StopEscort()
        return
    end

    isEscorting = true
    escortedPed = ped
    escortedData = npcData

    NPCPolice.AI.TransitionState(ped, 'escorted')

    TriggerEvent('npc_police:notify', '~b~Escorting',
        'Press ~INPUT_DETONATE~ (G) to stop escorting.')

    -- Escort loop: attach NPC near player
    CreateThread(function()
        while isEscorting and DoesEntityExist(ped) do
            local playerPed = PlayerPedId()
            local playerPos = GetEntityCoords(playerPed)
            local playerHeading = GetEntityHeading(playerPed)

            -- Calculate offset position (slightly behind and to the right)
            local offset = Config.Arrest.EscortOffset
            local targetPos = GetOffsetFromEntityInWorldCoords(playerPed, offset.x, offset.y, offset.z)

            -- Move NPC to follow
            if not IsPedInAnyVehicle(ped, false) then
                TaskGoStraightToCoord(ped, targetPos.x, targetPos.y, targetPos.z,
                    Config.Arrest.EscortSpeed, -1, playerHeading, 0.5)
            end

            -- Check for stop key
            if IsControlJustPressed(0, Config.Keys.Escort) then
                StopEscort()
                Wait(500)
                OpenPostArrestMenu(npcData)
                return
            end

            Wait(200)
        end
    end)
end

function StopEscort()
    if escortedPed and DoesEntityExist(escortedPed) then
        ClearPedTasks(escortedPed)
        -- Re-apply handcuff animation
        local animDict = Config.Anims.Surrender.dict
        local animName = Config.Anims.Surrender.name
        RequestAnimDict(animDict)
        while not HasAnimDictLoaded(animDict) do Wait(10) end
        TaskPlayAnim(escortedPed, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)
    end

    isEscorting = false
    escortedPed = nil

    TriggerEvent('npc_police:notify', '~b~Escort Stopped', 'You stopped escorting the suspect.')
end

-- ============================================================================
-- PLACE IN VEHICLE
-- ============================================================================

function PlaceInVehicle(npcData)
    local ped = npcData.ped
    if not DoesEntityExist(ped) then return end

    -- Find nearest police vehicle
    local closestVehicle = nil
    local closestDist = 10.0

    -- Search for police vehicles nearby
    local handle, vehicle = FindFirstVehicle()
    local success = true

    while success do
        if DoesEntityExist(vehicle) then
            local vehPos = GetEntityCoords(vehicle)
            local dist = #(playerPos - vehPos)

            if dist < closestDist then
                local vehClass = GetVehicleClass(vehicle)
                -- Class 18 = Emergency vehicles
                if vehClass == 18 or IsVehicleSirenOn(vehicle) then
                    closestDist = dist
                    closestVehicle = vehicle
                end
            end
        end
        success, vehicle = FindNextVehicle(handle)
    end
    EndFindVehicle(handle)

    -- Also check the player's last vehicle
    local playerVeh = GetVehiclePedIsIn(PlayerPedId(), true)
    if DoesEntityExist(playerVeh) then
        local dist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(playerVeh))
        if dist < 15.0 then
            closestVehicle = playerVeh
        end
    end

    if not closestVehicle then
        TriggerEvent('npc_police:notify', '~r~No Vehicle', 'No police vehicle found nearby.')
        Wait(500)
        OpenPostArrestMenu(npcData)
        return
    end

    -- Stop escorting if active
    if isEscorting then
        StopEscort()
    end

    ShowProgressBar('Placing suspect in vehicle...', Config.ProgressDurations.PlaceInVehicle,
        nil, nil,
        function()
            if not DoesEntityExist(ped) or not DoesEntityExist(closestVehicle) then return end

            -- Find an empty rear seat
            local seatIndex = -1
            if IsVehicleSeatFree(closestVehicle, 1) then
                seatIndex = 1  -- rear left
            elseif IsVehicleSeatFree(closestVehicle, 2) then
                seatIndex = 2  -- rear right
            elseif IsVehicleSeatFree(closestVehicle, 0) then
                seatIndex = 0  -- front passenger
            end

            if seatIndex == -1 then
                TriggerEvent('npc_police:notify', '~r~No Seats', 'No available seats in the vehicle.')
                Wait(500)
                OpenPostArrestMenu(npcData)
                return
            end

            -- Clear animations and put in vehicle
            ClearPedTasks(ped)
            Wait(200)

            TaskEnterVehicle(ped, closestVehicle, 5000, seatIndex, 1.0, 1, 0)

            -- Wait for ped to enter
            local timeout = 0
            while not IsPedInVehicle(ped, closestVehicle, false) and timeout < 8000 do
                Wait(500)
                timeout = timeout + 500
            end

            if IsPedInVehicle(ped, closestVehicle, false) then
                npcData.state = 'intransport'
                SetBlockingOfNonTemporaryEvents(ped, true)
                SetPedCanBeDraggedOut(ped, false)

                TriggerEvent('npc_police:notify', '~g~Suspect Loaded',
                    npcData.identity.fullName .. ' has been placed in the vehicle.')

                -- Open transport menu
                Wait(500)
                OpenTransportMenu(npcData, closestVehicle)
            else
                -- Force warp into vehicle
                SetPedIntoVehicle(ped, closestVehicle, seatIndex)
                npcData.state = 'intransport'
                SetBlockingOfNonTemporaryEvents(ped, true)

                TriggerEvent('npc_police:notify', '~g~Suspect Loaded',
                    npcData.identity.fullName .. ' has been placed in the vehicle.')

                Wait(500)
                OpenTransportMenu(npcData, closestVehicle)
            end
        end,
        function()
            TriggerEvent('npc_police:notify', '~r~Cancelled', 'Placement cancelled.')
            Wait(500)
            OpenPostArrestMenu(npcData)
        end
    )
end

-- ============================================================================
-- TRANSPORT MENU
-- ============================================================================

function OpenTransportMenu(npcData, vehicle)
    local useOx = Config.UseOxLib and NPCPolice.HasOxLib()

    if useOx then
        lib.registerContext({
            id = 'npc_police_transport',
            title = '🚔 Transport: ' .. npcData.identity.fullName,
            options = {
                {
                    title = 'Transport to Jail',
                    description = 'Drive to Bolingbroke Penitentiary',
                    icon = 'building-columns',
                    onSelect = function()
                        TransportToJail(npcData)
                    end,
                },
                {
                    title = 'Remove from Vehicle',
                    description = 'Take the suspect back out',
                    icon = 'door-open',
                    onSelect = function()
                        RemoveFromVehicle(npcData, vehicle)
                    end,
                },
                {
                    title = 'Set GPS to Jail',
                    description = 'Set waypoint to Bolingbroke',
                    icon = 'location-dot',
                    onSelect = function()
                        SetNewWaypoint(Config.Arrest.JailLocation.x, Config.Arrest.JailLocation.y)
                        TriggerEvent('npc_police:notify', '~b~GPS Set',
                            'Waypoint set to Bolingbroke Penitentiary.')
                    end,
                },
            },
        })

        lib.showContext('npc_police_transport')
    else
        TriggerEvent('npc_police:notify', '~b~Transport',
            'Drive to the jail marker to process the suspect.\nWaypoint set to Bolingbroke.')
        SetNewWaypoint(Config.Arrest.JailLocation.x, Config.Arrest.JailLocation.y)

        -- Monitor for arrival at jail
        MonitorJailArrival(npcData)
    end
end

-- ============================================================================
-- TRANSPORT TO JAIL
-- ============================================================================

function TransportToJail(npcData)
    if isTransporting then
        TriggerEvent('npc_police:notify', '~y~Already Transporting', 'Already in transit.')
        return
    end

    isTransporting = true

    -- Set waypoint to jail
    SetNewWaypoint(Config.Arrest.JailLocation.x, Config.Arrest.JailLocation.y)
    TriggerEvent('npc_police:notify', '~b~Transport Started',
        'Waypoint set to Bolingbroke Penitentiary. Drive the suspect there.')

    -- Monitor for arrival
    MonitorJailArrival(npcData)
end

function MonitorJailArrival(npcData)
    CreateThread(function()
        local jailPos = Config.Arrest.JailLocation
        local ped = npcData.ped

        while isTransporting and DoesEntityExist(ped) do
            local playerPos = GetEntityCoords(PlayerPedId())
            local dist = #(playerPos - jailPos)

            if dist < 50.0 then
                isTransporting = false

                TriggerEvent('npc_police:notify', '~g~Arrived at Jail',
                    'Processing ' .. npcData.identity.fullName .. ' into custody.')

                -- Notify server
                TriggerServerEvent('npc_police:suspectJailed', {
                    name = npcData.identity.fullName,
                    violations = npcData.violations,
                })

                -- Dispatch all clear
                TriggerEvent('npc_police:dispatch', 'allClear',
                    string.format(Config.Immersion.DispatchMessages.allClear,
                        'Bolingbroke Penitentiary'
                    )
                )

                -- Despawn the NPC after delay
                Wait(Config.Arrest.DespawnDelay)
                DespawnArrestedNPC(npcData)
                return
            end

            Wait(2000)
        end

        isTransporting = false
    end)
end

-- ============================================================================
-- REMOVE FROM VEHICLE
-- ============================================================================

function RemoveFromVehicle(npcData, vehicle)
    local ped = npcData.ped
    if not DoesEntityExist(ped) then return end

    if IsPedInAnyVehicle(ped, false) then
        TaskLeaveVehicle(ped, vehicle, 0)

        local timeout = 0
        while IsPedInAnyVehicle(ped, false) and timeout < 5000 do
            Wait(500)
            timeout = timeout + 500
        end
    end

    npcData.state = 'handcuffed'
    NPCPolice.AI.TransitionState(ped, 'handcuffed')

    TriggerEvent('npc_police:notify', '~b~Removed', 'Suspect removed from vehicle.')
    Wait(500)
    OpenPostArrestMenu(npcData)
end

-- ============================================================================
-- RELEASE SUSPECT
-- ============================================================================

function ReleaseSuspect(npcData)
    local ped = npcData.ped
    if not DoesEntityExist(ped) then return end

    -- Stop escorting if active
    if isEscorting then
        StopEscort()
    end

    -- Clear animations and free the NPC
    ClearPedTasks(ped)
    SetBlockingOfNonTemporaryEvents(ped, false)
    SetPedCanBeDraggedOut(ped, true)
    SetPedCanRagdoll(ped, true)

    TriggerEvent('npc_police:showSubtitle', "You're free to go.")
    TriggerEvent('npc_police:notify', '~g~Released', npcData.identity.fullName .. ' has been released.')

    -- Make the NPC walk away
    local awayPos = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, -50.0, 0.0)
    TaskGoStraightToCoord(ped, awayPos.x, awayPos.y, awayPos.z, 1.0, 20000, GetEntityHeading(ped), 1.0)

    -- Despawn after walking away
    CreateThread(function()
        Wait(20000)
        if DoesEntityExist(ped) then
            local dist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(ped))
            if dist > 30.0 then
                SetEntityAsMissionEntity(ped, false, true)
                DeleteEntity(ped)
            end
        end
    end)

    -- Clean up data
    CancelTrafficStop()
end

-- ============================================================================
-- DESPAWN ARRESTED NPC
-- ============================================================================

function DespawnArrestedNPC(npcData)
    local ped = npcData.ped

    if DoesEntityExist(ped) then
        -- Fade out
        NetworkFadeOutEntity(ped, true, false)
        Wait(1500)

        if DoesEntityExist(ped) then
            if IsPedInAnyVehicle(ped, false) then
                local vehicle = GetVehiclePedIsIn(ped, false)
                TaskLeaveVehicle(ped, vehicle, 0)
                Wait(1000)
            end

            SetEntityAsMissionEntity(ped, false, true)
            DeleteEntity(ped)
        end
    end

    -- Clean up from active NPCs
    for npcId, data in pairs(activeNPCs) do
        if data.ped == npcData.ped then
            activeNPCs[npcId] = nil
            break
        end
    end

    CancelTrafficStop()

    TriggerEvent('npc_police:notify', '~g~Suspect Processed',
        npcData.identity.fullName .. ' has been booked into custody.')
end

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        if isEscorting then
            StopEscort()
        end
        isTransporting = false
    end
end)
