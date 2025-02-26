local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nAimedShotDmg = 0

-- Init trait datat
local nEyesintheSky = 0
local nPenetratingShots = 0
local nTrickShots, nTrickShotsUnitCap = 0, 0
local nAspectoftheHydra, nAspectoftheHydraUnitCap = 0, 1
local nPrecisionDetonation, nExplosiveShotDmg, nExplosiveShotSoftCap = 0, 0, 0
local nKillerMark = 0
local nOhnahranWindsUnitCap = 0
local nPhantomPain = 0
local nIncendiaryAmmunition = 0
local nDoubleTapAimShot = 0
local nUnerringVision = 0

-- Ability value calculation
local function CheckAbilityValue()

    if not wan.PlayerState.Status 
        or not wan.IsSpellUsable(wan.spellData.AimedShot.id)
        or wan.UnitIsCasting("player", wan.spellData.AimedShot.name)
        or (wan.traitData.NoScope.known and wan.UnitIsCasting("player", wan.spellData.RapidFire.name))
    then
        wan.UpdateAbilityData(wan.spellData.AimedShot.basename)
        return
    end

    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.AimedShot.id, wan.spellData.AimedShot.castTime)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(wan.spellData.AimedShot.basename)
        return
    end

    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.AimedShot.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.AimedShot.basename)
        return
    end

    if wan.traitData.TrickShots.known and countValidUnit > 2 and not wan.CheckUnitBuff(nil, wan.traitData.TrickShots.traitkey) then
        wan.UpdateAbilityData(wan.spellData.AimedShot.basename)
        return
    end

    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cAimedShotInstantDmg = 0
    local cAimedShotDotDmg = 0
    local cAimedShotInstantDmgAoE = 0
    local cAimedShotDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- MARKSMAN TRAITS ----

    local cEyesintheSky = 1
    if wan.spellData.EyesintheSky.known then
        local checkSpottersMark = wan.CheckUnitDebuff(nil, "SpottersMark")
        if checkSpottersMark then
            cEyesintheSky = cEyesintheSky + nEyesintheSky

            if wan.traitData.KillerMark.known then
                critChanceMod = critChanceMod + nKillerMark
            end
        end
    end

    local cTrickShotsInstantDmgAoE = 0
    local checkTrickShotsBuff = wan.CheckUnitBuff(nil, wan.traitData.TrickShots.traitkey)
    if checkTrickShotsBuff then
        local countTrickShots = 0

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
            if nameplateGUID ~= targetGUID then
                local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                cTrickShotsInstantDmgAoE = cTrickShotsInstantDmgAoE + (nAimedShotDmg * nTrickShots * checkUnitPhysicalDR)

                countTrickShots = countTrickShots + 1

                if countTrickShots >= nTrickShotsUnitCap then break end
            end
        end
    end

    local cAspectoftheHydra = 0
    if wan.traitData.AspectoftheHydra.known then
        local countAspectoftheHydraUnit = 0

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                cAspectoftheHydra = cAspectoftheHydra + (nAimedShotDmg * nAspectoftheHydra * checkUnitPhysicalDR)

                countAspectoftheHydraUnit = countAspectoftheHydraUnit + 1

                if countAspectoftheHydraUnit >= nAspectoftheHydraUnitCap then break end
            end
        end
    end

    if wan.traitData.PenetratingShots.known then
        critDamageMod = critDamageMod + (wan.CritChance * nPenetratingShots)
        critChanceModBase = critChanceModBase + (wan.CritChance * nPenetratingShots)
    end

    local cPrecisionDetonationInstantDmgAoE = 0
    if wan.traitData.PrecisionDetonation.known then
        local checkExplosiveShotDebuff = wan.CheckUnitDebuff(nil, wan.spellData.ExplosiveShot.formattedName)
        if checkExplosiveShotDebuff then
            local cExplosiveShotUnitOverflow = wan.AdjustSoftCapUnitOverflow(nExplosiveShotSoftCap, countValidUnit)

            cPrecisionDetonationInstantDmgAoE = cPrecisionDetonationInstantDmgAoE + (nExplosiveShotDmg * cExplosiveShotUnitOverflow * nPrecisionDetonation)
        end
    end

    local cEyesintheSkyAoE = 1
    if wan.traitData.OhnahranWinds.known then

        if checkTrickShotsBuff then
            local countTrickShots = 0
            local countSpottersMarkDebuff = 0
            local cTrickShotsUnit =math.min(nTrickShotsUnitCap, countValidUnit)

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkSpottersMark = wan.CheckUnitDebuff(nameplateUnitToken, "SpottersMark")
    
                    if checkSpottersMark then
                        countSpottersMarkDebuff = countSpottersMarkDebuff + 1
                    end
    
                    countTrickShots = countTrickShots + 1
    
                    if countTrickShots >= nOhnahranWindsUnitCap then break end
                end
            end

            if countSpottersMarkDebuff > 0 then
                cEyesintheSkyAoE = cEyesintheSkyAoE + ((nEyesintheSky * countTrickShots) / cTrickShotsUnit)
            end

        elseif wan.traitData.AspectoftheHydra.known then
            local countAspectoftheHydraUnit = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkSpottersMark = wan.CheckUnitDebuff(nameplateUnitToken, "SpottersMark")

                    if checkSpottersMark then
                        cEyesintheSkyAoE = cEyesintheSkyAoE + nEyesintheSky
                    end

                    countAspectoftheHydraUnit = countAspectoftheHydraUnit + 1

                    if countAspectoftheHydraUnit >= nAspectoftheHydraUnitCap then break end
                end
            end
        end
    end

    if wan.traitData.IncendiaryAmmunition.known then
        local checkBulletstormBuff = wan.CheckUnitBuff(nil, wan.traitData.Bulletstorm.traitkey)
        if checkBulletstormBuff then
            local nBulletstormStacks = checkBulletstormBuff.applications

            critDamageMod = critDamageMod + (nIncendiaryAmmunition * nBulletstormStacks)
        end
    end

    local cDoubleTap = 1
    if wan.traitData.DoubleTap.known then
        local checkDoubleTapBuff = wan.CheckUnitBuff(nil, wan.traitData.DoubleTap.traitkey)
        if checkDoubleTapBuff then
            cDoubleTap = cDoubleTap + nDoubleTapAimShot
        end
    end

    if wan.traitData.UnerringVision.known then
        local checkTrueshotBuff = wan.CheckUnitBuff(nil, wan.spellData.Trueshot.formattedName)
        if checkTrueshotBuff then
            critDamageMod = critDamageMod + nUnerringVision
            critDamageModBase = critDamageModBase + nUnerringVision
        end
    end

    ---- DARK RANGER TRAITS ----

    local cPhantomPain = 0
    if wan.traitData.PhantomPain.known then
        local countPhantomPain = 0

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                local checkBlackArrowDebuff = wan.CheckUnitDebuff(nameplateUnitToken, wan.traitData.BlackArrow.traitkey)
                if checkBlackArrowDebuff then
                    countPhantomPain = countPhantomPain + 1
                end
            end
        end

        cPhantomPain = cPhantomPain + (nAimedShotDmg * nPhantomPain * countPhantomPain)
    end

    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cAimedShotCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cAimedShotCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cAimedShotInstantDmg = cAimedShotInstantDmg
        + (nAimedShotDmg * checkPhysicalDR * cAimedShotCritValue * cEyesintheSky * cDoubleTap)

    cAimedShotDotDmg = cAimedShotDotDmg

    cAimedShotInstantDmgAoE = cAimedShotInstantDmgAoE
        + (cTrickShotsInstantDmgAoE * cAimedShotCritValue * cEyesintheSky * cEyesintheSkyAoE * cDoubleTap)
        + (cAspectoftheHydra * cAimedShotCritValue * cEyesintheSkyAoE * cDoubleTap)
        + (cPhantomPain * checkPhysicalDR * cAimedShotCritValue * cEyesintheSky)

    cAimedShotDotDmgAoE = cAimedShotDotDmgAoE

    local cAimedShotDmg = (cAimedShotInstantDmg + cAimedShotDotDmg + cAimedShotInstantDmgAoE + cAimedShotDotDmgAoE) * castEfficiency

    -- Update ability data
    local abilityValue = math.floor(cAimedShotDmg)
    wan.UpdateAbilityData(wan.spellData.AimedShot.basename, abilityValue, wan.spellData.AimedShot.icon, wan.spellData.AimedShot.name)
