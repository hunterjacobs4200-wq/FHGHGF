--[[
    NPC Police Interactions - Client Main
    Handles NPC traffic spawning, violation assignment, and traffic density.
    Core loop that manages all active NPC vehicles in the player's vicinity.
]]

-- ============================================================================
-- LOCAL STATE
-- ============================================================================

local activeNPCs = {}          -- All managed NPC vehicles: { [netId] = npcData }
local isOnDuty = false         -- Whether the player is currently on police duty
local playerJob = nil          -- Cached player job name

-- ============================================================================
-- FRAMEWORK INTEGRATION
-- ============================================================================

CreateThread(function()
    NPCPolice.DetectFramework()

    if NPCPolice.Framework == 'esx' then
        local ESX = NPCPolice.FrameworkObj
        local playerData = ESX.GetPlayerData()
        if playerData and playerData.job then
            playerJob = playerData.job.name
            isOnDuty = NPCPolice.TableContains(Config.PoliceJobs, playerJob)
        end

        RegisterNetEvent('esx:setJob')
        AddEventHandler('esx:setJob', function(job)
            playerJob = job.name
            isOnDuty = NPCPolice.TableContains(Config.PoliceJobs, playerJob)
            if not isOnDuty then
                CleanupAllNPCs()
            end
        end)

    elseif NPCPolice.Framework == 'qbcore' then
        local QBCore = NPCPolice.FrameworkObj
        local playerData = QBCore.Functions.GetPlayerData()
        if playerData and playerData.job then
            playerJob = playerData.job.name
            isOnDuty = NPCPolice.TableContains(Config.PoliceJobs, playerJob)
                and (not Config.RequireOnDuty or playerData.job.onduty)
        end

        RegisterNetEvent('QBCore:Client:OnJobUpdate')
        AddEventHandler('QBCore:Client:OnJobUpdate', function(jobInfo)
            playerJob = jobInfo.name
            isOnDuty = NPCPolice.TableContains(Config.PoliceJobs, playerJob)
                and (not Config.RequireOnDuty or jobInfo.onduty)
            if not isOnDuty then
                CleanupAllNPCs()
            end
        end)

    else
        -- Standalone mode: always on duty
        isOnDuty = true
    end
end)

-- ============================================================================
-- EXPORTS: Let other scripts check state
-- ============================================================================

exports('IsOnDuty', function()
    return isOnDuty
end)

exports('GetActiveNPCs', function()
    return activeNPCs
end)

exports('GetNPCData', function(netId)
    return activeNPCs[netId]
end)

-- ============================================================================
-- NPC DATA STRUCTURE FACTORY
-- ============================================================================

local function CreateNPCData(ped, vehicle, plate)
    local isMale = GetEntityModel(ped) ~= GetHashKey('a_f_y_business_01')
        and GetEntityModel(ped) ~= GetHashKey('a_f_y_hipster_01')
        and GetEntityModel(ped) ~= GetHashKey('a_f_m_downtown_01')
        and GetEntityModel(ped) ~= GetHashKey('a_f_m_bevhills_01')
        and GetEntityModel(ped) ~= GetHashKey('a_f_y_tourist_01')

    local identity = NPCPolice.GenerateIdentity(isMale)

    -- Roll violations
    local violations = {}
    for violationType, chance in pairs(Config.Violations) do
        if math.random() < chance then
            violations[violationType] = true
        end
    end

    -- Determine NPC reaction profile
    local reactionType, reactionProfile = NPCPolice.WeightedRandom(Config.Reactions)

    -- Generate BAC if DUI
    local bac
    if violations.DUI then
        local levels = Config.Tests.BACLevels
        local roll = math.random()
        if roll < 0.3 then
            bac = NPCPolice.RandomFloat(levels.buzzed.min, levels.buzzed.max)
        elseif roll < 0.7 then
            bac = NPCPolice.RandomFloat(levels.impaired.min, levels.impaired.max)
        else
            bac = NPCPolice.RandomFloat(levels.drunk.min, levels.drunk.max)
        end
    else
        bac = NPCPolice.RandomFloat(0.0, 0.02)
    end

    -- Drug test result
    local drugResult = 'Negative'
    if violations.DUI and math.random() < 0.3 then
        drugResult = NPCPolice.RandomFromArray(Config.Tests.DrugTestResults)
    end

    return {
        ped = ped,
        vehicle = vehicle,
        plate = plate,
        identity = identity,
        violations = violations,
        reactionType = reactionType,
        reaction = reactionProfile,
        bac = bac,
        drugResult = drugResult,
        state = 'driving',           -- driving, pullingOver, stopped, fleeing, arrested, despawned
        hasBeenStopped = false,
        idChecked = false,
        plateChecked = false,
        frisked = false,
        vehicleSearched = false,
        breathalyzerDone = false,
        drugTestDone = false,
        ticketed = false,
        warned = false,
        spawnTime = GetGameTimer(),
        isMale = isMale,
    }
