--[[
    NPC Police Interactions - Pullover System
    Detects when an officer activates lights/siren behind an NPC vehicle.
    Handles NPC pullover behavior, approach detection, and stop initiation.
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local currentTarget = nil       -- Currently targeted NPC ped handle
local isInitiatingStop = false  -- Whether we're in the process of pulling someone over
local sirenTimer = 0            -- How long sirens have been active behind target
local approachPhase = false     -- Whether officer is in approach phase

-- ============================================================================
-- PULLOVER DETECTION LOOP
-- ============================================================================

CreateThread(function()
    while true do
        local sleep = 1000

        if isOnDuty and not isInitiatingStop and not currentTarget then
            local playerPed = PlayerPedId()

            if IsPedInAnyVehicle(playerPed, false) then
                local playerVehicle = GetVehiclePedIsIn(playerPed, false)

                -- Check if player has sirens/lights on
                local sirenActive = IsVehicleSirenOn(playerVehicle)

                if sirenActive then
                    sleep = 500

                    -- Look for NPC vehicles ahead of us
                    local target = FindNPCVehicleAhead(playerPed, playerVehicle)

                    if target then
                        sirenTimer = sirenTimer + 500

                        -- Show targeting indicator
                        local targetPos = GetEntityCoords(target.vehicle)
                        DrawMarker(2, targetPos.x, targetPos.y, targetPos.z + 2.5,
                            0, 0, 0, 0, 0, 0,
                            0.5, 0.5, 0.5,
                            255, 0, 0, 180,
                            true, true, 2, false, nil, nil, false
                        )

                        -- Check if siren has been on long enough
                        if sirenTimer >= Config.Pullover.SirenResponseTime then
                            InitiateTrafficStop(target)
                        end
                    else
                        sirenTimer = 0
                    end
                else
                    sirenTimer = 0
                end
            else
                sirenTimer = 0
            end
        elseif currentTarget and approachPhase then
            sleep = 0
        else
            sleep = 2000
        end

        Wait(sleep)
    end
end)

-- ============================================================================
-- NPC VEHICLE DETECTION
-- ============================================================================

--- Find the closest managed NPC vehicle in front of the player's vehicle
---@param playerPed number
---@param playerVehicle number
---@return table|nil npcData
function FindNPCVehicleAhead(_, playerVehicle)
    local playerPos = GetEntityCoords(playerVehicle)
    local playerForward = GetEntityForwardVector(playerVehicle)

    local bestTarget = nil
    local bestDist = Config.Pullover.DetectionRange

    for _, data in pairs(activeNPCs) do
        if data.state == 'driving' and not data.hasBeenStopped then
            if DoesEntityExist(data.vehicle) then
                local npcPos = GetEntityCoords(data.vehicle)
                local dist = #(playerPos - npcPos)

                if dist < bestDist then
                    -- Check if the NPC is roughly in front of us
                    local direction = norm(npcPos - playerPos)
                    local dot = playerForward.x * direction.x
                        + playerForward.y * direction.y

                    if dot > 0.5 then -- Within ~60 degree cone
                        bestDist = dist
                        bestTarget = data
                    end
                end
            end
        end
    end

    return bestTarget
end

--- Normalize a vector3
---@param v vector3
---@return vector3
function norm(v)
    local len = #v
    if len == 0 then return vector3(0, 0, 0) end
    return v / len
end

-- ============================================================================
-- TRAFFIC STOP INITIATION
-- ============================================================================

--- Begin a traffic stop on a target NPC
---@param npcData table
function InitiateTrafficStop(npcData)
    if isInitiatingStop then return end
    isInitiatingStop = true
    currentTarget = npcData.ped
    sirenTimer = 0

    local ped = npcData.ped
    local vehicle = npcData.vehicle

    -- Dispatch notification
    local pos = GetEntityCoords(vehicle)
    local streetName = NPCPolice.GetStreetName(pos)
    TriggerEvent('npc_police:dispatch', 'trafficStop',
        string.format(Config.Immersion.DispatchMessages.trafficStop, streetName)
    )

    -- Notify server of traffic stop
    TriggerServerEvent('npc_police:trafficStopInitiated', {
        plate = npcData.plate,
        location = streetName,
        violations = npcData.violations,
    })

    -- Trigger NPC AI response
    NPCPolice.AI.TransitionState(ped, 'alerted')

    -- Notify player
    TriggerEvent('npc_police:notify', '~b~Traffic Stop',
        'Vehicle is responding to your lights. Approach when stopped.'
    )

    -- Monitor until NPC is stopped
    CreateThread(function()
        local timeout = 0
        while npcData.state ~= 'stopped' and npcData.state ~= 'fleeing_car'
            and npcData.state ~= 'fleeing_foot' and timeout < 30000 do
            Wait(500)
            timeout = timeout + 500
        end

        if npcData.state == 'fleeing_car' or npcData.state == 'fleeing_foot' then
            TriggerEvent('npc_police:notify', '~r~Suspect Fleeing!',
                'The driver is attempting to flee!')
            NPCPolice.AI.MonitorFlee(ped, npcData)
            isInitiatingStop = false
            return
        end

        if npcData.state == 'stopped' then
            approachPhase = true
            TriggerEvent('npc_police:notify', '~g~Vehicle Stopped',
                'The vehicle has pulled over. Approach the driver.')
            BeginApproachPhase(npcData)
        end

        isInitiatingStop = false
    end)
end

-- ============================================================================
-- APPROACH PHASE
-- ============================================================================

--- Handle the approach phase after NPC has stopped
---@param npcData table
function BeginApproachPhase(npcData)
    CreateThread(function()
        while approachPhase and DoesEntityExist(npcData.ped) do
            local playerPed = PlayerPedId()
            local playerPos = GetEntityCoords(playerPed)
            local npcPos = GetEntityCoords(npcData.ped)
            local dist = #(playerPos - npcPos)

            -- Show interaction prompt when close enough
            if dist < 3.0 and not IsPedInAnyVehicle(playerPed, false) then
                -- Display help text
                BeginTextCommandDisplayHelp('STRING')
                AddTextComponentSubstringPlayerName('Press ~INPUT_CONTEXT~ to interact with the driver')
                EndTextCommandDisplayHelp(0, false, true, -1)

                -- Check for interaction key press
                if IsControlJustPressed(0, Config.Keys.InteractionMenu) then
                    approachPhase = false
                    -- Show greeting dialogue
                    local greeting = NPCPolice.AI.GetDialogue(npcData, 'greeting')
                    TriggerEvent('npc_police:showSubtitle', greeting)

                    -- Open interaction menu
                    TriggerEvent('npc_police:openMenu', npcData)
                end
            elseif dist < 10.0 then
                -- Draw approach marker
                DrawMarker(25, npcPos.x, npcPos.y, npcPos.z + 1.2,
                    0, 0, 0, 0, 0, 0,
                    0.5, 0.5, 0.5,
                    100, 150, 255, 180,
                    true, true, 2, false, nil, nil, false
                )
            end

            Wait(0)
        end
    end)
end

-- ============================================================================
-- CANCEL / RESET STOP
-- ============================================================================

--- Cancel the current traffic stop
function CancelTrafficStop()
    if currentTarget and DoesEntityExist(currentTarget) then
        local data = GetNPCDataByPed(currentTarget)
        if data and data.state == 'stopped' then
            -- Let NPC drive away
            local vehicle = data.vehicle
            if DoesEntityExist(vehicle) then
                SetVehicleHandbrake(vehicle, false)
                SetVehicleEngineOn(vehicle, true, true, false)
                SetVehicleIndicatorLights(vehicle, 0, false)
                SetVehicleIndicatorLights(vehicle, 1, false)
                TaskVehicleDriveWander(data.ped, vehicle, 15.0, 786603)
            end
            data.state = 'driving'
            data.hasBeenStopped = false
        end
    end

    currentTarget = nil
    currentTargetId = nil
    isInitiatingStop = false
    approachPhase = false
    sirenTimer = 0
end

--- Get current target NPC data
---@return table|nil
function GetCurrentTargetData()
    if currentTarget and DoesEntityExist(currentTarget) then
        return GetNPCDataByPed(currentTarget)
    end
    return nil
end

--- Check if there's an active traffic stop
---@return boolean
function HasActiveStop()
    return currentTarget ~= nil
end

-- ============================================================================
-- EXPORTS
-- ============================================================================

exports('CancelTrafficStop', CancelTrafficStop)
exports('GetCurrentTargetData', GetCurrentTargetData)
exports('HasActiveStop', HasActiveStop)

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        CancelTrafficStop()
    end
end)
