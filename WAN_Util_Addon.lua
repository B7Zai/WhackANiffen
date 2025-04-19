local _, wan = ...

-- Create and fire custom events
function wan.CustomEvents(event, ...)
    local onEvent = wan.EventFrame:GetScript("OnEvent")
    if onEvent then
        onEvent(wan.EventFrame, event, ...)
    end
end

-- Helper function to format strings used for keys
function wan.FormatNameForKey(string)
    if not string or string:match("^%s*$") then return nil end

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