end

-- ============================================================================
-- VEHICLE SPAWNING
-- ============================================================================

local function GetRandomRoadPosition(playerPos)
    local nodeFound, nodePos, nodeHeading = false, vector3(0, 0, 0), 0.0
    local attempts = 0

    while not nodeFound and attempts < 15 do
        attempts = attempts + 1
        local offsetX = math.random(-200, 200)
        local offsetY = math.random(-200, 200)
        local testPos = playerPos + vector3(offsetX, offsetY, 0.0)

        local found, pos, heading = GetClosestVehicleNodeWithHeading(testPos.x, testPos.y, testPos.z, 1, 3.0, 0)
        if found then
            local dist = #(playerPos - pos)
            if dist > 80.0 and dist < Config.Traffic.SpawnRadius then
                nodeFound = true
                nodePos = pos
                nodeHeading = heading
            end
        end
    end

    return nodeFound, nodePos, nodeHeading
end

local function LoadModel(model)
    local hash = type(model) == 'string' and GetHashKey(model) or model
    if not IsModelValid(hash) then return false end
    RequestModel(hash)
    local timeout = 0
    while not HasModelLoaded(hash) and timeout < 5000 do
        Wait(10)
        timeout = timeout + 10
    end
    return HasModelLoaded(hash)
end

local function GetRandomVehicleModel()
    if #Config.Traffic.VehicleModels > 0 then
        return GetHashKey(NPCPolice.RandomFromArray(Config.Traffic.VehicleModels))
    end

    -- Use common ambient vehicle models
    local ambientVehicles = {
        'sultan', 'buffalo', 'oracle', 'fugitive', 'tailgater', 'schafter2',
        'exemplar', 'felon', 'jackal', 'sentinel', 'zion', 'fusilade',
        'prairie', 'penumbra', 'blista', 'issi2', 'panto', 'dilettante',
        'asea', 'asterope', 'emperor', 'ingot', 'intruder', 'premier',
        'primo', 'regina', 'stanier', 'stratum', 'surge', 'washington',
        'minivan', 'rumpo', 'youga', 'bison', 'bobcatxl', 'sadler',
        'picador', 'ratloader', 'sandking',
    }

    return GetHashKey(NPCPolice.RandomFromArray(ambientVehicles))
end

