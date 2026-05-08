--[[
    NPC Police Interactions - Server Side
    Handles server-side event logging, framework integration,
    backup dispatching, and cross-player synchronization.
]]

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local Framework = nil
local FrameworkObj = nil

CreateThread(function()
    NPCPolice.DetectFramework()
    Framework = NPCPolice.Framework
    FrameworkObj = NPCPolice.FrameworkObj
    print(('[NPC Police] Server started - Framework: %s'):format(Framework))
end)

-- ============================================================================
-- POLICE JOB VERIFICATION
-- ============================================================================

--- Check if a player has a police job
---@param source number
---@return boolean
local function IsPlayerPolice(source)
    if Framework == 'esx' then
        local xPlayer = FrameworkObj.GetPlayerFromId(source)
        if xPlayer then
            return NPCPolice.TableContains(Config.PoliceJobs, xPlayer.getJob().name)
        end
    elseif Framework == 'qbcore' then
        local player = FrameworkObj.Functions.GetPlayer(source)
        if player then
            return NPCPolice.TableContains(Config.PoliceJobs, player.PlayerData.job.name)
        end
    else
        -- Standalone: always allow
        return true
    end
    return false
end

-- ============================================================================
-- TRAFFIC STOP EVENTS
-- ============================================================================

RegisterNetEvent('npc_police:trafficStopInitiated')
AddEventHandler('npc_police:trafficStopInitiated', function(data)
    local source = source
    if not IsPlayerPolice(source) then return end

    local playerName = GetPlayerName(source)

    -- Log the traffic stop
    print(('[NPC Police] Officer %s (#%d) initiated a traffic stop on plate %s at %s'):format(
        playerName, source, data.plate or 'Unknown', data.location or 'Unknown'
    ))

    -- Build violation summary
    local violationList = {}
    if data.violations then
        for violation, active in pairs(data.violations) do
            if active then
                violationList[#violationList + 1] = violation
            end
        end
    end

    if #violationList > 0 then
        NPCPolice.Debug(('  Violations: %s'):format(table.concat(violationList, ', ')))
    end
end)

-- ============================================================================
-- WARNING / TICKET EVENTS
-- ============================================================================

RegisterNetEvent('npc_police:warningIssued')
AddEventHandler('npc_police:warningIssued', function(data)
    local source = source
    if not IsPlayerPolice(source) then return end

    local playerName = GetPlayerName(source)
    print(('[NPC Police] Officer %s (#%d) issued a warning to %s [Plate: %s]'):format(
        playerName, source, data.name or 'Unknown', data.plate or 'Unknown'
    ))
end)

RegisterNetEvent('npc_police:ticketIssued')
AddEventHandler('npc_police:ticketIssued', function(data)
    local source = source
    if not IsPlayerPolice(source) then return end

    local playerName = GetPlayerName(source)
    print(('[NPC Police] Officer %s (#%d) issued a $%d ticket to %s [Plate: %s]'):format(
        playerName, source, data.fine or 0, data.name or 'Unknown', data.plate or 'Unknown'
    ))

    -- Give fine money to the officer (optional, framework-dependent)
    if Framework == 'esx' then
        local xPlayer = FrameworkObj.GetPlayerFromId(source)
        if xPlayer then
            xPlayer.addMoney(math.floor(data.fine * 0.1)) -- 10% commission
        end
    elseif Framework == 'qbcore' then
        local player = FrameworkObj.Functions.GetPlayer(source)
        if player then
            player.Functions.AddMoney('cash', math.floor(data.fine * 0.1), 'npc-ticket-commission')
        end
    end
end)

-- ============================================================================
-- ARREST EVENTS
-- ============================================================================

RegisterNetEvent('npc_police:suspectArrested')
AddEventHandler('npc_police:suspectArrested', function(data)
    local source = source
    if not IsPlayerPolice(source) then return end

    local playerName = GetPlayerName(source)
    print(('[NPC Police] Officer %s (#%d) arrested %s at %s'):format(
        playerName, source, data.name or 'Unknown', data.location or 'Unknown'
    ))

    -- Build violation summary for arrest record
    local charges = {}
    if data.violations then
        for violation, active in pairs(data.violations) do
            if active then
                charges[#charges + 1] = violation
            end
        end
    end

    if #charges > 0 then
        print(('[NPC Police]   Charges: %s'):format(table.concat(charges, ', ')))
    end
end)

RegisterNetEvent('npc_police:suspectJailed')
AddEventHandler('npc_police:suspectJailed', function(data)
    local source = source
    if not IsPlayerPolice(source) then return end

    local playerName = GetPlayerName(source)
    print(('[NPC Police] Officer %s (#%d) transported %s to jail'):format(
        playerName, source, data.name or 'Unknown'
    ))

    -- Reward officer for completing the full arrest process
    local reward = 500
    if data.violations then
        for _, active in pairs(data.violations) do
            if active then
                reward = reward + math.random(50, 200)
            end
        end
    end

    if Framework == 'esx' then
        local xPlayer = FrameworkObj.GetPlayerFromId(source)
        if xPlayer then
            xPlayer.addMoney(reward)
            TriggerClientEvent('npc_police:notify', source, '~g~Payment',
                string.format('You earned $%d for processing the arrest.', reward))
        end
    elseif Framework == 'qbcore' then
        local player = FrameworkObj.Functions.GetPlayer(source)
        if player then
            player.Functions.AddMoney('cash', reward, 'npc-arrest-reward')
            TriggerClientEvent('npc_police:notify', source, '~g~Payment',
                string.format('You earned $%d for processing the arrest.', reward))
        end
    else
        TriggerClientEvent('npc_police:notify', source, '~g~Arrest Complete',
            'Suspect has been processed into custody.')
    end
end)

-- ============================================================================
-- EVIDENCE EVENTS
-- ============================================================================

RegisterNetEvent('npc_police:evidenceFound')
AddEventHandler('npc_police:evidenceFound', function(data)
    local source = source
    if not IsPlayerPolice(source) then return end

    local playerName = GetPlayerName(source)
    print(('[NPC Police] Officer %s (#%d) found evidence during %s on %s'):format(
        playerName, source, data.type or 'search', data.suspect or 'Unknown'
    ))

    if data.items then
        for _, item in ipairs(data.items) do
            -- Strip color codes for server log
            local cleanItem = item:gsub('~%a~', '')
            print(('[NPC Police]   - %s'):format(cleanItem))
        end
    end
end)

-- ============================================================================
-- BACKUP REQUEST SYSTEM
-- ============================================================================

RegisterNetEvent('npc_police:requestBackup')
AddEventHandler('npc_police:requestBackup', function(data)
    local source = source
    if not IsPlayerPolice(source) then return end

    local playerName = GetPlayerName(source)
    print(('[NPC Police] Officer %s (#%d) requesting backup at %s'):format(
        playerName, source, data.location or 'Unknown'
    ))

    -- Notify all other police players
    local players = GetPlayers()
    for _, playerId in ipairs(players) do
        local pid = tonumber(playerId)
        if pid ~= source and IsPlayerPolice(pid) then
            TriggerClientEvent('npc_police:notify', pid, '~r~BACKUP REQUEST',
                string.format('Officer %s needs backup at %s!', playerName, data.location or 'Unknown'))

            -- Add blip for responding officers
            if data.coords then
                TriggerClientEvent('npc_police:addBackupBlip', pid, data.coords,
                    'Backup: ' .. playerName)
            end
        end
    end
end)

-- ============================================================================
-- TOW REQUEST
-- ============================================================================

RegisterNetEvent('npc_police:towRequested')
AddEventHandler('npc_police:towRequested', function(data)
    local source = source
    if not IsPlayerPolice(source) then return end

    local playerName = GetPlayerName(source)
    print(('[NPC Police] Officer %s (#%d) requested tow for plate %s at %s'):format(
        playerName, source, data.plate or 'Unknown', data.location or 'Unknown'
    ))
end)

-- ============================================================================
-- UTILITY: GET ALL PLAYERS
-- ============================================================================

function GetPlayers()
    local players = {}
    for i = 0, GetNumPlayerIndices() - 1 do
        local playerId = GetPlayerFromIndex(i)
        if playerId then
            players[#players + 1] = tostring(playerId)
        end
    end
    return players
end

-- ============================================================================
-- ADMIN COMMANDS
-- ============================================================================

RegisterCommand('npcpolice:stats', function(source)
    if source == 0 then -- Console only
        print('[NPC Police] Server Statistics:')
        print(('  Framework: %s'):format(Framework or 'detecting...'))
        print(('  Connected Players: %d'):format(#GetPlayers()))
    end
end, true) -- Restricted to admins

-- ============================================================================
-- RESOURCE LIFECYCLE
-- ============================================================================

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('[NPC Police] Resource started successfully.')
    end
end)

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        print('[NPC Police] Resource stopping. Cleaning up...')
    end
end)
