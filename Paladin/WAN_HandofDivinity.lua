local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nHandofDivinity = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.auraData.player.buff_InfusionofLight
    or wan.auraData.player.buff_HandofDivinity
    or not wan.IsSpellUsable(wan.spellData.HandofDivinity.id)
    then
        wan.UpdateMechanicData(wan.spellData.HandofDivinity.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()
        local groupAbilityValue = 0

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then
                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cHandofDivinity = nHandofDivinity 

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cHandofDivinity, currentPercentHealth)
                groupAbilityValue = groupAbilityValue + abilityValue
            end
        end

        groupAbilityValue = groupAbilityValue >= nHandofDivinity and groupAbilityValue or 0
        wan.UpdateMechanicData(wan.spellData.HandofDivinity.basename, groupAbilityValue, wan.spellData.HandofDivinity.icon, wan.spellData.HandofDivinity.name)
    else
        -- Base defensive value
        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
        local cHandofDivinity = nHandofDivinity

        -- Update ability data
        local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cHandofDivinity, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.HandofDivinity.basename, abilityValue, wan.spellData.HandofDivinity.icon, wan.spellData.HandofDivinity.name)
    end
end

-- Init frame 
local frameHandofDivinity = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nHandofDivinity = wan.DefensiveCooldownToValue(wan.spellData.HandofDivinity.id)
        end
    end)
end
frameHandofDivinity:RegisterEvent("ADDON_LOADED")
frameHandofDivinity:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.HandofDivinity.known and wan.spellData.HandofDivinity.id
        wan.SetUpdateRate(frameHandofDivinity, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameHandofDivinity, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameHandofDivinity, CheckAbilityValue, abilityActive)
    end
end)