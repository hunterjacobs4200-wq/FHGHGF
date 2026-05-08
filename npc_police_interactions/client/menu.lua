--[[
    NPC Police Interactions - Police Interaction Menu
    Full interaction menu using ox_lib (with built-in fallback).
    Includes progress bars, animations, and NPC dialogue responses.
]]

-- ============================================================================
-- MENU EVENT HANDLER
-- ============================================================================

RegisterNetEvent('npc_police:openMenu')
AddEventHandler('npc_police:openMenu', function(npcData)
    if not npcData then return end
    OpenInteractionMenu(npcData)
end)

-- ============================================================================
-- MAIN INTERACTION MENU
-- ============================================================================

function OpenInteractionMenu(npcData)
    local useOx = Config.UseOxLib and NPCPolice.HasOxLib()

    if useOx then
        OpenOxMenu(npcData)
    else
        OpenBuiltInMenu(npcData)
    end
end

-- ============================================================================
-- OX_LIB MENU
-- ============================================================================

function OpenOxMenu(npcData)
    local inVehicle = IsPedInAnyVehicle(npcData.ped, false)

    local options = {
        {
            title = 'Request ID',
            description = 'Ask the driver for identification',
            icon = 'id-card',
            onSelect = function()
                ActionRequestID(npcData)
            end,
        },
        {
            title = 'Run Plate',
            description = 'Run the vehicle plate through dispatch',
            icon = 'magnifying-glass',
            onSelect = function()
                ActionRunPlate(npcData)
            end,
        },
        {
            title = 'Ask Questions',
            description = 'Question the driver about their activity',
            icon = 'comments',
            onSelect = function()
                ActionAskQuestions(npcData)
            end,
        },
        {
            title = 'Breathalyzer Test',
            description = 'Administer a breathalyzer test',
            icon = 'wine-glass',
            onSelect = function()
                ActionBreathalyzer(npcData)
            end,
        },
        {
            title = 'Drug Test',
            description = 'Administer a field drug test',
            icon = 'flask',
            onSelect = function()
                ActionDrugTest(npcData)
            end,
        },
    }

    if inVehicle then
        options[#options + 1] = {
            title = 'Order Out of Vehicle',
            description = 'Command the driver to exit the vehicle',
            icon = 'door-open',
            onSelect = function()
                ActionOrderOut(npcData)
            end,
        }
    end

    if not inVehicle then
        options[#options + 1] = {
            title = 'Frisk Suspect',
            description = 'Pat down the suspect for weapons',
            icon = 'hand',
            onSelect = function()
                ActionFrisk(npcData)
            end,
        }
    end

    options[#options + 1] = {
        title = 'Search Vehicle',
        description = 'Conduct a search of the vehicle',
        icon = 'car',
        onSelect = function()
            ActionSearchVehicle(npcData)
        end,
    }

    options[#options + 1] = {
        title = 'Issue Warning',
        description = 'Issue a verbal warning',
        icon = 'triangle-exclamation',
        onSelect = function()
            ActionIssueWarning(npcData)
        end,
    }

    options[#options + 1] = {
        title = 'Issue Ticket',
        description = 'Write a citation/ticket',
        icon = 'file-lines',
        onSelect = function()
            ActionIssueTicket(npcData)
        end,
    }

    options[#options + 1] = {
        title = 'Arrest Suspect',
        description = 'Place the suspect under arrest',
        icon = 'handcuffs',
        onSelect = function()
            ActionArrest(npcData)
        end,
    }

    options[#options + 1] = {
        title = 'Call Backup',
        description = 'Request backup to your location',
        icon = 'phone',
        onSelect = function()
            ActionCallBackup(npcData)
        end,
    }

    options[#options + 1] = {
        title = 'Tow Vehicle',
        description = 'Request a tow truck for the vehicle',
        icon = 'truck-pickup',
        onSelect = function()
            ActionTowVehicle(npcData)
        end,
    }

    options[#options + 1] = {
        title = '~r~Cancel Stop',
        description = 'Let the driver go and end the stop',
        icon = 'xmark',
        onSelect = function()
            ActionCancelStop(npcData)
        end,
    }

    lib.registerContext({
        id = 'npc_police_interaction',
        title = '👮 Police Interaction - ' .. npcData.identity.fullName,
        options = options,
    })

    lib.showContext('npc_police_interaction')
