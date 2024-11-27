local _, wan = ...

wan.auraData = wan.auraData or {}
wan.instanceIDMap = wan.instanceIDMap or {}

setmetatable(wan.auraData, {
    __index = function(t, key)
        local default = {} 
        t[key] = default 
        return default
    end
}) -- Set default values if data doesnt exists

local auraInstanceThrottler = {}

local function UpdateAuras(auraDataArray, unitID, updateInfo)
    if not updateInfo then return end

    auraDataArray[unitID] = auraDataArray[unitID] or {}
    wan.instanceIDMap[unitID] = wan.instanceIDMap[unitID] or {}

    if updateInfo.isFullUpdate then -- Full aura update for units
        wan.WipeTable(auraDataArray[unitID])
        wan.WipeTable(wan.instanceIDMap[unitID])

        for i = 1, 40 do
            local buffData = C_UnitAuras.GetAuraDataByIndex(unitID, i, "HELPFUL")
            if not buffData then break end
            if buffData.auraInstanceID then
                local spellName = wan.FormatNameForKey(buffData.name)
                local key = "buff_" .. spellName
                auraDataArray[unitID][key] = buffData
                wan.instanceIDMap[unitID][buffData.auraInstanceID] = key
            end
        end

        for i = 1, 40 do
            local debuffData = C_UnitAuras.GetAuraDataByIndex(unitID, i, "HARMFUL")
            if not debuffData then break end
            if debuffData.sourceUnit == "player" then
                local spellName = wan.FormatNameForKey(debuffData.name)
                local key = "debuff_" .. spellName
                auraDataArray[unitID][key] = debuffData
                wan.instanceIDMap[unitID][debuffData.auraInstanceID] = key
            end
        end
        return
    end

    if updateInfo.addedAuras then -- Aura update when auras get added
        for _, aura in pairs(updateInfo.addedAuras) do
            if unitID == "player"
            or (unitID == wan.TargetUnitID and (aura.isHelpful or aura.sourceUnit == "player"))
            or (unitID == wan.NameplateUnitID[unitID] and (aura.isHelpful or aura.sourceUnit == "player"))
            or (unitID == wan.GroupUnitID[unitID] and (aura.isHelpful and aura.canApplyAura or aura.isHarmful))
             then
                local spellName = wan.FormatNameForKey(aura.name)
                if spellName then
                    local key = aura.isHelpful and "buff_" .. spellName or aura.isHarmful and "debuff_" .. spellName
                    auraDataArray[unitID][key] = aura
                    wan.instanceIDMap[unitID][aura.auraInstanceID] = key
                end
            end
        end
    end

    if updateInfo.updatedAuraInstanceIDs then -- Aura update when auras change
        for _, instanceID in pairs(updateInfo.updatedAuraInstanceIDs) do
            if wan.instanceIDMap[unitID][instanceID] then
                local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unitID, instanceID)
                if aura then
                    local key = wan.instanceIDMap[unitID][aura.auraInstanceID]
                    auraDataArray[unitID][key] = aura
                    wan.instanceIDMap[unitID][aura.auraInstanceID] = key
                end
            end
        end
    end

    if updateInfo.removedAuraInstanceIDs then -- Remove flagged auras
        for _, flaggedInstanceID in pairs(updateInfo.removedAuraInstanceIDs) do
            local removedKey = wan.instanceIDMap[unitID][flaggedInstanceID]
            if not removedKey then return end
            if removedKey then
                wan.instanceIDMap[unitID][flaggedInstanceID] = nil
                auraDataArray[unitID][removedKey] = nil

                for cachedID, cachedkey in pairs(wan.instanceIDMap[unitID]) do -- Update aura data with existing data if data was erased
                    if removedKey == cachedkey then
                        local activeAura = C_UnitAuras.GetAuraDataByAuraInstanceID(unitID, cachedID)
                        if activeAura then
                            auraDataArray[unitID][cachedkey] = activeAura
                        end
                    end
                end
            end
        end
    end
end

local function AuraUpdate(self, event, unitID, updateInfo)

    -- wipe aura data on player logout
    if event == "PLAYER_LOGOUT" then
        wan.WipeTable(wan.auraData)
        wan.WipeTable(wan.instanceIDMap)
    end

    -- wipe aura data on a loading screen and perform a full aura update for player
    if event == "PLAYER_ENTERING_WORLD" then
        wan.WipeTable(wan.auraData)
        wan.WipeTable(wan.instanceIDMap)
        UpdateAuras(wan.auraData, "player", { isFullUpdate = true })
        for groupUnitID, _ in pairs(wan.GroupUnitID) do
            UpdateAuras(wan.auraData, groupUnitID, { isFullUpdate = true })
        end
    end

    -- update aura data for the player
    if unitID == "player" then
        UpdateAuras(wan.auraData, "player", updateInfo)
    end

    -- update aura data on target when switching targets
    if event == "PLAYER_TARGET_CHANGED" then
        UpdateAuras(wan.auraData, wan.TargetUnitID, { isFullUpdate = true })
    end

    -- update aura data on the target
    if unitID == wan.TargetUnitID then
        UpdateAuras(wan.auraData, wan.TargetUnitID, updateInfo)
    end

    -- removes aura data on nameplate unit tokens
    if event == "NAME_PLATE_UNIT_REMOVED" then
        wan.WipeTable(wan.auraData[unitID])
        wan.WipeTable(wan.instanceIDMap[unitID])
    end

    -- update aura data on nameplates
    if unitID == wan.NameplateUnitID[unitID] then
        UpdateAuras(wan.auraData, unitID, updateInfo)
    end

    -- update aura data on group members
    if unitID == wan.GroupUnitID[unitID] then
        if updateInfo and updateInfo.updatedAuraInstanceIDs then
            local lastUpdate = auraInstanceThrottler[unitID]
            if not lastUpdate or lastUpdate < GetTime() - 0.5 then
                lastUpdate = GetTime()

                print("Updating instanceID aura for:", unitID)
                auraInstanceThrottler[unitID] = GetTime()

                UpdateAuras(wan.auraData, unitID, updateInfo)

            end
        else
            UpdateAuras(wan.auraData, unitID, updateInfo)
        end
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
    "GROUP_ROSTER_UPDATE",
    "PLAYER_LOGOUT"
)
auraFrame:SetScript("OnEvent", AuraUpdate)