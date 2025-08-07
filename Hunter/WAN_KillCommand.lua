local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nKillCommandDmg = 0
local nExplosiveShotDmg, nExplosiveShotSoftCap = 0, 0

-- Init trait data
local aHarmonize, nHarmonize = {}, 0
local nSolitaryCompanion = 0
local nGoForTheThroat = 0
local nKillCleave, nKillCleaveSoftCap = 0, 0
local nQuickShotProcChance, nQuickShotDmg, nArcaneShotDmg = 0, 0, 0
local nSerpentineRhythm = 0
local nTrainingExpert = 0
local nAMurderOfCrows, nAMurderOfCrowsStacks, nAMurderofCrownsStacksCap = 0, 0, 0
local nBestialWrath = 0
local aKillerInstinct, nKillerInstinct= {}, 0
local nHowlofthePackLeaderWyvern, nHowlofthePackLeaderBoarAttacks, nHowlofthePackLeaderBoarInstantDmg, nHowlofthePackLeaderBoarInstantDmgAoE, nHowlofthePackLeaderBoarSoftCap, nHowlofthePackLeaderBearDotDmg, nHowlofthePackLeaderBearUnitCap = 0, 0, 0, 0, 0, 0, 0
local aBetterTogether, nBetterTogether = {}, 0
local nPackMentality = 0
local nLeadFromtheFront = 0
local nPhantomPain = 0
local nPiercingFangs = 0
local nExposedFlank, nExposedFlankUnitCap = 0, 0
local nSulfurLinedPockets = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsPetUsable()
    or not wan.IsSpellUsable(wan.spellData.KillCommand.id)
    then
        wan.UpdateAbilityData(wan.spellData.KillCommand.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.KillCommand.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.KillCommand.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critChanceModBase = 0
    local critDamageMod = 0
    local critDamageModBase = 0

    local cKillCommandInstantDmg = 0
    local cKillCommandDotDmg = 0
    local cKillCommandInstantDmgAoE = 0
    local cKillCommandDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- HUNTER TRAITS ----

    local cHarmonize = 1
    if aHarmonize.known then
        cHarmonize = cHarmonize + nHarmonize
    end

    ---- BEAST MASTERY TRAITS ----

    -- animal companion trait layer
    local cAnimalCompanion = 1
    if wan.traitData.AnimalCompanion.known then
        cAnimalCompanion = cAnimalCompanion + 1
    end

    local cSolitaryCompanion = 1
    if wan.traitData.SolitaryCompanion.known then
        cSolitaryCompanion = cSolitaryCompanion + nSolitaryCompanion
    end

    -- go for the throat trait layer
    if wan.traitData.GofortheThroat.known then
        local cGoForTheThroat = nGoForTheThroat
        critDamageMod = critDamageMod + (wan.CritChance * cGoForTheThroat)
    end

    -- serpentine rhythm trait layer
    local cSerpentineRhythm = 1
    if wan.traitData.SerpentineRhythm.known then
        local checkSerpentineBlessingBuff = wan.CheckUnitBuff(nil, wan.traitData.SerpentineRhythm.traitkey)
        if checkSerpentineBlessingBuff then
            cSerpentineRhythm = cSerpentineRhythm + nSerpentineRhythm
        end
    end

    -- kill cleave trait layer
    local cKillCleaveInstantDmgAoE = 0
    if wan.traitData.KillCleave.known then
        local checkBeastCleaveBuff = wan.CheckUnitBuff(nil, wan.traitData.BeastCleave.traitkey)

        if checkBeastCleaveBuff then
            local cKillCleaveUnitOverflow = wan.SoftCapOverflow(nKillCleaveSoftCap, countValidUnit)

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                    cKillCleaveInstantDmgAoE = cKillCleaveInstantDmgAoE + (nKillCommandDmg * nKillCleave * checkUnitPhysicalDR * cKillCleaveUnitOverflow)
                end
            end
        end
    end

    local cTrainingExpert = 1
    if wan.traitData.TrainingExpert.known then
        cTrainingExpert = cTrainingExpert + nTrainingExpert
    end

    -- a murder of crows trait layer
    local cAMurderOfCrows = 0
    if wan.traitData.AMurderofCrows.known then
        local checkAMurderofCrowsBuff = wan.CheckUnitBuff(nil, wan.traitData.AMurderofCrows.traitkey)
        local cAMurderofCrownsStacks = checkAMurderofCrowsBuff and checkAMurderofCrowsBuff.applications

        if cAMurderofCrownsStacks == nAMurderofCrownsStacksCap then
            local checkPhysicalDRAMurderOfCrows = not wan.traitData.BansheesMark.known and wan.CheckUnitPhysicalDamageReduction() or 1
            cAMurderOfCrows = cAMurderOfCrows + (nAMurderOfCrows * checkPhysicalDRAMurderOfCrows)
        end
    end

    -- bestial wrath trait layer
    local cBestialWrath = 1
    if wan.traitData.BestialWrath.known then
        local checkBestialWrathBuff = wan.CheckUnitBuff(nil, wan.spellData.BestialWrath.formattedName)
        if checkBestialWrathBuff then
            cBestialWrath = cBestialWrath + nBestialWrath

            if wan.traitData.LeadFromtheFront.known then
                cBestialWrath = cBestialWrath + nLeadFromtheFront
            end
        end
    end

    -- killer instinct trait layer
    local cKillerInstinct = 1
    if aKillerInstinct.known then
        cKillerInstinct = cKillerInstinct + (nKillerInstinct)
    end

    -- piercing fangs trait layer
    if wan.traitData.PiercingFangs.known then
        local checkBestialWrathBuff = wan.CheckUnitBuff(nil, wan.traitData.BestialWrath.traitkey)
        if checkBestialWrathBuff then
            critDamageMod = critDamageMod + nPiercingFangs
        end
    end

    ---- SURVIVAL TRAITS ----

    -- quick shot trait layer
    local cQuickShotInstantDmg = 0
    local cQuickShotInstantDmgAoE = 0
    if wan.traitData.QuickShot.known then
        cQuickShotInstantDmg = cQuickShotInstantDmg + (nArcaneShotDmg * nQuickShotProcChance * nQuickShotDmg)

        if wan.traitData.SulfurLinedPockets.known then
            local checkSulfurLinedPocketsBuff = wan.CheckUnitBuff(nil, wan.traitData.SulfurLinedPockets.traitkey)
            if checkSulfurLinedPocketsBuff and checkSulfurLinedPocketsBuff.spellId == 459834 then
                local cExplosiveShotUnitOverflow = wan.AdjustSoftCapUnitOverflow(nExplosiveShotSoftCap, countValidUnit)
                local cExplosiveShotDmg = nExplosiveShotDmg * cExplosiveShotUnitOverflow
                cQuickShotInstantDmgAoE = cQuickShotInstantDmgAoE + (cExplosiveShotDmg * nSulfurLinedPockets * nQuickShotProcChance)
            end
        end
    end

    -- exposed flank trait layer
    local cExposedFlank = 1
    local countExposedFlank = 0
    local cExposedFlankInstantDmgAoE = 0
    if wan.traitData.ExposedFlank.known then
        local checkExposedFlankBuff = wan.CheckUnitBuff(nil, wan.traitData.ExposedFlank.traitkey)
        cExposedFlank = cExposedFlank + nExposedFlank

        if checkExposedFlankBuff then

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                    cExposedFlankInstantDmgAoE = cExposedFlankInstantDmgAoE + (nKillCommandDmg * checkUnitPhysicalDR)
                    countExposedFlank = countExposedFlank + 1

                    if countExposedFlank >= nExposedFlankUnitCap then break end
                end
            end
        end
    end

    ---- PACK LEADER TRAITS ----

    -- howl of the pack leader trait layer
    local cHowlOfThePackLeaderWyvern = 1
    local cHowlOfThePackLeaderBoarInstantDmg = 0
    local cHowlOfThePackLeaderBoarInstantDmgAoE = 0
    local cHowlOfThePackLeaderBearDotDmgAoE = 0
    local cPackMentality = 1
    if wan.traitData.HowlofthePackLeader.known then

        local checkWyvernsCryBuff = wan.CheckUnitBuff(nil, "WyvernsCry")
        if checkWyvernsCryBuff then
            local cWyvernsCryStacks = checkWyvernsCryBuff.applications
            cHowlOfThePackLeaderWyvern = cHowlOfThePackLeaderWyvern + (nHowlofthePackLeaderWyvern * cWyvernsCryStacks)

            if wan.traitData.PackMentality.known then
                cPackMentality = cPackMentality + nPackMentality
            end
        end

        local checkHowlOfThePackLeaderBuff = wan.CheckUnitBuff(nil, wan.traitData.HowlofthePackLeader.traitkey)
        if checkHowlOfThePackLeaderBuff then
            if checkHowlOfThePackLeaderBuff.spellId == 472324 then
                local cHowlOfThePackLeaderBoarSecondaryUnits = math.max(countValidUnit - 1, 0)
                local cHowlOfThePackLeaderBoarUnitOverflow = wan.SoftCapOverflow(nHowlofthePackLeaderBoarSoftCap, cHowlOfThePackLeaderBoarSecondaryUnits)
                local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(targetUnitToken)
                local dotPotency = wan.CheckDotPotency(nHowlofthePackLeaderBoarInstantDmg)

                cHowlOfThePackLeaderBoarInstantDmg = cHowlOfThePackLeaderBoarInstantDmg + (nHowlofthePackLeaderBoarInstantDmg * nHowlofthePackLeaderBoarAttacks * checkPhysicalDR * dotPotency)

                for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                    if nameplateGUID ~= targetGUID then
                        local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)
                        local unitDotPotency = wan.CheckDotPotency(nHowlofthePackLeaderBoarInstantDmg, nameplateUnitToken)

                        cHowlOfThePackLeaderBoarInstantDmgAoE = cHowlOfThePackLeaderBoarInstantDmgAoE + (nHowlofthePackLeaderBoarInstantDmgAoE * nHowlofthePackLeaderBoarAttacks * cHowlOfThePackLeaderBoarUnitOverflow * checkUnitPhysicalDR * unitDotPotency)
                    end
                end

                if wan.traitData.PackMentality.known then
                    cPackMentality = cPackMentality + nPackMentality
                end

            elseif checkHowlOfThePackLeaderBuff.spellId == 472325 then
                local countHowlofthePackLeaderUnit = 0

                for nameplateUnitToken, _ in pairs(idValidUnit) do
                    local unitDotPotency = wan.CheckDotPotency(nHowlofthePackLeaderBoarInstantDmg, nameplateUnitToken)

                    cHowlOfThePackLeaderBearDotDmgAoE = cHowlOfThePackLeaderBearDotDmgAoE + (nHowlofthePackLeaderBearDotDmg * unitDotPotency)

                    countHowlofthePackLeaderUnit = countHowlofthePackLeaderUnit + 1

                    if countHowlofthePackLeaderUnit >= nHowlofthePackLeaderBearUnitCap then break end
                end

                if wan.traitData.PackMentality.known then
                    cPackMentality = cPackMentality + nPackMentality
                end
            end
        end
    end

    local cBetterTogether = 1
    if aBetterTogether.known then
        cBetterTogether = cBetterTogether + nBetterTogether
    end

    ---- DARK RANGER TRAITS ----

    -- phantom pain trait layer
    local cPhantomPain = 0
    if wan.traitData.PhantomPain.known then

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkBlackArrowDebuff = wan.CheckUnitDebuff(nameplateUnitToken, wan.traitData.BlackArrow.traitkey)

            if checkBlackArrowDebuff then
                cPhantomPain = cPhantomPain + (nKillCommandDmg * cAnimalCompanion * cSolitaryCompanion * cSerpentineRhythm * cTrainingExpert * cKillerInstinct * nPhantomPain)
            end
        end
    end

    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cKillCommandCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cKillCommandBaseCritValue = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cKillCommandInstantDmg = cKillCommandInstantDmg
        + (nKillCommandDmg * cHarmonize * cAnimalCompanion * cSolitaryCompanion * cSerpentineRhythm * cTrainingExpert * cBestialWrath * cKillerInstinct * cHowlOfThePackLeaderWyvern * cBetterTogether * cPackMentality * cExposedFlank * checkPhysicalDR * cKillCommandCritValue)
        + (cQuickShotInstantDmg * cKillCommandBaseCritValue)
        + (cHowlOfThePackLeaderBoarInstantDmg * cKillCommandBaseCritValue)

    cKillCommandDotDmg = cKillCommandDotDmg
        + (cAMurderOfCrows * cKillCommandBaseCritValue)

    cKillCommandInstantDmgAoE = cKillCommandInstantDmgAoE
        + (cKillCleaveInstantDmgAoE * cHarmonize * cAnimalCompanion * cSolitaryCompanion * cSerpentineRhythm * cTrainingExpert * cBestialWrath * cKillerInstinct * cHowlOfThePackLeaderWyvern * cBetterTogether * cPackMentality * cKillCommandCritValue)
        + (cExposedFlankInstantDmgAoE * cExposedFlank * cKillCommandCritValue)
        + (cQuickShotInstantDmgAoE * cKillCommandBaseCritValue)
        + (cHowlOfThePackLeaderBoarInstantDmgAoE * cKillCommandBaseCritValue)
        + cPhantomPain

    cKillCommandDotDmgAoE = cKillCommandDotDmgAoE
        + (cHowlOfThePackLeaderBearDotDmgAoE * cKillCommandBaseCritValue)

    local cKillCommandDmg = cKillCommandInstantDmg + cKillCommandDotDmg + cKillCommandInstantDmgAoE + cKillCommandDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cKillCommandDmg)
    wan.UpdateAbilityData(wan.spellData.KillCommand.basename, abilityValue, wan.spellData.KillCommand.icon, wan.spellData.KillCommand.name)