local function SpawnNPCVehicle()
    if not isOnDuty then return end

    local activeCount = 0
    for _ in pairs(activeNPCs) do
        activeCount = activeCount + 1
    end

    if activeCount >= Config.Traffic.MaxActiveVehicles then return end

    local playerPed = PlayerPedId()
    local playerPos = GetEntityCoords(playerPed)

    local found, spawnPos, spawnHeading = GetRandomRoadPosition(playerPos)
    if not found then return end

    -- Get a random vehicle model
    local vehicleModel = GetRandomVehicleModel()
    if not LoadModel(vehicleModel) then return end

    -- Get a random ped model
    local pedModelName = NPCPolice.RandomFromArray(Config.Traffic.PedModels)
    local pedModel = GetHashKey(pedModelName)
    if not LoadModel(pedModel) then
        SetModelAsNoLongerNeeded(vehicleModel)
        return
    end

    -- Create vehicle
    local vehicle = CreateVehicle(vehicleModel, spawnPos.x, spawnPos.y, spawnPos.z, spawnHeading, true, true)
    if not DoesEntityExist(vehicle) then
        SetModelAsNoLongerNeeded(vehicleModel)
        SetModelAsNoLongerNeeded(pedModel)
        return
    end

    -- Generate and set plate
    local plate = NPCPolice.GeneratePlate()
    SetVehicleNumberPlateText(vehicle, plate)

    -- Create driver ped
    local ped = CreatePedInsideVehicle(vehicle, 4, pedModel, -1, true, true)
    if not DoesEntityExist(ped) then
        DeleteEntity(vehicle)
        SetModelAsNoLongerNeeded(vehicleModel)
        SetModelAsNoLongerNeeded(pedModel)
        return
    end

    -- Set basic ped attributes
    SetEntityAsMissionEntity(ped, true, true)
    SetEntityAsMissionEntity(vehicle, true, true)
    SetPedRandomComponentVariation(ped, 0)
    SetBlockingOfNonTemporaryEvents(ped, true)

    -- Make the ped drive around
    TaskVehicleDriveWander(ped, vehicle, 20.0, 786603)

    -- Clean up model memory
    SetModelAsNoLongerNeeded(vehicleModel)
    SetModelAsNoLongerNeeded(pedModel)

    -- Store NPC data
    local npcData = CreateNPCData(ped, vehicle, plate)
    local npcId = ped  -- Use ped handle as key

    activeNPCs[npcId] = npcData

    -- Apply driving behavior based on violations
    ApplyViolationBehavior(npcId, npcData)

    NPCPolice.Debug(('Spawned NPC: %s driving %s [%s]'):format(
        npcData.identity.fullName,
        GetDisplayNameFromVehicleModel(GetEntityModel(vehicle)),
        plate
    ))
end

-- ============================================================================
-- VIOLATION BEHAVIOR APPLICATION
-- ============================================================================

function ApplyViolationBehavior(npcId, data)
    local ped = data.ped
    local vehicle = data.vehicle

    if not DoesEntityExist(ped) or not DoesEntityExist(vehicle) then return end

    -- Speeding
    if data.violations.Speeding then
        local speedBoost = NPCPolice.RandomFloat(15.0, 40.0)
        TaskVehicleDriveWander(ped, vehicle, 25.0 + speedBoost, 524288)
    end

    -- Reckless driving
    if data.violations.RecklessDriving then
        SetDriverAbility(ped, 0.0)
        SetDriverAggressiveness(ped, 1.0)
        TaskVehicleDriveWander(ped, vehicle, 35.0, 524288 + 2 + 4 + 32)
    end

    -- DUI / Swerving behavior
    if data.violations.DUI or data.violations.Swerving then
        SetDriverAbility(ped, 0.1)
        SetPedIsDrunk(ped, true)
        SetPedConfigFlag(ped, 100, true) -- drunk flag

        -- Create swerving behavior via periodic steering input
        CreateThread(function()
            while DoesEntityExist(ped) and DoesEntityExist(vehicle)
                and activeNPCs[npcId] and activeNPCs[npcId].state == 'driving' do

                if IsPedInAnyVehicle(ped, false) then
                    local speed = GetEntitySpeed(vehicle)
                    if speed > 2.0 then
                        local swerveAmount = NPCPolice.RandomFloat(-0.5, 0.5)
                        SetVehicleSteer(vehicle, swerveAmount)
                    end
                end
                Wait(math.random(1000, 3000))
            end
        end)
    end

    -- Running red lights / stop signs
    if data.violations.RunRedLight or data.violations.RunStopSign then
        SetDriverAggressiveness(ped, 0.8)
        TaskVehicleDriveWander(ped, vehicle, 22.0, 1 + 2 + 4 + 32 + 512)
    end

    -- Broken taillight visual
    if data.violations.BrokenTaillight then
        SetVehicleDamage(vehicle, -1.0, -1.5, -0.5, 100.0, 100.0, true)
    end
end

-- ============================================================================
-- CLEANUP SYSTEM
-- ============================================================================

