local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local percentValue = 10
local nCleanseToxins = 0
local dispelType = {}

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.CleanseToxins.id)
    then
        wan.UpdateMechanicData(wan.spellData.CleanseToxins.basename)
        wan.UpdateSupportData(nil, wan.spellData.CleanseToxins.basename)
        return
    end

    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, _ in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken]then

                local cCleanseToxins = wan.AbilityPercentageToValue(nCleanseToxins)
                local dispelValue = wan.GetDispelValue(groupUnitToken, dispelType)

                cCleanseToxins = nCleanseToxins * dispelValue

                local abilityValue = math.floor(cCleanseToxins)
                wan.UpdateSupportData(groupUnitToken, wan.spellData.CleanseToxins.basename, abilityValue, wan.spellData.CleanseToxins.icon, wan.spellData.CleanseToxins.name)
            else
                wan.UpdateSupportData(groupUnitToken, wan.spellData.CleanseToxins.basename)
            end
        end
    else
        local dispelValue = wan.GetDispelValue(playerUnitToken, dispelType)
        local cCleanseToxins = nCleanseToxins * dispelValue
        local abilityValue = math.floor(cCleanseToxins)
        wan.UpdateMechanicData(wan.spellData.CleanseToxins.basename, abilityValue, wan.spellData.CleanseToxins.icon, wan.spellData.CleanseToxins.name)
    end
end

-- Init frame 
local frameCleanseToxins = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nCleanseToxins = wan.AbilityPercentageToValue(percentValue)
            dispelType = wan.CheckDispelType(wan.spellData.CleanseToxins.id)
        end
    end)
end
frameCleanseToxins:RegisterEvent("ADDON_LOADED")
frameCleanseToxins:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.CleanseToxins.known and wan.spellData.CleanseToxins.id
        wan.BlizzardEventHandler(frameCleanseToxins, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameCleanseToxins, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.CleanseToxins.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.CleanseToxins.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameCleanseToxins, CheckAbilityValue, abilityActive)
    end
end)