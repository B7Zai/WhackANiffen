local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameFerociousBite = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

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
        -- Early exits
        if not wan.PlayerState.Status or not wan.auraData.player.buff_CatForm
            or wan.auraData.player.buff_Prowl or not wan.IsSpellUsable(wan.spellData.FerociousBite.id)
        then
            wan.UpdateAbilityData(wan.spellData.FerociousBite.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.FerociousBite.id)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.FerociousBite.basename)
            return
        end

        -- Combo checkers and early exit
        currentCombo = math.max(checkCombo, ((wan.auraData.player.buff_ApexPredatorsCraving and comboMax) or 0))
        comboPercentage = (currentCombo / comboMax) * 100
        if comboPercentage < 80 then
            wan.UpdateAbilityData(wan.spellData.FerociousBite.basename)
            return
        end

        -- Energy and damage value scaling with energy
        checkEnergy = UnitPower("player", 3) or 0
        currentEnergy = math.max(checkEnergy, ((wan.auraData.player.buff_ApexPredatorsCraving and nFerociousBiteFullCost) or 0))
        local energyMod = math.min(currentEnergy, nFerociousBiteFullCost)
        local bonusDmgPerEnergy = ((nFerociousBiteFullCost / nFerociousBiteCost) * energyMod) / (nFerociousBiteFullCost * 2)
        local bonusDmgFromEnergy = nFerociousBiteDmg * currentCombo * bonusDmgPerEnergy

        -- Set icon desaturation below full cost
        local bFerociousBiteDesat = false
        if currentEnergy < nFerociousBiteFullCost then bFerociousBiteDesat = true end

        -- Remove physical layer
        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(wan.classificationData)
        local checkPhysicalDRAoE = wan.CheckUnitPhysicalDamageReductionAoE(wan.classificationData, wan.spellData.FerociousBite.id)
        local cFerociousBiteDmg = ((nFerociousBiteDmg * currentCombo) + bonusDmgFromEnergy) * checkPhysicalDR                                                                                       -- Base value

        -- Rampant Ferocity
        if wan.traitData.RampantFerocity.known and countValidUnit > 1 then
            local ripDebuffedUnitAoE = wan.CheckForDebuffAoE(wan.auraData, idValidUnit, wan.spellData.Rip.name)

            if wan.auraData[wan.TargetUnitID].debuff_Rip then ripDebuffedUnitAoE = ripDebuffedUnitAoE - 1 end

            local validUnitSoftCappedAoE = wan.AdjustSoftCapUnitOverflow(nRampantFerocitySoftCap, ripDebuffedUnitAoE)
            local cRampantFerocityDmg = nRampantFerocity * currentCombo * bonusDmgPerEnergy * validUnitSoftCappedAoE * checkPhysicalDRAoE
            cFerociousBiteDmg = cFerociousBiteDmg + cRampantFerocityDmg
        end

         -- Saber Jaws
        if wan.traitData.SaberJaws.rank > 0 then
            local cSaberJawsDmg = bonusDmgFromEnergy * nSaberJaws * checkPhysicalDR

            cFerociousBiteDmg = cFerociousBiteDmg + cSaberJawsDmg
        end

        --Ravage AoE
        if wan.traitData.Ravage.known and wan.auraData.player.buff_Ravage and countValidUnit > 1 then
            local ravageUnitAoE = countValidUnit - 1
            local cleaveRavageDmg = nFerociousBiteDmgAoE * ravageUnitAoE * checkPhysicalDRAoE

            cFerociousBiteDmg = cFerociousBiteDmg + cleaveRavageDmg
        end

        -- Dreadful Wound
        if wan.traitData.DreadfulWound.known and wan.auraData.player.buff_Ravage then
            local cDreadfulWoundDmg = nDreadfulWound * countValidUnit

            cFerociousBiteDmg = cFerociousBiteDmg + cDreadfulWoundDmg
        end

        -- Bursting Growth
        if wan.traitData.BurstingGrowth.known and wan.auraData[wan.TargetUnitID].debuff_BloodseekerVines
            and countValidUnit > 1 then
            local burstingGrowthUnitAoE = countValidUnit - 1
            local validUnitSoftCappedAoE = wan.AdjustSoftCapUnitOverflow(nBurstingGrowthSoftCap, burstingGrowthUnitAoE)
            local cBurstingGrowthDmg = nBurstingGrowth * validUnitSoftCappedAoE * checkPhysicalDRAoE

            cFerociousBiteDmg = cFerociousBiteDmg + cBurstingGrowthDmg
        end

        -- Crit layer
        cFerociousBiteDmg = cFerociousBiteDmg * wan.ValueFromCritical(wan.CritChance)

        -- Update ability data
        local abilityValue = math.floor(cFerociousBiteDmg)
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

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local ferociousBiteValues = wan.GetSpellDescriptionNumbers(wan.spellData.FerociousBite.id, { 4, 5 })
            nFerociousBiteDmg = ferociousBiteValues[1]
            nFerociousBiteDmgAoE = ferociousBiteValues[2]

            nFerociousBiteCost = wan.GetSpellCost(wan.spellData.FerociousBite.id, 3) or 1
            if nFerociousBiteCost == 0 then nFerociousBiteCost = 1 end
            nFerociousBiteFullCost =  nFerociousBiteCost * 2

            nRampantFerocity = wan.GetSpellDescriptionNumbers(wan.traitData.RampantFerocity.id, { 1 })

            nDreadfulWound = wan.GetSpellDescriptionNumbers(wan.traitData.DreadfulWound.id, { 1 })

            local burstingGrowthValues = wan.GetTraitDescriptionNumbers(wan.traitData.BurstingGrowth.entryid, { 1, 2 })
            nBurstingGrowth = burstingGrowthValues[1]
            nBurstingGrowthSoftCap = burstingGrowthValues[2]

        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
        
        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.FerociousBite.known and wan.spellData.FerociousBite.id
            wan.BlizzardEventHandler(frameFerociousBite, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "UNIT_POWER_UPDATE", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameFerociousBite, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then
            nRampantFerocitySoftCap = wan.GetTraitDescriptionNumbers(wan.traitData.RampantFerocity.entryid, { 3 })
            nSaberJaws = wan.GetTraitDescriptionNumbers(wan.traitData.SaberJaws.entryid, { 1 }, wan.traitData.SaberJaws.rank) / 100
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameFerociousBite, CheckAbilityValue, abilityActive)
        end
    end)
end

frameFerociousBite:RegisterEvent("ADDON_LOADED")
frameFerociousBite:SetScript("OnEvent", AddonLoad)