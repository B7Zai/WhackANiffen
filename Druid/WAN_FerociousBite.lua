local _, wan = ...

-- Init data
local frameFerociousBite = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init spell data
    local abilityActive = false
    local nFerociousBiteDmg, nFerociousBiteDmgAoE = 0, 0
    local nFerociousBiteCost, nFerociousBiteFullCost = 0, 0
    local checkCombo, currentCombo, comboPercentage, comboMax = 0, 0, 0, 0
    local checkEnergy, currentEnergy = 0, 0

    -- Init trait data
    local nRampantFerocity, nRampantFerocitySoftCap = 0, 0
    local nSaberJaws = 0
    local nDreadfulWound = 0
    local nBurstingGrowth, nBurstingGrowthSoftCap = 0, 0

    -- Ability value calculation
    local function CheckAbilityValue()
        if not wan.PlayerState.Status or not wan.auraData.player.buff_CatForm 
        or wan.auraData.player.buff_Prowl or not wan.IsSpellUsable(wan.spellData.FerociousBite.id)
        then wan.UpdateAbilityData(wan.spellData.FerociousBite.basename) return end -- Early exits

        local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.FerociousBite.id)
        if not isValidUnit then wan.UpdateAbilityData(wan.spellData.FerociousBite.basename) return end -- Check for valid unit

        currentCombo = math.max(checkCombo, ((wan.auraData.player.buff_ApexPredatorsCraving and comboMax) or 0))
        comboPercentage = (currentCombo / comboMax) * 100
        if comboPercentage < 80 then wan.UpdateAbilityData(wan.spellData.FerociousBite.basename) return end -- Combo checkers and early exit

        checkEnergy = UnitPower("player", 3) or 0
        currentEnergy = math.max(checkEnergy, ((wan.auraData.player.buff_ApexPredatorsCraving and nFerociousBiteFullCost) or 0))
        local energyMod = math.min(currentEnergy, nFerociousBiteFullCost)
        local bonusDmgPerEnergy = ((nFerociousBiteFullCost / nFerociousBiteCost) * energyMod) / (nFerociousBiteFullCost * 2)
        local bonusDmgFromEnergy = nFerociousBiteDmg * currentCombo * bonusDmgPerEnergy -- Energy and damage value scaling with energy

        local bFerociousBiteDesat = false
        if currentEnergy < nFerociousBiteFullCost then bFerociousBiteDesat = true end -- Set icon desaturation below full cost

        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(wan.classificationData)
        local checkPhysicalDRAoE = wan.CheckUnitPhysicalDamageReductionAoE(wan.classificationData, wan.spellData.FerociousBite.id)

        local cFerociousBiteDmg = ((nFerociousBiteDmg * currentCombo) + bonusDmgFromEnergy) * checkPhysicalDR -- Base value

        if wan.traitData.RampantFerocity.known and countValidUnit > 1 then -- Rampant Ferocity
            local ripDebuffedUnitAoE = wan.CheckForDebuffAoE(wan.auraData, idValidUnit, wan.spellData.Rip.name)
            if wan.auraData[wan.TargetUnitID].debuff_Rip then ripDebuffedUnitAoE = ripDebuffedUnitAoE - 1 end

            local validUnitSoftCappedAoE = wan.AdjustSoftCapUnitOverFlow(nRampantFerocitySoftCap, ripDebuffedUnitAoE)
            local cRampantFerocityDmg = nRampantFerocity * currentCombo * bonusDmgPerEnergy * validUnitSoftCappedAoE * checkPhysicalDRAoE
            cFerociousBiteDmg = cFerociousBiteDmg + cRampantFerocityDmg
        end

        if wan.traitData.SaberJaws.rank > 0 then -- Saber Jaws
            local cSaberJawsDmg = bonusDmgFromEnergy * nSaberJaws * checkPhysicalDR

            cFerociousBiteDmg = cFerociousBiteDmg + cSaberJawsDmg
        end

        if wan.traitData.Ravage.known and wan.auraData.player.buff_Ravage and countValidUnit > 1 then --Ravage AoE
            local ravageUnitAoE = countValidUnit - 1
            local cleaveRavageDmg = nFerociousBiteDmgAoE * ravageUnitAoE * checkPhysicalDRAoE

            cFerociousBiteDmg = cFerociousBiteDmg + cleaveRavageDmg
        end

        if wan.traitData.DreadfulWound.known and wan.auraData.player.buff_Ravage then -- Dreadful Wound
            local cDreadfulWoundDmg = nDreadfulWound * countValidUnit

            cFerociousBiteDmg = cFerociousBiteDmg + cDreadfulWoundDmg
        end

        if wan.traitData.BurstingGrowth.known and wan.auraData[wan.TargetUnitID].debuff_BloodseekerVines
        and countValidUnit > 1 then -- Bursting Growth
            local burstingGrowthUnitAoE = countValidUnit - 1
            local validUnitSoftCappedAoE = wan.AdjustSoftCapUnitOverFlow(nBurstingGrowthSoftCap, burstingGrowthUnitAoE)
            local cBurstingGrowthDmg = nBurstingGrowth * validUnitSoftCappedAoE * checkPhysicalDRAoE

            cFerociousBiteDmg = cFerociousBiteDmg + cBurstingGrowthDmg
        end

        cFerociousBiteDmg = cFerociousBiteDmg * wan.ValueFromCritical(wan.CritChance) -- Crit Mod

        local abilityValue = math.floor(cFerociousBiteDmg) -- Update AbilityData
        if abilityValue == 0 then wan.UpdateAbilityData(wan.spellData.FerociousBite.basename) return end
        wan.UpdateAbilityData(wan.spellData.FerociousBite.basename, abilityValue, wan.spellData.FerociousBite.icon, wan.spellData.FerociousBite.name, bFerociousBiteDesat)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)

        if event == "SPELLS_CHANGED" then
            comboMax = UnitPowerMax("player", 4) or 5
            checkCombo = UnitPower("player", 4) or 0
            comboPercentage = (currentCombo / comboMax) * 100
        end

        if event == "UNIT_POWER_UPDATE" then
            local unitID, powerType = ...
            if unitID == "player" and powerType == "COMBO_POINTS" then
                checkCombo = UnitPower("player", 4) or 0
                currentCombo = math.max(checkCombo)
                comboPercentage = (currentCombo / comboMax) * 100
            end
        end

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED"  then
            local ferociousBiteValues = wan.GetSpellDescriptionNumbers(wan.spellData.FerociousBite.id, { 4, 5 })
            nFerociousBiteDmg = ferociousBiteValues[1]
            nFerociousBiteDmgAoE = ferociousBiteValues[2]

            nFerociousBiteCost = wan.GetSpellCost(wan.spellData.FerociousBite.id, 3) or 1
            if nFerociousBiteCost == 0 then nFerociousBiteCost = 1 end
            nFerociousBiteFullCost =  nFerociousBiteCost * 2

            nRampantFerocity = wan.GetSpellDescriptionNumbers(wan.traitData.RampantFerocity.id, { 1 })

            nDreadfulWound = wan.GetSpellDescriptionNumbers(wan.traitData.DreadfulWound.id, { 1 })

            local burstingGrowthValues = wan.GetSpellDescriptionNumbers(wan.traitData.BurstingGrowth.id, { 1, 2 })
            nBurstingGrowth = burstingGrowthValues[1]
            nBurstingGrowthSoftCap = burstingGrowthValues[2]

        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
        
        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.FerociousBite.known and wan.spellData.FerociousBite.id
            wan.BlizzardEventHandler(frameFerociousBite, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "UNIT_POWER_UPDATE")
            wan.SetUpdateRate(frameFerociousBite, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then
            nRampantFerocitySoftCap = wan.GetSpellDescriptionNumbers(wan.traitData.RampantFerocity.id, { 3 })
            nSaberJaws = (wan.GetSpellDescriptionNumbers(wan.traitData.SaberJaws.id, { 1 }) * wan.traitData.SaberJaws.rank) / 100
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameFerociousBite, CheckAbilityValue, abilityActive)
        end
    end)
end

frameFerociousBite:RegisterEvent("ADDON_LOADED")
frameFerociousBite:SetScript("OnEvent", OnEvent)