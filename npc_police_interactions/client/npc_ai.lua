--[[
    NPC Police Interactions - NPC AI System
    Behavior trees and state handling for NPC reactions.
    Controls how NPCs respond to police presence and commands.
]]

-- ============================================================================
-- AI STATE MACHINE
-- ============================================================================

-- Possible AI states:
-- 'driving'      -> Normal driving
-- 'alerted'      -> Noticed police behind them
-- 'pullingOver'  -> Actively looking for a spot to stop
-- 'stopped'      -> Pulled over and waiting
-- 'exiting'      -> Getting out of vehicle
-- 'standing'     -> Standing outside vehicle
-- 'fleeing_car'  -> Fleeing in vehicle
-- 'fleeing_foot' -> Fleeing on foot
-- 'fighting'     -> Attacking the officer
-- 'surrendering' -> Hands up / giving up
-- 'handcuffed'   -> In custody
-- 'escorted'     -> Being walked by officer
-- 'intransport'  -> Placed in police vehicle
-- 'despawned'    -> Cleaned up

local AI = {}

-- ============================================================================
-- STATE TRANSITION HANDLERS
-- ============================================================================

--- Transition an NPC to a new state with proper setup
---@param npcId number
---@param newState string
---@param params table|nil optional params for the state
function AI.TransitionState(npcId, newState, params)
    local data = GetNPCDataByPed(npcId) or (activeNPCs and activeNPCs[npcId])
    if not data then return end

    local oldState = data.state
    data.state = newState
    params = params or {}

    NPCPolice.Debug(('NPC %s: %s -> %s'):format(data.identity.fullName, oldState, newState))

    -- Execute state entry logic
    if newState == 'alerted' then
        AI.OnAlerted(data, params)
    elseif newState == 'pullingOver' then
        AI.OnPullingOver(data, params)
    elseif newState == 'stopped' then
        AI.OnStopped(data, params)
    elseif newState == 'exiting' then
        AI.OnExiting(data, params)
    elseif newState == 'standing' then
        AI.OnStanding(data, params)
    elseif newState == 'fleeing_car' then
        AI.OnFleeingCar(data, params)
    elseif newState == 'fleeing_foot' then
        AI.OnFleeingFoot(data, params)
    elseif newState == 'fighting' then
        AI.OnFighting(data, params)
    elseif newState == 'surrendering' then
        AI.OnSurrendering(data, params)
    elseif newState == 'handcuffed' then
        AI.OnHandcuffed(data, params)
    elseif newState == 'escorted' then
        AI.OnEscorted(data, params)
    end
end

-- ============================================================================
-- STATE ENTRY HANDLERS
-- ============================================================================

function AI.OnAlerted(data, _params)
    local ped = data.ped
    if not DoesEntityExist(ped) then return end

    -- NPC notices the police
    SetBlockingOfNonTemporaryEvents(ped, true)

    -- Brief delay to simulate reaction time
    CreateThread(function()
        Wait(math.random(1000, 2500))

        if not DoesEntityExist(ped) then return end

        -- Decide: pull over or flee
        local shouldFlee = false

        if data.reaction.mayFlee and math.random() < Config.Pullover.FleeChance * 3.0 then
            shouldFlee = true
        elseif data.violations.ActiveWarrant and math.random() < 0.6 then
            shouldFlee = true
        elseif data.violations.StolenVehicle and math.random() < 0.4 then
            shouldFlee = true
        elseif math.random() < Config.Pullover.FleeChance then
            shouldFlee = true
        end

        if shouldFlee then
            AI.TransitionState(data.ped, 'fleeing_car')
        else
            AI.TransitionState(data.ped, 'pullingOver')
        end
    end)
end

