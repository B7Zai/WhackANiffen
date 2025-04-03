local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DEMONHUNTER" then return end

-- Init spell data
local abilityActive = false
local nChaosStrikeDmg = 0
local isTank = false

-- Init trait data
local bKnowYourEnemy, nKnowYourEnemy = false, 0
local bSerratedGlaive, sSerratedGlaive, nSerratedGlaive = false, "SerratedGlaive", 0
local bChaosTheory, buffChaosTheory = false, "ChaosTheory"
local bInnerDemon, nInnerDemonDmg, nInnerDemonSoftCap, nInnerDemonMaxRange = false, 0, 0, 11
local bRelentlessOnslaught, nRelentlessOnslaughtProcChance = false, 0
local bEssenceBreak, sEssenceBreak, nEssenceBreak = false, "EssenceBreak",  0

local bReaversMark, sReaversMark, nReaversMark = false, "ReaversMark", 0
local bWarbladesHunger, sWarbladesHunger, nWarbladesHunger = false, "WarbladesHunger", 0

local checkDemonsurgeEmpowerment = false
local bDemonsurge, nDemonsurgeDmg, nDemonsurgeSoftCap, bDemonsurgeMaxRange = false, 0, 0, 11
local bBurningBlades, nBurningBlades = false, 0
local bFocusedHatred, nFocusedHatred, nFocusedHatredStep = false, 0, 0
local bFelBarrage, sFelBarrageBuff = false, "FelBarrage"

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or not wan.IsSpellUsable(wan.spellData.ChaosStrike.id)
        or (bFelBarrage and wan.CheckUnitBuff(nil, sFelBarrageBuff))
    then
        wan.UpdateAbilityData(wan.spellData.ChaosStrike.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.ChaosStrike.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ChaosStrike.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cChaosStrikeInstantDmg = 0
    local cChaosStrikeDotDmg = 0
    local cChaosStrikeInstantDmgAoE = 0
    local cChaosStrikeDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- HAVOC TRAITS ----

    local cSerratedGlaive = 1
    if bSerratedGlaive then
        local checkSerratedGlaiveDebuff = wan.CheckUnitDebuff(nil, sSerratedGlaive)
        if checkSerratedGlaiveDebuff then
            cSerratedGlaive = cSerratedGlaive + nSerratedGlaive
        end
    end

    if bChaosTheory then
        local checkChaosTheoryBuff = wan.CheckUnitBuff(nil, buffChaosTheory)
        if checkChaosTheoryBuff then
            for _, nChaosTheoryCritChance  in pairs(checkChaosTheoryBuff.points) do
                critChanceMod = critChanceMod + nChaosTheoryCritChance
                break
            end
        end
    end

    local cInnerDemonInstantDmgAoE = 0
    if bInnerDemon then
        local checkMetamorphosisBuff = wan.CheckUnitBuff(nil, wan.spellData.Metamorphosis.formattedName)
        if checkMetamorphosisBuff and checkDemonsurgeEmpowerment then
            local _, countValidUnitInnerDemon, _ = wan.ValidUnitBoolCounter(nil, nInnerDemonMaxRange)
            local cInnerDemonUnitOverflow = wan.AdjustSoftCapUnitOverflow(nInnerDemonSoftCap, countValidUnitInnerDemon)

            cInnerDemonInstantDmgAoE = cInnerDemonInstantDmgAoE + (nInnerDemonDmg * cInnerDemonUnitOverflow)
        end
    end

    local cRelentlessOnslaught = 0
    if bRelentlessOnslaught then
        cRelentlessOnslaught = cRelentlessOnslaught + (nChaosStrikeDmg * nRelentlessOnslaughtProcChance)
    end

    if bKnowYourEnemy then
        critDamageMod = critDamageMod + (wan.CritChance * nKnowYourEnemy)
        critDamageModBase = critDamageModBase + (wan.CritChance * nKnowYourEnemy)
    end

    local cEssenceBreak = 1
    if bEssenceBreak then
        local checkEssenceBreakDebuff = wan.CheckUnitDebuff(nil, sEssenceBreak)
        if checkEssenceBreakDebuff then
            cEssenceBreak = cEssenceBreak + nEssenceBreak
        end
    end

    ---- ALDRACHI REAVER TRAITS ----

    local cReaversMark = 1
    if bReaversMark then
        local checkReaversMarkDebuff = wan.CheckUnitDebuff(nil, sReaversMark)
        if checkReaversMarkDebuff then
            local cReaversMarkStacks = checkReaversMarkDebuff and checkReaversMarkDebuff.applications

            if not cReaversMarkStacks or cReaversMarkStacks == 0 then
                cReaversMarkStacks = 1
            end

            cReaversMark = cReaversMark + (nReaversMark * cReaversMarkStacks)
        end
    end

    local cWarbladesHungerInstantDmg = 0
    if bWarbladesHunger then
        local checkWarbladesHungerBuff = wan.CheckUnitBuff(nil, sWarbladesHunger)

        if checkWarbladesHungerBuff then
            local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()

            cWarbladesHungerInstantDmg = cWarbladesHungerInstantDmg + (nWarbladesHunger * checkPhysicalDR)
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

    local cBurningBladesDotDmg = 0
    if bBurningBlades then
        local checkDotPotency = wan.CheckDotPotency(nChaosStrikeDmg)

        cBurningBladesDotDmg = cBurningBladesDotDmg + ((nChaosStrikeDmg + cRelentlessOnslaught) * nBurningBlades * checkDotPotency)
    end

    local cChaosStrikeCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cChaosStrikeCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cChaosStrikeInstantDmg = cChaosStrikeInstantDmg
        + (nChaosStrikeDmg * cChaosStrikeCritValue * cSerratedGlaive * cEssenceBreak * cReaversMark)
        + (cRelentlessOnslaught * cChaosStrikeCritValueBase * cSerratedGlaive * cEssenceBreak * cReaversMark)
        + (cWarbladesHungerInstantDmg * cChaosStrikeCritValueBase * cReaversMark)

    cChaosStrikeDotDmg = cChaosStrikeDotDmg
        + (cBurningBladesDotDmg * cChaosStrikeCritValue * cSerratedGlaive * cEssenceBreak)

    cChaosStrikeInstantDmgAoE = cChaosStrikeInstantDmgAoE
        + (cInnerDemonInstantDmgAoE * cChaosStrikeCritValueBase * cReaversMark)
        + (cDemonsurgeInstantDmgAoE * cChaosStrikeCritValueBase)

    cChaosStrikeDotDmgAoE = cChaosStrikeDotDmgAoE

    local cChaosStrikeDmg = cChaosStrikeInstantDmg + cChaosStrikeDotDmg + cChaosStrikeInstantDmgAoE + cChaosStrikeDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cChaosStrikeDmg)
    wan.UpdateAbilityData(wan.spellData.ChaosStrike.basename, abilityValue, wan.spellData.ChaosStrike.icon, wan.spellData.ChaosStrike.name)
