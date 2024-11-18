local _, wan = ...

wan.traitData = wan.traitData or {}
setmetatable(wan.traitData, {
    __index = function(t, key)
        local default = {
            name = "Unknown",
            id = 61304,
            entryid = 0,
            known = false,
            rank = 0
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

                for _, entryID in pairs(nodeInfo.entryIDs) do
                    local entryInfo = C_Traits.GetEntryInfo(configID, entryID)

                    if entryInfo and entryInfo.definitionID then
                        local definitionInfo = C_Traits.GetDefinitionInfo(entryInfo.definitionID)
                        local spellInfo = C_Spell.GetSpellInfo(definitionInfo.spellID)

                        if spellInfo then
                            local keyName = wan.FormatNameForKey(spellInfo.name)
                            local isActive = nodeInfo.currentRank > 0
                            if isSelectionType then isActive = (entryID == activeEntryID) end

                            dataArray[keyName] = {
                                name = spellInfo.name,
                                id = definitionInfo.spellID,
                                entryid = activeEntryID,
                                known = isActive,
                                rank = nodeInfo.currentRank,
                            }
                        end
                    end
                end
            end
        end
    end
    wan.CustomEvents("TRAIT_DATA_READY")
end

local traitFrame = CreateFrame("Frame")
wan.RegisterBlizzardEvents(traitFrame,
    "TRAIT_CONFIG_UPDATED",
    "PLAYER_ENTERING_WORLD",
    "PLAYER_LOGOUT"
)

traitFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_ENTERING_WORLD" then
        GetTraitData(wan.traitData)
    end

    if event == "PLAYER_LOGOUT" then
        wan.WipeTable(wan.traitData)
    end
end)