end

-- Init frame 
local frameKillCommand = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nKillCommandDmg = wan.GetSpellDescriptionNumbers(wan.spellData.KillCommand.id, { 1 })

            local nAMurderOfCrowsValues = wan.GetTraitDescriptionNumbers(wan.traitData.AMurderofCrows.entryid, { 1, 2 })
            nAMurderOfCrowsStacks = nAMurderOfCrowsValues[1]
            nAMurderofCrownsStacksCap = math.max((nAMurderOfCrowsStacks - 1), 0)
            nAMurderOfCrows = nAMurderOfCrowsValues[2]

            nArcaneShotDmg = wan.GetSpellDescriptionNumbers(wan.spellData.ArcaneShot.id, { 1 })

            local nExplosiveShotValues = wan.GetTraitDescriptionNumbers(wan.traitData.ExplosiveShot.entryid, { 2, 4 })
            nExplosiveShotDmg = nExplosiveShotValues[1]
            nExplosiveShotSoftCap = nExplosiveShotValues[2]
        end
    end)
end
frameKillCommand:RegisterEvent("ADDON_LOADED")
frameKillCommand:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.KillCommand.known and wan.spellData.KillCommand.id
        wan.BlizzardEventHandler(frameKillCommand, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameKillCommand, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then

        aHarmonize = wan.traitData.Harmonize
        nHarmonize = wan.GetTraitDescriptionNumbers(aHarmonize.entryid, { 1 }) * 0.01

        nSolitaryCompanion = wan.GetTraitDescriptionNumbers(wan.traitData.SolitaryCompanion.entryid, { 1 }) * 0.01

        nGoForTheThroat = wan.GetTraitDescriptionNumbers(wan.traitData.GofortheThroat.entryid, { 1 }) * 0.01

        nSerpentineRhythm = wan.GetTraitDescriptionNumbers(wan.traitData.SerpentineRhythm.entryid, { 1 }) * 0.01

        nTrainingExpert = wan.GetTraitDescriptionNumbers(wan.traitData.TrainingExpert.entryid, { 1 }) * 0.01

        local nQuickShotValues = wan.GetTraitDescriptionNumbers(wan.traitData.QuickShot.entryid, { 1, 2 })
        nQuickShotProcChance = nQuickShotValues[1] * 0.01
        nQuickShotDmg = nQuickShotValues[2] * 0.01

        local nExposedFlankValues = wan.GetTraitDescriptionNumbers(wan.traitData.ExposedFlank.entryid, { 1, 2 })
        nExposedFlank = nExposedFlankValues[1] * 0.01
        nExposedFlankUnitCap = nExposedFlankValues[2]

        local nKillCleaveValues = wan.GetTraitDescriptionNumbers(wan.traitData.KillCleave.entryid, { 1, 2 })
        nKillCleave = nKillCleaveValues[1] * 0.01
        nKillCleaveSoftCap = nKillCleaveValues[2]

        nBestialWrath = wan.GetTraitDescriptionNumbers(wan.traitData.BestialWrath.entryid, { 2 }) * 0.01

        aKillerInstinct = wan.traitData.KillerInstinct
        nKillerInstinct = wan.GetTraitDescriptionNumbers(aKillerInstinct.entryid, { 1 }, aKillerInstinct.rank) * 0.01

        local nHowlofthePackLeaderValues = wan.GetTraitDescriptionNumbers(wan.traitData.HowlofthePackLeader.entryid, { 4, 8, 9, 10, 11, 14, 16 })
        nHowlofthePackLeaderWyvern = nHowlofthePackLeaderValues[1] * 0.001
        nHowlofthePackLeaderBoarAttacks = nHowlofthePackLeaderValues[2]
        nHowlofthePackLeaderBoarInstantDmg = nHowlofthePackLeaderValues[3]
        nHowlofthePackLeaderBoarInstantDmgAoE = nHowlofthePackLeaderValues[4]
        nHowlofthePackLeaderBoarSoftCap = nHowlofthePackLeaderValues[5]
        nHowlofthePackLeaderBearDotDmg = nHowlofthePackLeaderValues[6]
        nHowlofthePackLeaderBearUnitCap = nHowlofthePackLeaderValues[7]

        aBetterTogether = wan.traitData.BetterTogether
        nBetterTogether = wan.GetTraitDescriptionNumbers(aBetterTogether.entryid, { 1 }) * 0.01

        nPackMentality = wan.GetTraitDescriptionNumbers(wan.traitData.PackMentality.entryid, { 1 }) * 0.01

        nLeadFromtheFront = wan.GetTraitDescriptionNumbers(wan.traitData.LeadFromtheFront.entryid, { 2 }) * 0.01

        nPiercingFangs = wan.GetTraitDescriptionNumbers(wan.traitData.PiercingFangs.entryid, { 1 })

        nPhantomPain = wan.GetTraitDescriptionNumbers(wan.traitData.PhantomPain.entryid, { 1 }) * 0.01

        nSulfurLinedPockets = wan.GetTraitDescriptionNumbers(wan.traitData.SulfurLinedPockets.entryid, { 2 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameKillCommand, CheckAbilityValue, abilityActive)
    end
end)