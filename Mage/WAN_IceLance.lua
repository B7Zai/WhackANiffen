local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nIceLanceDmg, nIceLanceShatter = 0, 3
local sFrozenDebuffs = {}

-- Init trait data
local nOverflowingEnergy = 0
local nMasteryIciclesDmg = 0
local nShatterMultiplier, nShatter = 0, 0
local nPiercingCold = 0
local nSplittingIce, nSplittingIceUnitCap = 0, 1
local nExcessFireDmg, nExcessFireSoftCap = 0, 0
local nArcaneSplinterDmg, nArcaneSplinterDotDmg = 0, 0
local nControlledInstincts, nControlledInstinctsSoftCap = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.IceLance.id)
    then
        wan.UpdateAbilityData(wan.spellData.IceLance.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.IceLance.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.IceLance.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critChanceModBase = 0
    local critDamageMod = 0
    local critDamageModBase = 0

    local cIceLanceInstantDmg = 0
    local cIceLanceDotDmg = 0
    local cIceLanceInstantDmgAoE = 0
    local cIceLanceDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cIcelanceShatter = 1
    local isFrozen = false
    for _, debuff in pairs(sFrozenDebuffs) do
        local checkID = debuff == wan.traitData.FreezingCold.traitkey and 386770 or nil
        local checkFrozenDebuff = wan.CheckUnitDebuff(nil, debuff, checkID)
        if checkFrozenDebuff then
            cIcelanceShatter = nIceLanceShatter
            isFrozen = true
            break
        end
    end

    ---- CLASS TRAITS ----

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
    end

    local cMasteryIciclesInstantDmg = 0
    local cMasteryIciclesInstantDmgAoE = 0
    if wan.spellData.MasteryIcicles.known and not wan.traitData.GlacialSpike.known then
        local checkIciclesBuff = wan.CheckUnitBuff(nil, "Icicles")

        if checkIciclesBuff then
            local nIciclesStacks = checkIciclesBuff.applications > 0 and checkIciclesBuff.applications or 1
            cMasteryIciclesInstantDmg = cMasteryIciclesInstantDmg + (nMasteryIciclesDmg * nIciclesStacks)

            if wan.traitData.SplittingIce.known then
                local countSplittingIceUnit = 0

                for _, nameplateGUID in pairs(idValidUnit) do

                    if nameplateGUID ~= targetGUID then

                        cMasteryIciclesInstantDmgAoE = cMasteryIciclesInstantDmgAoE + (nMasteryIciclesDmg * nSplittingIce * nIciclesStacks)
        
                        countSplittingIceUnit = countSplittingIceUnit + 1
        
                        if countSplittingIceUnit >= nSplittingIceUnitCap then break end
                    end
                end
            end
        end
    end

    ---- FROST TRAITS ----

    local checkFingersofFrost = false
    if wan.traitData.FingersofFrost.known then
        local checkFingersofFrostBuff = wan.CheckUnitBuff(nil, wan.traitData.FingersofFrost.traitkey)
        if checkFingersofFrostBuff then
            cIcelanceShatter = nIceLanceShatter
            checkFingersofFrost = true
        end
    end

    if wan.traitData.Shatter.known then
        for _, debuff in pairs(sFrozenDebuffs) do
            local checkID = debuff == wan.traitData.FreezingCold.traitkey and 386770 or nil
            local checkFrozenDebuff = wan.CheckUnitDebuff(nil, debuff, checkID)
            if checkFrozenDebuff or checkFingersofFrost then
                critChanceMod = critChanceMod + ((wan.CritChance * nShatterMultiplier) + nShatter)
                break
            end
        end

        if wan.traitData.SplittingIce.known then
            local frozenUnitCap = 1 + nSplittingIceUnitCap
            local countSplittingIceUnit = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
                
                if nameplateGUID ~= targetGUID then

                    for _, debuff in pairs(sFrozenDebuffs) do
                        local checkID = debuff == wan.traitData.FreezingCold.traitkey and 386770 or nil
                        local checkFrozenDebuff = wan.CheckUnitDebuff(nameplateUnitToken, debuff, checkID)
                        if checkFrozenDebuff or checkFingersofFrost then
                            critChanceMod = critChanceMod + ((wan.CritChance * nShatterMultiplier) + nShatter)
                        end
                    end

                    countSplittingIceUnit = countSplittingIceUnit + 1
                            
                    if countSplittingIceUnit >= nSplittingIceUnitCap then break end
                end
            end

            critChanceMod = critChanceMod / frozenUnitCap
        end
    end

    local cPiercingCold = 1
    if wan.traitData.PiercingCold.known then
        cPiercingCold = cPiercingCold + nPiercingCold
    end

    local cSplittingIceInstantDmgAoE = 0
    if wan.traitData.SplittingIce.known then
        local countSplittingIceUnit = 0
        local cIceLanceShatterAoE = 1
        local isFrozenSplittingIce = false

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                for _, debuff in pairs(sFrozenDebuffs) do
                    local checkID = debuff == wan.traitData.FreezingCold.traitkey and 386770 or nil
                    local checkFrozenDebuff = wan.CheckUnitDebuff(nameplateUnitToken, debuff, checkID)
                    if checkFrozenDebuff or checkFingersofFrost then
                        cIceLanceShatterAoE = nIceLanceShatter
                        isFrozenSplittingIce = true
                        break
                    end
                end

                cSplittingIceInstantDmgAoE = cSplittingIceInstantDmgAoE + (nIceLanceDmg * nSplittingIce * cIceLanceShatterAoE)

                countSplittingIceUnit = countSplittingIceUnit + 1

                if countSplittingIceUnit >= nSplittingIceUnitCap then break end
            end
        end
    end

    ---- FROSTFIRE TRAITS ----

    local cExcessFireInstantDmgAoE = 0
    if wan.traitData.ExcessFire.known then
        local checkExcessFireBuff = wan.CheckUnitBuff(nil, wan.traitData.ExcessFire.traitkey)
        if checkExcessFireBuff then
            local cExcessFireUnitOverflow = wan.AdjustSoftCapUnitOverflow(nExcessFireSoftCap, countValidUnit)
            cExcessFireInstantDmgAoE = cExcessFireInstantDmgAoE + (nExcessFireDmg * cExcessFireUnitOverflow)
        end
    end

    ---- SPELLSLINGER TRAITS ----

    local cArcaneSplinterInstantDmg = 0
    local cArcaneSplinterDotDmg = 0
    local cControlledInstinctsInstantDmgAoE = 0
    if wan.traitData.SplinteringSorcery.known then
        local checkWintersChill = wan.CheckUnitDebuff(nil, "WintersChill")
        if checkWintersChill or checkFingersofFrost then
            cArcaneSplinterInstantDmg = cArcaneSplinterInstantDmg + nArcaneSplinterDmg

            local dotPotency = wan.CheckDotPotency(nIceLanceDmg, targetUnitToken)
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

    local cIceLanceCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cIceLanceCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cIceLanceInstantDmg = cIceLanceInstantDmg
        + (nIceLanceDmg * cIcelanceShatter * cIceLanceCritValue)
        + (cMasteryIciclesInstantDmg * cIceLanceCritValue * cPiercingCold)
        + (cArcaneSplinterInstantDmg * cIceLanceCritValueBase)

    cIceLanceDotDmg = cIceLanceDotDmg
        + (cArcaneSplinterDotDmg * cIceLanceCritValueBase)

    cIceLanceInstantDmgAoE = cIceLanceInstantDmgAoE
        + (cSplittingIceInstantDmgAoE * cIceLanceCritValue)
        + (cMasteryIciclesInstantDmgAoE * cIceLanceCritValue * cPiercingCold)
        + (cExcessFireInstantDmgAoE * cIceLanceCritValueBase)
        + (cControlledInstinctsInstantDmgAoE * cIceLanceCritValueBase)

    cIceLanceDotDmgAoE = cIceLanceDotDmgAoE

    local cIceLanceDmg = cIceLanceInstantDmg + cIceLanceDotDmg + cIceLanceInstantDmgAoE + cIceLanceDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cIceLanceDmg)
    wan.UpdateAbilityData(wan.spellData.IceLance.basename, abilityValue, wan.spellData.IceLance.icon, wan.spellData.IceLance.name)
