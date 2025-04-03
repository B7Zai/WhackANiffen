local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init spell data
local abilityActive = false
local nThrowGlaiveDmg, nThrowGlaiveUnitCap = 0, 1

-- Init trait data
local bBouncingGlaives, nBouncingGlaivesHitCount = false, 0
local bAcceleratedBlade, nAcceleratedBladeMainTarget, nAcceleratedBladeSecondaryTarget = false,  0, 0
local bFuriousThrows = false
local bSerratedGlaive, sSerratedGlaive, nSerratedGlaive = false, "SerratedGlaive", 0
local bBurningWound, sBurningWoundDebuff, nBurningWoundDotDmg, nBurningWoundUnitCap = false, "BurningWound", 0, 0
local bSoulscar, sSoulscarDebuff, nSoulscar = false, "Soulscar", 0
local bKnowYourEnemy, nKnowYourEnemy = false, 0

local bFieryDemise, sFieryDemise, nFieryDemise = false, "FieryBrand", 0
local sFrailty = "Frailty"
local bVulnerability, nVulnerability = false, 0

local sFuryoftheAldrachiBuff, sRendingFuryBuff = "GlaiveFlurry", "RendingFury"
local bReaversMark, sReaversMark, nReaversMark = false, "ReaversMark", 0
local bWoundedQuarry, nWoundedQuarry = false, 0
local bPreemptiveStrike, nPreemptiveStrikeDmg = false, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or not wan.IsSpellUsable(wan.spellData.ThrowGlaive.id)
        or (bFuriousThrows and not wan.IsSpellUsable(wan.spellData.ChaosStrike.id))
        or (wan.spellData.ThrowGlaive.name == "Reaver's Glaive" and not wan.IsSpellUsable(wan.spellData.BladeDance.id))
        or wan.CheckUnitBuff(nil, sFuryoftheAldrachiBuff)
        or wan.CheckUnitBuff(nil, sRendingFuryBuff)
    then
        wan.UpdateAbilityData(wan.spellData.ThrowGlaive.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.ThrowGlaive.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ThrowGlaive.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cThrowGlaiveInstantDmg = 0
    local cThrowGlaiveDotDmg = 0
    local cThrowGlaiveInstantDmgAoE = 0
    local cThrowGlaiveDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cThrowGlaiveInstantDmgBaseAoE = 0
    local countThrowGlaiveUnits = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

        cThrowGlaiveInstantDmgBaseAoE = cThrowGlaiveInstantDmgBaseAoE + (nThrowGlaiveDmg * checkUnitPhysicalDR)

        countThrowGlaiveUnits = countThrowGlaiveUnits + 1

        if countThrowGlaiveUnits >= nThrowGlaiveUnitCap then break end
    end

    ---- HAVOC TRAITS ----

    local cAcceleratedBlade = 1
    if bAcceleratedBlade then
        cAcceleratedBlade = cAcceleratedBlade + (nAcceleratedBladeMainTarget / countThrowGlaiveUnits)

        if countValidUnit > 1 then
            cAcceleratedBlade = cAcceleratedBlade + (nAcceleratedBladeSecondaryTarget / countThrowGlaiveUnits)
        end
    end

    local cFuriousThrowsInstantDmgAoE = 0
    if bFuriousThrows and wan.spellData.ThrowGlaive.name ~= "Reaver's Glaive" then
        local countFuriousThrowsUnits = 0
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

            cFuriousThrowsInstantDmgAoE = cFuriousThrowsInstantDmgAoE + (nThrowGlaiveDmg * checkUnitPhysicalDR)

            countFuriousThrowsUnits = countFuriousThrowsUnits + 1

            if countFuriousThrowsUnits >= nThrowGlaiveUnitCap then break end
        end
    end

    local cSerratedGlaiveAoE = 1
    if bSerratedGlaive then

        local countSerratedGlaiveUnits = 0
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitSerratedGlaiveDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sSerratedGlaive)

            if checkUnitSerratedGlaiveDebuff then
                cSerratedGlaiveAoE = cSerratedGlaiveAoE + (nSerratedGlaive / countThrowGlaiveUnits)
            end

            countSerratedGlaiveUnits = countSerratedGlaiveUnits + 1

            if countSerratedGlaiveUnits >= nThrowGlaiveUnitCap then break end
        end
    end

    local cBurningWoundDotDmgAoE = 0
    if bBurningWound then

        local countBurningWoundDebuff = 0
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitBurningWoundDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sBurningWoundDebuff)
            if checkUnitBurningWoundDebuff then
                countBurningWoundDebuff = countBurningWoundDebuff + 1

                if countBurningWoundDebuff >= nBurningWoundUnitCap then
                    break
                end
            end
        end

        if countBurningWoundDebuff < nBurningWoundUnitCap then
            local countBurningWoundUnits = 0

            for nameplateUnitToken, _ in pairs(idValidUnit) do
                local checkUnitBurningWoundDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sBurningWoundDebuff)

                if not checkUnitBurningWoundDebuff then
                    local checkDotPotency = wan.CheckDotPotency(nThrowGlaiveDmg, nameplateUnitToken)

                    cBurningWoundDotDmgAoE = cBurningWoundDotDmgAoE + (nBurningWoundDotDmg * checkDotPotency)
                end

                countBurningWoundUnits = countBurningWoundUnits + 1

                if countBurningWoundUnits >= nThrowGlaiveUnitCap then break end
            end
        end
    end

    local cSoulscarDotDmgAoE = 0
    if bSoulscar then
        local countSoulscarUnits = 0
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkSoulscarDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sSoulscarDebuff)

            if not checkSoulscarDebuff then
                local checkDotPotency = wan.CheckDotPotency(nThrowGlaiveDmg, nameplateUnitToken)
                local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                cSoulscarDotDmgAoE = cSoulscarDotDmgAoE + (nThrowGlaiveDmg * checkUnitPhysicalDR * nSoulscar * checkDotPotency)
            end

            countSoulscarUnits = countSoulscarUnits + 1

            if countSoulscarUnits >= nThrowGlaiveUnitCap then break end
        end
    end

    if bKnowYourEnemy then
        critDamageMod = critDamageMod + (wan.CritChance * nKnowYourEnemy)
        critDamageModBase = critDamageModBase + (wan.CritChance * nKnowYourEnemy)
    end

    ---- VENGEANCE TRAITS ----

    local cFieryDemiseAoE = 1
    if bFieryDemise then
        local countFieryDemiseUnits = 0

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitFieryBrandDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sFieryDemise)
            if checkUnitFieryBrandDebuff then

                cFieryDemiseAoE = cFieryDemiseAoE + (nFieryDemise / countThrowGlaiveUnits)
            end

            countFieryDemiseUnits = countFieryDemiseUnits + 1

            if countFieryDemiseUnits >= nThrowGlaiveUnitCap then
                break
            end
        end
    end

    local cVulnerabilityAoE = 1
    if bVulnerability then
        local countVulnerabilityUnits = 0

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitFrailtyDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sFrailty)
            if checkUnitFrailtyDebuff then
                local nFrailtyStacks = checkUnitFrailtyDebuff and checkUnitFrailtyDebuff.applications

                if nFrailtyStacks and nFrailtyStacks == 0 then nFrailtyStacks = 1 end

                cVulnerabilityAoE = cVulnerabilityAoE + ((nVulnerability * nFrailtyStacks) / countThrowGlaiveUnits)
            end

            countVulnerabilityUnits = countVulnerabilityUnits + 1

            if countVulnerabilityUnits >= nThrowGlaiveUnitCap then
                break
            end
        end
    end

    ---- ALDRACHI REAVER TRAITS ----

    local cReaversMarkMinusWoundedQuarry = 1
    local cReaversMarkAoE = 1
    if bReaversMark then

        local countReaversMarkUnits = 0

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitReaversMarkDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sReaversMark)

            if checkUnitReaversMarkDebuff then
                local cReaversMarkStacks = checkUnitReaversMarkDebuff and checkUnitReaversMarkDebuff.applications

                if not cReaversMarkStacks or cReaversMarkStacks == 0 then
                    cReaversMarkStacks = 1
                end

                local cWoundedQuarry = 0
                if bWoundedQuarry then
                    cWoundedQuarry = cWoundedQuarry + (nWoundedQuarry)
                end

                cReaversMarkMinusWoundedQuarry = cReaversMarkMinusWoundedQuarry + ((nReaversMark * cReaversMarkStacks) / countThrowGlaiveUnits)
                cReaversMarkAoE = cReaversMarkAoE + (((nReaversMark * cReaversMarkStacks) + cWoundedQuarry) / countThrowGlaiveUnits)
            end

            countReaversMarkUnits = countReaversMarkUnits + 1

            if countReaversMarkUnits >= nThrowGlaiveUnitCap then break end
        end
    end

    local cPreemptiveStrike = 0
    if bPreemptiveStrike then

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                cPreemptiveStrike = cPreemptiveStrike + (nPreemptiveStrikeDmg * checkUnitPhysicalDR)
            end
        end
    end

    ---- FEL-SCARRED TRAITS ----

    local cThrowGlaiveCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cThrowGlaiveCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cThrowGlaiveInstantDmg = cThrowGlaiveInstantDmg

    cThrowGlaiveDotDmg = cThrowGlaiveDotDmg

    cThrowGlaiveInstantDmgAoE = cThrowGlaiveInstantDmgAoE
        + (cThrowGlaiveInstantDmgBaseAoE * cThrowGlaiveCritValue * cAcceleratedBlade * cSerratedGlaiveAoE * cReaversMarkAoE * cVulnerabilityAoE)
        + (cFuriousThrowsInstantDmgAoE * cThrowGlaiveCritValue * cAcceleratedBlade * cSerratedGlaiveAoE * cReaversMarkAoE)
        + (cPreemptiveStrike * cThrowGlaiveCritValueBase)

    cThrowGlaiveDotDmgAoE = cThrowGlaiveDotDmgAoE
        + (cBurningWoundDotDmgAoE * cThrowGlaiveCritValueBase * cFieryDemiseAoE)
        + (cSoulscarDotDmgAoE * cThrowGlaiveCritValue * cAcceleratedBlade * cSerratedGlaiveAoE * cReaversMarkMinusWoundedQuarry)

    local cThrowGlaiveDmg = cThrowGlaiveInstantDmg + cThrowGlaiveDotDmg + cThrowGlaiveInstantDmgAoE + cThrowGlaiveDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cThrowGlaiveDmg)
    wan.UpdateAbilityData(wan.spellData.ThrowGlaive.basename, abilityValue, wan.spellData.ThrowGlaive.icon, wan.spellData.ThrowGlaive.name)
