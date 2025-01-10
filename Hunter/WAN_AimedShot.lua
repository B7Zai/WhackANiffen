local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nAimedShotDmg = 0

-- Init trait datat
local nPenetratingShots = 0
local nTrickShots, nTrickShotsUnitCap = 0, 0
local nCarefulAim, nCarefulAimThreshold = 0, 0
local nNightHunter = 0
local nSerpentstalkersTrickeryInstantDmg, nSerpentstalkersTrickeryDotDmg = 0, 0
local nHydrasBiteUnitCap = 0
local nLegacyOfTheWindrunners = 0
local nWailingArrowInstantDmg, nWailingArrowInstantDmgAoE = 0, 0
local nReadiness = 0
local nPhantomPain = 0

-- Ability value calculation
local function CheckAbilityValue()
    local checkTrickShots = wan.auraData.player.buff_TrickShots

    -- Early exits
    if not wan.PlayerState.Status 
        or not wan.IsSpellUsable(wan.spellData.AimedShot.id)
        or (checkTrickShots and (wan.UnitIsCasting("player", wan.spellData.RapidFire.name)
            or wan.UnitIsCasting("player", wan.spellData.Barrage.name)
            or wan.UnitIsCasting("player", wan.spellData.AimedShot.name)))
    then
        wan.UpdateAbilityData(wan.spellData.AimedShot.basename)
        return
    end


    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.AimedShot.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.AimedShot.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cAimedShotInstantDmg = 0
    local cAimedShotDotDmg = 0
    local cAimedShotInstantDmgAoE = 0
    local cAimedShotDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cPenetratingShots = 0
    if wan.traitData.PenetratingShots.known then
        cPenetratingShots = cPenetratingShots + (wan.CritChance * nPenetratingShots)
        critDamageMod = critDamageMod + (wan.CritChance * nPenetratingShots)
    end

    local cCarefulAim = 1
    if wan.traitData.CarefulAim.known then
        local targetPercentHealth = targetGUID and UnitPercentHealthFromGUID(targetGUID) or 1

        if nCarefulAimThreshold < targetPercentHealth then
            cCarefulAim = cCarefulAim + nCarefulAim
        end
    end

    local cWailingArrowInstantDmgAoE = 0
    local bWailingArrowUsable = false
    if wan.traitData.WailingArrow.known and wan.spellData.AimedShot.name == wan.traitData.WailingArrow.name then
        bWailingArrowUsable = true

        for _, nameplateGUID in pairs(idValidUnit) do
            if nameplateGUID ~= targetGUID  then
                cWailingArrowInstantDmgAoE = cWailingArrowInstantDmgAoE + nWailingArrowInstantDmgAoE
            end
        end
    end

    local cTrickShotsInstantDmgAoE = 0
    if wan.traitData.TrickShots.known and wan.auraData.player.buff_TrickShots and not bWailingArrowUsable then
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

    if wan.traitData.NightHunter.known then
        critChanceMod = critChanceMod + nNightHunter
    end

    local cSerpentstalkersTrickeryInstantDmg = 0
    local cSerpentstalkersTrickeryDotDmg = 0
    if wan.traitData.SerpentstalkersTrickery.known then
        local checkSerpentstalkersTrickeryDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken].debuff_SerpentSting
        cSerpentstalkersTrickeryInstantDmg = cSerpentstalkersTrickeryInstantDmg + nSerpentstalkersTrickeryInstantDmg

        if not checkSerpentstalkersTrickeryDebuff then
            cSerpentstalkersTrickeryDotDmg = cSerpentstalkersTrickeryDotDmg + nSerpentstalkersTrickeryDotDmg
        end
    end

    local cHydrasBiteInstantDmg = 0
    local cHydrasBiteDotDmg = 0
    if wan.traitData.HydrasBite.known then
        local cHydrasBiteUnitCap = math.min(countValidUnit, nHydrasBiteUnitCap)
        local checkHydrasBiteDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken].debuff_SerpentSting or bWailingArrowUsable
        local countHydrasBite = 0

        if checkHydrasBiteDebuff then
            cHydrasBiteInstantDmg = cHydrasBiteInstantDmg + (cSerpentstalkersTrickeryInstantDmg * cHydrasBiteUnitCap)

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID and (not wan.auraData[nameplateUnitToken].debuff_SerpentSting or bWailingArrowUsable) then

                    cHydrasBiteDotDmg = cHydrasBiteDotDmg + nSerpentstalkersTrickeryDotDmg

                    countHydrasBite = countHydrasBite + 1
                    if countHydrasBite >= nHydrasBiteUnitCap then break end
                end
            end
        end
    end

    local cLegacyOfTheWindrunners = 0
    if wan.traitData.LegacyoftheWindrunners.known then
        cLegacyOfTheWindrunners = cLegacyOfTheWindrunners + nLegacyOfTheWindrunners

        if wan.traitData.Readiness.known and wan.auraData.player.buff_Trueshot then
            cLegacyOfTheWindrunners = cLegacyOfTheWindrunners * nReadiness
        end
    end

    local checkPhysicalDR = wan.traitData.WailingArrow.known and 1 or wan.CheckUnitPhysicalDamageReduction()
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.AimedShot.id, wan.spellData.AimedShot.castTime)
    local cAimedShotCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cBaseCritValue = wan.ValueFromCritical(wan.CritChance, nil, cPenetratingShots)

    cAimedShotInstantDmg = cAimedShotInstantDmg + (((nAimedShotDmg * cCarefulAim * cAimedShotCritValue) + (cLegacyOfTheWindrunners * cBaseCritValue)) * checkPhysicalDR) + (cSerpentstalkersTrickeryInstantDmg * cBaseCritValue)
    cAimedShotDotDmg = cAimedShotDotDmg + (cSerpentstalkersTrickeryDotDmg * cBaseCritValue)
    cAimedShotInstantDmgAoE = cAimedShotInstantDmgAoE + (cTrickShotsInstantDmgAoE * cCarefulAim * cAimedShotCritValue) + ((cWailingArrowInstantDmgAoE + cHydrasBiteInstantDmg) * cBaseCritValue)

    local cPhantomPain = 0
    if wan.traitData.PhantomPain.known then
        local countPhantomPain = 0

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
            if nameplateGUID ~= targetGUID then
                local checkBlackArrowDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. wan.traitData.BlackArrow.traitkey]
                if checkBlackArrowDebuff then
                    countPhantomPain = countPhantomPain + 1
                end
            end
        end
        cPhantomPain = cPhantomPain + (nAimedShotDmg * cCarefulAim * cAimedShotCritValue * nPhantomPain * countPhantomPain)
    end

    cAimedShotDotDmgAoE = cAimedShotDotDmgAoE + ((cHydrasBiteDotDmg + cPhantomPain) * cBaseCritValue)

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

            local nSerpentstalkersTrickeryValues = wan.GetTraitDescriptionNumbers(wan.traitData.SerpentstalkersTrickery.entryid, { 3, 4 })
            nSerpentstalkersTrickeryInstantDmg = nSerpentstalkersTrickeryValues[1]
            nSerpentstalkersTrickeryDotDmg = nSerpentstalkersTrickeryValues[2]

            local nLegacyOfTheWindrunnersValues = wan.GetTraitDescriptionNumbers(wan.traitData.LegacyoftheWindrunners.entryid, { 1, 2 })
            nLegacyOfTheWindrunners = nLegacyOfTheWindrunnersValues[1] * nLegacyOfTheWindrunnersValues[2]

            local nWailingArrowValues = wan.GetTraitDescriptionNumbers(wan.traitData.WailingArrow.entryid, { 2, 3 })
            nWailingArrowInstantDmg = nWailingArrowValues[1]
            nWailingArrowInstantDmgAoE = nWailingArrowValues[2]
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
        nPenetratingShots = wan.GetTraitDescriptionNumbers(wan.traitData.PenetratingShots.entryid, { 1 }) * 0.01

        local nTrickShotsValues = wan.GetTraitDescriptionNumbers(wan.traitData.TrickShots.entryid, { 2, 3 })
        nTrickShots = nTrickShotsValues[2] * 0.01
        nTrickShotsUnitCap = nTrickShotsValues[1]

        local nCarefulAimValues = wan.GetTraitDescriptionNumbers(wan.traitData.CarefulAim.entryid, { 1, 2 })
        nCarefulAim = nCarefulAimValues[1] * 0.01
        nCarefulAimThreshold = nCarefulAimValues[2] * 0.01

        nNightHunter = wan.GetTraitDescriptionNumbers(wan.traitData.NightHunter.entryid, { 1 })

        nHydrasBiteUnitCap = wan.GetTraitDescriptionNumbers(wan.traitData.HydrasBite.entryid, { 1 })

        nReadiness = wan.GetTraitDescriptionNumbers(wan.traitData.Readiness.entryid, { 1 })

        nPhantomPain = wan.GetTraitDescriptionNumbers(wan.traitData.PhantomPain.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameAimedShot, CheckAbilityValue, abilityActive)
    end
end)