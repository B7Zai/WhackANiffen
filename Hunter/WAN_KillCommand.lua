local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nKillCommandDmg = 0
local nExplosiveShotDmg, nExplosiveShotSoftCap = 0, 0
local checkDebuffs = {}

-- Init trait data
local nGoForTheThroat = 0
local nKillCleave, nKillCleaveAoECap = 0, 0
local nQuickShotProcChance, nQuickShotDmg, nArcaneShotDmg = 0, 0, 0
local nSerpentineRhythm = 0
local nBloodseeker = 0
local nAMurderOfCrows, nAMurderOfCrowsStacks, nAMurderofCrownsStacksCap = 0, 0, 0
local nKillerInstinct, nKillerInstinctThreshold = 0, 0
local nBasiliskCollar = 0
local nBloodshed = 0
local nShowerOfBloodUnitCap = 0
local nVenomousBite = 0
local nViciousHunt = 0
local nFrenziedTear = 0
local nPhantomPain = 0
local nPiercingFangs = 0
local nExposedFlank, nExposedFlankUnitCap = 0, 0
local nSulfurLinedPockets = 0
local nHowlOfThePack = 0

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
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.KillCommand.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.KillCommand.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critDamageModBase = 0

    local cKillCommandInstantDmg = 0
    local cKillCommandDotDmg = 0
    local cKillCommandInstantDmgAoE = 0
    local cKillCommandDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- BEAST MASTERY TRAITS ----

    -- animal companion trait layer
    local cAnimalCompanion = 1
    if wan.traitData.AnimalCompanion.known then
        cAnimalCompanion = cAnimalCompanion * 2
    end

    -- go for the throat trait layer
    if wan.traitData.GofortheThroat.known then
        local cGoForTheThroat = nGoForTheThroat
        critDamageMod = critDamageMod + (wan.CritChance * cGoForTheThroat)
    end

    -- serpentine rhythm trait layer
    local cSerpentineRhythm = 1
    if wan.traitData.SerpentineRhythm.known and wan.auraData.player.buff_SerpentineBlessing then
        cSerpentineRhythm = cSerpentineRhythm + nSerpentineRhythm
    end

    -- kill cleave trait layer
    local cKillCleaveInstantDmgAoE = 0
    if wan.traitData.KillCleave.known and wan.auraData.player.buff_BeastCleave then
        local cKillCleaveUnitOverflow = wan.SoftCapOverflow(nKillCleaveAoECap, countValidUnit)

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
            if nameplateGUID ~= targetGUID then
                local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                cKillCleaveInstantDmgAoE = cKillCleaveInstantDmgAoE + (nKillCommandDmg * nKillCleave * checkUnitPhysicalDR *  cKillCleaveUnitOverflow)
            end
        end
    end

    -- a murder of crows trait layer
    local cAMurderOfCrows = 0
    if wan.traitData.AMurderofCrows.known and wan.auraData.player.buff_AMurderofCrows then
        local cAMurderofCrownsStacks = wan.auraData.player.buff_AMurderofCrows.applications

        if cAMurderofCrownsStacks == nAMurderofCrownsStacksCap then
            local checkPhysicalDRAMurderOfCrows = wan.traitData.BansheesMark.known and 1 or wan.CheckUnitPhysicalDamageReduction()
            cAMurderOfCrows = cAMurderOfCrows + (nAMurderOfCrows * checkPhysicalDRAMurderOfCrows)
        end
    end

    -- killec instinct trait layer
    local cKillerInstinct = 1
    if wan.traitData.KillerInstinct.known then
        local targetPercentHealth = targetGUID and UnitPercentHealthFromGUID(targetGUID) or 1

        if nKillerInstinctThreshold > targetPercentHealth then
            cKillerInstinct = cKillerInstinct + nKillerInstinct
        end
    end

    -- basilisk collar trait layer
    local cBasiliskCollar = 1
    local cBasiliskCollarAoE = 1
    if wan.traitData.BasiliskCollar.known then
        local countDebuff = wan.CountUnitDebuff(targetUnitToken, checkDebuffs)
        cBasiliskCollar = cBasiliskCollar + (nBasiliskCollar * countDebuff)

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
            if nameplateGUID ~= targetGUID then
                local countDebuff = wan.CountUnitDebuff(nameplateUnitToken, checkDebuffs)
                cBasiliskCollarAoE = cBasiliskCollarAoE + (nBasiliskCollar * countDebuff)
            end
        end
    end

    -- piercing fangs trait layer
    if wan.traitData.PiercingFangs.known and wan.auraData.player["buff_" .. wan.spellData.BestialWrath.basename] then
        critDamageMod = critDamageMod + nPiercingFangs
    end

    -- bloodshed trait layer
    local cBloodshed = 1
    local cBloodshedAoE = 1
    if wan.traitData.Bloodshed.known then
        if wan.traitData.ShowerofBlood.known then
            local checkBloodshedDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.traitData.Bloodshed.traitkey]

            if checkBloodshedDebuff then
                cBloodshed = cBloodshed + nBloodshed

                -- venomous bite trait layer
                if wan.traitData.VenomousBite.known then
                    cBloodshed = cBloodshed + nVenomousBite
                end
            end
            local countShowerofBlood = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
                if nameplateGUID ~= targetGUID then
                    local checkBloodshedDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. wan.traitData.Bloodshed.traitkey]

                    if checkBloodshedDebuff then
                        cBloodshedAoE = cBloodshedAoE + nBloodshed
                        countShowerofBlood = countShowerofBlood + 1

                        if (checkBloodshedDebuff and countShowerofBlood >= nShowerOfBloodUnitCap)
                            or (countShowerofBlood > nShowerOfBloodUnitCap)
                        then
                            break
                        end
                    end
                end
            end
        end
    end

    ---- SURVIVAL TRAITS ----

    -- quick shot trait layer
    local cQuickShotInstantDmg = 0
    local cQuickShotInstantDmgAoE = 0
    if wan.traitData.QuickShot.known then
        cQuickShotInstantDmg = cQuickShotInstantDmg + (nArcaneShotDmg * nQuickShotProcChance * nQuickShotDmg)

        if wan.traitData.SulfurLinedPockets.known and wan.auraData.player["buff_" .. wan.traitData.SulfurLinedPockets.traitkey] then
            local checkSulfurLinedPocketsBuffID = wan.auraData.player["buff_" .. wan.traitData.SulfurLinedPockets.traitkey].spellId
            if checkSulfurLinedPocketsBuffID == 459834 then
                local cExplosiveShotUnitOverflow = wan.AdjustSoftCapUnitOverflow(nExplosiveShotSoftCap, countValidUnit)
                local cExplosiveShotDmg = nExplosiveShotDmg * cExplosiveShotUnitOverflow
                cQuickShotInstantDmgAoE = cQuickShotInstantDmgAoE + (cExplosiveShotDmg * nSulfurLinedPockets * nQuickShotProcChance)
            end
        end
    end

    -- bloodseeker trait layer
    local cBloodseeker = 0
    if wan.traitData.Bloodseeker.known then
        local checkBloodseekerDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.spellData.KillCommand.basename]

        if not checkBloodseekerDebuff then
            cBloodseeker = cBloodseeker + nBloodseeker
        end
    end

    -- exposed flank trait layer
    local cExposedFlank = 1
    local countExposedFlank = 0
    local cExposedFlankInstantDmgAoE = 0
    if wan.traitData.ExposedFlank.known then
        local checkExposedFlankBuff = wan.auraData.player["buff_" .. wan.traitData.ExposedFlank.traitkey]
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

    -- vicious hunt trait layer
    local cViciousHunt = 0
    if wan.traitData.ViciousHunt.known and wan.auraData.player["buff_" .. wan.traitData.ViciousHunt.traitkey] then
        cViciousHunt = cViciousHunt + nViciousHunt
    end

    -- howl of the pack trait layer
    if wan.traitData.HowlofthePack.known then
        local checkHowlOfThePackBuff = wan.auraData.player["buff_" .. wan.traitData.HowlofthePack.traitkey]
        if checkHowlOfThePackBuff then
            local stacksHowlOfThePack = checkHowlOfThePackBuff.applications
            critDamageModBase = critDamageModBase + (nHowlOfThePack * stacksHowlOfThePack)
            critDamageMod = critDamageMod + (nHowlOfThePack * stacksHowlOfThePack)
        end
    end

    -- frenzied tear trait layer
    local cFrenziedTear = 1
    if wan.traitData.FrenziedTear.known and wan.auraData.player["buff_" .. wan.traitData.FrenziedTear.traitkey] then
        cFrenziedTear = cFrenziedTear + nFrenziedTear
    end

    ---- DARK RANGER TRAITS ----

    -- phantom pain trait layer
    local cPhantomPain = 0
    if wan.traitData.PhantomPain.known then
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkBlackArrowDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. wan.traitData.BlackArrow.traitkey]
            if checkBlackArrowDebuff then
                cPhantomPain = cPhantomPain + (nKillCommandDmg * cAnimalCompanion * cSerpentineRhythm * cKillerInstinct * cBasiliskCollar * cBloodshed * cFrenziedTear * nPhantomPain)
            end
        end
    end
    
    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cKillCommandCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cKillCommandBaseCritValue = wan.ValueFromCritical(wan.CritChance, nil, critDamageModBase)

    cKillCommandInstantDmg = cKillCommandInstantDmg + (nKillCommandDmg * cAnimalCompanion * cSerpentineRhythm * cKillerInstinct * cBasiliskCollar * cBloodshed * cFrenziedTear * cExposedFlank * checkPhysicalDR * cKillCommandCritValue) + (cQuickShotInstantDmg * cKillCommandBaseCritValue)  + (cViciousHunt * checkPhysicalDR * cKillCommandBaseCritValue)
    cKillCommandDotDmg = cKillCommandDotDmg + ((cAMurderOfCrows + cBloodseeker) * cKillCommandBaseCritValue)
    cKillCommandInstantDmgAoE = cKillCommandInstantDmgAoE + (cKillCleaveInstantDmgAoE * cAnimalCompanion * cSerpentineRhythm * cKillerInstinct * cBasiliskCollarAoE * cBloodshedAoE * cFrenziedTear * cKillCommandCritValue) + (cExposedFlankInstantDmgAoE * cExposedFlank * cKillCommandCritValue) + (cQuickShotInstantDmgAoE * cKillCommandBaseCritValue) + cPhantomPain
    cKillCommandDotDmgAoE = cKillCommandDotDmgAoE + (cBloodseeker * countExposedFlank * cKillCommandBaseCritValue)

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

            nViciousHunt = wan.GetTraitDescriptionNumbers(wan.traitData.ViciousHunt.entryid, { 1 })

            nArcaneShotDmg = wan.GetSpellDescriptionNumbers(wan.spellData.ArcaneShot.id, { 1 })

            nBloodseeker = wan.GetTraitDescriptionNumbers(wan.traitData.Bloodseeker.entryid, { 1 })

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

        checkDebuffs = {
            wan.spellData.BarbedShot.basename,
            wan.traitData.Laceration.traitkey,
            "SerpentSting",
            wan.traitData.AMurderofCrows.traitkey,
            "RavenousLeap",
            wan.traitData.Bloodshed.traitkey,
            wan.traitData.BlackArrow.traitkey,
        }
    end

    if event == "TRAIT_DATA_READY" then

        nGoForTheThroat = wan.GetTraitDescriptionNumbers(wan.traitData.GofortheThroat.entryid, { 1 }) * 0.01

        nSerpentineRhythm = wan.GetTraitDescriptionNumbers(wan.traitData.SerpentineRhythm.entryid, { 1 }) * 0.01

        local nQuickShotValues = wan.GetTraitDescriptionNumbers(wan.traitData.QuickShot.entryid, { 1, 2 })
        nQuickShotProcChance = nQuickShotValues[1] * 0.01
        nQuickShotDmg = nQuickShotValues[2] * 0.01

        local nExposedFlankValues = wan.GetTraitDescriptionNumbers(wan.traitData.ExposedFlank.entryid, { 1, 2 })
        nExposedFlank = nExposedFlankValues[1] * 0.01
        nExposedFlankUnitCap = nExposedFlankValues[2]

        local nKillCleaveValues = wan.GetTraitDescriptionNumbers(wan.traitData.BeastCleave.entryid, { 1, 2 })
        nKillCleave = nKillCleaveValues[1] * 0.01
        nKillCleaveAoECap = nKillCleaveValues[2]

        local nKillerInstinctValues = wan.GetTraitDescriptionNumbers(wan.traitData.KillerInstinct.entryid, { 1, 2 }, wan.traitData.KillerInstinct.rank)
        nKillerInstinct = nKillerInstinctValues[1] * 0.01
        nKillerInstinctThreshold = nKillerInstinctValues[2] * 0.01

        nBasiliskCollar = wan.GetTraitDescriptionNumbers(wan.traitData.BasiliskCollar.entryid, { 1 }, wan.traitData.BasiliskCollar.rank) * 0.01

        nPiercingFangs = wan.GetTraitDescriptionNumbers(wan.traitData.PiercingFangs.entryid, { 1 })

        nBloodshed = wan.GetTraitDescriptionNumbers(wan.traitData.Bloodshed.entryid, { 3 }) * 0.01

        nShowerOfBloodUnitCap = wan.GetTraitDescriptionNumbers(wan.traitData.ShowerofBlood.entryid, { 1 })

        nVenomousBite = wan.GetTraitDescriptionNumbers(wan.traitData.VenomousBite.entryid, { 1 }) * 0.01

        nFrenziedTear = wan.GetTraitDescriptionNumbers(wan.traitData.FrenziedTear.entryid, { 1 }) * 0.01

        nPhantomPain = wan.GetTraitDescriptionNumbers(wan.traitData.PhantomPain.entryid, { 1 }) * 0.01

        nSulfurLinedPockets = wan.GetTraitDescriptionNumbers(wan.traitData.SulfurLinedPockets.entryid, { 2 }) * 0.01

        nHowlOfThePack = wan.GetTraitDescriptionNumbers(wan.traitData.HowlofthePack.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameKillCommand, CheckAbilityValue, abilityActive)
    end
end)