end

-- Init frame 
local frameThrowGlaive = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nThrowGlaiveValues = wan.GetSpellDescriptionNumbers(wan.spellData.ThrowGlaive.id, { 1, 2 })
            nThrowGlaiveDmg = nThrowGlaiveValues[1]
            nThrowGlaiveUnitCap = 1 + ((bBouncingGlaives or wan.spellData.ThrowGlaive.name == "Reaver's Glaive") and nThrowGlaiveValues[2] or 1)

            nPreemptiveStrikeDmg = wan.GetTraitDescriptionNumbers(wan.traitData.PreemptiveStrike.entryid, { 1 }, wan.traitData.PreemptiveStrike.rank)
        end
    end)
end
frameThrowGlaive:RegisterEvent("ADDON_LOADED")
frameThrowGlaive:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = not wan.spellData.ThrowGlaive.isPassive and wan.spellData.ThrowGlaive.known and wan.spellData.ThrowGlaive.id
        wan.BlizzardEventHandler(frameThrowGlaive, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameThrowGlaive, CheckAbilityValue, abilityActive)

        sFieryDemise = wan.spellData.FieryBrand.formattedName
    end

    if event == "TRAIT_DATA_READY" then

        bBouncingGlaives = wan.traitData.BouncingGlaives.known
        nBouncingGlaivesHitCount = wan.GetTraitDescriptionNumbers(wan.traitData.BouncingGlaives.entryid, { 1 }, wan.traitData.BouncingGlaives.rank)

        bAcceleratedBlade = wan.traitData.AcceleratedBlade.known
        local aAcceleratedBlade = wan.GetTraitDescriptionNumbers(wan.traitData.AcceleratedBlade.entryid, { 1, 2 }, wan.traitData.AcceleratedBlade.rank)
        nAcceleratedBladeMainTarget = aAcceleratedBlade[1] * 0.01
        nAcceleratedBladeSecondaryTarget = aAcceleratedBlade[2] * 0.01

        bFuriousThrows = wan.traitData.FuriousThrows.known

        bSerratedGlaive = wan.traitData.SerratedGlaive.known
        sSerratedGlaive = wan.traitData.SerratedGlaive.traitkey
        nSerratedGlaive = wan.GetTraitDescriptionNumbers(wan.traitData.SerratedGlaive.entryid, { 1 }, wan.traitData.SerratedGlaive.rank) * 0.01

        bBurningWound = wan.traitData.BurningWound.known
        sBurningWoundDebuff = wan.traitData.BurningWound.traitkey
        local nBurningWoundValues = wan.GetTraitDescriptionNumbers(wan.traitData.BurningWound.entryid, { 1, 4 })
        nBurningWoundDotDmg = nBurningWoundValues[1]
        nBurningWoundUnitCap = nBurningWoundValues[2]

        bSoulscar = wan.traitData.Soulscar.known
        sSoulscarDebuff = wan.traitData.Soulscar.traitkey
        nSoulscar = wan.GetTraitDescriptionNumbers(wan.traitData.Soulscar.entryid, { 1 }, wan.traitData.Soulscar.rank) * 0.01

        bKnowYourEnemy = wan.traitData.KnowYourEnemy.known
        nKnowYourEnemy = wan.GetTraitDescriptionNumbers(wan.traitData.KnowYourEnemy.entryid, { 1 }, wan.traitData.KnowYourEnemy.rank) * 0.01

        bFieryDemise = wan.traitData.FieryDemise.known
        nFieryDemise = wan.GetTraitDescriptionNumbers(wan.traitData.FieryDemise .entryid, { 1 }, wan.traitData.FieryDemise .rank) * 0.01

        sFrailty = wan.traitData.Frailty.traitkey
        bVulnerability = wan.traitData.Vulnerability.known
        nVulnerability = wan.GetTraitDescriptionNumbers(wan.traitData.Vulnerability.entryid, { 1 }, wan.traitData.Vulnerability.rank) * 0.01

        bReaversMark = wan.traitData.ReaversMark.known
        sReaversMark = wan.traitData.ReaversMark.traitkey
        nReaversMark = wan.GetTraitDescriptionNumbers(wan.traitData.ReaversMark.entryid, { 1 }, wan.traitData.ReaversMark.rank) * 0.01

        bWoundedQuarry = wan.traitData.WoundedQuarry.known
        nWoundedQuarry = wan.GetTraitDescriptionNumbers(wan.traitData.WoundedQuarry.entryid, { 1 }, wan.traitData.WoundedQuarry.rank) * 0.01

        bPreemptiveStrike = wan.traitData.PreemptiveStrike.known
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameThrowGlaive, CheckAbilityValue, abilityActive)
    end
end)