function AI.OnPullingOver(data, _params)
    local ped = data.ped
    local vehicle = data.vehicle

    if not DoesEntityExist(ped) or not DoesEntityExist(vehicle) then return end

    SetBlockingOfNonTemporaryEvents(ped, true)

    -- Find a safe spot to pull over on the right side of the road
    local vehPos = GetEntityCoords(vehicle)

    local found, _, _ = GetClosestVehicleNodeWithHeading(
        vehPos.x, vehPos.y, vehPos.z, 1, 3.0, 0
    )

    if found then
        -- Offset to the right side of the road
        local rightOffset = GetOffsetFromEntityInWorldCoords(vehicle, 3.0, 15.0, 0.0)

        local roadFound, roadPos = GetClosestVehicleNodeWithHeading(
            rightOffset.x, rightOffset.y, rightOffset.z, 1, 3.0, 0
        )

        local targetPos = roadFound and roadPos or rightOffset

        -- Slow down and pull to the side
        TaskVehicleDriveToCoordLongrange(
            ped, vehicle,
            targetPos.x, targetPos.y, targetPos.z,
            8.0,  -- Slow speed
            786603,
            5.0   -- Stop distance
        )

        -- Monitor until stopped
        CreateThread(function()
            local timeout = 0
            while DoesEntityExist(vehicle) and data.state == 'pullingOver' and timeout < 15000 do
                Wait(500)
                timeout = timeout + 500

                local speed = GetEntitySpeed(vehicle)
                if speed < 0.5 then
                    AI.TransitionState(data.ped, 'stopped')
                    return
                end
            end

            -- Force stop if timeout
            if DoesEntityExist(vehicle) and data.state == 'pullingOver' then
                TaskVehicleTempAction(ped, vehicle, 1, 3000) -- brake
                Wait(2000)
                AI.TransitionState(data.ped, 'stopped')
            end
        end)
    else
        -- No node found, just slow down and stop
        TaskVehicleTempAction(ped, vehicle, 1, 5000)
        Wait(3000)
        AI.TransitionState(data.ped, 'stopped')
    end
end

function AI.OnStopped(data, _params)
    local ped = data.ped
    local vehicle = data.vehicle

    if not DoesEntityExist(ped) or not DoesEntityExist(vehicle) then return end

    -- Stop the vehicle completely
    TaskVehicleTempAction(ped, vehicle, 1, -1) -- brake forever
    SetVehicleEngineOn(vehicle, false, true, true)
    SetVehicleHandbrake(vehicle, true)
    SetBlockingOfNonTemporaryEvents(ped, true)

    data.hasBeenStopped = true

    -- Apply turn signals (hazards)
    SetVehicleIndicatorLights(vehicle, 0, true)
    SetVehicleIndicatorLights(vehicle, 1, true)

    -- Start patience timer
    CreateThread(function()
        Wait(Config.Pullover.PatienceTimeout)
        if data.state == 'stopped' and DoesEntityExist(ped) then
            -- NPC gets impatient and drives off
            SetVehicleHandbrake(vehicle, false)
            SetVehicleEngineOn(vehicle, true, true, false)
            SetVehicleIndicatorLights(vehicle, 0, false)
            SetVehicleIndicatorLights(vehicle, 1, false)
            TaskVehicleDriveWander(ped, vehicle, 15.0, 786603)
            data.state = 'driving'
            data.hasBeenStopped = false
        end
    end)
end

function AI.OnExiting(data, params)
    local ped = data.ped
    local vehicle = data.vehicle

    if not DoesEntityExist(ped) then return end

    if data.reaction.exitsOnCommand or (params and params.force) then
        -- Comply with exit command
        TaskLeaveVehicle(ped, vehicle, 0)

        CreateThread(function()
            local timeout = 0
            while IsPedInAnyVehicle(ped, false) and timeout < 8000 do
                Wait(200)
                timeout = timeout + 200
            end

            if DoesEntityExist(ped) and not IsPedInAnyVehicle(ped, false) then
                AI.TransitionState(data.ped, 'standing')
            end
        end)
    else
        -- Refuse to exit
        TriggerEvent('npc_police:showSubtitle', NPCPolice.RandomFromArray(
            Config.Dialogue.Aggressive.exitVehicle
        ))

        -- May escalate
        if data.reaction.mayAttack and math.random() < 0.3 then
            Wait(2000)
            AI.TransitionState(data.ped, 'fighting')
        elseif data.reaction.mayFlee and math.random() < 0.5 then
            Wait(1500)
            AI.TransitionState(data.ped, 'fleeing_car')
        end
    end
end

function AI.OnStanding(data, _params)
    local ped = data.ped
    if not DoesEntityExist(ped) then return end

    -- Stand still and face the officer
    local playerPed = PlayerPedId()
    local playerPos = GetEntityCoords(playerPed)

    TaskTurnPedToFaceCoord(ped, playerPos.x, playerPos.y, playerPos.z, 2000)
    SetBlockingOfNonTemporaryEvents(ped, true)

    -- Nervous fidgeting for nervous NPCs
    if data.reaction.nervous then
        CreateThread(function()
            while data.state == 'standing' and DoesEntityExist(ped) do
                if math.random() < 0.3 then
                    TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true)
                    Wait(math.random(3000, 6000))
                    ClearPedTasks(ped)
                end
                Wait(5000)
            end
        end)
    end
