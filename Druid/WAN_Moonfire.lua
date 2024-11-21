local _, wan = ...

-- Init data
local frameMoonfire = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init data
    local abilityActive = false
    local nMoonfireInstantDmg, nMoonfireDotDmg, nMoonfireDotDuration, nMoonfireDotDps = 0, 0, 0, 0

    -- Init trait
    local nGalacticGuardian = 0
    local nTwinMoonfireAoeCap = 2

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_Prowl
            or (wan.auraData.player.buff_CatForm and not wan.traitData.LunarInspiration.known)
            or not wan.IsSpellUsable(wan.spellData.Moonfire.id)
        then
            wan.UpdateAbilityData(wan.spellData.Moonfire.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Moonfire.id)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.Moonfire.basename)
            return
        end

        -- Dot value
        local cMoonfireInstantDmg = nMoonfireInstantDmg * ((wan.auraData.player.buff_GalacticGuardian and nGalacticGuardian) or 1)
        local dotPotency = wan.CheckDotPotency(cMoonfireInstantDmg)
        local cMoonfireDotDmg = (not wan.auraData[wan.TargetUnitID].debuff_Moonfire and (nMoonfireDotDmg * dotPotency)) or 0

        -- Base value
        local cMoonfireDmg = cMoonfireInstantDmg + cMoonfireDotDmg

        -- Twin Moonfire or Twin Moons
        if (wan.traitData.TwinMoonfire.known or wan.traitData.TwinMoons.known) and countValidUnit > 1 then
            local nTwinMoonfireInstantDmg = cMoonfireInstantDmg * math.min(countValidUnit, nTwinMoonfireAoeCap)
            local dotPotencyAoE = wan.CheckDotPotencyAoE(wan.auraData, idValidUnit, wan.spellData.Moonfire.name, nil, nTwinMoonfireInstantDmg)
            local unitMoonfireDebuffedAoE = wan.CheckForDebuffAoE(wan.auraData, idValidUnit, wan.spellData.Moonfire.name)
            local cTwinMoonfireRakeDotDmg = (unitMoonfireDebuffedAoE < countValidUnit and nMoonfireDotDmg * dotPotencyAoE) or 0
            if unitMoonfireDebuffedAoE > 0 and not wan.auraData[wan.TargetUnitID].debuff_Moonfire then cTwinMoonfireRakeDotDmg = 0 end
            local cTwinMoonfireDmg = cMoonfireInstantDmg + cTwinMoonfireRakeDotDmg
            cMoonfireDmg = cMoonfireDmg + cTwinMoonfireDmg
        end

        -- Crit layer
        cMoonfireDmg = cMoonfireDmg * wan.ValueFromCritical(wan.CritChance)

        -- Update ability data
        local abilityValue = math.floor(cMoonfireDmg)
        wan.UpdateAbilityData(wan.spellData.Moonfire.basename, abilityValue, wan.spellData.Moonfire.icon, wan.spellData.Moonfire.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            local moonfireValues = wan.GetSpellDescriptionNumbers(wan.spellData.Moonfire.id, { 1, 2, 3 })
            nMoonfireInstantDmg = moonfireValues[1]
            nMoonfireDotDmg = moonfireValues[2]
            nMoonfireDotDuration = moonfireValues[3]
            nMoonfireDotDps = moonfireValues[2] / moonfireValues[3]
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Moonfire.known and wan.spellData.Moonfire.id
            wan.BlizzardEventHandler(frameMoonfire, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
            wan.SetUpdateRate(frameMoonfire, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then 
            nGalacticGuardian = wan.GetTraitDescriptionNumbers(wan.traitData.GalacticGuardian.entryid, {3}) / 100
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameMoonfire, CheckAbilityValue, abilityActive)
        end
    end)
end

frameMoonfire:RegisterEvent("ADDON_LOADED")
frameMoonfire:SetScript("OnEvent", OnEvent)