end

-- ============================================================================
-- BUILT-IN FALLBACK MENU (No ox_lib)
-- ============================================================================

function OpenBuiltInMenu(npcData)
    local menuItems = {
        { label = '[1] Request ID',          action = 'requestID' },
        { label = '[2] Run Plate',           action = 'runPlate' },
        { label = '[3] Ask Questions',       action = 'askQuestions' },
        { label = '[4] Breathalyzer',        action = 'breathalyzer' },
        { label = '[5] Drug Test',           action = 'drugTest' },
        { label = '[6] Order Out',           action = 'orderOut' },
        { label = '[7] Frisk Suspect',       action = 'frisk' },
        { label = '[8] Search Vehicle',      action = 'searchVehicle' },
        { label = '[9] Issue Warning',       action = 'warning' },
        { label = '[0] Issue Ticket',        action = 'ticket' },
        { label = '[ENTER] Arrest',          action = 'arrest' },
        { label = '[B] Call Backup',         action = 'backup' },
        { label = '[T] Tow Vehicle',         action = 'tow' },
        { label = '[ESC] Cancel Stop',       action = 'cancel' },
    }

    local menuOpen = true

    CreateThread(function()
        while menuOpen do
            -- Draw menu background
            DrawRect(0.85, 0.5, 0.25, 0.7, 0, 0, 0, 180)

            -- Draw title
            DrawText2D(0.85, 0.17, '~b~Police Interaction', 0.5)
            DrawText2D(0.85, 0.21, npcData.identity.fullName, 0.35)

            -- Draw menu items
            local y = 0.26
            for _, item in ipairs(menuItems) do
                DrawText2D(0.85, y, item.label, 0.3)
                y = y + 0.035
            end

            -- Handle key presses
            if IsControlJustPressed(0, 157) then      -- 1
                menuOpen = false; ActionRequestID(npcData)
            elseif IsControlJustPressed(0, 158) then   -- 2
                menuOpen = false; ActionRunPlate(npcData)
            elseif IsControlJustPressed(0, 160) then   -- 3
                menuOpen = false; ActionAskQuestions(npcData)
            elseif IsControlJustPressed(0, 164) then   -- 4
                menuOpen = false; ActionBreathalyzer(npcData)
            elseif IsControlJustPressed(0, 165) then   -- 5
                menuOpen = false; ActionDrugTest(npcData)
            elseif IsControlJustPressed(0, 159) then   -- 6
                menuOpen = false; ActionOrderOut(npcData)
            elseif IsControlJustPressed(0, 161) then   -- 7
                menuOpen = false; ActionFrisk(npcData)
            elseif IsControlJustPressed(0, 162) then   -- 8
                menuOpen = false; ActionSearchVehicle(npcData)
            elseif IsControlJustPressed(0, 163) then   -- 9
                menuOpen = false; ActionIssueWarning(npcData)
            elseif IsControlJustPressed(0, 56) then    -- 0
                menuOpen = false; ActionIssueTicket(npcData)
            elseif IsControlJustPressed(0, 18) then    -- Enter
                menuOpen = false; ActionArrest(npcData)
            elseif IsControlJustPressed(0, 29) then    -- B
                menuOpen = false; ActionCallBackup(npcData)
            elseif IsControlJustPressed(0, 245) then   -- T
                menuOpen = false; ActionTowVehicle(npcData)
            elseif IsControlJustPressed(0, 200) then   -- ESC
                menuOpen = false; ActionCancelStop(npcData)
            end

            Wait(0)
        end
    end)
end

--- Simple 2D text drawing helper
---@param x number
---@param y number
---@param text string
---@param scale number
function DrawText2D(x, y, text, scale)
    SetTextFont(4)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextCentre(true)
    SetTextDropshadow(1, 0, 0, 0, 255)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

-- ============================================================================
-- PROGRESS BAR HELPER
-- ============================================================================

