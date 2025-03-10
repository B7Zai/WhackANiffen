local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nBitterImmunity = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.BitterImmunity.id)
    then
        wan.UpdateMechanicData(wan.spellData.BitterImmunity.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cBitterImmunity = nBitterImmunity

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cBitterImmunity, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.BitterImmunity.basename, abilityValue, wan.spellData.BitterImmunity.icon, wan.spellData.BitterImmunity.name)
end

-- Init frame 
local frameBitterImmunity = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nBitterImmunity = wan.DefensiveCooldownToValue(wan.spellData.BitterImmunity.id)
        end
    end)
end
frameBitterImmunity:RegisterEvent("ADDON_LOADED")
frameBitterImmunity:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BitterImmunity.known and wan.spellData.BitterImmunity.id
        wan.BlizzardEventHandler(frameBitterImmunity, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBitterImmunity, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBitterImmunity, CheckAbilityValue, abilityActive)
    end
end)
