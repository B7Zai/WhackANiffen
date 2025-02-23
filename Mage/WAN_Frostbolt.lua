local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nFrostboltDmg, nFrostboltDotDmg = 0, 0

-- Init trait data
local nOverflowingEnergy = 0
local nMasteryIgnite = 0
local nFirestarterThreshold = 0
local nPyrotechnics = 0
local nImprovedScorch = 0
local nMasterofFlame = 0
local nWildfireCritDmg, nWildfireCombustionCritDmg = 0, 0
local nFiresIre = 0
local nMoltenFuryThreshold, nMoltenFury = 0, 0
local nMeteorDmg, nMeteorDotDmg = 0, 0 -- this for firefall talent
local nIsothermicCoreMeteor, nIsothermicCoreCometStorm, nCometStormDmg = 0, 0, 0
local nFrostfireEmpowerment, nFrostfireEmpowermentAoE = 0, 0
local nShatterMultiplier, nShatter, sFrozenDebuffs = 0, 0, {}
local nMasteryIciclesDmg, nMasteryIciclesCap = 0, 0
local nPiercingCold, nPiercingColdIcicleCritDamage = 0, 0
local nDeepShatter = 0
local nSplinteringColdProcChance = 0
local nFracturedFrostUnitCap, nFracturedFrost = 0, 0
local nSplittingIce, nSplittingIceUnitCap = 0, 1
local nArcaneSplinterDmg, nArcaneSplinterDotDmg = 0, 0
local nControlledInstincts, nControlledInstinctsSoftCap = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or (wan.spellData.ArcaneBlast.known and wan.IsSpellUsable(wan.spellData.ArcaneBlast.id))
        or not wan.IsSpellUsable(wan.spellData.Frostbolt.id)
    then
        wan.UpdateAbilityData(wan.spellData.Frostbolt.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Frostbolt.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Frostbolt.basename)
        return
    end

    local canMovecast = (wan.auraData.player.buff_IceFloes and true) or false
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Frostbolt.id, wan.spellData.Frostbolt.castTime, canMovecast)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(wan.spellData.Frostbolt.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critChanceModBase = 0
    local critDamageMod = 0
    local critDamageModBase = 0

    local cFrostboltInstantDmg = 0
    local cFrostboltDotDmg = 0
    local cFrostboltInstantDmgAoE = 0
    local cFrostboltDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- CLASS TRAITS ----

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
    end

    local cMasteryIgnite = 0
    if wan.spellData.MasteryIgnite.known then
        local dotPotency = wan.CheckDotPotency(nFrostboltDmg, targetUnitToken)

        cMasteryIgnite = cMasteryIgnite + (nMasteryIgnite * dotPotency)
    end

    local cMasteryIciclesInstantDmg = 0
    local cMasteryIciclesInstantDmgAoE = 0
    local cPiercingCold = 1
    if wan.spellData.MasteryIcicles.known then
        local checkIciclesBuff = wan.CheckUnitBuff(nil, "Icicles")
        if checkIciclesBuff and checkIciclesBuff.applications == nMasteryIciclesCap then
            cMasteryIciclesInstantDmg = cMasteryIciclesInstantDmg + nMasteryIciclesDmg

            if wan.traitData.SplinteringCold.known then
                cMasteryIciclesInstantDmg = cMasteryIciclesInstantDmg + (nMasteryIciclesDmg * nSplinteringColdProcChance)
            end

            if wan.traitData.SplittingIce.known then
                local countSplittingIceUnit = 0

                for _, nameplateGUID in pairs(idValidUnit) do

                    if nameplateGUID ~= targetGUID then

                        cMasteryIciclesInstantDmgAoE = cMasteryIciclesInstantDmgAoE + (nMasteryIciclesDmg * nSplittingIce)
        
                        countSplittingIceUnit = countSplittingIceUnit + 1
        
                        if countSplittingIceUnit >= nSplittingIceUnitCap then break end
                    end
                end
            end
        end

        if wan.traitData.PiercingCold.known then
            cPiercingCold = cPiercingCold + nPiercingColdIcicleCritDamage
        end
    end

    ---- FIRE TRAITS ----

    if wan.traitData.Firestarter.known then
        local checkPercentageHealth = targetGUID and UnitPercentHealthFromGUID(targetGUID) or 1
        if checkPercentageHealth > nFirestarterThreshold then
            critChanceMod = critChanceMod + 100
        end
    end

    if wan.traitData.Pyrotechnics.known then
        local checkPyrotechnicsBuff = wan.CheckUnitBuff(nil, wan.traitData.Pyrotechnics.traitkey)
        local checkPyrotechnicsStacks = checkPyrotechnicsBuff and checkPyrotechnicsBuff.applications

        if checkPyrotechnicsStacks == 0 then
            checkPyrotechnicsStacks = 1
        end

        if checkPyrotechnicsBuff then
            critChanceMod = critChanceMod + (nPyrotechnics * checkPyrotechnicsStacks)
        end
    end

    local cImprovedScorch = 1
    if wan.traitData.ImprovedScorch.known then
        local checkImprovedScorchDebuff = wan.CheckUnitDebuff(nil, wan.traitData.ImprovedScorch.traitkey)
        local checkImprovedScorchStacks = checkImprovedScorchDebuff and checkImprovedScorchDebuff.applications

        if checkImprovedScorchStacks == 0 then
            checkImprovedScorchStacks = 1
        end

        if checkImprovedScorchDebuff then
            cImprovedScorch = cImprovedScorch + (nImprovedScorch * checkImprovedScorchStacks)
        end
    end

    if wan.traitData.Combustion.known then
        local checkCombustionBuff = wan.CheckUnitBuff(nil, wan.spellData.Combustion.formattedName)
        if checkCombustionBuff then
            critChanceMod = critChanceMod + 100

            if wan.traitData.FiresIre.known then
                critChanceMod = critChanceMod + nFiresIre
            end
        end
    end

    local cMasterofFlame = 1
    if wan.traitData.MasterofFlame.known then
        local checkCombustionBuff = wan.CheckUnitBuff(nil, wan.spellData.Combustion.formattedName)
        if not checkCombustionBuff then
            cMasterofFlame = cMasterofFlame + nMasterofFlame
        end
    end

    if wan.traitData.Wildfire.known then
        critDamageMod = critDamageMod + nWildfireCritDmg
        local checkCombustionBuff = wan.CheckUnitBuff(nil, wan.spellData.Combustion.formattedName)
        if checkCombustionBuff then
            critDamageMod = critDamageMod + nWildfireCombustionCritDmg

            critDamageModBase = critDamageModBase + nWildfireCombustionCritDmg
        end
    end

    local cMoltenFury = 1
    if wan.traitData.MoltenFury.known then
        local checkPercentageHealth = targetGUID and UnitPercentHealthFromGUID(targetGUID) or 1
        if checkPercentageHealth < nMoltenFuryThreshold then
            cMoltenFury = cMoltenFury + nMoltenFury
        end
    end

    local cFirefallInstantDmgAoE = 0
    local cFirefallDotDmgAoE = 0
    local cIsothermicCoreInstantDmgAoE = 0
    if wan.traitData.Firefall.known then
        local checkFirefallBuff = wan.CheckUnitBuff(nil, wan.traitData.Firefall.traitkey)
        if checkFirefallBuff and checkFirefallBuff.spellId == 384038 then
            cFirefallInstantDmgAoE = cFirefallInstantDmgAoE + (nMeteorDmg * countValidUnit)

            for nameplateUnitToken, _ in pairs(idValidUnit) do
                local dotPotency = wan.CheckDotPotency(nMeteorDmg, nameplateUnitToken)

                cFirefallDotDmgAoE = cFirefallDotDmgAoE + (nMeteorDotDmg * dotPotency)
            end

            if wan.traitData.IsothermicCore.known then
                cIsothermicCoreInstantDmgAoE = cIsothermicCoreInstantDmgAoE + (nCometStormDmg * nIsothermicCoreCometStorm * countValidUnit)
            end
        end
    end

    ---- FROST TRAITS ----

    local isFrozen = false
    local nSecondaryFrozenUnits = 0
    local countShatterFracturedFrostUnit = 0
    if wan.traitData.Shatter.known then
        for _, debuff in pairs(sFrozenDebuffs) do
            local checkID = debuff == wan.traitData.FreezingCold.traitkey and 386770 or nil
            local checkFrozenDebuff = wan.CheckUnitDebuff(nil, debuff, checkID)
            if checkFrozenDebuff then
                critChanceMod = critChanceMod + ((wan.CritChance * nShatterMultiplier) + nShatter)
                isFrozen = true
                break
            end
        end

        if wan.traitData.FracturedFrost.known then
            local frozenUnitCap = 1 + nFracturedFrostUnitCap
            local checkIcyVeinsBuff = wan.CheckUnitBuff(nil, wan.spellData.IcyVeins.formattedName)

            if checkIcyVeinsBuff then

                for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                    if nameplateGUID ~= targetGUID then

                        for _, debuff in pairs(sFrozenDebuffs) do
                            local checkID = debuff == wan.traitData.FreezingCold.traitkey and 386770 or nil
                            local checkFrozenDebuff = wan.CheckUnitDebuff(nameplateUnitToken, debuff, checkID)
                            if checkFrozenDebuff then
                                critChanceMod = critChanceMod + ((wan.CritChance * nShatterMultiplier) + nShatter)
                                nSecondaryFrozenUnits = nSecondaryFrozenUnits + 1
                            end
                        end

                        countShatterFracturedFrostUnit = countShatterFracturedFrostUnit + 1

                        if countShatterFracturedFrostUnit >= nFracturedFrostUnitCap then break end
                    end
                end

                critChanceMod = critChanceMod / frozenUnitCap
            end
        end
    end

    if wan.traitData.PiercingCold.known then
        critDamageMod = critDamageMod + nPiercingCold
    end

    local cDeepShatter = 1
    local cDeepShatterAoE = 1
    if wan.traitData.DeepShatter.known then
        if isFrozen then
            cDeepShatter = cDeepShatter + nDeepShatter
        end

        if wan.traitData.FracturedFrost.known and nSecondaryFrozenUnits > 0 then
            cDeepShatterAoE = cDeepShatterAoE + (nDeepShatter * (nSecondaryFrozenUnits / countShatterFracturedFrostUnit))
        end
    end

    local cFracturedFrost = 1
    local cFracturedFrostIntantDmgAoE = 0
    if wan.traitData.FracturedFrost.known then
        local countFracturedFrostUnit = 0
        local checkIcyVeinsBuff = wan.CheckUnitBuff(nil, wan.spellData.IcyVeins.formattedName)

        if checkIcyVeinsBuff then
            cFracturedFrost = cFracturedFrost + nFracturedFrost

            for _, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then

                    cFracturedFrostIntantDmgAoE = cFracturedFrostIntantDmgAoE + (nFrostboltDmg * cFracturedFrost)

                    countFracturedFrostUnit = countFracturedFrostUnit + 1

                    if countShatterFracturedFrostUnit >= nFracturedFrostUnitCap then break end
                end
            end
        end
    end

    ---- FROSTFIRE TRAITS ----

    local cFrostfireBoltDotDmg = 0
    local cFrostfireBoltDotDmgAoE = 0
    if wan.traitData.FrostfireBolt.known then
        local dotPotency = wan.CheckDotPotency(nFrostboltDmg, targetUnitToken)

        cFrostfireBoltDotDmg = cFrostfireBoltDotDmg + (nFrostboltDotDmg * dotPotency)

        if wan.traitData.FracturedFrost.known then
            local countFracturedFrostUnit = 0
            local checkIcyVeinsBuff = wan.CheckUnitBuff(nil, wan.spellData.IcyVeins.formattedName)

            if checkIcyVeinsBuff then

                for _, nameplateGUID in pairs(idValidUnit) do

                    if nameplateGUID ~= targetGUID then
                        local unitDotPotency = wan.CheckDotPotency(nFrostboltDmg, targetUnitToken)

                        cFrostfireBoltDotDmgAoE = cFrostfireBoltDotDmgAoE + (nFrostboltDotDmg * unitDotPotency)

                        countFracturedFrostUnit = countFracturedFrostUnit + 1

                        if countShatterFracturedFrostUnit >= nFracturedFrostUnitCap then break end
                    end
                end
            end
        end
    end

    local cFrostfireEmpowerment = 1
    local cFrostfireEmpowermentInstantDmgAoE = 0
    if wan.traitData.FrostfireEmpowerment.known then
        local checkFrostfireEmpowermentBuff = wan.CheckUnitBuff(nil, wan.traitData.FrostfireEmpowerment.traitkey)
        if checkFrostfireEmpowermentBuff then
            cFrostfireEmpowerment = cFrostfireEmpowerment + nFrostfireEmpowerment

            cFrostfireEmpowermentInstantDmgAoE = cFrostfireEmpowermentInstantDmgAoE + (nFrostboltDmg * nFrostfireEmpowermentAoE * countValidUnit)

            critChanceMod = critChanceMod + 100
        end
    end

    ---- SPELLSLINGER TRAITS ----

    local cArcaneSplinterInstantDmg = 0
    local cArcaneSplinterDotDmg = 0
    local cControlledInstinctsInstantDmgAoE = 0
    if wan.traitData.SplinteringSorcery.known then
        local checkWintersChill = wan.CheckUnitDebuff(nil, "WintersChill")
        if checkWintersChill then
            cArcaneSplinterInstantDmg = cArcaneSplinterInstantDmg + nArcaneSplinterDmg

            local dotPotency = wan.CheckDotPotency(nFrostboltDmg, targetUnitToken)
            cArcaneSplinterDotDmg = cArcaneSplinterDotDmg + (nArcaneSplinterDotDmg * dotPotency)
        end

        if wan.traitData.ControlledInstincts.known then
            local checkBlizzardDebuff = wan.CheckUnitDebuff(nil, wan.spellData.Blizzard.formattedName)
            if checkBlizzardDebuff then
                local countControlledInstinctsUnit = math.max(countValidUnit - 1, 0)
                local cControlledInstinctsUnit = wan.AdjustSoftCapUnitOverflow(nControlledInstinctsSoftCap, countControlledInstinctsUnit)
                cControlledInstinctsInstantDmgAoE = cControlledInstinctsInstantDmgAoE + (nArcaneSplinterDmg * nControlledInstincts * cControlledInstinctsUnit)
            end
        end
    end

    local cFrostboltCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cFrostboltCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cFrostboltInstantDmg = cFrostboltInstantDmg
        + (nFrostboltDmg * cImprovedScorch * cMoltenFury * cFrostfireEmpowerment * cFrostboltCritValue * cDeepShatter * cFracturedFrost)
        + (cMasteryIciclesInstantDmg * cFrostboltCritValue * cPiercingCold)
        + (cArcaneSplinterInstantDmg * cFrostboltCritValue)

    cFrostboltDotDmg = cFrostboltDotDmg
        + (nFrostboltDmg * cImprovedScorch * cMasteryIgnite * cMasterofFlame * cMoltenFury * cFrostfireEmpowerment * cFrostboltCritValue) -- Ignite
        + (cFrostfireBoltDotDmg * cImprovedScorch * cMoltenFury * cFrostfireEmpowerment * cFrostboltCritValueBase)
        + (cArcaneSplinterDotDmg * cFrostboltCritValueBase)

    cFrostboltInstantDmgAoE = cFrostboltInstantDmgAoE
        + (cFirefallInstantDmgAoE * cFrostboltCritValueBase)
        + (cIsothermicCoreInstantDmgAoE * cFrostboltCritValueBase)
        + (cFrostfireEmpowermentInstantDmgAoE * cImprovedScorch * cMoltenFury * cFrostfireEmpowerment * cFrostboltCritValue * cDeepShatter)
        + (cFracturedFrostIntantDmgAoE * cFrostboltCritValue * cDeepShatterAoE)
        + (cMasteryIciclesInstantDmgAoE * cFrostboltCritValueBase * cPiercingCold)
        + (cControlledInstinctsInstantDmgAoE * cFrostboltCritValueBase)

    cFrostboltDotDmgAoE = cFrostboltDotDmgAoE
        + (cFirefallDotDmgAoE * cFrostboltCritValueBase)
        + (cFirefallInstantDmgAoE * cMasteryIgnite * cFrostboltCritValueBase) -- Ignite

    local cFrostboltDmg = (cFrostboltInstantDmg + cFrostboltDotDmg + cFrostboltInstantDmgAoE + cFrostboltDotDmgAoE) * castEfficiency

    -- Update ability data
    local abilityValue = math.floor(cFrostboltDmg)
    wan.UpdateAbilityData(wan.spellData.Frostbolt.basename, abilityValue, wan.spellData.Frostbolt.icon, wan.spellData.Frostbolt.name)
end

-- Init frame 
local frameFrostbolt = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nFrostboltValues = wan.GetSpellDescriptionNumbers(wan.spellData.Frostbolt.id, { 1, 3 })
            nFrostboltDmg = nFrostboltValues[1]
            nFrostboltDotDmg = wan.traitData.FrostfireBolt.known and nFrostboltValues[2] or 0

            nMasteryIgnite = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryIgnite.id, { 1 }) * 0.01

            local nMeteorValues = wan.GetSpellDescriptionNumbers(wan.spellData.Meteor.id, { 2, 4 })
            nMeteorDmg = nMeteorValues[1]
            nMeteorDotDmg = nMeteorValues[2]

            nCometStormDmg = wan.GetSpellDescriptionNumbers(wan.spellData.CometStorm.id, { 2 })

            local nMasteryIciclesValues = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryIcicles.id, { 1, 2 })
            nMasteryIciclesDmg = nMasteryIciclesValues[1]
            nMasteryIciclesCap= nMasteryIciclesValues[2]

            local nSplinteringSorceryValues = wan.GetTraitDescriptionNumbers(wan.traitData.SplinteringSorcery.entryid, { 3, 4 })
            nArcaneSplinterDmg = nSplinteringSorceryValues[1]
            nArcaneSplinterDotDmg = nSplinteringSorceryValues[2]
        end
    end)
