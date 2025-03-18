local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nNaturesSwiftness = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.NaturesSwiftness.id) then
        wan.UpdateMechanicData(wan.spellData.NaturesSwiftness.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()
        local groupAbilityValue = 0

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then
                local currentPercentHealth = wan.CheckUnitPercentHealth(groupUnitGUID)
                local cNaturesSwiftness = nNaturesSwiftness 

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cNaturesSwiftness, currentPercentHealth)
                groupAbilityValue = groupAbilityValue + abilityValue
            end
        end

        groupAbilityValue = groupAbilityValue >= nNaturesSwiftness and groupAbilityValue or 0
        wan.UpdateMechanicData(wan.spellData.NaturesSwiftness.basename, groupAbilityValue, wan.spellData.NaturesSwiftness.icon, wan.spellData.NaturesSwiftness.name)
    else
        -- Base defensive value
        local currentPercentHealth = wan.CheckUnitPercentHealth(playerGUID)
        local cNaturesSwiftness = nNaturesSwiftness

        -- Update ability data
        local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cNaturesSwiftness, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.NaturesSwiftness.basename, abilityValue, wan.spellData.NaturesSwiftness.icon, wan.spellData.NaturesSwiftness.name)
    end
end

-- Init frame 
local frameTreeofLife = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nNaturesSwiftness = wan.DefensiveCooldownToValue(wan.spellData.NaturesSwiftness.id)
        end
    end)
end
frameTreeofLife:RegisterEvent("ADDON_LOADED")
frameTreeofLife:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.NaturesSwiftness.known and wan.spellData.NaturesSwiftness.id
        wan.SetUpdateRate(frameTreeofLife, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameTreeofLife, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameTreeofLife, CheckAbilityValue, abilityActive)
    end
end)