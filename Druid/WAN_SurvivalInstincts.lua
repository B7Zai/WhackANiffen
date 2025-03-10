local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nSurvivalInstincts = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or wan.auraData.player.buff_SurvivalInstincts
        or not wan.IsSpellUsable(wan.spellData.SurvivalInstincts.id)
    then
        wan.UpdateMechanicData(wan.spellData.SurvivalInstincts.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cSurvivalInstincts = nSurvivalInstincts

    -- Update ability data
    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cSurvivalInstincts, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.SurvivalInstincts.basename, abilityValue, wan.spellData.SurvivalInstincts.icon, wan.spellData.SurvivalInstincts.name)
end

-- Init frame 
local frameSurvivalInstincts = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local survivalInstinctsValue = wan.GetSpellDescriptionNumbers(wan.spellData.SurvivalInstincts.id, { 1 })
            nSurvivalInstincts = wan.AbilityPercentageToValue(survivalInstinctsValue)
        end
    end)
end
frameSurvivalInstincts:RegisterEvent("ADDON_LOADED")
frameSurvivalInstincts:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.SurvivalInstincts.known and wan.spellData.SurvivalInstincts.id
        wan.BlizzardEventHandler(frameSurvivalInstincts, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameSurvivalInstincts, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSurvivalInstincts, CheckAbilityValue, abilityActive)
    end
end)