end

function AI.OnFleeingCar(data, _params)
    local ped = data.ped
    local vehicle = data.vehicle

    if not DoesEntityExist(ped) or not DoesEntityExist(vehicle) then return end

    -- Turn off hazards
    SetVehicleIndicatorLights(vehicle, 0, false)
    SetVehicleIndicatorLights(vehicle, 1, false)

    -- Start the engine and floor it
    SetVehicleHandbrake(vehicle, false)
    SetVehicleEngineOn(vehicle, true, true, false)
    SetBlockingOfNonTemporaryEvents(ped, false)

    -- Aggressive fleeing
    local playerPed = PlayerPedId()
    TaskSmartFleePed(ped, playerPed, 1000.0, -1, false, false)
    TaskVehicleDriveWander(ped, vehicle, 80.0, 524288 + 2 + 4 + 8 + 16 + 32)

    SetDriverAbility(ped, 1.0)
    SetDriverAggressiveness(ped, 1.0)

    -- Dispatch notification
    local pos = GetEntityCoords(vehicle)
    local streetName = NPCPolice.GetStreetName(pos)
    TriggerEvent('npc_police:dispatch', 'pursuit',
        string.format(Config.Immersion.DispatchMessages.pursuit, streetName)
    )
end

function AI.OnFleeingFoot(data, _params)
    local ped = data.ped

    if not DoesEntityExist(ped) then return end

    -- Get out of vehicle if still in one
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        SetVehicleHandbrake(vehicle, true)
        TaskLeaveVehicle(ped, vehicle, 4160) -- flee flag
        Wait(2000)
    end

    SetBlockingOfNonTemporaryEvents(ped, false)
    local playerPed = PlayerPedId()
    TaskSmartFleePed(ped, playerPed, 500.0, -1, true, true)

    -- Dispatch notification
    local pos = GetEntityCoords(ped)
    local streetName = NPCPolice.GetStreetName(pos)
    TriggerEvent('npc_police:dispatch', 'footPursuit',
        string.format(Config.Immersion.DispatchMessages.footPursuit, streetName)
    )
end

function AI.OnFighting(data, _params)
    local ped = data.ped

    if not DoesEntityExist(ped) then return end

    -- Get out of vehicle first
    if IsPedInAnyVehicle(ped, false) then
        local vehicle = GetVehiclePedIsIn(ped, false)
        TaskLeaveVehicle(ped, vehicle, 256)
        Wait(2000)
    end

    SetBlockingOfNonTemporaryEvents(ped, false)

    -- Give weapon if armed profile
    if data.reaction.hasWeapon then
        local weaponType = NPCPolice.RandomFromArray(Config.Evidence.WeaponTypes)
        GiveWeaponToPed(ped, GetHashKey(weaponType.model), 50, false, true)
        Wait(500)
    end

    -- Attack player
    local playerPed = PlayerPedId()
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)
    SetPedCombatAbility(ped, 2)
    TaskCombatPed(ped, playerPed, 0, 16)

    -- Dispatch: shots fired
    local pos = GetEntityCoords(ped)
    local streetName = NPCPolice.GetStreetName(pos)
    TriggerEvent('npc_police:dispatch', 'codeRed',
        string.format(Config.Immersion.DispatchMessages.codeRed, streetName)
    )
end

function AI.OnSurrendering(data, _params)
    local ped = data.ped
    if not DoesEntityExist(ped) then return end

    -- Clear any combat or flee tasks
    ClearPedTasks(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)

    -- Hands up animation
    local animDict = Config.Anims.HandsUp.dict
    local animName = Config.Anims.HandsUp.name
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(10) end
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)

    -- Face the officer
    local playerPos = GetEntityCoords(PlayerPedId())
    TaskTurnPedToFaceCoord(ped, playerPos.x, playerPos.y, playerPos.z, 2000)
end

function AI.OnHandcuffed(data, _params)
    local ped = data.ped
    if not DoesEntityExist(ped) then return end

    ClearPedTasks(ped)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    DisablePlayerFiring(ped, true)

    -- Handcuff animation
    local animDict = Config.Anims.Surrender.dict
    local animName = Config.Anims.Surrender.name
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(10) end
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)

    -- Remove weapons
    RemoveAllPedWeapons(ped, true)