end
frameFrostbolt:RegisterEvent("ADDON_LOADED")
frameFrostbolt:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Frostbolt.known and wan.spellData.Frostbolt.id
        wan.BlizzardEventHandler(frameFrostbolt, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFrostbolt, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        sFrozenDebuffs = {
            "WintersChill",
            wan.traitData.Frostbite.traitkey,
            wan.traitData.GlacialSpike.traitkey,
            wan.spellData.FrostNova.formattedName,
            wan.traitData.FreezingCold.traitkey,
            wan.traitData.IceNova.traitkey,
            "Freeze"
        }

        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        nFirestarterThreshold = wan.GetTraitDescriptionNumbers(wan.traitData.Firestarter.entryid, { 1 }) * 0.01

        nPyrotechnics = wan.GetTraitDescriptionNumbers(wan.traitData.Pyrotechnics.entryid, { 1 })

        nImprovedScorch = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedScorch.entryid, { 2 }) * 0.01

        local nWildfireValues = wan.GetTraitDescriptionNumbers(wan.traitData.Wildfire.entryid, { 1, 2 })
        nWildfireCritDmg = nWildfireValues[1]
        nWildfireCombustionCritDmg = nWildfireValues[2]

        nFiresIre = wan.GetTraitDescriptionNumbers(wan.traitData.FiresIre.entryid, { 2 }, wan.traitData.FiresIre.rank)

        local nMoltenFuryValues = wan.GetTraitDescriptionNumbers(wan.traitData.MoltenFury.entryid, { 1, 2 })
        nMoltenFuryThreshold = nMoltenFuryValues[1] * 0.01
        nMoltenFury = nMoltenFuryValues[2] * 0.01

        local nIsothermicCoreValues = wan.GetTraitDescriptionNumbers(wan.traitData.IsothermicCore.entryid, { 1, 2 })
        nIsothermicCoreMeteor = nIsothermicCoreValues[1] * 0.01
        nIsothermicCoreCometStorm = nIsothermicCoreValues[2] * 0.01

        local nFrostfireEmpowermentValues = wan.GetTraitDescriptionNumbers(wan.traitData.FrostfireEmpowerment.entryid, { 1, 2 })
        nFrostfireEmpowerment = nFrostfireEmpowermentValues[1] * 0.01
        nFrostfireEmpowermentAoE = nFrostfireEmpowermentValues[2] * 0.01

        local nShatterValues = wan.GetTraitDescriptionNumbers(wan.traitData.Shatter.entryid, { 1, 2 })
        nShatterMultiplier = nShatterValues[1]
        nShatter = nShatterValues[2]

        nPiercingCold = wan.GetTraitDescriptionNumbers(wan.traitData.PiercingCold.entryid, { 1 })
        nPiercingColdIcicleCritDamage = nPiercingCold * 0.01
        
        nDeepShatter = wan.GetTraitDescriptionNumbers(wan.traitData.DeepShatter.entryid, { 1 }, wan.traitData.DeepShatter.rank) * 0.01

        nSplinteringColdProcChance = wan.GetTraitDescriptionNumbers(wan.traitData.SplinteringCold.entryid, { 1 }, wan.traitData.SplinteringCold.rank) * 0.01

        local nFracturedFrostValues = wan.GetTraitDescriptionNumbers(wan.traitData.FracturedFrost.entryid, { 1, 2 })
        nFracturedFrostUnitCap = nFracturedFrostValues[1]
        nFracturedFrost = nFracturedFrostValues[2] * 0.01

        nSplittingIce = wan.GetTraitDescriptionNumbers(wan.traitData.SplittingIce.entryid, { 2 }) * 0.01

        local nControlledInstinctsValues = wan.GetTraitDescriptionNumbers(wan.traitData.ControlledInstincts.entryid, { 2, 3 })
        nControlledInstincts = nControlledInstinctsValues[1] * 0.01
        nControlledInstinctsSoftCap = nControlledInstinctsValues[2]
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFrostbolt, CheckAbilityValue, abilityActive)
    end
end)