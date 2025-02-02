local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nArdentDefender = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or wan.auraData.player["buff_" .. wan.spellData.DivineShield.basename]
        or wan.auraData.player["buff_" .. wan.spellData.ArdentDefender.basename]
        or wan.auraData.player["buff_" .. wan.spellData.Sentinel.basename]
        or wan.auraData.player["buff_" .. wan.spellData.BlessingofProtection.basename]
        or wan.auraData.player["buff_" .. wan.spellData.GuardianofAncientKings.basename]
        or not wan.IsSpellUsable(wan.spellData.ArdentDefender.id)
    then
        wan.UpdateMechanicData(wan.spellData.ArdentDefender.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cArdentDefender = nArdentDefender

    -- Update ability data
    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cArdentDefender, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.ArdentDefender.basename, abilityValue, wan.spellData.ArdentDefender.icon, wan.spellData.ArdentDefender.name)
end

-- Init frame 
local frameArdentDefender = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local nArdentDefenderValue = wan.GetSpellDescriptionNumbers(wan.spellData.ArdentDefender.id, { 1 })
            nArdentDefender = wan.AbilityPercentageToValue(nArdentDefenderValue)
        end
    end)
end
frameArdentDefender:RegisterEvent("ADDON_LOADED")
frameArdentDefender:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ArdentDefender.known and wan.spellData.ArdentDefender.id
        wan.BlizzardEventHandler(frameArdentDefender, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameArdentDefender, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameArdentDefender, CheckAbilityValue, abilityActive)
    end
end)