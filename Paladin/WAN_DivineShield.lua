local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nDivineShield = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or (wan.auraData.player.debuff_Forbearance and not wan.traitData.LightsRevocation.known)
        or ((wan.PlayerState.InGroup and wan.PlayerState.Role == "TANK") and not wan.traitData.FinalStand.known)
        or not wan.IsSpellUsable(wan.spellData.DivineShield.id)
    then
        wan.UpdateMechanicData(wan.spellData.DivineShield.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cDivineShield = nDivineShield

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cDivineShield, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.DivineShield.basename, abilityValue, wan.spellData.DivineShield.icon, wan.spellData.DivineShield.name)
end

-- Init frame 
local frameDivineShield = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nDivineShield = wan.DefensiveCooldownToValue(wan.spellData.DivineShield.id)
        end
    end)
end
frameDivineShield:RegisterEvent("ADDON_LOADED")
frameDivineShield:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.DivineShield.known and wan.spellData.DivineShield.id
        wan.BlizzardEventHandler(frameDivineShield, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameDivineShield, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.DivineShield.basename)
        else
            wan.UpdateSupportData(nil, wan.spellData.DivineShield.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameDivineShield, CheckAbilityValue, abilityActive)
    end
end)
