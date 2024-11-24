local _, wan = ...

-- Wipe nested tables
function wan.WipeTable(tbl)
    if not tbl then return end
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            wan.WipeTable(v)
        end
        tbl[k] = nil
    end
end

-- Get nested values of tables without refences
function wan.GetNestedValue(tbl, ...)
    local currentTable = tbl
    for i = 1, select("#", ...) do
        local key = select(i, ...)
        if type(currentTable) ~= "table" or currentTable[key] == nil then
            return nil
        end
        currentTable = currentTable[key]
    end
    return currentTable
end

-- Print all nested values of an array
function wan.PrintNestedValues(tbl)
    for k, v in pairs(tbl) do
        if type(v) == "table" then
            wan.PrintNestedValues(v)
        else
            print(tostring(k) .. ": " .. tostring(v))
        end
    end
end

-- Register multiple events at once
function wan.RegisterBlizzardEvents(frame, ...)
    for _, event in pairs({ ... }) do
        frame:RegisterEvent(event)
    end
end

-- Unregister multiple events at once
function wan.UnregisterBlizzardEvents(frame, ...)
    for _, event in pairs({ ... }) do
        frame:UnregisterEvent(event)
    end
end


function wan.BlizzardEventHandler(frame, spellBool, ...)
    for _, event in pairs({...}) do
        if spellBool then
            frame:RegisterEvent(event)
        else
            frame:UnregisterEvent(event)
        end
    end
end

-- Create and fire custom events
function wan.CustomEvents(event, ...)
    local onEvent = wan.EventFrame:GetScript("OnEvent")
    if onEvent then
        onEvent(wan.EventFrame, event, ...)
    end
end

-- Helper function to format strings used for keys
function wan.FormatNameForKey(string)
    string = string:gsub("|c%x%x%x%x%x%x%x%x", "")     -- Remove color prefix
    string = string:gsub("|r", "")                     -- Remove color reset
    string = string:gsub("|[nt]", "")                  -- Remove escape sequences
    string = string:gsub("|T.-|t", "")                 -- Remove texture tags
    string = string:gsub("|H.-|h", "")                 -- Remove hyperlinks
    string = string:gsub("[%s:_%-,'?!%(%).]", "")      -- Remove special characters
    return string
end

-- Checks gcd value
function wan.GetSpellGcdValue(spellID)
    local gcdValue = 1.5
    if spellID then
        local _, gcdMS = GetSpellBaseCooldown(spellID)
        if gcdMS and gcdMS >= 0 then
            if gcdMS == 0 then
                gcdValue = 1
            else
                gcdValue = gcdMS / 1000
            end
        end
    end
    return gcdValue
end


-- Sets the update rate for tickers or throttles
function wan.SetUpdateRate(frame, callback, spellID)
    if wan.UpdateRate[frame] then
        wan.UpdateRate[frame]:Cancel()
        wan.UpdateRate[frame] = nil
    end
    frame:SetScript("OnUpdate", nil)
    if not callback or not spellID then return end

    local gcdValue = wan.GetSpellGcdValue(spellID)
    local updateThrottle = gcdValue / (wan.Options.UpdateRate.Toggle and wan.Options.UpdateRate.Slider or 4)

    if wan.Options.UpdateRate.Toggle then
        local lastUpdate = 0
        frame:SetScript("OnUpdate", function(_, elapsed)
            lastUpdate = lastUpdate + elapsed
            if lastUpdate >= updateThrottle then
                lastUpdate = 0
                callback()
            end
        end)
    else
        wan.UpdateRate[frame] = C_Timer.NewTicker(updateThrottle, function()
            callback()
        end)
    end
end


-- Sets the update rate of the displays
function wan.UpdateFrameThrottle()
    local gcdValue = 1
    local _, gcdMS = GetSpellBaseCooldown(61304)
    if gcdMS then
        gcdValue = gcdMS / 1000
    end
    local setting = 8
    if wan.Options.UpdateRate.Toggle then
        setting = wan.Options.UpdateRate.Slider * 2
    else
        setting = 8
    end
    return gcdValue / setting
end

-- checks if aura found on units
function wan.IsUnitMissingAuraAoE(spellName)
    if not IsInGroup() then
        return C_UnitAuras.GetAuraDataBySpellName("player", spellName) == nil
    end

    local count = 1
    local groupType = UnitInRaid("player") and "raid" or UnitInParty("player") and "party"
    local numMembers = GetNumGroupMembers(groupType)

    if groupType then
        for i = 1, numMembers do
            local unit = groupType .. i
            if not UnitIsDeadOrGhost(unit)
                and UnitIsConnected(unit)
                and UnitInRange(unit)
                and C_UnitAuras.GetAuraDataBySpellName(unit, spellName) == nil
            then
                count = count + 1
            end
        end
    end

    if numMembers == count then
        return true
    end
    return false
end

-- checks and adds debuff durations together over all valid nameplates
function wan.CheckMissingDebuffDurationAoECapped(auraDataArray, spellName)
    local totalDuration = 0
    local formattedSpellName = "debuff_" .. spellName

    for unit, unitAuras in pairs(auraDataArray) do
        if unit:find("nameplate") then
            local auraData = unitAuras[formattedSpellName]
            if auraData and auraData.expirationTime and auraData.expirationTime > GetTime() then
                local debuffDuration = math.min(math.ceil(auraData.expirationTime - GetTime()), 4)
                totalDuration = totalDuration + debuffDuration
            end
        end
    end

    return totalDuration
end