--- Show a progress bar (ox_lib or built-in)
---@param label string
---@param duration number ms
---@param animDict string|nil
---@param animName string|nil
---@param onComplete function
---@param onCancel function|nil
function ShowProgressBar(label, duration, animDict, animName, onComplete, onCancel)
    local useOx = Config.UseOxLib and NPCPolice.HasOxLib()

    if useOx then
        local success = lib.progressBar({
            duration = duration,
            label = label,
            useWhileDead = false,
            canCancel = true,
            disable = { car = true, move = true, combat = true },
            anim = animDict and {
                dict = animDict,
                clip = animName,
            } or nil,
        })

        if success then
            if onComplete then onComplete() end
        else
            if onCancel then onCancel() end
        end
    else
        -- Built-in progress bar
        local startTime = GetGameTimer()
        local finished = false
        local cancelled = false

        -- Load animation if specified
        if animDict then
            RequestAnimDict(animDict)
            local timeout = 0
            while not HasAnimDictLoaded(animDict) and timeout < 5000 do
                Wait(10)
                timeout = timeout + 10
            end
            TaskPlayAnim(PlayerPedId(), animDict, animName, 8.0, -8.0, duration, 49, 0, false, false, false)
        end

        CreateThread(function()
            while not finished and not cancelled do
                local elapsed = GetGameTimer() - startTime
                local progress = math.min(elapsed / duration, 1.0)

                -- Draw progress bar
                DrawRect(0.5, 0.88, 0.25, 0.03, 0, 0, 0, 180)
                DrawRect(0.5 - (0.25 * (1 - progress) / 2), 0.88, 0.25 * progress, 0.025, 50, 150, 255, 220)

                -- Draw label
                DrawText2D(0.5, 0.85, label, 0.35)
                DrawText2D(0.5, 0.90, 'Press ~INPUT_FRONTEND_CANCEL~ to cancel', 0.25)

                if IsControlJustPressed(0, 200) then -- ESC
                    cancelled = true
                end

                if elapsed >= duration then
                    finished = true
                end

                Wait(0)
            end

            -- Clear animation
            if animDict then
                ClearPedTasks(PlayerPedId())
            end

            if finished and not cancelled then
                if onComplete then onComplete() end
            elseif cancelled then
                if onCancel then onCancel() end
            end
        end)
    end
end

-- ============================================================================
-- ACTION IMPLEMENTATIONS
-- ============================================================================

--- Request ID from NPC
function ActionRequestID(npcData)
    if npcData.idChecked then
        TriggerEvent('npc_police:notify', '~y~Already Checked', 'You already checked this person\'s ID.')
        Wait(500)
        OpenInteractionMenu(npcData)
        return
    end

    local response = NPCPolice.AI.DecideResponse(npcData, 'requestID')
    local dialogue = NPCPolice.AI.GetDialogue(npcData, 'idRequest')
    TriggerEvent('npc_police:showSubtitle', dialogue)

    ShowProgressBar('Checking identification...', Config.ProgressDurations.RequestID,
        Config.Anims.Clipboard.dict, Config.Anims.Clipboard.name,
        function()
            npcData.idChecked = true

            if response == 'comply' then
                local id = npcData.identity
                local idInfo = string.format(
                    '~b~Name:~w~ %s\n~b~DOB:~w~ %s\n~b~Age:~w~ %d\n~b~Gender:~w~ %s\n~b~Address:~w~ %s',
                    id.fullName, id.dob, id.age, id.gender, id.address
                )
                TriggerEvent('npc_police:notify', '~g~ID Verified', idInfo)

                -- Check for warrants
                if npcData.violations.ActiveWarrant then
                    Wait(2000)
                    TriggerEvent('npc_police:dispatch', 'warrant',
                        Config.Immersion.DispatchMessages.warrant)
                    TriggerEvent('npc_police:notify', '~r~WARRANT ALERT',
                        npcData.identity.fullName .. ' has an active warrant!')
                end

            elseif response == 'lie' then
                -- Generate a fake ID
                local fakeId = NPCPolice.GenerateIdentity(npcData.isMale)
                local idInfo = string.format(
                    '~b~Name:~w~ %s\n~b~DOB:~w~ %s\n~b~Age:~w~ %d\n~o~(Something seems off about this ID)',
                    fakeId.fullName, fakeId.dob, fakeId.age
                )
                TriggerEvent('npc_police:notify', '~o~ID Provided', idInfo)

            elseif response == 'refuse' then
                TriggerEvent('npc_police:notify', '~r~ID Refused',
                    'The driver refuses to provide identification.')
            end

            Wait(1000)
            OpenInteractionMenu(npcData)
        end,
        function()
            TriggerEvent('npc_police:notify', '~r~Cancelled', 'ID check cancelled.')
            Wait(500)
            OpenInteractionMenu(npcData)
        end
    )