end

-- Init frame 
local frameChaosStrike = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, unit, _, spellID)

        if (event == "UNIT_AURA" and unit == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nChaosStrikeDmg = wan.GetSpellDescriptionNumbers(wan.spellData.ChaosStrike.id, { 1 })

            nWarbladesHunger = wan.GetTraitDescriptionNumbers(wan.traitData.WarbladesHunger.entryid, { 1 }, wan.traitData.WarbladesHunger.rank)

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

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.ChaosStrike.id then
            checkDemonsurgeEmpowerment = false
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.Metamorphosis.id then
            checkDemonsurgeEmpowerment = true
        end

        if event == "UNIT_SPELLCAST_SUCCEEDED" and unit == "player" and spellID == wan.spellData.EyeBeam.id then
            checkDemonsurgeEmpowerment = true
        end

    end)
end
frameChaosStrike:RegisterEvent("ADDON_LOADED")
frameChaosStrike:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = not isTank and not wan.spellData.ChaosStrike.isPassive and wan.spellData.ChaosStrike.known and wan.spellData.ChaosStrike.id
        wan.BlizzardEventHandler(frameChaosStrike, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_SPELLCAST_SUCCEEDED")
        wan.SetUpdateRate(frameChaosStrike, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then

        isTank = wan.spellData.MasteryFelBlood.known

        bKnowYourEnemy = wan.traitData.KnowYourEnemy.known
        nKnowYourEnemy = wan.GetTraitDescriptionNumbers(wan.traitData.KnowYourEnemy.entryid, { 1 }, wan.traitData.KnowYourEnemy.rank) * 0.01

        bSerratedGlaive = wan.traitData.SerratedGlaive.known
        sSerratedGlaive = wan.traitData.SerratedGlaive.traitkey
        nSerratedGlaive = wan.GetTraitDescriptionNumbers(wan.traitData.SerratedGlaive.entryid, { 1 }, wan.traitData.SerratedGlaive.rank) * 0.01

        bChaosTheory = wan.traitData.ChaosTheory.known
        buffChaosTheory = wan.traitData.ChaosTheory.traitkey

        bInnerDemon = wan.traitData.InnerDemon.known
        local nInnerDemonValues = wan.GetTraitDescriptionNumbers(wan.traitData.InnerDemon.entryid, { 1, 2 }, wan.traitData.InnerDemon.rank)
        nInnerDemonDmg = nInnerDemonValues[1]
        nInnerDemonSoftCap = nInnerDemonValues[2]

        bRelentlessOnslaught = wan.traitData.RelentlessOnslaught.known
        nRelentlessOnslaughtProcChance = wan.GetTraitDescriptionNumbers(wan.traitData.RelentlessOnslaught.entryid, { 1 }, wan.traitData.RelentlessOnslaught.rank) * 0.01

        bEssenceBreak = wan.traitData.EssenceBreak.known
        sEssenceBreak = wan.traitData.EssenceBreak.traitkey
        nEssenceBreak = wan.GetTraitDescriptionNumbers(wan.traitData.EssenceBreak.entryid, { 2 } ) * 0.01

        bFelBarrage = wan.traitData.FelBarrage.known
        sFelBarrageBuff = wan.traitData.FelBarrage.traitkey

        bReaversMark = wan.traitData.ReaversMark.known
        sReaversMark = wan.traitData.ReaversMark.traitkey
        nReaversMark = wan.GetTraitDescriptionNumbers(wan.traitData.ReaversMark.entryid, { 1 }, wan.traitData.ReaversMark.rank) * 0.01

        bWarbladesHunger = wan.traitData.WarbladesHunger.known
        sWarbladesHunger = wan.traitData.WarbladesHunger.traitkey

        bDemonsurge = wan.traitData.Demonsurge.known

        bBurningBlades = wan.traitData.BurningBlades.known
        nBurningBlades = wan.GetTraitDescriptionNumbers(wan.traitData.BurningBlades.entryid, { 1 }, wan.traitData.BurningBlades.rank) * 0.01

        bFocusedHatred = wan.traitData.FocusedHatred.known
        local nFocusedHatredValues = wan.GetTraitDescriptionNumbers(wan.traitData.FocusedHatred.entryid, { 1, 2 }, wan.traitData.FocusedHatred.rank)
        nFocusedHatred = nFocusedHatredValues[1] * 0.01
        nFocusedHatredStep = nFocusedHatredValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameChaosStrike, CheckAbilityValue, abilityActive)
    end
end)