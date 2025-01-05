local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local percentValue = 10
local nRemoveCorruption = 0
local dispelType = {}

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.RemoveCorruption.id)
    then
        wan.UpdateMechanicData(wan.spellData.RemoveCorruption.basename)
        wan.UpdateSupportData(nil, wan.spellData.RemoveCorruption.basename)
        return
    end

    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, _ in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken]then

                local cRemoveCorruption = wan.AbilityPercentageToValue(nRemoveCorruption)
                local dispelValue = wan.GetDispelValue(groupUnitToken, dispelType)

                cRemoveCorruption = nRemoveCorruption * dispelValue

                local abilityValue = math.floor(cRemoveCorruption)
                wan.UpdateSupportData(groupUnitToken, wan.spellData.RemoveCorruption.basename, abilityValue, wan.spellData.RemoveCorruption.icon, wan.spellData.RemoveCorruption.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.RemoveCorruption.basename)
            end
        end
    else
        local dispelValue = wan.GetDispelValue(playerUnitToken, dispelType)
        local cRemoveCorruption = nRemoveCorruption * dispelValue
        local abilityValue = math.floor(cRemoveCorruption)
        wan.UpdateMechanicData(wan.spellData.RemoveCorruption.basename, abilityValue, wan.spellData.RemoveCorruption.icon, wan.spellData.RemoveCorruption.name)
    end
end

-- Init frame 
local frameRemoveCorruption = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nRemoveCorruption = wan.AbilityPercentageToValue(percentValue)
        end
    end)
end
frameRemoveCorruption:RegisterEvent("ADDON_LOADED")
frameRemoveCorruption:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.RemoveCorruption.known and wan.spellData.RemoveCorruption.id
        wan.BlizzardEventHandler(frameRemoveCorruption, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameRemoveCorruption, CheckAbilityValue, abilityActive)

        dispelType = wan.CheckDispelType(wan.spellData.RemoveCorruption.id)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.RemoveCorruption.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.RemoveCorruption.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRemoveCorruption, CheckAbilityValue, abilityActive)
    end
end)