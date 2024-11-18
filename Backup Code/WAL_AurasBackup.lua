local _, wal = ...

wal.auraData = wal.auraData or {}

-- Checks and stores player's buff and debuff data in an array
local function GetPlayerAuraData(auraDataArray)
    local unit = "player"

    auraDataArray[unit] = auraDataArray[unit] or {}
    wal.WipeTable(auraDataArray[unit])

    for i = 1, 40 do
        local buffData = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not buffData then break end

        if buffData.name then
            local spellNameFormat = buffData.name:gsub("[%s:_%-,'?!%.]", "")
            auraDataArray[unit]["buff_" .. spellNameFormat] = buffData
        end
    end

    for i = 1, 40 do
        local debuffData = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL")
        if not debuffData then break end

        if debuffData.name then
            local spellNameFormat = debuffData.name:gsub("[%s:_%-,'?!%.]", "")
            auraDataArray[unit]["debuff_" .. spellNameFormat] = debuffData
        end
    end
end


-- Checks and stores target's buff and debuff data in an array
local function GetUnitAuraData(auraDataArray)
    local unit = "softenemy"

    auraDataArray[unit] = auraDataArray[unit] or {}
    wal.WipeTable(auraDataArray[unit])

    for i = 1, 40 do
        local buffData = C_UnitAuras.GetAuraDataByIndex(unit, i, "HELPFUL")
        if not buffData then break end

        if buffData.name then
            local spellNameFormat = buffData.name:gsub("[%s:_%-,'?!%.]", "")
            auraDataArray[unit]["buff_" .. spellNameFormat] = buffData
        end
    end

    for i = 1, 40 do
        local debuffData = C_UnitAuras.GetAuraDataByIndex(unit, i, "HARMFUL|PLAYER")
        if not debuffData then break end

        if debuffData.name then
            local spellNameFormat = debuffData.name:gsub("[%s:_%-,'?!%.]", "")
            auraDataArray[unit]["debuff_" .. spellNameFormat] = debuffData
        end
    end
end


-- Checks and stores unit's buff and debuff data in an array
local function GetUnitAuraDataAoE(auraDataArray)
    for i = 1, 40 do
        local unit = C_NamePlate.GetNamePlateForUnit("nameplate" .. i, false)

        if unit and unit.namePlateUnitToken then
            local token = unit.namePlateUnitToken
            auraDataArray[token] = auraDataArray[token] or {}
            wal.WipeTable(auraDataArray[token])

            for index = 1, 40 do
                local buffData = C_UnitAuras.GetAuraDataByIndex(token, index, "HELPFUL")
                if not buffData then break end

                if buffData.name then
                    local spellNameFormat = buffData.name:gsub("[%s:_%-,'?!%.]", "")
                    auraDataArray[token]["buff_" .. spellNameFormat] = buffData
                end
            end

            for index = 1, 40 do
                local debuffData = C_UnitAuras.GetAuraDataByIndex(token, index, "HARMFUL|PLAYER")
                if not debuffData then break end

                if debuffData.name then
                    local spellNameFormat = debuffData.name:gsub("[%s:_%-,'?!%.]", "")
                    auraDataArray[token]["debuff_" .. spellNameFormat] = debuffData
                end
            end
        end
    end
end


local f = CreateFrame("Frame")

wal.BlizzardEvents(
    f,
    "UNIT_AURA",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_ENTERING_WORLD",
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
    "PLAYER_LOGOUT"
)

local nameplate = {}
f:SetScript("OnEvent", function(self, event, ...)
    local unitToken = ...

    if (event == "UNIT_AURA" and ... == "player") or event == "PLAYER_ENTERING_WORLD" then
        GetPlayerAuraData(wal.auraData)
    end

    if (event == "UNIT_AURA" and ... == "softenemy") or event == "PLAYER_TARGET_CHANGED" then
        GetUnitAuraData(wal.auraData)
    end

    if event == "NAME_PLATE_UNIT_ADDED" then
        local unit = unitToken
        nameplate[unit] = unit

    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local unit = unitToken
        nameplate[unit] = nil
    end

    if (event == "UNIT_AURA" and ... == nameplate[unitToken]) or event == "NAME_PLATE_UNIT_ADDED"
    or event == "NAME_PLATE_UNIT_REMOVED" then
        GetUnitAuraDataAoE(wal.auraData)
    end

    if event == "PLAYER_LOGOUT" then
        wal.auraData = nil
    end

end)