local _, wan = ...

-- Init data
local frameSwipe = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end
    
    -- Init spell data
    local abilityActive = false
    local checkDebuffs = { "Rake", "Thrash", "Rip", "Feral Frenzy", "Tear", "Frenzied Assault" }
    local nSwipeDmg, nMercilessClaws, nThrashDotDmg, nThrashMaxStacks, nSoftCap = 0, 0, 0, 0, 0

    -- Ability value calculation
    local function CheckAbilityValue()
        if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Swipe.id) 
        then wan.UpdateAbilityData(wan.spellData.Swipe.basename) return end -- Early exits

        local _, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.Swipe.maxRange)
        if countValidUnit == 0 then wan.UpdateAbilityData(wan.spellData.Swipe.basename) return end -- Check for valid unit

        local softCappedValidUnit = wan.AdjustSoftCapUnitOverFlow(nSoftCap, countValidUnit) -- Adjust unit overflow to soft cap
        local checkPhysicalDRAoE = wan.CheckUnitPhysicalDamageReductionAoE(wan.classificationData, nil, wan.spellData.Swipe.maxRange) -- Physical DR
        local cSwipeDmg = nSwipeDmg * softCappedValidUnit * checkPhysicalDRAoE -- Base values

        if wan.traitData.MercilessClaws.known then -- Merciless Claws
            local countDebuffed = wan.CheckForAnyDebuffAoE(wan.auraData, checkDebuffs, idValidUnit)
            local cMercilessClaws = nSwipeDmg * nMercilessClaws * countDebuffed * checkPhysicalDRAoE
            cSwipeDmg = cSwipeDmg + cMercilessClaws
        end

        if wan.traitData.ThrashingClaws.known then -- Thrashing Claws
            local countThrashDebuff = wan.CheckForDebuffAoE(wan.auraData, idValidUnit, wan.spellData.Thrash.name, nThrashMaxStacks)
            local dotPotencyAoE = wan.CheckDotPotencyAoE(wan.auraData, idValidUnit, wan.spellData.Thrash.name, nThrashMaxStacks, cSwipeDmg)
            local cThrashingClaws = nThrashDotDmg * (countValidUnit - countThrashDebuff) * dotPotencyAoE
            cSwipeDmg = cSwipeDmg + cThrashingClaws
        end

        cSwipeDmg = cSwipeDmg * wan.ValueFromCritical(wan.CritChance) -- Crit Mod

        local abilityValue = math.floor(cSwipeDmg) -- Update AbilityData
        if abilityValue == 0 then wan.UpdateAbilityData(wan.spellData.Swipe.basename) return end
        wan.UpdateAbilityData(wan.spellData.Swipe.basename, abilityValue, wan.spellData.Swipe.icon, wan.spellData.Swipe.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)

        if event == "SPELLS_CHANGED" then
            if not wan.traitData.BrutalSlash.known then
                nSoftCap = wan.GetSpellDescriptionNumbers(wan.spellData.Swipe.id, { 2 })
            elseif wan.traitData.BrutalSlash.known and wan.traitData.MercilessClaws.known then
                nSoftCap = wan.GetSpellDescriptionNumbers(wan.spellData.Swipe.id, { 3 })
            elseif wan.traitData.BrutalSlash.known and not wan.traitData.MercilessClaws.known then
                nSoftCap = wan.GetSpellDescriptionNumbers(wan.spellData.Swipe.id, { 2 })
            end
        end

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" then
            nSwipeDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Swipe.id, { 1 })
            local thrashValues = wan.GetSpellDescriptionNumbers(wan.spellData.Thrash.id, { 2, 4 })
            nThrashDotDmg = thrashValues[1]
            if wan.auraData.player and wan.auraData.player.buff_BearForm then
                nThrashMaxStacks = thrashValues[2]
            else
                nThrashMaxStacks = 1
            end
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)


        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Swipe.known and wan.spellData.Swipe.id
            wan.BlizzardEventHandler(frameSwipe, abilityActive, "SPELLS_CHANGED", "UNIT_AURA")
            wan.SetUpdateRate(frameSwipe, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then
            nMercilessClaws = wan.GetSpellDescriptionNumbers(wan.traitData.MercilessClaws.id, { 2 }) / 100
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameSwipe, CheckAbilityValue, abilityActive)
        end
    end)
end

frameSwipe:RegisterEvent("ADDON_LOADED")
frameSwipe:SetScript("OnEvent", OnEvent)