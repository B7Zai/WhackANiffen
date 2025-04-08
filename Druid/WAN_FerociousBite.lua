local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

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
local nMasterShapeshifter, nMasterShapeshifterCombo = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or not wan.CheckUnitBuff(nil, wan.spellData.CatForm.formattedName)
        or wan.auraData.player.buff_Prowl
        or not wan.IsSpellUsable(wan.spellData.FerociousBite.id)
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
    if wan.traitData.MasterShapeshifter.known and currentCombo ~= nMasterShapeshifterCombo or comboPercentage < 80 then
        wan.UpdateAbilityData(wan.spellData.FerociousBite.basename)
        return
    end

    -- Base value
    local cFerociousBiteInstantDmg = nFerociousBiteDmg * currentCombo
    local cFerociousBiteDotDmg = 0

    -- Energy and damage value scaling with energy
    checkEnergy = UnitPower("player", 3) or 0
    currentEnergy = math.max(checkEnergy, ((wan.auraData.player.buff_ApexPredatorsCraving and nFerociousBiteFullCost) or 0))
    local energyMod = math.min(currentEnergy, nFerociousBiteFullCost)
    local bonusDmgPerEnergy = ((nFerociousBiteFullCost / nFerociousBiteCost) * energyMod) / (nFerociousBiteFullCost * 2)
    local bonusDmgFromEnergy = nFerociousBiteDmg * currentCombo * bonusDmgPerEnergy

    local cFerociousBiteInstantDmgAoE = 0
    local cFerociousBiteDotDmgAoE = 0
    if countValidUnit > 1 then
        local nRampantFerocityUnitOverflow = wan.SoftCapOverflow(nRampantFerocitySoftCap, countValidUnit)
        local cBurstingGrowthUnitOverflow = wan.SoftCapOverflow(nBurstingGrowthSoftCap, countValidUnit)

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
            local cRampantFerocityDmg = 0
            local cRavageAoE = 0
            local cBurstingGrowthDmg = 0
            local targetGUID = wan.UnitState.GUID[wan.TargetUnitID]

            if nameplateGUID ~= targetGUID then
                local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                -- add Rampant Ferocity trait layer
                if wan.traitData.RampantFerocity.known then
                    local checkRipDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. wan.spellData.Rip.basename]
                    if checkRipDebuff then
                        local cRampantFerocityBonusDamageFromEnergy = nRampantFerocity * bonusDmgPerEnergy
                        cRampantFerocityDmg = (nRampantFerocity + cRampantFerocityBonusDamageFromEnergy) * currentCombo * nRampantFerocityUnitOverflow * checkUnitPhysicalDR
                    end
                end

                -- add Ravage trait layer
                if wan.traitData.Ravage.known and wan.auraData.player.buff_Ravage then
                    cRavageAoE = nFerociousBiteDmgAoE * currentCombo * checkUnitPhysicalDR
                end

                -- add Bursting Growth trait layer
                if wan.traitData.BurstingGrowth.known and wan.auraData[wan.TargetUnitID].debuff_BloodseekerVines then
                    cBurstingGrowthDmg = nBurstingGrowth * checkUnitPhysicalDR * cBurstingGrowthUnitOverflow
                end
            end

            -- add Dreadful Wound trait layer
            local cDreadfulWoundDmg = 0
            if wan.traitData.DreadfulWound.known and wan.auraData.player.buff_Ravage then
                local checkDreadfulWoundDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. wan.traitData.DreadfulWound.traitkey]
                if not checkDreadfulWoundDebuff then
                    local checkDotPotency = wan.CheckDotPotency(cFerociousBiteInstantDmg, nameplateUnitToken)
                    cDreadfulWoundDmg = nDreadfulWound * checkDotPotency
                end
            end

            cFerociousBiteInstantDmgAoE = cFerociousBiteInstantDmgAoE + (cRampantFerocityDmg + cRavageAoE + cBurstingGrowthDmg)
            cFerociousBiteDotDmgAoE = cFerociousBiteDotDmgAoE + cDreadfulWoundDmg
        end
    end

    -- Saber Jaws
    if wan.traitData.SaberJaws.rank > 0 then
        bonusDmgFromEnergy = bonusDmgFromEnergy * (1 + nSaberJaws)
    end

    -- Master Shapeshifter
    local cMasterShapeshifter = 1
    if wan.traitData.MasterShapeshifter.known and currentCombo == nMasterShapeshifterCombo then
        cMasterShapeshifter = cMasterShapeshifter + nMasterShapeshifter
    end

    -- add physical layer
    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()

    -- Crit layer
    local cFerociousBiteCritValue = wan.ValueFromCritical(wan.CritChance)

    cFerociousBiteInstantDmg = (cFerociousBiteInstantDmg + bonusDmgFromEnergy) * checkPhysicalDR * cMasterShapeshifter * cFerociousBiteCritValue
    cFerociousBiteDotDmg = cFerociousBiteDotDmg * cMasterShapeshifter * cFerociousBiteCritValue
    cFerociousBiteInstantDmgAoE = cFerociousBiteInstantDmgAoE * cMasterShapeshifter * cFerociousBiteCritValue
    cFerociousBiteDotDmgAoE = cFerociousBiteDotDmgAoE * cMasterShapeshifter * cFerociousBiteCritValue

    local cFerociousBiteDmg = cFerociousBiteInstantDmg + cFerociousBiteDotDmg + cFerociousBiteInstantDmgAoE + cFerociousBiteDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cFerociousBiteDmg)

    -- Set icon desaturation below full cost
    local bFerociousBiteDesat = currentEnergy < nFerociousBiteFullCost and true or false
    wan.UpdateAbilityData(wan.spellData.FerociousBite.basename, abilityValue, wan.spellData.FerociousBite.icon, wan.spellData.FerociousBite.name, bFerociousBiteDesat)
end

-- Init frame 
local frameFerociousBite = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

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
end
frameFerociousBite:RegisterEvent("ADDON_LOADED")
frameFerociousBite:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.FerociousBite.known and wan.spellData.FerociousBite.id
        wan.BlizzardEventHandler(frameFerociousBite, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "UNIT_POWER_UPDATE", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFerociousBite, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nRampantFerocitySoftCap = wan.GetTraitDescriptionNumbers(wan.traitData.RampantFerocity.entryid, { 3 })

        nSaberJaws = wan.GetTraitDescriptionNumbers(wan.traitData.SaberJaws.entryid, { 1 }, wan.traitData.SaberJaws.rank) * 0.01

        local nMasterShapeshifterValues = wan.GetTraitDescriptionNumbers(wan.traitData.MasterShapeshifter.entryid, { 9, 11 })
        nMasterShapeshifter = nMasterShapeshifterValues[1] * 0.01
        nMasterShapeshifterCombo = nMasterShapeshifterValues[2]
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFerociousBite, CheckAbilityValue, abilityActive)
    end
end)
