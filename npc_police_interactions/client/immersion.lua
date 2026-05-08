--[[
    NPC Police Interactions - Immersion System
    Handles dispatch notifications, police radio messages,
    ambient scanner audio, subtitles/dialogue, and notification display.
]]

-- ============================================================================
-- NOTIFICATION SYSTEM
-- ============================================================================

--- Display a notification to the player
--- Supports ox_lib, QBCore, ESX, and standalone methods
RegisterNetEvent('npc_police:notify')
AddEventHandler('npc_police:notify', function(title, message)
    local useOx = Config.UseOxLib and NPCPolice.HasOxLib()

    if useOx then
        lib.notify({
            title = title:gsub('~%a~', ''),  -- Strip GTA color codes for ox_lib
            description = message:gsub('~%a~', ''),
            type = 'inform',
            duration = 5000,
        })
    elseif NPCPolice.Framework == 'qbcore' then
        local QBCore = NPCPolice.FrameworkObj
        QBCore.Functions.Notify(message:gsub('~%a~', ''), 'primary', 5000)
    elseif NPCPolice.Framework == 'esx' then
        local ESX = NPCPolice.FrameworkObj
        ESX.ShowNotification(title .. ': ' .. message)
    else
        -- GTA V native notification
        SetNotificationTextEntry('STRING')
        AddTextComponentSubstringPlayerName(title .. '\n' .. message)
        DrawNotification(false, true)
    end
end)

-- ============================================================================
-- SUBTITLE / DIALOGUE SYSTEM
-- ============================================================================

local subtitleActive = false
local subtitleText = ''
local subtitleEndTime = 0

RegisterNetEvent('npc_police:showSubtitle')
AddEventHandler('npc_police:showSubtitle', function(text)
    if not Config.Immersion.EnableSubtitles then return end
    if not text or text == '' then return end

    subtitleText = text
    subtitleEndTime = GetGameTimer() + Config.Immersion.SubtitleDuration
    subtitleActive = true

    -- Play a subtle speech sound
    PlayAmbientSpeech()
end)

-- Subtitle rendering loop
CreateThread(function()
    while true do
        if subtitleActive then
            if GetGameTimer() < subtitleEndTime then
                -- Draw subtitle background
                DrawRect(0.5, 0.90, 0.45, 0.06, 0, 0, 0, 150)

                -- Draw subtitle text
                SetTextFont(4)
                SetTextScale(0.35, 0.35)
                SetTextColour(255, 255, 255, 255)
                SetTextCentre(true)
                SetTextDropshadow(1, 0, 0, 0, 255)
                SetTextWrap(0.28, 0.72)
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName(subtitleText)
                EndTextCommandDisplayText(0.5, 0.885)

                Wait(0)
            else
                subtitleActive = false
            end
        else
            Wait(500)
        end
    end
end)

-- ============================================================================
-- DISPATCH NOTIFICATION SYSTEM
-- ============================================================================

local dispatchQueue = {}
local dispatchActive = false

RegisterNetEvent('npc_police:dispatch')
AddEventHandler('npc_police:dispatch', function(dispatchType, message)
    if not Config.Immersion.EnableDispatch then return end

    dispatchQueue[#dispatchQueue + 1] = {
        type = dispatchType,
        message = message,
        time = GetGameTimer(),
    }

    if not dispatchActive then
        ProcessDispatchQueue()
    end
end)

function ProcessDispatchQueue()
    if #dispatchQueue == 0 then
        dispatchActive = false
        return
    end

    dispatchActive = true

    CreateThread(function()
        while #dispatchQueue > 0 do
            local dispatch = table.remove(dispatchQueue, 1)
            ShowDispatchMessage(dispatch)
            Wait(3000)  -- Gap between dispatch messages
        end

        dispatchActive = false
    end)
end

function ShowDispatchMessage(dispatch)
    -- Play radio static sound
    PlayRadioStatic()

    -- Show dispatch notification with special styling
    local useOx = Config.UseOxLib and NPCPolice.HasOxLib()

    if useOx then
        lib.notify({
            title = '📻 Dispatch',
            description = dispatch.message:gsub('~%a~', ''),
            type = GetDispatchNotifyType(dispatch.type),
            duration = 6000,
            icon = 'walkie-talkie',
        })
    else
        -- GTA notification with radio icon
        SetNotificationTextEntry('STRING')
        AddTextComponentSubstringPlayerName('~c~[DISPATCH]~w~ ' .. dispatch.message)
        SetNotificationMessage('CHAR_CALL911', 'CHAR_CALL911', false, 0, 'Police Dispatch', '~c~Radio')
        DrawNotification(false, true)
    end

    -- Also show as subtitle briefly
    TriggerEvent('npc_police:showSubtitle', '📻 ' .. dispatch.message:gsub('~%a~', ''))
end

