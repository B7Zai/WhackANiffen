local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nKillShotInstantDmg, nKillShotDotDmg, nKillShotCritDamage = 0, 0, 0

-- Init trait data
local nPenetratingShots = 0
local nAMurderOfCrows = 0
local nBansheesMarkProcChance = 0
local nImprovedDeathblow = 0
local nKillerAccuracy = 0
local nRazonFragments, nRazorFragmentsUnitCap, nRazorFragmentsAoE = 0, 0, 0
local nUnerringVision = 0
local aCulltheHerd, nCulltheHerd = {}, 0
local nSicEmUnitCap = 0
local aBleakPowder, bBleakPowder, nBleakPowder, nBleakPowderSoftCap = {}, false, 0, 0
local aUmbralReach, bUmbralReach = {}, false
local aWitheringFire, nWitheringFire, nWitheringFireHitCap = {}, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.KillShot.id)
    then
        wan.UpdateAbilityData(wan.spellData.KillShot.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, counValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.KillShot.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.KillShot.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critChanceModBase = 0
    local critDamageMod = 0
    local critDamageModBase = 0

    local cKillShotInstantDmg = 0
    local cKillShotDotDmg = 0
    local cKillShotInstantDmgAoE = 0
    local cKillShotDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[wan.TargetUnitID]

    ---- BEAST MASTERY TRAITS ----

    ---- MARKSMAN TRAITS ----

    -- penetrating shots trait layer
    if wan.traitData.PenetratingShots.known then
        critDamageModBase = critDamageModBase + (wan.CritChance * nPenetratingShots)
        critDamageMod = critDamageMod + (wan.CritChance * nPenetratingShots)
    end

    -- improved deathblow trait layer
    if wan.traitData.ImprovedDeathblow.known then
        critDamageMod = critDamageMod + nImprovedDeathblow
    end

    -- killer accuracy trait layer
    if wan.traitData.KillerAccuracy.known then
        critChanceMod = critChanceMod + nKillerAccuracy
        critDamageMod = critDamageMod + nKillerAccuracy
    end

    -- razor fragments trait layer
    local cRazorFragments = 1
    local cRazorFragmentDotDmgAoE = 0
    if wan.traitData.RazorFragments.known then
        local checkRazorFragmentsBuff = wan.CheckUnitBuff(nil, wan.traitData.RazorFragments.traitkey)
        local countRazorFragments = 0

        if checkRazorFragmentsBuff then
            cRazorFragments = cRazorFragments + nRazonFragments

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkRazorFragmentDebuff = wan.CheckUnitDebuff(nameplateUnitToken, wan.traitData.RazorFragments.traitkey)

                    if not checkRazorFragmentDebuff then
                        cRazorFragmentDotDmgAoE = cRazorFragmentDotDmgAoE + (nKillShotInstantDmg * nRazorFragmentsAoE)

                        countRazorFragments = countRazorFragments + 1

                        if countRazorFragments >= nRazorFragmentsUnitCap then break end
                    end
                end
            end
        end
    end

    if wan.traitData.UnerringVision.known then
        local checkTrueshotBuff = wan.CheckUnitBuff(nil, wan.spellData.Trueshot.formattedName)
        if checkTrueshotBuff then
            critDamageMod = critDamageMod + nUnerringVision
            critDamageModBase = critDamageModBase + nUnerringVision
        end
    end

    ---- SURVIVAL TRAITS ----

    local cCulltheHerd = 0
    if aCulltheHerd.known then
        cCulltheHerd = cCulltheHerd + (nKillShotInstantDmg * nCulltheHerd)
    end

    -- sic 'em trait layer
    local cSicEmInstantDmgAoE = 0
    if wan.traitData.SicEm.known then
        local countSicEmUnit = 0

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                local checkUnitPhysicalDR = wan.traitData.BlackArrow.known and 1 or wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                cSicEmInstantDmgAoE = cSicEmInstantDmgAoE + (nKillShotInstantDmg * checkUnitPhysicalDR)

                countSicEmUnit = countSicEmUnit + 1

                if countSicEmUnit >= nSicEmUnitCap then break end
            end
        end
    end

    ---- PACKLEADER TRAITS ----

    local cNoMercy = 0
    if wan.traitData.NoMercy.known and wan.IsPetUsable() then
        cNoMercy = cNoMercy + (nKillShotInstantDmg * 0.25)
    end

    ---- DARK RANGER TRAITS ----

    -- black arrow trait layer
    local cBlackArrowDotDmg = 0
    if wan.traitData.BlackArrow.known then
        local dotPotency = wan.CheckDotPotency(nKillShotInstantDmg, targetUnitToken)

        cBlackArrowDotDmg = cBlackArrowDotDmg + (nKillShotDotDmg * dotPotency)
    end


    local cBleakPowderInstantDmgAoE = 0
    if aBleakPowder.known then
        local cBleakPowderUnitOverflow = wan.AdjustSoftCapUnitOverflow(nBleakPowderSoftCap, counValidUnit)

        cBleakPowderInstantDmgAoE = cBleakPowderInstantDmgAoE + (nBleakPowder * cBleakPowderUnitOverflow)
    end

    local cUmbralReachDotDmgAoE = 0
    if aUmbralReach.known then

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local dotPotency = wan.CheckDotPotency(nBleakPowder, nameplateUnitToken)

                cUmbralReachDotDmgAoE = cUmbralReachDotDmgAoE + (nKillShotDotDmg * dotPotency)
            end
        end
    end

    -- banshee's mark trait layer
    local cBansheesMark = 0
    if wan.traitData.BansheesMark.known then
        cBansheesMark = cBansheesMark + (nAMurderOfCrows * nBansheesMarkProcChance)
    end

    local cWitheringFireInstantDmg = 0
    if aWitheringFire.known then
        local checkWitheringFireBuff = wan.CheckUnitBuff(nil, aWitheringFire.traitkey)
        if checkWitheringFireBuff then
            cWitheringFireInstantDmg = cWitheringFireInstantDmg + (nKillShotInstantDmg * nWitheringFire * nWitheringFireHitCap)
        end
    end

    local checkPhysicalDR = not wan.traitData.BlackArrow.known and wan.CheckUnitPhysicalDamageReduction() or 1
    local cKillShotCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cKillShitCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cKillShotInstantDmg = cKillShotInstantDmg
        + (nKillShotInstantDmg * checkPhysicalDR * cKillShotCritValue * cRazorFragments)
        + (cNoMercy * cKillShitCritValueBase)
        + (cWitheringFireInstantDmg * cKillShotCritValue * cRazorFragments)

    cKillShotDotDmg = cKillShotDotDmg
        + (cCulltheHerd * checkPhysicalDR * cKillShotCritValue)
        + (cBlackArrowDotDmg * cKillShitCritValueBase * cRazorFragments)
        + (cBansheesMark * cKillShitCritValueBase)

    cKillShotInstantDmgAoE = cKillShotInstantDmgAoE
        + (cSicEmInstantDmgAoE * cKillShotCritValue)
        + (cBleakPowderInstantDmgAoE * cKillShitCritValueBase)

    cKillShotDotDmgAoE = cKillShotDotDmgAoE
        + (cRazorFragmentDotDmgAoE * checkPhysicalDR * cKillShotCritValue * cRazorFragments)
        + (cUmbralReachDotDmgAoE * cKillShitCritValueBase)

    local cKillShotDmg = cKillShotInstantDmg + cKillShotDotDmg + cKillShotInstantDmgAoE + cKillShotDotDmgAoE

    local abilityValue = math.floor(cKillShotDmg)
    wan.UpdateAbilityData(wan.spellData.KillShot.basename, abilityValue, wan.spellData.KillShot.icon, wan.spellData.KillShot.name)
end

-- Init frame 
local frameKillShot = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nKillShotValues = wan.GetSpellDescriptionNumbers(wan.spellData.KillShot.id, { 1, 2, 3 })
            nKillShotInstantDmg = nKillShotValues[1]
            nKillShotDotDmg = wan.traitData.BlackArrow.known and nKillShotValues[2] or 0

            nAMurderOfCrows = wan.GetTraitDescriptionNumbers(wan.traitData.AMurderofCrows.entryid, { 2 })
        end
    end)
