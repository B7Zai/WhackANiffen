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

local function UpdateAuras(unitID, updateInfo)
    if not updateInfo then print("didnt update anything on", unitID) return end

    wan.auraData[unitID] = wan.auraData[unitID] or {}
    wan.instanceIDMap[unitID] = wan.instanceIDMap[unitID] or {}

    -- Full aura update for units
    if updateInfo.isFullUpdate then
        print("full update on", unitID)
        wan.auraData[unitID] = {}
        wan.instanceIDMap[unitID] = {}

        for i = 1, 40 do
            local aura = C_UnitAuras.GetAuraDataByIndex(unitID, i)
            if not aura then break end
            if unitID == "player"
            or (unitID == wan.TargetUnitID and (aura.isHelpful or aura.sourceUnit == "player"))
            or (wan.NameplateUnitID[unitID] and (aura.isHelpful or aura.sourceUnit == "player"))
            or (wan.GroupUnitID[unitID] and (aura.isHelpful and aura.canApplyAura or aura.isHarmful)) then
                local spellName = wan.FormatNameForKey(aura.name)
                local key = spellName and (aura.isHelpful and "buff_" .. spellName or aura.isHarmful and "debuff_" .. spellName)
                if key then
                    wan.auraData[unitID][key] = aura
                    wan.instanceIDMap[unitID][aura.auraInstanceID] = key
                end
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
                    wan.auraData[unitID][key] = aura
                    wan.instanceIDMap[unitID][aura.auraInstanceID] = key
                    print("added", key, "on", unitID)
                end
            end
        end
    end

    if updateInfo.updatedAuraInstanceIDs then -- Aura update when auras change
        for _, instanceID in pairs(updateInfo.updatedAuraInstanceIDs) do
            if wan.GroupUnitID[unitID] and wan.instanceIDMap[unitID][instanceID] then
                local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unitID, instanceID)
                if aura then
                    local key = wan.instanceIDMap[unitID][aura.auraInstanceID]
                    wan.auraData[unitID][key] = aura
                    wan.instanceIDMap[unitID][aura.auraInstanceID] = key
                    print("Refreshed group aura:", key, "on", unitID)
                end
            elseif unitID == "player" or unitID == wan.TargetUnitID or wan.NameplateUnitID[unitID] then
                local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unitID, instanceID)
                if aura then
                    local spellName = wan.FormatNameForKey(aura.name)
                    local key = aura.isHelpful and "buff_" .. spellName or aura.isHarmful and "debuff_" .. spellName
                    if key then
                        wan.auraData[unitID][key] = aura
                        wan.instanceIDMap[unitID][aura.auraInstanceID] = key
                        print("Refreshed non-group aura:", key, "on", unitID)
                    end
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
                wan.auraData[unitID][removedKey] = nil
                print("removed", removedKey, "on", unitID)

                -- Update aura data with existing data if data was erased
                for cachedID, cachedkey in pairs(wan.instanceIDMap[unitID]) do
                    if removedKey == cachedkey then
                        local activeAura = C_UnitAuras.GetAuraDataByAuraInstanceID(unitID, cachedID)
                        if activeAura then
                            wan.auraData[unitID][cachedkey] = activeAura
                            wan.instanceIDMap[unitID][activeAura.auraInstanceID] = cachedkey
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

    -- wipe aura data on a loading screen and perform a full aura update for player and group members
    if event == "PLAYER_ENTERING_WORLD" then
        wan.WipeTable(wan.auraData)
        wan.WipeTable(wan.instanceIDMap)
        UpdateAuras("player", { isFullUpdate = true })
        for groupUnitID, _ in pairs(wan.GroupUnitID) do
            UpdateAuras(groupUnitID, { isFullUpdate = true })
        end
    end

    -- update aura data for the player
    if unitID == "player" then
        UpdateAuras( "player", updateInfo)
    end

    -- update aura data on target when switching targets
    if event == "PLAYER_TARGET_CHANGED" then
        UpdateAuras(wan.TargetUnitID, { isFullUpdate = true })
    end

    -- update aura data on the target
    if unitID == wan.TargetUnitID then
        UpdateAuras(wan.TargetUnitID, updateInfo)
    end

    -- removes aura data on nameplate unit tokens
    if event == "NAME_PLATE_UNIT_REMOVED" then
        wan.auraData[unitID] = nil
        wan.instanceIDMap[unitID] = nil
    end

    -- update aura data on nameplates
    if wan.NameplateUnitID[unitID] then
        if updateInfo then
            print(unitID, "updating")
            UpdateAuras(unitID, updateInfo)
        else
            UpdateAuras(unitID, { isFullUpdate = true })
        end
    end

    -- update aura data on group members
    if wan.GroupUnitID[unitID] then
        if updateInfo and updateInfo.updatedAuraInstanceIDs then
            -- update rate for updatedAuraInstanceIDs, this will tank fps if not throttled for each unit token
            local lastUpdate = auraInstanceThrottler[unitID]
            if not lastUpdate or lastUpdate < GetTime() - 1 then
                lastUpdate = GetTime()
                auraInstanceThrottler[unitID] = GetTime()
                UpdateAuras(unitID, updateInfo)
            end
        elseif updateInfo and (updateInfo.isFullUpdate or updateInfo.addedAuras or updateInfo.removedAuraInstanceIDs) then
            UpdateAuras(unitID, updateInfo)
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