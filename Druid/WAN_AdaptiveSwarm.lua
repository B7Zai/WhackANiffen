local _, wan = ...

local frameAdaptiveSwarm = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init data
    local abilityActive = false
    local nAdaptiveSwarmHotHeal, nAdaptiveSwarmDotDmg, nAdaptiveSwarmSpreadChance = 0, 0, 0

    -- Init trait data
    local nUnbridledSwarm = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_Prowl
            or not wan.IsSpellUsable(wan.spellData.AdaptiveSwarm.id)
        then
            wan.UpdateAbilityData(wan.spellData.AdaptiveSwarm.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.AdaptiveSwarm.id)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.AdaptiveSwarm.basename)
            return
        end

        -- Dot value
        local dotPotency = wan.CheckDotPotency()
        local cAdaptiveSwarmSpreadMod = (countValidUnit * nAdaptiveSwarmSpreadChance) / 2
        local cAdaptiveSwarmDotDmg = nAdaptiveSwarmDotDmg * dotPotency * cAdaptiveSwarmSpreadMod

        -- Base value
        local cAdaptiveSwarmDmg = cAdaptiveSwarmDotDmg

        -- Crit layer
        cAdaptiveSwarmDmg = cAdaptiveSwarmDmg * wan.ValueFromCritical(wan.CritChance)

        -- Update ability data
        local abilityValue = math.floor(cAdaptiveSwarmDmg)
        wan.UpdateAbilityData(wan.spellData.AdaptiveSwarm.basename, abilityValue, wan.spellData.AdaptiveSwarm.icon, wan.spellData.AdaptiveSwarm.name)
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local adaptiveSwarmValues = wan.GetSpellDescriptionNumbers(wan.spellData.AdaptiveSwarm.id, { 1, 2 })
            nAdaptiveSwarmHotHeal = adaptiveSwarmValues[1]
            nAdaptiveSwarmDotDmg = adaptiveSwarmValues[2]
            nAdaptiveSwarmSpreadChance = 1 + nUnbridledSwarm
        end
    end)

    -- Set update rate and data update on custom events
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.AdaptiveSwarm.known and wan.spellData.AdaptiveSwarm.id
            wan.BlizzardEventHandler(frameAdaptiveSwarm, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
            wan.SetUpdateRate(frameAdaptiveSwarm, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then 
            nUnbridledSwarm = wan.GetTraitDescriptionNumbers(wan.traitData.UnbridledSwarm.entryid, {1}) / 100
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameAdaptiveSwarm, CheckAbilityValue, abilityActive)
        end
    end)
end

frameAdaptiveSwarm:RegisterEvent("ADDON_LOADED")
frameAdaptiveSwarm:SetScript("OnEvent", OnEvent)