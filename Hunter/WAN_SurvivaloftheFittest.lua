local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Local data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nSurvivalOfTheFittest = 0

-- Ability value calculation
local function CheckAbilityValue()

    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or wan.auraData.player["buff_" .. wan.spellData.SurvivaloftheFittest.basename]
        or not wan.IsSpellUsable(wan.spellData.SurvivaloftheFittest.id)
    then
        wan.UpdateMechanicData(wan.spellData.SurvivaloftheFittest.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cSurvivalOfTheFittest = nSurvivalOfTheFittest

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cSurvivalOfTheFittest, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.SurvivaloftheFittest.basename, abilityValue, wan.spellData.SurvivaloftheFittest.icon, wan.spellData.SurvivaloftheFittest.name)
end

local frameSurvivalOfTheFittest = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    if addonName ~= "WhackANiffen" then return end

    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local nSurvivalOfTheFittestValue = wan.GetSpellDescriptionNumbers(wan.spellData.SurvivaloftheFittest.id, { 1 })
            nSurvivalOfTheFittest = wan.AbilityPercentageToValue(nSurvivalOfTheFittestValue)
        end
    end)
end
frameSurvivalOfTheFittest:RegisterEvent("ADDON_LOADED")
frameSurvivalOfTheFittest:SetScript("OnEvent", AddonLoad)

-- Set update rate and data update on custom events
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.SurvivaloftheFittest.known and wan.spellData.SurvivaloftheFittest.id
        wan.BlizzardEventHandler(frameSurvivalOfTheFittest, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameSurvivalOfTheFittest, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSurvivalOfTheFittest, CheckAbilityValue, abilityActive)
    end
end)