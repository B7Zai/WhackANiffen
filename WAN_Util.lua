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

function wan.FormatDecimalNumbers(value)
    return math.floor(value)
end

function wan.FormatFractionalNumber(value)
    return math.floor(value * 10 + 0.5) / 10
end

function wan.AssignUnitState(frameCallback, isLevelScaling)
    local activeUnits = {}
    local unitToken = frameCallback and frameCallback.unit
    local unitGUID = unitToken and UnitGUID(unitToken)
    if unitGUID and unitToken then
        local maxHealth = UnitHealthMax(unitToken) or 0
        local unitLevel = UnitLevel(unitToken) or wan.UnitState.Level[wan.PlayerState.GUID]
        local role = UnitGroupRolesAssigned(unitToken) or "DAMAGER"
        local isAI = UnitInPartyIsAI(unitToken) or false

        wan.GroupUnitID[unitToken] = unitGUID
        activeUnits[unitGUID] = unitToken

        wan.UnitState.LevelScale[unitToken] = 1
        wan.UnitState.MaxHealth[unitToken] = maxHealth
        wan.UnitState.Level[unitToken] = unitLevel
        wan.UnitState.IsAI[unitToken] = isAI
        wan.UnitState.Role[unitToken] = role

        if isLevelScaling then
            if wan.UnitState.Level[unitToken] ~= wan.UnitState.Level["player"] then
                local levelScaleValue = wan.UnitState.MaxHealth[unitToken] / wan.UnitState.MaxHealth["player"]
                wan.UnitState.LevelScale[unitToken] = levelScaleValue
            end
        end
    end

    return activeUnits
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
local sliderValue = 0
function wan.SetUpdateRate(frame, callback, spellID)
    if not callback or not spellID then
        if wan.UpdateRate[frame] then
            wan.UpdateRate[frame]:Cancel()
            wan.UpdateRate[frame] = nil
        end

        frame:SetScript("OnUpdate", nil)
        return
    end

    local gcdValue = wan.GetSpellGcdValue(spellID)
    local updateThrottle = gcdValue / (wan.Options.UpdateRate.Toggle and wan.Options.UpdateRate.Slider or 4)

    if wan.Options.UpdateRate.Toggle then
        if wan.UpdateRate[frame] then
            wan.UpdateRate[frame]:Cancel()
            wan.UpdateRate[frame] = nil
        end

        local lastUpdate = 0
        if sliderValue ~= wan.Options.UpdateRate.Slider or not frame:GetScript("OnUpdate", 1) then
            frame:SetScript("OnUpdate", function(_, elapsed)
                lastUpdate = lastUpdate + elapsed
                if lastUpdate >= updateThrottle then
                    lastUpdate = 0
                    callback()
                end
            end)
            sliderValue = wan.Options.UpdateRate.Slider
        end
    else
        frame:SetScript("OnUpdate", nil)
        if not wan.UpdateRate[frame] then
            wan.UpdateRate[frame] = C_Timer.NewTicker(updateThrottle, function()
                callback()
            end)
        end
    end
end