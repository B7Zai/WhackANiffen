local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID or UnitGUID("player")
local abilityActive = false
local abilityAura = "Berserk"
local nBerserkMaxRange = 12
local nBerserkDmg, nBerserkHeal = 0, 0

 -- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData[playerGUID]["buff_" .. abilityAura]
        or wan.auraData[playerGUID].buff_Prowl or not wan.IsSpellUsable(wan.spellData.Berserk.id)
    then
        wan.UpdateAbilityData(wan.spellData.Berserk.basename)
        wan.UpdateMechanicData(wan.spellData.Berserk.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, _, idValidUnit = wan.ValidUnitBoolCounter(nil, nBerserkMaxRange)

    -- Base offensive value
    local cBerserkDmg = nBerserkDmg
    local cdPotency = wan.CheckOffensiveCooldownPotency(cBerserkDmg, isValidUnit, idValidUnit)

    -- Base defensive value
    local cBerserkHeal = nBerserkHeal
    local healThreshold = wan.HealThreshold() > cBerserkHeal

    -- Check whether berserk is an offensive or defensive ability
    local isDefensive = wan.traitData.BerserkPersistence.known

    -- Update ability data
    local damageValue = not isDefensive and cdPotency and math.floor(cBerserkDmg) or 0
    local healValue = isDefensive and healThreshold and math.floor(cBerserkHeal) or 0

    wan.UpdateAbilityData(wan.spellData.Berserk.basename, damageValue, wan.spellData.Berserk.icon, wan.spellData.Berserk.name)
    wan.UpdateMechanicData(wan.spellData.Berserk.basename, healValue, wan.spellData.Berserk.icon, wan.spellData.Berserk.name)
end

-- Local frame and event handler
local frameBerserk = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nBerserkDmg = wan.OffensiveCooldownToValue(wan.spellData.Berserk.id)
            nBerserkHeal = wan.DefensiveCooldownToValue(wan.spellData.Berserk.id)
        end
    end)
end
frameBerserk:RegisterEvent("ADDON_LOADED")
frameBerserk:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Berserk.known and wan.spellData.Berserk.id
        abilityAura = wan.FormatNameForKey(wan.spellData.Berserk.name)
        wan.BlizzardEventHandler(frameBerserk, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
        wan.SetUpdateRate(frameBerserk, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        abilityActive = wan.spellData.Berserk.known and wan.spellData.Berserk.id
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBerserk, CheckAbilityValue, abilityActive)
    end
end)
