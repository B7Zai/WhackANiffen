local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local percentValue = 10
local nRemoveCurse = 0
local dispelType = {}

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.RemoveCurse.id)
    then
        wan.UpdateMechanicData(wan.spellData.RemoveCurse.basename)
        wan.UpdateSupportData(nil, wan.spellData.RemoveCurse.basename)
        return
    end

    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, _ in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken]then

                local cRemoveCurse = wan.AbilityPercentageToValue(nRemoveCurse)
                local dispelValue = wan.GetDispelValue(groupUnitToken, dispelType)

                cRemoveCurse = nRemoveCurse * dispelValue

                local abilityValue = math.floor(cRemoveCurse)
                wan.UpdateSupportData(groupUnitToken, wan.spellData.RemoveCurse.basename, abilityValue, wan.spellData.RemoveCurse.icon, wan.spellData.RemoveCurse.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.RemoveCurse.basename)
            end
        end
    else
        local dispelValue = wan.GetDispelValue(playerUnitToken, dispelType)
        local cRemoveCurse = nRemoveCurse * dispelValue
        local abilityValue = math.floor(cRemoveCurse)
        wan.UpdateMechanicData(wan.spellData.RemoveCurse.basename, abilityValue, wan.spellData.RemoveCurse.icon, wan.spellData.RemoveCurse.name)
    end
end

-- Init frame 
local frameRemoveCurse = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nRemoveCurse = wan.AbilityPercentageToValue(percentValue)
            dispelType = wan.CheckDispelType(wan.spellData.RemoveCurse.id)
        end
    end)
end
frameRemoveCurse:RegisterEvent("ADDON_LOADED")
frameRemoveCurse:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.RemoveCurse.known and wan.spellData.RemoveCurse.id
        wan.BlizzardEventHandler(frameRemoveCurse, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameRemoveCurse, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.RemoveCurse.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.RemoveCurse.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRemoveCurse, CheckAbilityValue, abilityActive)
    end
end)