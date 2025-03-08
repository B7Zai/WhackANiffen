local _, wan = ...

wan.auraData = {}
wan.instanceIDMap = {}

local function UpdateAuras(unitToken, updateInfo)
    if not updateInfo then return end
    
    wan.auraData[unitToken] = wan.auraData[unitToken] or {}
    wan.instanceIDMap[unitToken] = wan.instanceIDMap[unitToken] or {}

    if updateInfo.isFullUpdate then -- Full aura update for units
        wan.auraData[unitToken] = {}
        wan.instanceIDMap[unitToken] = {}

        for i = 1, 40 do
            local aura = C_UnitAuras.GetBuffDataByIndex(unitToken, i)
            if not aura then break end
            if unitToken == "player"
                or (unitToken == "pet" and aura.sourceUnit == "player")
                or (unitToken == wan.TargetUnitID and aura.isStealable)
                or (wan.NameplateUnitID[unitToken] and aura.isStealable)
                or (wan.GroupUnitID[unitToken] and (aura.sourceUnit == "player" or aura.canApplyAura or wan.UnitState.IsAI[unitToken])) then
                local spellName = wan.FormatNameForKey(aura.name)
                local key = spellName and "buff_" .. spellName
                if key then
                    wan.auraData[unitToken][key] = aura
                    wan.instanceIDMap[unitToken][aura.auraInstanceID] = key
                end
            end
        end

        for i = 1, 40 do
            local aura = C_UnitAuras.GetDebuffDataByIndex(unitToken, i)
            if not aura then break end
            if unitToken == "player"
                or (unitToken == "pet" and aura.isRaid)
                or (unitToken == wan.TargetUnitID and aura.sourceUnit == "player")
                or (wan.NameplateUnitID[unitToken] and aura.sourceUnit == "player")
                or (wan.GroupUnitID[unitToken] and aura.isRaid) then
                local spellName = wan.FormatNameForKey(aura.name)
                local key = spellName and "debuff_" .. spellName
                if key then
                    wan.auraData[unitToken][key] = aura
                    wan.instanceIDMap[unitToken][aura.auraInstanceID] = key
                end
            end
        end
        return
    end

    if updateInfo.addedAuras then -- Aura update when auras get added
        for _, aura in pairs(updateInfo.addedAuras) do
            if unitToken == "player"
                or (unitToken == "pet" and (aura.isRaid or aura.sourceUnit == "player"))
                or (unitToken == wan.TargetUnitID and (aura.isStealable or aura.sourceUnit == "player"))
                or (wan.NameplateUnitID[unitToken] and (aura.isStealable or aura.sourceUnit == "player"))
                or (wan.GroupUnitID[unitToken] and (aura.sourceUnit == "player" or aura.canApplyAura or wan.UnitState.IsAI[unitToken] or (aura.isHarmful and aura.isRaid)))
            then
                local spellName = wan.FormatNameForKey(aura.name)
                if spellName then
                    local key = aura.isHelpful and "buff_" .. spellName or aura.isHarmful and "debuff_" .. spellName
                    wan.auraData[unitToken][key] = aura
                    wan.instanceIDMap[unitToken][aura.auraInstanceID] = key
                end
            end
        end
    end

    if updateInfo.updatedAuraInstanceIDs then -- Aura update when auras change
        for _, instanceID in pairs(updateInfo.updatedAuraInstanceIDs) do
            if wan.instanceIDMap[unitToken][instanceID] then
                local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unitToken, instanceID)
                if aura then
                    local key = wan.instanceIDMap[unitToken][instanceID]
                    wan.auraData[unitToken][key] = aura
                    wan.instanceIDMap[unitToken][instanceID] = nil
                    wan.instanceIDMap[unitToken][aura.auraInstanceID] = key
                end
            end
        end
    end

    if updateInfo.removedAuraInstanceIDs then -- Remove flagged auras
        for _, flaggedInstanceID in pairs(updateInfo.removedAuraInstanceIDs) do
            local removedKey = wan.instanceIDMap[unitToken][flaggedInstanceID]
            if removedKey then
                wan.instanceIDMap[unitToken][flaggedInstanceID] = nil
                wan.auraData[unitToken][removedKey] = nil

                -- Update aura data with existing data if data was erased
                for cachedID, cachedkey in pairs(wan.instanceIDMap[unitToken]) do
                    if removedKey == cachedkey then
                        local activeAura = C_UnitAuras.GetAuraDataByAuraInstanceID(unitToken, cachedID)
                        if activeAura then
                            wan.auraData[unitToken][cachedkey] = activeAura
                            wan.instanceIDMap[unitToken][activeAura.auraInstanceID] = cachedkey
                        end
                    end
                end
            end
        end
    end
end

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "TARGET_UNITID_ASSIGNED" then
        UpdateAuras(wan.TargetUnitID, { isFullUpdate = true })
    end

    if event == "PET_UNITID_ASSIGNED" then
        UpdateAuras("pet", { isFullUpdate = true })
    end

    if event == "NAMEPLATE_UNITID_ASSIGNED" then
        local nameplateUnitToken = ...
        UpdateAuras(nameplateUnitToken, { isFullUpdate = true })
    end

    if event == "GROUP_UNITID_ASSIGNED" then
        for groupUnitToken, _ in pairs(wan.GroupUnitID) do
            if groupUnitToken ~= "player" then
                UpdateAuras(groupUnitToken, { isFullUpdate = true })
            end
        end
    end
end)

local function AuraUpdate(self, event, unitToken, updateInfo)
    -- perform a full aura update for player and group members on loading screen
    if event == "PLAYER_ENTERING_WORLD" then
        UpdateAuras("player", { isFullUpdate = true })
        UpdateAuras("pet", { isFullUpdate = true })
        for groupUnitToken, _ in pairs(wan.GroupUnitID) do
            UpdateAuras(groupUnitToken, { isFullUpdate = true })
        end
    end

    -- update aura data on player when resurrecting or changing talents
    if event == "PLAYER_ALIVE" or event == "TRAIT_CONFIG_UPDATED" then
        UpdateAuras("player", { isFullUpdate = true })
        UpdateAuras("pet", { isFullUpdate = true })
    end

    -- update aura data on unitTokens
    if unitToken then
        if unitToken == "player" then
            UpdateAuras(unitToken, updateInfo)
        elseif unitToken == "pet" then
            UpdateAuras(unitToken, updateInfo)
        elseif unitToken == wan.TargetUnitID then
            UpdateAuras(unitToken, updateInfo)
        elseif wan.NameplateUnitID[unitToken] then
            UpdateAuras(unitToken, updateInfo)
        elseif wan.GroupUnitID[unitToken] and unitToken ~= "player" then
            UpdateAuras(unitToken, updateInfo)
        end
    end
end

local auraFrame = CreateFrame("Frame")
wan.RegisterBlizzardEvents(
    auraFrame,
    "UNIT_AURA",
    "PLAYER_ALIVE",
    "PLAYER_TARGET_CHANGED",
    "PLAYER_ENTERING_WORLD",
    "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED",
    "TRAIT_CONFIG_UPDATED",
    "GROUP_ROSTER_UPDATE"
)
auraFrame:SetScript("OnEvent", AuraUpdate)
