local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nGuardianofAncientKings = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or wan.auraData.player["buff_" .. wan.spellData.DivineShield.basename]
        or wan.auraData.player["buff_" .. wan.spellData.BlessingofProtection.basename]
        or wan.auraData.player["buff_" .. wan.spellData.GuardianofAncientKings.basename]
        or not wan.IsSpellUsable(wan.spellData.GuardianofAncientKings.id)
    then
        wan.UpdateMechanicData(wan.spellData.GuardianofAncientKings.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cGuardianofAncientKings = nGuardianofAncientKings

    -- Update ability data
    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cGuardianofAncientKings, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.GuardianofAncientKings.basename, abilityValue, wan.spellData.GuardianofAncientKings.icon, wan.spellData.GuardianofAncientKings.name)
end

-- Init frame 
local frameGuardianofAncientKings = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local nGuardianofAncientKingsValue = wan.GetSpellDescriptionNumbers(wan.spellData.GuardianofAncientKings.id, { 1 })
            nGuardianofAncientKings = wan.AbilityPercentageToValue(nGuardianofAncientKingsValue)
        end
    end)
end
frameGuardianofAncientKings:RegisterEvent("ADDON_LOADED")
frameGuardianofAncientKings:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.GuardianofAncientKings.known and wan.spellData.GuardianofAncientKings.id
        wan.BlizzardEventHandler(frameGuardianofAncientKings, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameGuardianofAncientKings, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameGuardianofAncientKings, CheckAbilityValue, abilityActive)
    end
end)