end

--- Run the vehicle plate
function ActionRunPlate(npcData)
    if npcData.plateChecked then
        TriggerEvent('npc_police:notify', '~y~Already Run', 'Plate already checked.')
        Wait(500)
        OpenInteractionMenu(npcData)
        return
    end

    ShowProgressBar('Running plate through dispatch...', Config.ProgressDurations.RunPlate,
        nil, nil,
        function()
            npcData.plateChecked = true

            local plateInfo = string.format('~b~Plate:~w~ %s\n', npcData.plate)

            if npcData.violations.StolenVehicle then
                plateInfo = plateInfo .. '~r~⚠ STOLEN VEHICLE ⚠~w~\n'
                TriggerEvent('npc_police:dispatch', 'stolenVehicle',
                    string.format(Config.Immersion.DispatchMessages.stolenVehicle,
                        NPCPolice.GetStreetName(GetEntityCoords(npcData.vehicle))
                    )
                )
            end

            if npcData.violations.ExpiredRegistration then
                plateInfo = plateInfo .. '~o~Registration: EXPIRED~w~\n'
            else
                plateInfo = plateInfo .. '~g~Registration: Valid~w~\n'
            end

            if npcData.violations.NoInsurance then
                plateInfo = plateInfo .. '~o~Insurance: NONE~w~\n'
            else
                plateInfo = plateInfo .. '~g~Insurance: Active~w~\n'
            end

            if npcData.violations.ActiveWarrant then
                plateInfo = plateInfo .. '~r~Owner has ACTIVE WARRANT~w~'
            end

            TriggerEvent('npc_police:notify', '~b~Plate Results', plateInfo)
            Wait(1000)
            OpenInteractionMenu(npcData)
        end,
        function()
            TriggerEvent('npc_police:notify', '~r~Cancelled', 'Plate check cancelled.')
            Wait(500)
            OpenInteractionMenu(npcData)
        end
    )
end

