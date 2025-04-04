local _, wan = ...

wan.traitData = {}
setmetatable(wan.traitData, {
    __index = function(t, key)
        local default = {
            name = "Unknown",
            id = 0,
            entryid = 0,
            known = false,
            rank = 0,
            traitkey = "UnknownKey"
        }
        t[key] = default
        return default
    end
})

-- Returns custom trait info into an array based on trait names
local function GetTraitData(dataArray)
    local configID = C_ClassTalents.GetActiveConfigID()
    if not configID then return end  -- Early exit if configID is invalid

    local configInfo = C_Traits.GetConfigInfo(configID)
    if not configInfo or not configInfo.treeIDs then return end

    for _, treeID in pairs(configInfo.treeIDs) do
        for _, nodeID in pairs(C_Traits.GetTreeNodes(treeID)) do
            local nodeInfo = C_Traits.GetNodeInfo(configID, nodeID)

            if nodeInfo and nodeInfo.entryIDs then
                local isSelectionType = nodeInfo.type == 2
                local activeEntryID = nodeInfo.activeEntry and nodeInfo.activeEntry.entryID or nil

                for _, entryID in ipairs(nodeInfo.entryIDs) do
                    local entryInfo = C_Traits.GetEntryInfo(configID, entryID)

                    if entryInfo and entryInfo.definitionID then
                        local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                        local overriddenSpellID = definitionInfo.overriddenSpellID or definitionInfo.spellID
                        local spellName = overriddenSpellID and C_Spell.GetSpellName(overriddenSpellID)

                        if spellName then
                            local keyReference = definitionInfo.overrideName or spellName
                            local keyName = wan.FormatNameForKey(keyReference)
                            local isActive = nodeInfo.currentRank > 0 and nodeInfo.subTreeActive ~= false
                            if isSelectionType then isActive = (entryID == activeEntryID) and nodeInfo.subTreeActive ~= false end

                            dataArray[keyName] = {
                                name = spellName,
                                id = definitionInfo.spellID,
                                entryid = entryID,
                                known = isActive,
                                rank = nodeInfo.currentRank,
                                traitkey = keyName,
                            }

                        end
                    end
                end
            end
        end
    end
end

local traitFrame = CreateFrame("Frame")
wan.RegisterBlizzardEvents(traitFrame,
    "TRAIT_CONFIG_UPDATED",
    "PLAYER_ENTERING_WORLD"
)

traitFrame:SetScript("OnEvent", function(self, event, ...)

    if event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_ENTERING_WORLD" then

        C_Timer.After(1, function()
            wan.WipeTable(wan.AbilityData)
            wan.WipeTable(wan.MechanicData)
            wan.WipeTable(wan.HealingData)
            wan.WipeTable(wan.SupportData)
            wan.WipeTable(wan.traitData)
            GetTraitData(wan.traitData)
            wan.CustomEvents("TRAIT_DATA_READY")
        end)
    end
end)