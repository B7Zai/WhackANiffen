local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Local data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nAspectOfTheTurtle = 0

-- Ability value calculation
local function CheckAbilityValue()

    if not wan.PlayerState.Status or not wan.PlayerState.Combat
        or wan.auraData.player["buff_" .. wan.spellData.AspectoftheTurtle.basename]
        or not wan.IsSpellUsable(wan.spellData.AspectoftheTurtle.id)
    then
        wan.UpdateMechanicData(wan.spellData.AspectoftheTurtle.basename)
        return
    end

    local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
    local cAspectOfTheTurtle = nAspectOfTheTurtle

    local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cAspectOfTheTurtle, currentPercentHealth)
    wan.UpdateMechanicData(wan.spellData.AspectoftheTurtle.basename, abilityValue, wan.spellData.AspectoftheTurtle.icon, wan.spellData.AspectoftheTurtle.name)
end

local frameAspectOfTheTurtle = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    if addonName ~= "WhackANiffen" then return end

    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nAspectOfTheTurtle = wan.DefensiveCooldownToValue(wan.spellData.AspectoftheTurtle.id)
        end
    end)
end
frameAspectOfTheTurtle:RegisterEvent("ADDON_LOADED")
frameAspectOfTheTurtle:SetScript("OnEvent", AddonLoad)

-- Set update rate and data update on custom events
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.AspectoftheTurtle.known and wan.spellData.AspectoftheTurtle.id
        wan.BlizzardEventHandler(frameAspectOfTheTurtle, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameAspectOfTheTurtle, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameAspectOfTheTurtle, CheckAbilityValue, abilityActive)
    end
end)