function CleanupNPC(npcId)
    local data = activeNPCs[npcId]
    if not data then return end

    if DoesEntityExist(data.ped) then
        SetEntityAsMissionEntity(data.ped, false, true)
        DeleteEntity(data.ped)
    end

    if DoesEntityExist(data.vehicle) then
        SetEntityAsMissionEntity(data.vehicle, false, true)
        DeleteEntity(data.vehicle)
    end

    activeNPCs[npcId] = nil
    NPCPolice.Debug(('Cleaned up NPC: %s'):format(tostring(npcId)))
end

function CleanupAllNPCs()
    for npcId in pairs(activeNPCs) do
        CleanupNPC(npcId)
    end
    activeNPCs = {}
end

-- Cleanup NPCs that are too far from the player
local function CleanupDistantNPCs()
    local playerPos = GetEntityCoords(PlayerPedId())

    for npcId, data in pairs(activeNPCs) do
        if data.state ~= 'stopped' and data.state ~= 'arrested' then
            if DoesEntityExist(data.vehicle) then
                local npcPos = GetEntityCoords(data.vehicle)
                local dist = #(playerPos - npcPos)

                if dist > Config.Traffic.DespawnRadius then
                    CleanupNPC(npcId)
                end
            else
                -- Entity no longer exists, clean up data
                activeNPCs[npcId] = nil
            end
        end
    end
end

-- ============================================================================
-- MAIN TRAFFIC LOOP
-- ============================================================================

CreateThread(function()
    -- Wait for framework detection
    while NPCPolice.Framework == nil do
        Wait(100)
    end

    while true do
        if isOnDuty then
            -- Spawn new NPCs if under limit
            SpawnNPCVehicle()

            -- Clean up distant NPCs
            CleanupDistantNPCs()

            Wait(Config.Traffic.SpawnInterval)
        else
            Wait(5000)
        end
    end
end)

-- ============================================================================
-- TRAFFIC DENSITY MANAGEMENT
-- ============================================================================

CreateThread(function()
    while true do
        if isOnDuty then
            -- Apply density multiplier to keep performance in check
            SetParkedVehicleDensityMultiplierThisFrame(Config.Traffic.DensityMultiplier)
            SetVehicleDensityMultiplierThisFrame(Config.Traffic.DensityMultiplier)
            SetRandomVehicleDensityMultiplierThisFrame(Config.Traffic.DensityMultiplier)
            SetPedDensityMultiplierThisFrame(Config.Traffic.DensityMultiplier)
            SetScenarioPedDensityMultiplierThisFrame(Config.Traffic.DensityMultiplier, Config.Traffic.DensityMultiplier)
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

-- ============================================================================
-- TOGGLE DUTY COMMAND (STANDALONE)
-- ============================================================================

RegisterCommand(Config.CommandPrefix .. ':duty', function()
    if NPCPolice.Framework == 'standalone' then
        isOnDuty = not isOnDuty
        if isOnDuty then
            TriggerEvent('npc_police:notify', '~g~On Duty', 'You are now on police duty.')
        else
            CleanupAllNPCs()
            TriggerEvent('npc_police:notify', '~r~Off Duty', 'You are now off duty.')
        end
    else
        TriggerEvent('npc_police:notify', '~r~Error', 'Duty is managed by your framework.')
    end
end, false)

-- ============================================================================
-- RESOURCE CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        CleanupAllNPCs()
    end
end)

-- ============================================================================
-- EXPORTED FUNCTIONS FOR OTHER CLIENT SCRIPTS
-- ============================================================================

--- Get NPC data by ped handle (used by pullover, menu, etc.)
---@param ped number
---@return table|nil
function GetNPCDataByPed(ped)
    for npcId, data in pairs(activeNPCs) do
        if data.ped == ped then
            return data, npcId
        end
    end
    return nil, nil
end

--- Get NPC data by vehicle handle
---@param vehicle number
---@return table|nil
function GetNPCDataByVehicle(vehicle)
    for npcId, data in pairs(activeNPCs) do
        if data.vehicle == vehicle then
            return data, npcId
        end
    end
    return nil, nil
end

--- Update NPC state
---@param npcId number
---@param newState string
function SetNPCState(npcId, newState)
    if activeNPCs[npcId] then
        activeNPCs[npcId].state = newState
    end
end
