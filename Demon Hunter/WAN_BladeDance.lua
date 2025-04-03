local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init spell data
local abilityActive = false
local nBladeDanceDmg, nBladeDanceSoftCap, nBladeDanceMaxRange, nBladeDanceHitCount = 0, 0, 11, 4

-- Init trait data
local bFirstBlood, nFirstBloodDmg = false, 0
local bTrailofRuin, sTrailofRuin, nTrailofRuinDmg = false, "TrailofRuin", 0
local bKnowYourEnemy, nKnowYourEnemy = false, 0
local bEssenceBreak, sEssenceBreak, nEssenceBreak = false, "EssenceBreak",  0
local checkFuryoftheAldrachiEmpowerment = false
local bFuryoftheAldrachi, sFuryoftheAldrachiBuff, nFuryoftheAldrachiHits, nFuryoftheAldrachiHitCap, nFuryoftheAldrachiDmg = false, "GlaiveFlurry", 0, 0, 0
local bReaversMark, sReaversMark, nReaversMark = false, "ReaversMark", 0
local bWoundedQuarry, nWoundedQuarry = false, 0
local checkDemonsurgeEmpowerment = false
local bDemonsurge, nDemonsurgeDmg, nDemonsurgeSoftCap, bDemonsurgeMaxRange = false, 0, 0, 11
local bFocusedHatred, nFocusedHatred, nFocusedHatredStep = false, 0, 0
local bScreamingBrutality, nScreamingBrutalityPrimaryTarget, nScreamingBrutalityProcChance, nScreamingBrutalityNonTarget = false, 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.BladeDance.id)
    then
        wan.UpdateAbilityData(wan.spellData.BladeDance.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nBladeDanceMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.BladeDance.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cBladeDanceInstantDmg = 0
    local cBladeDanceDotDmg = 0
    local cBladeDanceInstantDmgAoE = 0
    local cBladeDanceDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cBladeDanceInstantDmgBase = bFirstBlood and nFirstBloodDmg or nBladeDanceDmg
    local cBladeDanceInstantDmgBaseAoE = 0
    local cBladeDanceUnitOverflow = wan.SoftCapOverflow(nBladeDanceSoftCap, countValidUnit)
    for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

        if nameplateGUID ~= targetGUID then
            local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)
            
            cBladeDanceInstantDmgBaseAoE = cBladeDanceInstantDmgBaseAoE + (nBladeDanceDmg * cBladeDanceUnitOverflow * checkUnitPhysicalDR)
        end
    end

    ---- HAVOC TRAITS ----

    local cTrailofRuinDotDmgAoE = 0
    if bTrailofRuin then
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkTrailofRuinDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sTrailofRuin)
            if not checkTrailofRuinDebuff then
                local checkDotPotency = wan.CheckDotPotency(nBladeDanceDmg)

                cTrailofRuinDotDmgAoE = cTrailofRuinDotDmgAoE + (nTrailofRuinDmg * checkDotPotency)
            end
        end
    end

    if bKnowYourEnemy then
        critDamageMod = critDamageMod + (wan.CritChance * nKnowYourEnemy)
        critDamageModBase = critDamageModBase + (wan.CritChance * nKnowYourEnemy)
    end

    local cEssenceBreak = 1
    local cEssenceBreakAoE = 1
    if bEssenceBreak then
        local checkEssenceBreakDebuff = wan.CheckUnitDebuff(nil, sEssenceBreak)

        if checkEssenceBreakDebuff then
            cEssenceBreak = cEssenceBreak + nEssenceBreak
        end

        local countEssenceBreakUnits = math.max(countValidUnit - 1, 0)
        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local checkUnitEssenceBreakDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sEssenceBreak)

                if checkUnitEssenceBreakDebuff then
                    cEssenceBreakAoE = cEssenceBreakAoE + (nEssenceBreak / countEssenceBreakUnits)
                end
            end
        end
    end

    local cScreamingBrutalityInstantDmgAoE = 0
    if bScreamingBrutality and wan.spellData.ThrowGlaive.name ~= "Reaver's Glaive" then
        local nThrowGlaiveDmg = wan.AbilityData.ThrowGlaive and wan.AbilityData.ThrowGlaive.value or 0
        cScreamingBrutalityInstantDmgAoE = cScreamingBrutalityInstantDmgAoE
            + (nThrowGlaiveDmg * nScreamingBrutalityPrimaryTarget)
            + (nThrowGlaiveDmg * nBladeDanceHitCount * nScreamingBrutalityProcChance * nScreamingBrutalityNonTarget)
    end

    ---- ALDRACHI REAVER TRAITS ----

    local cFuryoftheAldrachiInstantDmgAoE = 0
    if bFuryoftheAldrachi then
        local checkGlaiveFlurryBuff = wan.CheckUnitBuff(nil, sFuryoftheAldrachiBuff)
        local cFuryoftheAldrachiHits = checkFuryoftheAldrachiEmpowerment and nFuryoftheAldrachiHitCap or nFuryoftheAldrachiHits
        if checkGlaiveFlurryBuff then
            cFuryoftheAldrachiInstantDmgAoE = cFuryoftheAldrachiInstantDmgAoE + (nFuryoftheAldrachiDmg * cFuryoftheAldrachiHits * countValidUnit)
        end
    end

    local cReaversMark = 1
    if bReaversMark then
        local checkReaversMarkDebuff = wan.CheckUnitDebuff(nil, sReaversMark)
        if checkReaversMarkDebuff then
            local cReaversMarkStacks = checkReaversMarkDebuff and checkReaversMarkDebuff.applications

            if not cReaversMarkStacks or cReaversMarkStacks == 0 then
                cReaversMarkStacks = 1
            end

            local cWoundedQuarry = 0
            if bWoundedQuarry and not bFirstBlood then
                cWoundedQuarry = cWoundedQuarry + (nWoundedQuarry)
            end

            cReaversMark = cReaversMark + (nReaversMark * cReaversMarkStacks) + cWoundedQuarry
        end
    end

    ---- FEL-SCARRED TRAITS ----

    local cDemonsurgeInstantDmgAoE = 0
    if bDemonsurge and checkDemonsurgeEmpowerment then
        local _, countValidUnitDemonsurge = wan.ValidUnitBoolCounter(nil, bDemonsurgeMaxRange)
        local cDemonsurgeUnitOverflow = wan.AdjustSoftCapUnitOverflow(nDemonsurgeSoftCap, countValidUnitDemonsurge)

        local cFocusedHatred = 1
        if bFocusedHatred then
            local nFocusedHatredUnits = math.max(countValidUnitDemonsurge - 1, 0)

            cFocusedHatred = cFocusedHatred + (math.max((nFocusedHatred - (nFocusedHatredStep *  nFocusedHatredUnits)), 0))
        end

        cDemonsurgeInstantDmgAoE = cDemonsurgeInstantDmgAoE + (nDemonsurgeDmg * cDemonsurgeUnitOverflow * cFocusedHatred)
    end

    local checkPhysicalDR = not bFirstBlood and wan.CheckUnitPhysicalDamageReduction() or 1
    local cBladeDanceCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cBladeDanceCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cBladeDanceInstantDmg = cBladeDanceInstantDmg
        + (cBladeDanceInstantDmgBase * cBladeDanceCritValue * checkPhysicalDR * cBladeDanceUnitOverflow * cEssenceBreak * cReaversMark)

    cBladeDanceDotDmg = cBladeDanceDotDmg

    cBladeDanceInstantDmgAoE = cBladeDanceInstantDmgAoE
        + (cBladeDanceInstantDmgBaseAoE * cBladeDanceCritValue * cEssenceBreakAoE)
        + (cScreamingBrutalityInstantDmgAoE)
        + (cFuryoftheAldrachiInstantDmgAoE * cBladeDanceCritValueBase)
        + (cDemonsurgeInstantDmgAoE * cBladeDanceCritValueBase)

    cBladeDanceDotDmgAoE = cBladeDanceDotDmgAoE
        + (cTrailofRuinDotDmgAoE * cBladeDanceCritValueBase)

    local cBladeDanceDmg = cBladeDanceInstantDmg + cBladeDanceDotDmg + cBladeDanceInstantDmgAoE + cBladeDanceDotDmgAoE

    -- priority modifier for the Aldrachi hero class
    if countValidUnit > 1 and cFuryoftheAldrachiInstantDmgAoE > 0 and not checkFuryoftheAldrachiEmpowerment then
        cBladeDanceDmg = 0
    end

    -- Update ability data
    local abilityValue = math.floor(cBladeDanceDmg)
    wan.UpdateAbilityData(wan.spellData.BladeDance.basename, abilityValue, wan.spellData.BladeDance.icon, wan.spellData.BladeDance.name)