end

function AI.OnEscorted(data, _params)
    local ped = data.ped
    if not DoesEntityExist(ped) then return end

    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedCanRagdoll(ped, false)

    -- Escort animation
    local animDict = Config.Anims.Escort.dict
    local animName = Config.Anims.Escort.name
    RequestAnimDict(animDict)
    while not HasAnimDictLoaded(animDict) do Wait(10) end
    TaskPlayAnim(ped, animDict, animName, 8.0, -8.0, -1, 49, 0, false, false, false)
end

-- ============================================================================
-- AI DECISION MAKING
-- ============================================================================

--- Determine NPC response to a specific officer action
---@param data table NPC data
---@param action string the action being performed
---@return string response type: 'comply', 'refuse', 'flee', 'attack', 'lie'
function AI.DecideResponse(data, action)
    local reaction = data.reaction

    if action == 'requestID' then
        if reaction.providesRealID then
            return 'comply'
        elseif data.reactionType == 'FakeID' then
            return 'lie'
        else
            return 'refuse'
        end

    elseif action == 'exitVehicle' then
        if reaction.exitsOnCommand then
            return 'comply'
        elseif reaction.mayAttack and math.random() < 0.2 then
            return 'attack'
        elseif reaction.mayFlee and math.random() < 0.4 then
            return 'flee'
        else
            return 'refuse'
        end

    elseif action == 'frisk' then
        if reaction.allowsSearch then
            return 'comply'
        elseif reaction.mayAttack and math.random() < 0.15 then
            return 'attack'
        else
            return 'refuse'
        end

    elseif action == 'searchVehicle' then
        if reaction.allowsSearch then
            return 'comply'
        else
            return 'refuse'
        end

    elseif action == 'arrest' then
        if reaction.cooperates then
            return 'comply'
        elseif reaction.mayFlee and math.random() < 0.3 then
            return 'flee'
        elseif reaction.mayAttack and math.random() < 0.2 then
            return 'attack'
        else
            return 'comply' -- Eventually comply with arrest
        end

    elseif action == 'breathalyzer' then
        if reaction.cooperates then
            return 'comply'
        else
            return 'refuse'
        end

    elseif action == 'questions' then
        if data.reactionType == 'Intoxicated' then
            return 'lie' -- Slurred / incoherent
        elseif reaction.cooperates then
            return 'comply'
        else
            return 'refuse'
        end
    end

    return 'comply'
end

--- Get dialogue for a specific action based on NPC reaction type
---@param data table NPC data
---@param dialogueType string
---@return string
function AI.GetDialogue(data, dialogueType)
    local reactionType = data.reactionType
    local dialogueSet = Config.Dialogue[reactionType]

    if not dialogueSet then
        dialogueSet = Config.Dialogue.Compliant
    end

    if dialogueSet[dialogueType] then
        return NPCPolice.RandomFromArray(dialogueSet[dialogueType])
    end

    -- Fallback
    local fallback = Config.Dialogue.Compliant[dialogueType]
    if fallback then
        return NPCPolice.RandomFromArray(fallback)
    end

    return "..."
end

-- ============================================================================
-- FLEE MONITORING
-- ============================================================================

--- Monitor a fleeing NPC and handle surrender conditions
---@param npcId number
function AI.MonitorFlee(_npcId, data)
    CreateThread(function()
        local ped = data.ped
        local startTime = GetGameTimer()

        while DoesEntityExist(ped) and (data.state == 'fleeing_car' or data.state == 'fleeing_foot') do
            local elapsed = GetGameTimer() - startTime

            -- Check if ped is injured / incapacitated
            if IsPedFatallyInjured(ped) or IsPedRagdoll(ped) then
                Wait(2000)
                if DoesEntityExist(ped) and not IsPedFatallyInjured(ped) then
                    AI.TransitionState(ped, 'surrendering')
                end
                return
            end

            -- Small chance to give up after extended chase
            if elapsed > 30000 and math.random() < 0.02 then
                AI.TransitionState(ped, 'surrendering')
                return
            end

            Wait(1000)
        end
    end)
end

-- ============================================================================
-- MAKE AI FUNCTIONS GLOBALLY ACCESSIBLE
-- ============================================================================

NPCPolice.AI = AI
