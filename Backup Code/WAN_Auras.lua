local _, wan = ...

wan.auraData = wan.auraData or {}
wan.instanceIDMap = wan.instanceIDMap or {}

setmetatable(wan.auraData, {
    __index = function(t, key)
        local default = {
            ["buff_" .. key] = nil,
            ["debuff_" .. key] = nil
        }
        t[key] = default
        return default
    end
})

local function UpdateAuras(auraDataArray, unitID, updateInfo)
    if not updateInfo then return end

    auraDataArray[unitID] = auraDataArray[unitID] or {}
    wan.instanceIDMap[unitID] = wan.instanceIDMap[unitID] or {}

    if updateInfo.isFullUpdate then
        wan.WipeTable(auraDataArray[unitID])
        wan.instanceIDMap[unitID] = {}


        for i = 1, 40 do
            local buffData = C_UnitAuras.GetAuraDataByIndex(unitID, i, "HELPFUL")
            if not buffData then break end
            if buffData.name then
                local spellName = wan.FormatNameForKey(buffData.name)
                local key = "buff_" .. spellName
                auraDataArray[unitID][key] = buffData
                wan.instanceIDMap[unitID][buffData.auraInstanceID] = key
            end
        end

        for i = 1, 40 do
            local debuffData = C_UnitAuras.GetAuraDataByIndex(unitID, i, "HARMFUL")
            if not debuffData then break end
            if debuffData.name then
                local spellName = wan.FormatNameForKey(debuffData.name)
                local key = "debuff_" .. spellName

                if unitID == "player" or debuffData.sourceUnit == "player" then
                    auraDataArray[unitID][key] = debuffData
                    wan.instanceIDMap[unitID][debuffData.auraInstanceID] = key
                end
            end
        end
        return
    end

    if updateInfo.addedAuras then
        for _, aura in pairs(updateInfo.addedAuras) do
            if aura.name then
                local spellName = wan.FormatNameForKey(aura.name)
                if aura.isHelpful then
                    local key = "buff_" .. spellName
                    auraDataArray[unitID][key] = aura
                    wan.instanceIDMap[unitID][aura.auraInstanceID] = key
                elseif unitID == "player" or aura.sourceUnit == "player" then
                    local key = "debuff_" .. spellName
                    auraDataArray[unitID][key] = aura
                    wan.instanceIDMap[unitID][aura.auraInstanceID] = key
                end
            end
        end
    end

    if updateInfo.updatedAuraInstanceIDs then
        for _, instanceID in pairs(updateInfo.updatedAuraInstanceIDs) do
            local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unitID, instanceID)
            if aura and aura.name then
                local spellName = wan.FormatNameForKey(aura.name)
                if aura.isHelpful then
                    local key = "buff_" .. spellName
                    auraDataArray[unitID][key] = aura
                    wan.instanceIDMap[unitID][instanceID] = key
                elseif unitID == "player" or aura.sourceUnit == "player" then
                    local key = "debuff_" .. spellName
                    auraDataArray[unitID][key] = aura
                    wan.instanceIDMap[unitID][instanceID] = key
                end
            end
        end
    end

    if updateInfo.removedAuraInstanceIDs then
        for _, instanceID in pairs(updateInfo.removedAuraInstanceIDs) do
            local key = wan.instanceIDMap[unitID][instanceID]
            if key then
                auraDataArray[unitID][key] = nil
                wan.instanceIDMap[unitID][instanceID] = nil
            end
        end
    end
end


local nameplate = {}
local function OnEvent(self, event, unitID, updateInfo)

    if event == "PLAYER_LOGOUT" then
        wan.WipeTable(wan.auraData)
        wan.WipeTable(wan.instanceIDMap)
    end

    if event == "PLAYER_ENTERING_WORLD" then
        wan.WipeTable(wan.auraData)
        wan.WipeTable(wan.instanceIDMap)
        UpdateAuras(wan.auraData, "player", { isFullUpdate = true })
    end

    if event == "PLAYER_TARGET_CHANGED" then
        UpdateAuras(wan.auraData, wan.TargetUnitID, { isFullUpdate = true })
    end

    if unitID == "player" then
        UpdateAuras(wan.auraData, "player", updateInfo)
    end

    if unitID == wan.TargetUnitID then
        UpdateAuras(wan.auraData, wan.TargetUnitID, updateInfo)
    end

    if event == "NAME_PLATE_UNIT_ADDED" then
        nameplate[unitID] = unitID
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        nameplate[unitID] = nil
    end

    if nameplate[unitID] then
        UpdateAuras(wan.auraData, unitID, updateInfo)
    end
end

local auraFrame = CreateFrame("Frame")
wan.RegisterBlizzardEvents(
    auraFrame,
    "UNIT_AURA",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_ENTERING_WORLD",
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
    "PLAYER_LOGOUT"
)
auraFrame:SetScript("OnEvent", OnEvent)