end

-- Init frame 
local frameBladeDance = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, unit, _, spellID)

        if (event == "UNIT_AURA" and unit == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nBladeDanceValues = wan.GetSpellDescriptionNumbers(wan.spellData.BladeDance.id, { 1, 2, 3 })
            nBladeDanceDmg = bFirstBlood and nBladeDanceValues[2] or nBladeDanceValues[1]
            nBladeDanceSoftCap = bFirstBlood and nBladeDanceValues[3] or nBladeDanceValues[2]

            nFirstBloodDmg = wan.GetTraitDescriptionNumbers(wan.traitData.FirstBlood.entryid, { 1 }, wan.traitData.FirstBlood.rank)

            nTrailofRuinDmg = wan.GetTraitDescriptionNumbers(wan.traitData.TrailofRuin.entryid, { 1 }, wan.traitData.TrailofRuin.rank)

            -- nFuryoftheAldrachiDmg is a made up value
            -- no tooltip carry any values for this talent except the buff itself
            -- when checking the buff, .points is an empty array
            nFuryoftheAldrachiDmg = nBladeDanceDmg * 0.8

            local nDemonsurgeValues = wan.GetTraitDescriptionNumbers(wan.traitData.Demonsurge.entryid, { 2, 3 }, wan.traitData.Demonsurge.rank)
            nDemonsurgeDmg = nDemonsurgeValues[1]
            nDemonsurgeSoftCap = nDemonsurgeValues[2]

            if bDemonsurge then
                
                local checkMetamorphosisBuff = wan.CheckUnitBuff(nil, wan.spellData.Metamorphosis.formattedName)
                if not checkMetamorphosisBuff then
                    checkDemonsurgeEmpowerment = false
                end
            end
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.BladeDance.id then
            checkDemonsurgeEmpowerment = false
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.Metamorphosis.id then
            checkDemonsurgeEmpowerment = true
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.EyeBeam.id then
            checkDemonsurgeEmpowerment = true
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.ChaosStrike.id then
            local checkGlaiveFlurryBuff = wan.CheckUnitBuff(nil, sFuryoftheAldrachiBuff)
            if checkGlaiveFlurryBuff then
                checkFuryoftheAldrachiEmpowerment = true
            end
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.BladeDance.id then
            checkFuryoftheAldrachiEmpowerment = false
        end

    end)
