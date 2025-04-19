local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameAdaptiveSwarm = CreateFrame("Frame")

-- Init data
local abilityActive = false
local nAdaptiveSwarmHotHeal = 0
local nAdaptiveSwarmDotDmg = 0
local nAdaptiveSwarmSpreadChance = 0

-- Init trait data
local sProwl = "Prowl"
local nUnbridledSwarm = 0

-- Ability value calculation
local function CheckAbilityValue()

    -- Early exits
    if not wan.PlayerState.Status
        or wan.CheckUnitBuff(nil, sProwl)
        or not wan.IsSpellUsable(wan.spellData.AdaptiveSwarm.id)
    then
        wan.UpdateAbilityData(wan.spellData.AdaptiveSwarm.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit = wan.ValidUnitBoolCounter(wan.spellData.AdaptiveSwarm.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.AdaptiveSwarm.basename)
        return
    end

    -- Dot value
    local cAdaptiveSwarmSpreadMod = (countValidUnit * nAdaptiveSwarmSpreadChance) / 2
    local cAdaptiveSwarmDotDmg = nAdaptiveSwarmDotDmg * cAdaptiveSwarmSpreadMod

    -- Base value
    local cAdaptiveSwarmDmg = cAdaptiveSwarmDotDmg

    -- Crit layer
    cAdaptiveSwarmDmg = cAdaptiveSwarmDmg * wan.ValueFromCritical(wan.CritChance)

    -- Update ability data
    local abilityValue = math.floor(cAdaptiveSwarmDmg)
    wan.UpdateAbilityData(wan.spellData.AdaptiveSwarm.basename, abilityValue, wan.spellData.AdaptiveSwarm.icon, wan.spellData.AdaptiveSwarm.name)
end

-- Local event handler
local function AddonLoad(self, event, addonName)
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local adaptiveSwarmValues = wan.GetSpellDescriptionNumbers(wan.spellData.AdaptiveSwarm.id, { 1, 2 })
            nAdaptiveSwarmHotHeal = adaptiveSwarmValues[1]
            nAdaptiveSwarmDotDmg = adaptiveSwarmValues[2]
            nAdaptiveSwarmSpreadChance = 1 + nUnbridledSwarm
        end
    end)
end
frameAdaptiveSwarm:RegisterEvent("ADDON_LOADED")
frameAdaptiveSwarm:SetScript("OnEvent", AddonLoad)

-- Set update rate and data update on custom events
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.AdaptiveSwarm.known and wan.spellData.AdaptiveSwarm.id
        wan.BlizzardEventHandler(frameAdaptiveSwarm, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameAdaptiveSwarm, CheckAbilityValue, abilityActive)

        sProwl = wan.spellData.Prowl.formattedName
    end

    if event == "TRAIT_DATA_READY" then
        nUnbridledSwarm = wan.GetTraitDescriptionNumbers(wan.traitData.UnbridledSwarm.entryid, { 1 }) / 100
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameAdaptiveSwarm, CheckAbilityValue, abilityActive)
    end
end)