--- Map dispatch type to ox_lib notify type
---@param dispatchType string
---@return string
function GetDispatchNotifyType(dispatchType)
    local typeMap = {
        trafficStop = 'inform',
        pursuit = 'error',
        footPursuit = 'error',
        arrest = 'success',
        backup = 'warning',
        codeRed = 'error',
        allClear = 'success',
        stolenVehicle = 'error',
        dui = 'warning',
        warrant = 'error',
    }
    return typeMap[dispatchType] or 'inform'
end

-- ============================================================================
-- AMBIENT POLICE RADIO
-- ============================================================================

local radioChatterActive = false

CreateThread(function()
    -- Wait for framework detection
    while NPCPolice.Framework == nil do
        Wait(100)
    end

    while true do
        if isOnDuty and Config.Immersion.EnableRadioChatter then
            -- Periodically play ambient radio chatter
            if not radioChatterActive and math.random() < 0.05 then
                PlayRadioChatter()
            end
            Wait(30000)  -- Check every 30 seconds
        else
            Wait(10000)
        end
    end
end)

function PlayRadioChatter()
    radioChatterActive = true

    CreateThread(function()
        -- Use scanner audio for ambient chatter
        local scannerSounds = {
            { audioBank = 'POLICE_SCANNER_ACTIVE',   soundName = 'CRIMINAL_DAMAGE' },
            { audioBank = 'POLICE_SCANNER_ACTIVE',   soundName = 'SUSPECTS_SPOTTED' },
            { audioBank = 'POLICE_SCANNER_ACTIVE',   soundName = 'CRIME_AMBULANCE' },
        }

        -- Play scanner audio
        PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)

        -- Show ambient dispatch text
        local ambientMessages = {
            '~c~[RADIO]~w~ 10-4, copy that dispatch.',
            '~c~[RADIO]~w~ All units, be advised of increased activity downtown.',
            '~c~[RADIO]~w~ Unit responding to a domestic disturbance call.',
            '~c~[RADIO]~w~ 10-20, what\'s your location?',
            '~c~[RADIO]~w~ Copy, unit en route to scene.',
            '~c~[RADIO]~w~ Be advised, suspect vehicle last seen heading eastbound.',
            '~c~[RADIO]~w~ 10-9, repeat your last transmission.',
            '~c~[RADIO]~w~ All clear on the north side.',
            '~c~[RADIO]~w~ Requesting traffic control at Main and 5th.',
        }

        local msg = NPCPolice.RandomFromArray(ambientMessages)

        SetNotificationTextEntry('STRING')
        AddTextComponentSubstringPlayerName(msg)
        DrawNotification(false, false)

        Wait(math.random(5000, 10000))
        radioChatterActive = false
    end)
end

-- ============================================================================
-- AUDIO HELPERS
-- ============================================================================

function PlayRadioStatic()
    -- Play a brief radio click/static sound
    PlaySoundFrontend(-1, 'Start_Squelch', 'CB_RADIO_SFX', true)

    -- Delayed end squelch
    CreateThread(function()
        Wait(500)
        PlaySoundFrontend(-1, 'End_Squelch', 'CB_RADIO_SFX', true)
    end)
end

function PlayAmbientSpeech()
    -- Play a generic ambient speech sound to indicate NPC is talking
    local playerPed = PlayerPedId()
    local closestPed = nil
    local closestDist = 5.0

    -- Find the closest NPC for speech
    for _, data in pairs(activeNPCs) do
        if DoesEntityExist(data.ped) then
            local dist = #(GetEntityCoords(playerPed) - GetEntityCoords(data.ped))
            if dist < closestDist then
                closestDist = dist
                closestPed = data.ped
            end
        end
    end

    if closestPed then
        -- Use ambient speech native for NPC voice
        local speeches = {
            'GENERIC_HI',
            'CHAT_STATE',
            'CHAT_RESP',
            'GENERIC_THANKS',
        }
        PlayPedAmbientSpeechNative(closestPed, NPCPolice.RandomFromArray(speeches), 'SPEECH_PARAMS_FORCE_NORMAL')
    end
end

-- ============================================================================
-- BLIP SYSTEM (Optional backup blips)
-- ============================================================================

local backupBlips = {}

RegisterNetEvent('npc_police:addBackupBlip')
AddEventHandler('npc_police:addBackupBlip', function(coords, label)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 526)
    SetBlipColour(blip, 3)
    SetBlipScale(blip, 1.2)
    SetBlipFlashes(blip, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label or 'Backup Requested')
    EndTextCommandSetBlipName(blip)

    backupBlips[#backupBlips + 1] = { blip = blip, time = GetGameTimer() }

    -- Auto-remove after 60 seconds
    CreateThread(function()
        Wait(60000)
        if DoesBlipExist(blip) then
            RemoveBlip(blip)
        end
    end)
end)

-- ============================================================================
-- CLEANUP
-- ============================================================================

AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Remove all backup blips
        for _, blipData in ipairs(backupBlips) do
            if DoesBlipExist(blipData.blip) then
                RemoveBlip(blipData.blip)
            end
        end
        backupBlips = {}
    end
end)