end
frameBladeDance:RegisterEvent("ADDON_LOADED")
frameBladeDance:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = not wan.spellData.BladeDance.isPassive and wan.spellData.BladeDance.known and wan.spellData.BladeDance.id
        wan.BlizzardEventHandler(frameBladeDance, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED")
        wan.SetUpdateRate(frameBladeDance, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then

        bFirstBlood = wan.traitData.FirstBlood.known

        bTrailofRuin = wan.traitData.TrailofRuin.known
        sTrailofRuin = wan.traitData.TrailofRuin.traitkey

        bKnowYourEnemy = wan.traitData.KnowYourEnemy.known
        nKnowYourEnemy = wan.GetTraitDescriptionNumbers(wan.traitData.KnowYourEnemy.entryid, { 1 }, wan.traitData.KnowYourEnemy.rank) * 0.01

        bEssenceBreak = wan.traitData.EssenceBreak.known
        sEssenceBreak = wan.traitData.EssenceBreak.traitkey
        nEssenceBreak = wan.GetTraitDescriptionNumbers(wan.traitData.EssenceBreak.entryid, { 2 } ) * 0.01

        bScreamingBrutality = wan.traitData.ScreamingBrutality.known
        local aScreamingBrutality = wan.GetTraitDescriptionNumbers(wan.traitData.ScreamingBrutality.entryid, { 1, 2, 3 }, wan.traitData.ScreamingBrutality.rank)
        nScreamingBrutalityPrimaryTarget = aScreamingBrutality[1] * 0.01
        nScreamingBrutalityProcChance = aScreamingBrutality[2] * 0.01
        nScreamingBrutalityNonTarget = aScreamingBrutality[3] * 0.01

        bFuryoftheAldrachi = wan.traitData.FuryoftheAldrachi.known
        local nFuryoftheAldrachiValues = wan.GetTraitDescriptionNumbers(wan.traitData.FuryoftheAldrachi.entryid, { 1, 2 }, wan.traitData.FuryoftheAldrachi.rank)
        nFuryoftheAldrachiHits = nFuryoftheAldrachiValues[1]
        nFuryoftheAldrachiHitCap = nFuryoftheAldrachiValues[2]

        bReaversMark = wan.traitData.ReaversMark.known
        sReaversMark = wan.traitData.ReaversMark.traitkey
        nReaversMark = wan.GetTraitDescriptionNumbers(wan.traitData.ReaversMark.entryid, { 1 }, wan.traitData.ReaversMark.rank) * 0.01

        bWoundedQuarry = wan.traitData.WoundedQuarry.known
        nWoundedQuarry = wan.GetTraitDescriptionNumbers(wan.traitData.WoundedQuarry.entryid, { 1 }, wan.traitData.WoundedQuarry.rank) * 0.01

        bDemonsurge = wan.traitData.Demonsurge.known

        bFocusedHatred = wan.traitData.FocusedHatred.known
        local nFocusedHatredValues = wan.GetTraitDescriptionNumbers(wan.traitData.FocusedHatred.entryid, { 1, 2 }, wan.traitData.FocusedHatred.rank)
        nFocusedHatred = nFocusedHatredValues[1] * 0.01
        nFocusedHatredStep = nFocusedHatredValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBladeDance, CheckAbilityValue, abilityActive)
    end
end)