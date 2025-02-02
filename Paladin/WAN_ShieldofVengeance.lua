local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nShieldofVengeance = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or wan.auraData.player["buff_" .. wan.spellData.DivineShield.basename]
        or wan.auraData.player["buff_" .. wan.spellData.DivineProtection.basename]
        or wan.auraData.player["buff_" .. wan.spellData.ShieldofVengeance.basename]
        or wan.auraData.player["buff_" .. wan.spellData.BlessingofProtection.basename]
        or not wan.IsSpellUsable(wan.spellData.ShieldofVengeance.id)
    then
        wan.UpdateMechanicData(wan.spellData.ShieldofVengeance.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cShieldofVengeance = nShieldofVengeance

    -- Update ability data
    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cShieldofVengeance, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.ShieldofVengeance.basename, abilityValue, wan.spellData.ShieldofVengeance.icon, wan.spellData.ShieldofVengeance.name)
end

-- Init frame 
local frameShieldofVengeance = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nShieldofVengeance = wan.GetSpellDescriptionNumbers(wan.spellData.ShieldofVengeance.id, { 1 })
        end
    end)
end
frameShieldofVengeance:RegisterEvent("ADDON_LOADED")
frameShieldofVengeance:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ShieldofVengeance.known and wan.spellData.ShieldofVengeance.id
        wan.BlizzardEventHandler(frameShieldofVengeance, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameShieldofVengeance, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameShieldofVengeance, CheckAbilityValue, abilityActive)
    end
end)