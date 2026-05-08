--[[
    NPC Police Interactions - Shared Utilities
    Framework auto-detection and common helper functions.
    Loaded on both client and server.
]]

NPCPolice = NPCPolice or {}
NPCPolice.Framework = nil
NPCPolice.FrameworkObj = nil

-- ============================================================================
-- FRAMEWORK DETECTION
-- ============================================================================

function NPCPolice.DetectFramework()
    if Config.Framework ~= 'auto' then
        NPCPolice.Framework = Config.Framework
    else
        if GetResourceState('es_extended') == 'started' then
            NPCPolice.Framework = 'esx'
        elseif GetResourceState('qb-core') == 'started' then
            NPCPolice.Framework = 'qbcore'
        else
            NPCPolice.Framework = 'standalone'
        end
    end

    if NPCPolice.Framework == 'esx' then
        NPCPolice.FrameworkObj = exports['es_extended']:getSharedObject()
    elseif NPCPolice.Framework == 'qbcore' then
        NPCPolice.FrameworkObj = exports['qb-core']:GetCoreObject()
    end

    if Config.Debug then
        print(('[NPC Police] Framework detected: %s'):format(NPCPolice.Framework))
    end

    return NPCPolice.Framework
end

-- ============================================================================
-- UTILITY FUNCTIONS
-- ============================================================================

--- Check if ox_lib is available
---@return boolean
function NPCPolice.HasOxLib()
    return GetResourceState('ox_lib') == 'started'
end

--- Random float between min and max
---@param min number
---@param max number
---@return number
function NPCPolice.RandomFloat(min, max)
    return min + math.random() * (max - min)
end

--- Weighted random selection from a table with 'chance' fields
---@param items table
---@return string|nil selectedKey
---@return table|nil selectedItem
function NPCPolice.WeightedRandom(items)
    local totalWeight = 0.0
    for _, item in pairs(items) do
        totalWeight = totalWeight + (item.chance or 0.0)
    end

    local roll = math.random() * totalWeight
    local cumulative = 0.0

    for key, item in pairs(items) do
        cumulative = cumulative + (item.chance or 0.0)
        if roll <= cumulative then
            return key, item
        end
    end

    return nil, nil
end

--- Pick a random element from an array
---@param tbl table
---@return any
function NPCPolice.RandomFromArray(tbl)
    if not tbl or #tbl == 0 then return nil end
    return tbl[math.random(#tbl)]
end

--- Generate a random license plate
---@return string
function NPCPolice.GeneratePlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local plate = ''
    for _ = 1, 3 do
        local idx = math.random(#chars)
        plate = plate .. chars:sub(idx, idx)
    end
    plate = plate .. ' '
    for _ = 1, 4 do
        plate = plate .. tostring(math.random(0, 9))
    end
    return plate
end

--- Generate a random NPC identity
---@param isMale boolean
---@return table identity
function NPCPolice.GenerateIdentity(isMale)
    local firstNames = isMale and Config.Identity.FirstNames.Male or Config.Identity.FirstNames.Female
    local firstName = NPCPolice.RandomFromArray(firstNames)
    local lastName = NPCPolice.RandomFromArray(Config.Identity.LastNames)
    local age = math.random(Config.Identity.MinAge, Config.Identity.MaxAge)
    local dob = string.format('%02d/%02d/%04d',
        math.random(1, 12),
        math.random(1, 28),
        2026 - age
    )

    return {
        firstName = firstName,
        lastName = lastName,
        fullName = firstName .. ' ' .. lastName,
        age = age,
        dob = dob,
        gender = isMale and 'Male' or 'Female',
        address = string.format('%d %s %s',
            math.random(100, 9999),
            NPCPolice.RandomFromArray({
                'Grove St', 'Vinewood Blvd', 'Alta St', 'Strawberry Ave',
                'Davis Ave', 'Palomino Ave', 'San Andreas Ave', 'Elgin Ave',
                'Mirror Park Blvd', 'Bay City Ave', 'Del Perro Blvd',
                'Route 68', 'Grapeseed Main St', 'Paleto Blvd',
            }),
            NPCPolice.RandomFromArray({
                'Los Santos', 'Sandy Shores', 'Paleto Bay', 'Grapeseed',
                'Harmony', 'Chumash', 'Del Perro',
            })
        ),
    }
end

--- Get the street name at a position
---@param coords vector3
---@return string
function NPCPolice.GetStreetName(coords)
    if not IsDuplicityVersion() then
        local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
        local streetName = GetStreetNameFromHashKey(streetHash)
        local crossingName = GetStreetNameFromHashKey(crossingHash)
        if crossingName and crossingName ~= '' then
            return streetName .. ' / ' .. crossingName
        end
        return streetName or 'Unknown'
    end
    return 'Unknown'
end

--- Get zone name at a position
---@param coords vector3
---@return string
function NPCPolice.GetZoneName(coords)
    if not IsDuplicityVersion() then
        local zoneHash = GetNameOfZone(coords.x, coords.y, coords.z)
        return GetLabelText(zoneHash) or 'Unknown'
    end
    return 'Unknown'
end

--- Format distance for display
---@param dist number
---@return string
function NPCPolice.FormatDistance(dist)
    if dist < 1000 then
        return string.format('%.0fm', dist)
    end
    return string.format('%.1fkm', dist / 1000)
end

--- Check if a value exists in an array
---@param tbl table
---@param val any
---@return boolean
function NPCPolice.TableContains(tbl, val)
    for _, v in ipairs(tbl) do
        if v == val then
            return true
        end
    end
    return false
end

--- Deep copy a table
---@param orig table
---@return table
function NPCPolice.DeepCopy(orig)
    local copy = {}
    for k, v in pairs(orig) do
        if type(v) == 'table' then
            copy[k] = NPCPolice.DeepCopy(v)
        else
            copy[k] = v
        end
    end
    return copy
end

--- Debug print
---@param ... any
function NPCPolice.Debug(...)
    if Config.Debug then
        print('[NPC Police Debug]', ...)
    end
end
