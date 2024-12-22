local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameSwipe = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end
    
    -- Init spell data
    local abilityActive = false
    local checkDebuffs = { "Rake", "Thrash", "Rip", "Feral Frenzy", "Tear", "Frenzied Assault" }
    local nSwipeDmg, nSoftCap = 0, 0
    local nThrashDotDmg, nThrashMaxStacks = 0, 0

    -- Init trait data
    local nStrikeForTheHeart = 0
    local nMercilessClaws = 0


    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Swipe.id)
        then
            wan.UpdateAbilityData(wan.spellData.Swipe.basename)
            return
        end

        -- Check for valid unit
        local _, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.Swipe.maxRange)
        if countValidUnit == 0 then
            wan.UpdateAbilityData(wan.spellData.Swipe.basename)
            return
        end

        -- Base values
        local critChanceMod = 0
        local critDamageMod = 0

        local cSwipeInstantDmg = 0
        local cSwipeDotDmg = 0

        for unitToken, _ in pairs (idValidUnit) do
            local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(unitToken)

            -- Merciless Claws
            local cMercilessClaws = 1
            if wan.traitData.MercilessClaws.known then
                local checkDebuff = wan.CheckForAnyDebuff(wan.auraData, checkDebuffs, unitToken)
                cMercilessClaws = 1 + ((checkDebuff and nMercilessClaws) or 0)
            end

            -- Thrashing Claws
            local cThrashingClaws = 0
            if wan.traitData.ThrashingClaws.known then
                local checkDebuff = wan.auraData[unitToken]["debuff_" .. wan.spellData.Thrash.basename]
                if not checkDebuff then
                    local dotPotency = wan.CheckDotPotency(nSwipeDmg, unitToken)
                    cThrashingClaws = nThrashDotDmg * dotPotency
                end
            end

            cSwipeInstantDmg = cSwipeInstantDmg + (nSwipeDmg * checkPhysicalDR * cMercilessClaws)
            cSwipeDotDmg = cSwipeDotDmg + cThrashingClaws
        end 

        -- Strike for the Heart
        if wan.traitData.StrikefortheHeart.known then
            critChanceMod = critChanceMod + nStrikeForTheHeart
            critDamageMod = critDamageMod + nStrikeForTheHeart
        end

        local unitOverflow = wan.SoftCapOverflow(nSoftCap, countValidUnit)

        -- Crit layer
        local cSwipeInstantCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
        local cSwipeDotCritValue = wan.ValueFromCritical(wan.CritChance)

        cSwipeInstantDmg = cSwipeInstantDmg * cSwipeInstantCritValue * unitOverflow
        cSwipeDotDmg = cSwipeDotDmg * cSwipeDotCritValue

        local cSwipeDmg = cSwipeInstantDmg + cSwipeDotDmg

        -- Update ability data
        local abilityValue = math.floor(cSwipeDmg)
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

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
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
            wan.BlizzardEventHandler(frameSwipe, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameSwipe, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then
            nMercilessClaws = wan.GetTraitDescriptionNumbers(wan.traitData.MercilessClaws.entryid, { 2 }) / 100
            nStrikeForTheHeart = wan.GetTraitDescriptionNumbers(wan.traitData.StrikefortheHeart.entryid, { 1 })
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameSwipe, CheckAbilityValue, abilityActive)
        end
    end)
end

frameSwipe:RegisterEvent("ADDON_LOADED")
frameSwipe:SetScript("OnEvent", AddonLoad)