--- Ask questions
function ActionAskQuestions(npcData)
    local response = NPCPolice.AI.DecideResponse(npcData, 'questions')

    ShowProgressBar('Questioning driver...', Config.ProgressDurations.AskQuestions,
        Config.Anims.Notepad.dict, Config.Anims.Notepad.name,
        function()
            local answers = {}

            if response == 'comply' then
                answers = {
                    "I'm just heading home from work.",
                    "I was visiting a friend nearby.",
                    "Just running some errands, officer.",
                    "I'm on my way to pick up my kids.",
                    "Just going for a drive to clear my head.",
                }
            elseif response == 'refuse' then
                answers = {
                    "I don't have to answer your questions.",
                    "Am I being detained?",
                    "I plead the fifth.",
                    "I want a lawyer.",
                }
            elseif response == 'lie' then
                answers = {
                    "*avoids eye contact* Just... driving around...",
                    "I... uh... was at the store... yeah...",
                    "*sweating* Nothing, officer. Nothing at all.",
                    "I don't remember where I was going...",
                }
            end

            local answer = NPCPolice.RandomFromArray(answers)
            TriggerEvent('npc_police:showSubtitle', answer)

            -- Add behavioral observations
            local observations = {}
            if npcData.reaction.nervous then
                observations[#observations + 1] = 'Subject appears nervous'
            end
            if npcData.reaction.slurredSpeech then
                observations[#observations + 1] = 'Subject has slurred speech'
            end
            if npcData.violations.DUI then
                observations[#observations + 1] = 'Possible signs of intoxication'
            end
            if #observations > 0 then
                Wait(2000)
                TriggerEvent('npc_police:notify', '~o~Officer Notes',
                    table.concat(observations, '\n'))
            end

            Wait(1000)
            OpenInteractionMenu(npcData)
        end,
        function()
            Wait(500)
            OpenInteractionMenu(npcData)
        end
    )
end

--- Order driver out of vehicle
function ActionOrderOut(npcData)
    TriggerEvent('npc_police:showSubtitle', 'Step out of the vehicle, please.')

    local response = NPCPolice.AI.DecideResponse(npcData, 'exitVehicle')
    local dialogue = NPCPolice.AI.GetDialogue(npcData, 'exitVehicle')

    Wait(1500)
    TriggerEvent('npc_police:showSubtitle', dialogue)

    if response == 'comply' then
        NPCPolice.AI.TransitionState(npcData.ped, 'exiting')
        TriggerEvent('npc_police:notify', '~g~Complying', 'Driver is exiting the vehicle.')
    elseif response == 'refuse' then
        TriggerEvent('npc_police:notify', '~r~Refusing', 'Driver refuses to exit the vehicle.')
    elseif response == 'flee' then
        NPCPolice.AI.TransitionState(npcData.ped, 'fleeing_foot')
    elseif response == 'attack' then
        NPCPolice.AI.TransitionState(npcData.ped, 'fighting')
    end

    Wait(2000)
    if npcData.state ~= 'fleeing_car' and npcData.state ~= 'fleeing_foot'
        and npcData.state ~= 'fighting' then
        OpenInteractionMenu(npcData)
    end
end

--- Frisk suspect
function ActionFrisk(npcData)
    if npcData.frisked then
        TriggerEvent('npc_police:notify', '~y~Already Frisked', 'Suspect already frisked.')
        Wait(500)
        OpenInteractionMenu(npcData)
        return
    end

    local response = NPCPolice.AI.DecideResponse(npcData, 'frisk')

    if response == 'comply' then
        ShowProgressBar('Frisking suspect...', Config.ProgressDurations.Frisk,
            Config.Anims.Frisk.dict, Config.Anims.Frisk.name,
            function()
                npcData.frisked = true
                local foundItems = GenerateFriskResults(npcData)

                if #foundItems > 0 then
                    local itemList = ''
                    for _, item in ipairs(foundItems) do
                        itemList = itemList .. '- ' .. item .. '\n'
                    end
                    TriggerEvent('npc_police:notify', '~r~Items Found!', itemList)
                else
                    TriggerEvent('npc_police:notify', '~g~Clear', 'No contraband found on suspect.')
                end

                Wait(1000)
                OpenInteractionMenu(npcData)
            end,
            function()
                TriggerEvent('npc_police:notify', '~r~Cancelled', 'Frisk cancelled.')
                Wait(500)
                OpenInteractionMenu(npcData)
            end
        )
    elseif response == 'attack' then
        NPCPolice.AI.TransitionState(npcData.ped, 'fighting')
    else
        TriggerEvent('npc_police:notify', '~r~Refused', 'Suspect refuses to be frisked.')
        Wait(1000)
        OpenInteractionMenu(npcData)
    end
end

--- Search vehicle
function ActionSearchVehicle(npcData)
    if npcData.vehicleSearched then
        TriggerEvent('npc_police:notify', '~y~Already Searched', 'Vehicle already searched.')
        Wait(500)
        OpenInteractionMenu(npcData)
        return
    end

    local dialogue = NPCPolice.AI.GetDialogue(npcData, 'searchConsent')
    TriggerEvent('npc_police:showSubtitle', dialogue)

    ShowProgressBar('Searching vehicle...', Config.ProgressDurations.SearchVehicle,
        Config.Anims.SearchCar.dict, Config.Anims.SearchCar.name,
        function()
            npcData.vehicleSearched = true
            local foundItems = GenerateVehicleSearchResults(npcData)

            if #foundItems > 0 then
                local itemList = ''
                for _, item in ipairs(foundItems) do
                    itemList = itemList .. '- ' .. item .. '\n'
                end
                TriggerEvent('npc_police:notify', '~r~Evidence Found!', itemList)
            else
                TriggerEvent('npc_police:notify', '~g~Clear', 'No contraband found in vehicle.')
            end

            Wait(1000)
            OpenInteractionMenu(npcData)
        end,
        function()
            TriggerEvent('npc_police:notify', '~r~Cancelled', 'Vehicle search cancelled.')
            Wait(500)
            OpenInteractionMenu(npcData)
        end
    )
end

--- Breathalyzer test
function ActionBreathalyzer(npcData)
    if npcData.breathalyzerDone then
        TriggerEvent('npc_police:notify', '~y~Already Tested', 'Breathalyzer already administered.')
        Wait(500)
        OpenInteractionMenu(npcData)
        return
    end

    local response = NPCPolice.AI.DecideResponse(npcData, 'breathalyzer')

    if response == 'refuse' then
        TriggerEvent('npc_police:notify', '~r~Refused', 'Suspect refuses the breathalyzer test.')
        Wait(1000)
        OpenInteractionMenu(npcData)
        return
    end

    ShowProgressBar('Administering breathalyzer...', Config.ProgressDurations.Breathalyzer,
        Config.Anims.Breathalyzer.dict, Config.Anims.Breathalyzer.name,
        function()
            npcData.breathalyzerDone = true
            local bac = npcData.bac
            local bacStr = string.format('%.3f', bac)

            local status = '~g~SOBER'
            if bac >= Config.Tests.BACLevels.drunk.min then
                status = '~r~HEAVILY INTOXICATED'
            elseif bac >= Config.Tests.BACLevels.impaired.min then
                status = '~r~IMPAIRED'
            elseif bac >= Config.Tests.BACLevels.buzzed.min then
                status = '~o~BUZZED'
            end

            local resultText = string.format(
                '~b~BAC Reading:~w~ %s\n~b~Status:~w~ %s\n~b~Legal Limit:~w~ %.3f',
                bacStr, status, Config.Tests.LegalBACLimit
            )

            if bac >= Config.Tests.LegalBACLimit then
                resultText = resultText .. '\n~r~OVER LEGAL LIMIT'
                TriggerEvent('npc_police:dispatch', 'dui',
                    string.format(Config.Immersion.DispatchMessages.dui,
                        NPCPolice.GetStreetName(GetEntityCoords(PlayerPedId()))
                    )
                )
            end

            TriggerEvent('npc_police:notify', '~b~Breathalyzer Results', resultText)
            Wait(1000)
            OpenInteractionMenu(npcData)
        end,
        function()
            TriggerEvent('npc_police:notify', '~r~Cancelled', 'Breathalyzer cancelled.')
            Wait(500)
            OpenInteractionMenu(npcData)
        end
    )
end

--- Drug test
function ActionDrugTest(npcData)
    if npcData.drugTestDone then
        TriggerEvent('npc_police:notify', '~y~Already Tested', 'Drug test already administered.')
        Wait(500)
        OpenInteractionMenu(npcData)
        return
    end

    ShowProgressBar('Administering drug test...', Config.ProgressDurations.DrugTest,
        nil, nil,
        function()
            npcData.drugTestDone = true

            local result = npcData.drugResult
            local color = result == 'Negative' and '~g~' or '~r~'

            TriggerEvent('npc_police:notify', '~b~Drug Test Results',
                string.format('~b~Result:~w~ %s%s', color, result))

            Wait(1000)
            OpenInteractionMenu(npcData)
        end,
        function()
            TriggerEvent('npc_police:notify', '~r~Cancelled', 'Drug test cancelled.')
            Wait(500)
            OpenInteractionMenu(npcData)
        end
    )
end

--- Issue warning
function ActionIssueWarning(npcData)
    if npcData.warned then
        TriggerEvent('npc_police:notify', '~y~Already Warned', 'Warning already issued.')
        Wait(500)
        OpenInteractionMenu(npcData)
        return
    end

    ShowProgressBar('Issuing verbal warning...', 2000,
        nil, nil,
        function()
            npcData.warned = true
            TriggerEvent('npc_police:showSubtitle',
                "You're free to go. Drive safely.")
            TriggerEvent('npc_police:notify', '~g~Warning Issued',
                'Verbal warning issued to ' .. npcData.identity.fullName)

            -- Notify server
            TriggerServerEvent('npc_police:warningIssued', {
                name = npcData.identity.fullName,
                plate = npcData.plate,
            })

            Wait(2000)

            -- Let them go
            ActionCancelStop(npcData)
        end,
        function()
            Wait(500)
            OpenInteractionMenu(npcData)
        end
    )
end

--- Issue ticket
function ActionIssueTicket(npcData)
    if npcData.ticketed then
        TriggerEvent('npc_police:notify', '~y~Already Ticketed', 'Ticket already issued.')
        Wait(500)
        OpenInteractionMenu(npcData)
        return
    end

    ShowProgressBar('Writing citation...', Config.ProgressDurations.WriteTicket,
        Config.Anims.Notepad.dict, Config.Anims.Notepad.name,
        function()
            npcData.ticketed = true

            -- Calculate fine based on violations
            local totalFine = 0
            local violationList = ''

            for violation, active in pairs(npcData.violations) do
                if active and Config.Fines[violation] then
                    local fine = math.random(Config.Fines[violation].min, Config.Fines[violation].max)
                    totalFine = totalFine + fine
                    violationList = violationList .. string.format('- %s: $%d\n', violation, fine)
                end
            end

            if totalFine == 0 then
                totalFine = math.random(100, 300)
                violationList = '- General traffic violation: $' .. totalFine .. '\n'
            end

            local ticketInfo = string.format(
                '~b~Issued to:~w~ %s\n~b~Plate:~w~ %s\n\n%s\n~b~Total Fine:~w~ ~g~$%d',
                npcData.identity.fullName, npcData.plate, violationList, totalFine
            )

            TriggerEvent('npc_police:notify', '~b~Citation Issued', ticketInfo)

            -- Notify server
            TriggerServerEvent('npc_police:ticketIssued', {
                name = npcData.identity.fullName,
                plate = npcData.plate,
                fine = totalFine,
                violations = npcData.violations,
            })

            Wait(3000)

            -- Let them go after ticket
            TriggerEvent('npc_police:showSubtitle', "Here's your citation. Drive safely.")
            Wait(2000)
            ActionCancelStop(npcData)
        end,
        function()
            TriggerEvent('npc_police:notify', '~r~Cancelled', 'Ticket writing cancelled.')
            Wait(500)
            OpenInteractionMenu(npcData)
        end
    )
end

--- Arrest suspect (delegates to arrest system)
function ActionArrest(npcData)
    TriggerEvent('npc_police:beginArrest', npcData)
end

--- Call backup
function ActionCallBackup(npcData)
    local pos = GetEntityCoords(PlayerPedId())
    local streetName = NPCPolice.GetStreetName(pos)

    TriggerEvent('npc_police:dispatch', 'backup',
        string.format(Config.Immersion.DispatchMessages.backup, streetName)
    )

    TriggerServerEvent('npc_police:requestBackup', {
        location = streetName,
        coords = { x = pos.x, y = pos.y, z = pos.z },
    })

    TriggerEvent('npc_police:notify', '~b~Backup Requested',
        'Backup has been dispatched to your location.')

    Wait(1000)
    OpenInteractionMenu(npcData)
end

--- Tow vehicle
function ActionTowVehicle(npcData)
    if not DoesEntityExist(npcData.vehicle) then
        TriggerEvent('npc_police:notify', '~r~Error', 'Vehicle no longer exists.')
        return
    end

    ShowProgressBar('Calling tow truck...', Config.ProgressDurations.TowVehicle,
        nil, nil,
        function()
            TriggerEvent('npc_police:notify', '~g~Tow Dispatched',
                'Vehicle will be towed from the scene.')

            -- Notify server
            TriggerServerEvent('npc_police:towRequested', {
                plate = npcData.plate,
                location = NPCPolice.GetStreetName(GetEntityCoords(npcData.vehicle)),
            })

            -- Fade out and delete vehicle
            Wait(3000)
            if DoesEntityExist(npcData.vehicle) then
                NetworkFadeOutEntity(npcData.vehicle, true, false)
                Wait(2000)
                if DoesEntityExist(npcData.vehicle) then
                    SetEntityAsMissionEntity(npcData.vehicle, false, true)
                    DeleteEntity(npcData.vehicle)
                end
            end

            TriggerEvent('npc_police:dispatch', 'allClear',
                string.format(Config.Immersion.DispatchMessages.allClear,
                    NPCPolice.GetStreetName(GetEntityCoords(PlayerPedId()))
                )
            )
        end,
        function()
            TriggerEvent('npc_police:notify', '~r~Cancelled', 'Tow request cancelled.')
            Wait(500)
            OpenInteractionMenu(npcData)
        end
    )
end

--- Cancel the traffic stop
function ActionCancelStop(npcData)
    TriggerEvent('npc_police:dispatch', 'allClear',
        string.format(Config.Immersion.DispatchMessages.allClear,
            NPCPolice.GetStreetName(GetEntityCoords(PlayerPedId()))
        )
    )

    CancelTrafficStop()

    TriggerEvent('npc_police:notify', '~g~Stop Ended', 'Traffic stop concluded.')
end
