--[[
    NPC Police Interactions - Evidence & Search System
    Generates randomized evidence for vehicle and person searches.
    Handles contraband, weapons, stolen items, and other evidence.
]]

-- ============================================================================
-- FRISK RESULTS GENERATION
-- ============================================================================

--- Generate results from frisking a suspect
---@param npcData table
---@return table foundItems
function GenerateFriskResults(npcData)
    local foundItems = {}

    -- Check for weapons on person
    if npcData.reaction.hasWeapon or math.random() < Config.Evidence.WeaponChance then
        local weapon = NPCPolice.RandomFromArray(Config.Evidence.WeaponTypes)
        if weapon then
            foundItems[#foundItems + 1] = string.format(
                '~r~Weapon:~w~ %s (%s)', weapon.name, weapon.severity
            )

            -- Remove weapon from ped if they have it
            if DoesEntityExist(npcData.ped) then
                RemoveWeaponFromPed(npcData.ped, GetHashKey(weapon.model))
            end
        end
    end

    -- Check for drugs on person (lower chance than vehicle)
    if math.random() < Config.Evidence.DrugChance * 0.5 then
        local drug = NPCPolice.RandomFromArray(Config.Evidence.DrugTypes)
        if drug then
            foundItems[#foundItems + 1] = string.format(
                '~r~Drugs:~w~ %s (%s) - %s', drug.name, drug.weight, drug.severity
            )
        end
    end

    -- Check for fake ID
    if npcData.reactionType == 'FakeID' or math.random() < Config.Evidence.FakeIDChance then
        foundItems[#foundItems + 1] = '~o~Fake ID:~w~ Fraudulent identification document'
    end

    -- Check for cash (suspicious amount)
    if math.random() < 0.1 then
        local amount = math.random(500, 10000)
        foundItems[#foundItems + 1] = string.format(
            '~o~Cash:~w~ $%s in small bills (suspicious)', FormatNumber(amount)
        )
    end

    -- Notify server of found evidence
    if #foundItems > 0 then
        TriggerServerEvent('npc_police:evidenceFound', {
            type = 'frisk',
            suspect = npcData.identity.fullName,
            items = foundItems,
        })
    end

    return foundItems
end

-- ============================================================================
-- VEHICLE SEARCH RESULTS GENERATION
-- ============================================================================

--- Generate results from searching a vehicle
---@param npcData table
---@return table foundItems
function GenerateVehicleSearchResults(npcData)
    local foundItems = {}

    -- Drug search
    if npcData.violations.DUI or math.random() < Config.Evidence.DrugChance then
        local drug = NPCPolice.RandomFromArray(Config.Evidence.DrugTypes)
        if drug then
            local location = NPCPolice.RandomFromArray({
                'under the driver seat',
                'in the glove compartment',
                'in the center console',
                'in the trunk',
                'hidden under the floor mat',
                'inside a backpack on the rear seat',
                'in a hidden compartment',
            })
            foundItems[#foundItems + 1] = string.format(
                '~r~Drugs:~w~ %s (%s) found %s - %s',
                drug.name, drug.weight, location, drug.severity
            )
        end
    end

    -- Weapon search
    if npcData.reaction.hasWeapon or math.random() < Config.Evidence.WeaponChance then
        local weapon = NPCPolice.RandomFromArray(Config.Evidence.WeaponTypes)
        if weapon then
            local location = NPCPolice.RandomFromArray({
                'under the passenger seat',
                'in the trunk',
                'in the glove box',
                'between the front seats',
                'hidden in the spare tire well',
            })
            foundItems[#foundItems + 1] = string.format(
                '~r~Weapon:~w~ %s found %s - %s',
                weapon.name, location, weapon.severity
            )
        end
    end

    -- Stolen items
    if npcData.violations.StolenVehicle or math.random() < Config.Evidence.StolenItemChance then
        local item = NPCPolice.RandomFromArray(Config.Evidence.StolenItems)
        if item then
            local location = NPCPolice.RandomFromArray({
                'in the trunk',
                'on the back seat',
                'hidden under a blanket in the trunk',
                'in a duffel bag',
            })
            foundItems[#foundItems + 1] = string.format(
                '~o~Stolen Property:~w~ %s (est. value $%s) found %s',
                item.name, FormatNumber(item.value), location
            )
        end
    end

    -- Alcohol containers
    if npcData.violations.DUI or math.random() < Config.Evidence.AlcoholChance then
        local container = NPCPolice.RandomFromArray({
            'Open beer can',
            'Half-empty whiskey bottle',
            'Open wine bottle',
            'Multiple empty beer bottles',
            'Flask with alcohol',
            'Open container of vodka',
        })
        local location = NPCPolice.RandomFromArray({
            'in the cup holder',
            'on the passenger floor',
            'between the seats',
            'in the driver door pocket',
        })
        foundItems[#foundItems + 1] = string.format(
            '~o~Open Container:~w~ %s found %s', container, location
        )
    end

    -- Fake ID (in vehicle)
    if npcData.reactionType == 'FakeID' and math.random() < 0.5 then
        foundItems[#foundItems + 1] = '~o~Fake IDs:~w~ Multiple fraudulent identification documents found in glove box'
    end

    -- Random additional items
    if math.random() < 0.15 then
        local miscItems = {
            '~w~Prescription medication bottle (no name)',
            '~w~Burner phone with no contacts',
            '~w~Large amount of plastic baggies',
            '~w~Digital scale',
            '~w~Ski mask',
            '~w~Crowbar',
            '~w~Bolt cutters',
            '~w~Duct tape and zip ties',
        }
        foundItems[#foundItems + 1] = '~o~Suspicious Item:~w~ ' .. NPCPolice.RandomFromArray(miscItems)
    end

    -- Notify server of found evidence
    if #foundItems > 0 then
        TriggerServerEvent('npc_police:evidenceFound', {
            type = 'vehicleSearch',
            suspect = npcData.identity.fullName,
            plate = npcData.plate,
            items = foundItems,
        })
    end

    return foundItems
end

-- ============================================================================
-- UTILITY
-- ============================================================================

--- Format a number with commas
---@param n number
---@return string
function FormatNumber(n)
    local formatted = tostring(n)
    local k
    while true do
        formatted, k = string.gsub(formatted, '^(-?%d+)(%d%d%d)', '%1,%2')
        if k == 0 then break end
    end
    return formatted
end