end

-- Init frame 
local frameAimedShot = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nAimedShotDmg = wan.GetSpellDescriptionNumbers(wan.spellData.AimedShot.id, { 1 })

            local nExplosiveShotValues = wan.GetSpellDescriptionNumbers(wan.spellData.ExplosiveShot.id, { 2, 4 })
            nExplosiveShotDmg = nExplosiveShotValues[1]
            nExplosiveShotSoftCap = nExplosiveShotValues[2]
        end
    end)
end
frameAimedShot:RegisterEvent("ADDON_LOADED")
frameAimedShot:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.AimedShot.known and wan.spellData.AimedShot.id
        wan.BlizzardEventHandler(frameAimedShot, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameAimedShot, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nEyesintheSky = wan.GetSpellDescriptionNumbers(wan.spellData.EyesintheSky.id, { 4 }) * 0.01

        nPenetratingShots = wan.GetTraitDescriptionNumbers(wan.traitData.PenetratingShots.entryid, { 1 }) * 0.01

        local nTrickShotsValues = wan.GetTraitDescriptionNumbers(wan.traitData.TrickShots.entryid, { 2, 3 })
        nTrickShots = nTrickShotsValues[2] * 0.01
        nTrickShotsUnitCap = nTrickShotsValues[1]

        nAspectoftheHydra = wan.GetTraitDescriptionNumbers(wan.traitData.AspectoftheHydra.entryid, { 1 }) * 0.01

        nPrecisionDetonation = wan.GetTraitDescriptionNumbers(wan.traitData.PrecisionDetonation.entryid, { 1 }) * 0.01

        nKillerMark = wan.GetTraitDescriptionNumbers(wan.traitData.KillerMark.entryid, { 1 })

        nOhnahranWindsUnitCap = wan.GetTraitDescriptionNumbers(wan.traitData.OhnahranWinds.entryid, { 2 })

        nIncendiaryAmmunition = wan.GetTraitDescriptionNumbers(wan.traitData.IncendiaryAmmunition.entryid, { 1 })

        nDoubleTapAimShot = wan.GetTraitDescriptionNumbers(wan.traitData.DoubleTap.entryid, { 1 }) * 0.01

        nUnerringVision = wan.GetTraitDescriptionNumbers(wan.traitData.UnerringVision.entryid, { 2 })

        nPhantomPain = wan.GetTraitDescriptionNumbers(wan.traitData.PhantomPain.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameAimedShot, CheckAbilityValue, abilityActive)
    end
end)