local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nRenewalHeal = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Renewal.id)
    then
        wan.UpdateMechanicData(wan.spellData.Renewal.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cRenewalHeal = nRenewalHeal

    -- update healing data
    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cRenewalHeal, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.Renewal.basename, abilityValue, wan.spellData.Renewal.icon, wan.spellData.Renewal.name)
end

-- Init frame 
local frameRenewal = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local renewalValue = wan.GetSpellDescriptionNumbers(wan.spellData.Renewal.id, { 1 })
            nRenewalHeal = wan.AbilityPercentageToValue(renewalValue)
        end
    end)
end
frameRenewal:RegisterEvent("ADDON_LOADED")
frameRenewal:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Renewal.known and wan.spellData.Renewal.id
        wan.BlizzardEventHandler(frameRenewal, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameRenewal, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRenewal, CheckAbilityValue, abilityActive)
    end
end)