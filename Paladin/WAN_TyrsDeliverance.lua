local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nTyrsDeliverance = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData.player.buff_TyrsDeliverance
    or not wan.IsSpellUsable(wan.spellData.TyrsDeliverance.id)
    then
        wan.UpdateMechanicData(wan.spellData.TyrsDeliverance.basename)
        return
    end

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()
        local groupAbilityValue = 0

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then
                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cTyrsDeliverance = nTyrsDeliverance 

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cTyrsDeliverance, currentPercentHealth)
                groupAbilityValue = groupAbilityValue + abilityValue
            end
        end

        groupAbilityValue = groupAbilityValue >= nTyrsDeliverance and groupAbilityValue or 0
        wan.UpdateMechanicData(wan.spellData.TyrsDeliverance.basename, groupAbilityValue, wan.spellData.TyrsDeliverance.icon, wan.spellData.TyrsDeliverance.name)
    else
        -- Base defensive value
        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
        local cTyrsDeliverance = nTyrsDeliverance

        -- Update ability data
        local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cTyrsDeliverance, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.TyrsDeliverance.basename, abilityValue, wan.spellData.TyrsDeliverance.icon, wan.spellData.TyrsDeliverance.name)
    end
end

-- Init frame 
local frameTyrsDeliverance = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nTyrsDeliverance = wan.DefensiveCooldownToValue(wan.spellData.TyrsDeliverance.id)
        end
    end)
end
frameTyrsDeliverance:RegisterEvent("ADDON_LOADED")
frameTyrsDeliverance:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.TyrsDeliverance.known and wan.spellData.TyrsDeliverance.id
        wan.SetUpdateRate(frameTyrsDeliverance, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameTyrsDeliverance, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameTyrsDeliverance, CheckAbilityValue, abilityActive)
    end
end)