end
frameKillShot:RegisterEvent("ADDON_LOADED")
frameKillShot:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.KillShot.known and wan.spellData.KillShot.id
        wan.BlizzardEventHandler(frameKillShot, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameKillShot, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nPenetratingShots = wan.GetTraitDescriptionNumbers(wan.traitData.PenetratingShots.entryid, { 1 }) * 0.01

        nBansheesMarkProcChance = wan.GetTraitDescriptionNumbers(wan.traitData.BansheesMark.entryid, { 1 }) * 0.01

        nImprovedDeathblow = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedDeathblow.entryid, { 3 })

        nKillerAccuracy = wan.GetTraitDescriptionNumbers(wan.traitData.KillerAccuracy.entryid, { 1 })

        local nRazorFragmentsValues = wan.GetTraitDescriptionNumbers(wan.traitData.RazorFragments.entryid, { 1, 2, 3 })
        nRazonFragments = nRazorFragmentsValues[1] * 0.01
        nRazorFragmentsUnitCap = nRazorFragmentsValues[2]
        nRazorFragmentsAoE = nRazorFragmentsValues[3] * 0.01

        aCulltheHerd = wan.traitData.CulltheHerd
        nCulltheHerd = wan.GetTraitDescriptionNumbers(aCulltheHerd.entryid, { 1 }) * 0.01

        nSicEmUnitCap = wan.GetTraitDescriptionNumbers(wan.traitData.SicEm.entryid, { 2 })

        nUnerringVision = wan.GetTraitDescriptionNumbers(wan.traitData.UnerringVision.entryid, { 2 })

        aBleakPowder = wan.traitData.BleakPowder
        local nBleakPowderValues = wan.GetTraitDescriptionNumbers(aBleakPowder.entryid, { 1, 2 }, aBleakPowder.rank)
        nBleakPowder = nBleakPowderValues[1]
        nBleakPowderSoftCap = nBleakPowderValues[2]

        aUmbralReach = wan.traitData.UmbralReach

        aWitheringFire = wan.traitData.WitheringFire
        local nWitheringFireValues = wan.GetTraitDescriptionNumbers(aWitheringFire.entryid, { 2, 3, 4, 5 })
        local nWitheringFireHitCapBeastMaster = nWitheringFireValues[3]
        local nWitheringFireBeastMaster = nWitheringFireValues[4] * 0.01
        local nWitheringFireHitCapMarksmanship = nWitheringFireValues[2]
        local nWitheringFireMarksmanship = nWitheringFireValues[3] * 0.01
        nWitheringFireHitCap = wan.PlayerState.SpecializationNumber == 1 and nWitheringFireHitCapBeastMaster or wan.PlayerState.SpecializationNumber == 2 and nWitheringFireHitCapMarksmanship or 0
        nWitheringFire = wan.PlayerState.SpecializationNumber == 1 and nWitheringFireBeastMaster or  wan.PlayerState.SpecializationNumber == 2 and nWitheringFireMarksmanship or 0
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameKillShot, CheckAbilityValue, abilityActive)
    end
end)