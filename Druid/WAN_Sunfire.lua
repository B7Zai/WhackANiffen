local _, wan = ...

-- Init data
local frameSunfire = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init data
    local abilityActive = false
    local nSunfireInstantDmg, nSunfireDotDmg, nSunfireDotDuration = 0, 0, 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
            or wan.auraData.player.buff_BearForm or not wan.IsSpellUsable(wan.spellData.Sunfire.id)
        then
            wan.UpdateAbilityData(wan.spellData.Sunfire.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Sunfire.id)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.Sunfire.basename)
            return
        end

        -- Base value
        local cSunfireDmg = nSunfireInstantDmg

        -- Improved Sunfire & Dot value
        if wan.traitData.ImprovedSunfire.known then
            local dotPotencyAoE = wan.CheckDotPotencyAoE(wan.auraData, idValidUnit, wan.spellData.Sunfire.name, nil, nSunfireInstantDmg)
            local sunfireDebuffedUnitAoE = wan.CheckForDebuffAoE(wan.auraData, idValidUnit, wan.spellData.Sunfire.name)
            local missingSunfireDebuffAoE = countValidUnit - sunfireDebuffedUnitAoE
            local cImprovedSunfireDotDmg = nSunfireDotDmg * dotPotencyAoE * missingSunfireDebuffAoE
            cSunfireDmg = cSunfireDmg + cImprovedSunfireDotDmg
        else
            local dotPotency = wan.CheckDotPotency(nSunfireInstantDmg)
            local cSunfireDotDmg = (not wan.auraData[wan.TargetUnitID].debuff_Sunfire and (nSunfireDotDmg * dotPotency)) or 0
            cSunfireDmg = cSunfireDmg + cSunfireDotDmg
        end

        -- Crit layer
        cSunfireDmg = cSunfireDmg * wan.ValueFromCritical(wan.CritChance)

        -- Update ability data
        local abilityValue = math.floor(cSunfireDmg)
        wan.UpdateAbilityData(wan.spellData.Sunfire.basename, abilityValue, wan.spellData.Sunfire.icon, wan.spellData.Sunfire.name)
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local sunfireValues = wan.GetSpellDescriptionNumbers(wan.spellData.Sunfire.id, { 1, 2, 3 })
            nSunfireInstantDmg = sunfireValues[1]
            nSunfireDotDmg = sunfireValues[2]
            nSunfireDotDuration = sunfireValues[3]
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Sunfire.known and wan.spellData.Sunfire.id
            wan.BlizzardEventHandler(frameSunfire, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameSunfire, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameSunfire, CheckAbilityValue, abilityActive)
        end
    end)
end

frameSunfire:RegisterEvent("ADDON_LOADED")
frameSunfire:SetScript("OnEvent", OnEvent)