end

-- Init frame 
local frameIceLance = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nIceLanceDmg = wan.GetSpellDescriptionNumbers(wan.spellData.IceLance.id, { 1 })

            nMasteryIciclesDmg = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryIcicles.id, { 1 })

            local nExcessFireValues = wan.GetTraitDescriptionNumbers(wan.traitData.ExcessFire.entryid, { 1, 2 })
            nExcessFireDmg = nExcessFireValues[1]
            nExcessFireSoftCap = nExcessFireValues[2]

            local nSplinteringSorceryValues = wan.GetTraitDescriptionNumbers(wan.traitData.SplinteringSorcery.entryid, { 3, 4 })
            nArcaneSplinterDmg = nSplinteringSorceryValues[1]
            nArcaneSplinterDotDmg = nSplinteringSorceryValues[2]
        end
    end)
end
frameIceLance:RegisterEvent("ADDON_LOADED")
frameIceLance:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.IceLance.known and wan.spellData.IceLance.id
        wan.BlizzardEventHandler(frameIceLance, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameIceLance, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        sFrozenDebuffs = {
            "WintersChill",
            wan.traitData.Frostbite.traitkey,
            wan.traitData.IceLance.traitkey,
            wan.spellData.FrostNova.formattedName,
            wan.traitData.FreezingCold.traitkey,
            wan.traitData.IceNova.traitkey,
            "Freeze"
        }

        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        local nShatterValues = wan.GetTraitDescriptionNumbers(wan.traitData.Shatter.entryid, { 1, 2 })
        nShatterMultiplier = nShatterValues[1]
        nShatter = nShatterValues[2]

        nPiercingCold = wan.GetTraitDescriptionNumbers(wan.traitData.PiercingCold.entryid, { 1 }) * 0.01

        nSplittingIce = wan.GetTraitDescriptionNumbers(wan.traitData.SplittingIce.entryid, { 2 }) * 0.01

        local nControlledInstinctsValues = wan.GetTraitDescriptionNumbers(wan.traitData.ControlledInstincts.entryid, { 2, 3 })
        nControlledInstincts = nControlledInstinctsValues[1] * 0.01
        nControlledInstinctsSoftCap = nControlledInstinctsValues[2]
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameIceLance, CheckAbilityValue, abilityActive)
    end
end)