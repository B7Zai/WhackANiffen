local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nSentinel = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or wan.auraData.player["buff_" .. wan.spellData.DivineShield.basename]
        or wan.auraData.player["buff_" .. wan.spellData.Sentinel.basename]
        or wan.auraData.player["buff_" .. wan.spellData.BlessingofProtection.basename]
        or wan.auraData.player["buff_" .. wan.spellData.GuardianofAncientKings.basename]
        or not wan.IsSpellUsable(wan.spellData.Sentinel.id)
    then
        wan.UpdateMechanicData(wan.spellData.Sentinel.basename)
        return
    end
    -- Defensive value
    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cSentinel = wan.UnitAbilityHealValue(playerUnitToken, nSentinel, currentPercentHealth)

    -- Update ability data
    local abilityValue = cSentinel
    wan.UpdateMechanicData(wan.spellData.Sentinel.basename, abilityValue, wan.spellData.Sentinel.icon, wan.spellData.Sentinel.name)
end

local frameSentinel = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)

    if addonName ~= "WhackANiffen" then return end

    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nSentinel = wan.DefensiveCooldownToValue(wan.spellData.Sentinel.id)
        end
    end)
end
frameSentinel:RegisterEvent("ADDON_LOADED")
frameSentinel:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Sentinel.known and wan.spellData.Sentinel.id
        wan.SetUpdateRate(frameSentinel, CheckAbilityValue, abilityActive)
        wan.BlizzardEventHandler(frameSentinel, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.Sentinel.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.Sentinel.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSentinel, CheckAbilityValue, abilityActive)
    end
end)
