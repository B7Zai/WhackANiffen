local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nDivineProtection = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or wan.auraData.player["buff_" .. wan.spellData.DivineProtection.basename]
        or not wan.IsSpellUsable(wan.spellData.DivineProtection.id)
    then
        wan.UpdateMechanicData(wan.spellData.DivineProtection.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cDivineProtection = nDivineProtection

    -- Update ability data
    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cDivineProtection, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.DivineProtection.basename, abilityValue, wan.spellData.DivineProtection.icon, wan.spellData.DivineProtection.name)
end

-- Init frame 
local frameDivineProtection = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local nDivineProtectionValue = wan.GetSpellDescriptionNumbers(wan.spellData.DivineProtection.id, { 1 })
            nDivineProtection = wan.AbilityPercentageToValue(nDivineProtectionValue)
        end
    end)
end
frameDivineProtection:RegisterEvent("ADDON_LOADED")
frameDivineProtection:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.DivineProtection.known and wan.spellData.DivineProtection.id
        wan.BlizzardEventHandler(frameDivineProtection, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameDivineProtection, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameDivineProtection, CheckAbilityValue, abilityActive)
    end
end)