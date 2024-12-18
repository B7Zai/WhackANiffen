local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame
local frameRake = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nRakeInstantDmg, nRakeDotDmg, nRakeDotDuration, nRakeDotDps = 0, 0, 0, 0

    -- Init trait
    local nPouncingStrikes = 0
    local nDoubleClawedRakeAoeCap = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or not wan.auraData.player.buff_CatForm
            or not wan.IsSpellUsable(wan.spellData.Rake.id)
        then
            wan.UpdateAbilityData(wan.spellData.Rake.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Rake.id)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.Rake.basename)
            return
        end

        -- Dot value
        local dotPotency = wan.CheckDotPotency(nRakeInstantDmg)
        local cRakeDotDmg = (not wan.auraData[wan.TargetUnitID].debuff_Rake and (nRakeDotDmg * dotPotency)) or 0

        -- Base values
        local cRakeDmg = nRakeInstantDmg + cRakeDotDmg

        -- Double-Clawed Rake
        if wan.traitData.DoubleClawedRake.known and countValidUnit > 1 then
            local nDoubleClawedInstantDmg = nRakeInstantDmg * math.min(countValidUnit, nDoubleClawedRakeAoeCap)
            local dotPotencyAoE = wan.CheckDotPotencyAoE(wan.auraData, idValidUnit, wan.spellData.Rake.name, nil,
                nDoubleClawedInstantDmg)
            local rakeDebuffedUnitAoE = wan.CheckForDebuffAoE(wan.auraData, idValidUnit, wan.spellData.Rake.name)
            local cDoubleClawedRakeDotDmg = (rakeDebuffedUnitAoE < countValidUnit and nRakeDotDmg * dotPotencyAoE) or 0
            if rakeDebuffedUnitAoE > 0 and not wan.auraData[wan.TargetUnitID].debuff_Rake then cDoubleClawedRakeDotDmg = 0 end
            local cDoubleClawedRakeDmg = nRakeInstantDmg + cDoubleClawedRakeDotDmg
            cRakeDmg = cRakeDmg + cDoubleClawedRakeDmg
        end

        -- Pouncing Strikes
        if wan.auraData.player.buff_SuddenAmbush or
            (wan.traitData.PouncingStrikes.known and wan.auraData.player.buff_Prowl) then
            local cPouncingStrikes = cRakeDmg * nPouncingStrikes
            cRakeDmg = cRakeDmg + cPouncingStrikes
        end

        -- Crit value
        cRakeDmg = cRakeDmg * wan.ValueFromCritical(wan.CritChance)

        -- Update ability data
        local abilityValue = math.floor(cRakeDmg)
        wan.UpdateAbilityData(wan.spellData.Rake.basename, abilityValue, wan.spellData.Rake.icon, wan.spellData.Rake.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local rakeValues = wan.GetSpellDescriptionNumbers(wan.spellData.Rake.id, { 1, 2, 3 })
            nRakeInstantDmg = rakeValues[1]
            nRakeDotDmg = rakeValues[2]
            nRakeDotDuration = rakeValues[3]
            nRakeDotDps = rakeValues[2] / rakeValues[3]
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Rake.known and wan.spellData.Rake.id
            wan.BlizzardEventHandler(frameRake, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameRake, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then
            nPouncingStrikes = wan.GetTraitDescriptionNumbers(wan.traitData.PouncingStrikes.entryid, { 3 }) / 100
            nDoubleClawedRakeAoeCap = wan.GetTraitDescriptionNumbers(wan.traitData.DoubleClawedRake.entryid, { 1 }) + 1
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameRake, CheckAbilityValue, abilityActive)
        end
    end)
end

frameRake:RegisterEvent("ADDON_LOADED")
frameRake:SetScript("OnEvent", AddonLoad)