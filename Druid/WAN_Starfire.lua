local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local aStarfireData, nStarfireDmg, nStarfireDmgAoE, nStarfireAoECap = {}, 0, 0, 0
local aMasteryAstralInvocation, nMasteryAstralInvocationArcane, nMasteryAstralInvocationNature = {}, 0, 0
local sMoonfire, sSunfire = "Moonfire", "Sunfire"
local sCatForm, sBearForm = "CatForm", "BearForm"

-- Init trait data
local aAstronomicalImpact, nAstronomicalImpact = {}, 0
local aWildSurges, nWildSurges = {}, 0
local aAstralSmolder, nAstralSmolderProcChance, nAstralSmolder = {}, 0, 0
local aUmbralEmbrace, sEclipseSolar, sEclipseLunar, nUmbralEmbraceDmg = {}, "EclipseSolar", "EclipseLunar", 0

local bLunarCalling = false

local aDreamSurge, sDreamBurst, nDreamSurgeDmg, nDreamSurgeSoftCap = {}, "DreamBurst", 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or wan.CheckUnitBuff(nil, sCatForm)
        or wan.CheckUnitBuff(nil, sBearForm)
        or not wan.IsSpellUsable(aStarfireData.id)
    then
        wan.UpdateAbilityData(aStarfireData.basename)
        return
    end

    local castEfficiency = wan.CheckCastEfficiency(aStarfireData.id, aStarfireData.castTime)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(aStarfireData.basename)
        return
    end

    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(aStarfireData.id)
    if not isValidUnit then
        wan.UpdateAbilityData(aStarfireData.basename)
        return
    end

    local checkSolarEclipseBuff = nil
    local checkLunarEclipseBuff = nil
    if aMasteryAstralInvocation.known then
        checkSolarEclipseBuff = wan.CheckUnitBuff(nil, sEclipseSolar)
        checkLunarEclipseBuff = wan.CheckUnitBuff(nil, sEclipseLunar)

        local castCount = wan.CheckSpellCount(aStarfireData.id)
        if castCount == 1 and wan.UnitIsCasting("player", aStarfireData.id) then
            wan.UpdateAbilityData(aStarfireData.basename)
            return
        end

        if (bLunarCalling or countValidUnit > 1) and not checkSolarEclipseBuff and not checkLunarEclipseBuff then
            wan.UpdateAbilityData(aStarfireData.basename)
            return
        end
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cStarfireInstantDmg = 0
    local cStarfireDotDmg = 0
    local cStarfireInstantDmgAoE = 0
    local cStarfireDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cStarfireInstantDmgBaseAoE = 0
    local cStarfireUnitOverflow = wan.SoftCapOverflow(nStarfireAoECap, countValidUnit)
    for _, nameplateGUID in pairs(idValidUnit) do

        if nameplateGUID ~= targetGUID then
            cStarfireInstantDmgBaseAoE = cStarfireInstantDmgBaseAoE + (nStarfireDmgAoE * cStarfireUnitOverflow)
        end
    end

    ---- BALANCE TRAITS ----

    local cMasteryAstralInvocation = 1
    local cMasteryAstralInvocationAoE = 1
    if aMasteryAstralInvocation.known then
        local checkMoonfireDebuff = wan.CheckUnitDebuff(nil, sMoonfire)
        local cMasteryAstralInvocationArcaneValue = checkMoonfireDebuff and nMasteryAstralInvocationArcane or 0

        cMasteryAstralInvocation = cMasteryAstralInvocation + cMasteryAstralInvocationArcaneValue

        local checkUmbralEmbraceBuff = nil
        if aUmbralEmbrace.known then
            local checkUmbralEmbraceBuff = wan.CheckUnitBuff(nil, aUmbralEmbrace.formattedName)

            if checkUmbralEmbraceBuff and (checkSolarEclipseBuff or checkLunarEclipseBuff) then
                local checkSunfireDebuff = wan.CheckUnitDebuff(nil, sSunfire)
                local cMasteryAstralInvocationNatureValue = checkSunfireDebuff and nMasteryAstralInvocationNature or 0

                cMasteryAstralInvocation = cMasteryAstralInvocation + cMasteryAstralInvocationNatureValue
            end
        end

        local countStarfireSecondaryTargets = math.max(countValidUnit - 1, 0)
        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local checkMoonfireDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sMoonfire)
                local cMasteryAstralInvocationArcaneValue = checkMoonfireDebuff and nMasteryAstralInvocationArcane or 0

                cMasteryAstralInvocationAoE = cMasteryAstralInvocationAoE + (cMasteryAstralInvocationArcaneValue / countStarfireSecondaryTargets)

                if aUmbralEmbrace.known then
                    if checkUmbralEmbraceBuff and (checkSolarEclipseBuff or checkLunarEclipseBuff) then
                        local checkSunfireDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sSunfire)
                        local cMasteryAstralInvocationNatureValue = checkSunfireDebuff and nMasteryAstralInvocationNature or 0

                        cMasteryAstralInvocationAoE = cMasteryAstralInvocationAoE + (cMasteryAstralInvocationNatureValue / countStarfireSecondaryTargets)
                    end
                end
            end
        end
    end

    -- Wild Surges
    if wan.traitData.WildSurges.known then
        critChanceMod = critChanceMod + nWildSurges
    end

    -- Astral Smolder
    local cAstralSmolderDotDmg = 0
    local cAStralSmolderDotDmgAoE = 0
    if aAstralSmolder.known then
        cAstralSmolderDotDmg = cAstralSmolderDotDmg + (nStarfireDmg * nAstralSmolder * nAstralSmolderProcChance)

        for _, nameplateGUID in pairs(idValidUnit) do
        
            if nameplateGUID ~= targetGUID then
                cAStralSmolderDotDmgAoE = cAStralSmolderDotDmgAoE + (nStarfireDmgAoE * nAstralSmolder * nAstralSmolderProcChance)
            end
        end
    end

    local cUmbralEmbrace = 1
    if aUmbralEmbrace.known then
        local checkUmbralEclipseBuff = wan.CheckUnitBuff(nil, aUmbralEmbrace.traitkey)

        if checkUmbralEclipseBuff and (checkSolarEclipseBuff or checkLunarEclipseBuff) then
            cUmbralEmbrace = cUmbralEmbrace + nUmbralEmbraceDmg

            if aAstronomicalImpact.known then
                critDamageMod = critDamageMod + nAstronomicalImpact
            end
        end
    end

    ---- KEEPER OF THE GROVE TRAITS ----

    local cDreamSurgeInstantDmgAoE = 0
    if aDreamSurge.known then
        local checkDreamBurstBuff = wan.CheckUnitBuff(nil, sDreamBurst)

        if checkDreamBurstBuff then
            local cDreamSurgeUnitOverflow = wan.SoftCapOverflow(nDreamSurgeSoftCap, countValidUnit)

            for nameplateUnitToken, _ in pairs(idValidUnit) do

                local cMasteryAstralInvocationNature = 1
                if aMasteryAstralInvocation.known then
                    local checkSunfireDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sSunfire)
                    local nMasteryAstralInvocation = checkSunfireDebuff and nMasteryAstralInvocationNature or 0
                    cMasteryAstralInvocationNature = cMasteryAstralInvocationNature + nMasteryAstralInvocation
                end

                cDreamSurgeInstantDmgAoE = cDreamSurgeInstantDmgAoE + (nDreamSurgeDmg * cDreamSurgeUnitOverflow * cMasteryAstralInvocationNature)
            end
        end
    end

    local cStarfireCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cStarfireCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cStarfireInstantDmg = cStarfireInstantDmg
        + (nStarfireDmg * cStarfireCritValue * cMasteryAstralInvocation * cUmbralEmbrace)

    cStarfireDotDmg = cStarfireDotDmg
        + (cAstralSmolderDotDmg * cStarfireCritValueBase * cUmbralEmbrace)


    cStarfireInstantDmgAoE = cStarfireInstantDmgAoE
        + (cStarfireInstantDmgBaseAoE * cStarfireCritValue * cMasteryAstralInvocationAoE * cUmbralEmbrace)
        + (cDreamSurgeInstantDmgAoE * cStarfireCritValueBase)

    cStarfireDotDmgAoE = cStarfireDotDmgAoE
        + (cAStralSmolderDotDmgAoE * cStarfireCritValueBase * cUmbralEmbrace)

    local cStarfireDmg = (cStarfireInstantDmg + cStarfireDotDmg + cStarfireInstantDmgAoE + cStarfireDotDmgAoE) * castEfficiency

    -- Update ability data
    local abilityValue = math.floor(cStarfireDmg)
    wan.UpdateAbilityData(aStarfireData.basename, abilityValue, aStarfireData.icon, aStarfireData.name)
end

-- Init frame 
local frameStarfire = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local starfireValues = wan.GetSpellDescriptionNumbers(aStarfireData.id, { 1, 2, 3 })
            nStarfireDmg = starfireValues[1]
            nStarfireDmgAoE = starfireValues[2]
            nStarfireAoECap = 1 + starfireValues[3]

            nDreamSurgeDmg = wan.GetTraitDescriptionNumbers(aDreamSurge.entryid, { 2 }, aDreamSurge.rank)

            local nMasteryAstralInvocationValues = wan.GetSpellDescriptionNumbers(aMasteryAstralInvocation.id, { 2, 4 })
            nMasteryAstralInvocationArcane = nMasteryAstralInvocationValues[1] * 0.01
            nMasteryAstralInvocationNature = nMasteryAstralInvocationValues[2] * 0.01

        end
    end)
end
frameStarfire:RegisterEvent("ADDON_LOADED")
frameStarfire:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings & data update on traits
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        aStarfireData = wan.spellData.Starfire

        abilityActive = aStarfireData.known and aStarfireData.id
        wan.BlizzardEventHandler(frameStarfire, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameStarfire, CheckAbilityValue, abilityActive)

        sCatForm = wan.spellData.CatForm.formattedName
        sBearForm = wan.spellData.BearForm.formattedName

        aMasteryAstralInvocation = wan.spellData.MasteryAstralInvocation
        sMoonfire = wan.spellData.Moonfire.formattedName
        sSunfire = wan.spellData.Sunfire.formattedName
    end

    if event == "TRAIT_DATA_READY" then
        aWildSurges = wan.traitData.WildSurges
        nWildSurges = wan.GetTraitDescriptionNumbers(aWildSurges.entryid, { 1 }, aWildSurges.rank)

        aAstralSmolder = wan.traitData.AstralSmolder
        local astralSmolderValues = wan.GetTraitDescriptionNumbers(aAstralSmolder.entryid, { 1, 2 }, aAstralSmolder.rank)
        nAstralSmolderProcChance = astralSmolderValues[1] * 0.01
        nAstralSmolder = astralSmolderValues[2] * 0.01

        aAstronomicalImpact = wan.traitData.AstronomicalImpact
        nAstronomicalImpact = wan.GetTraitDescriptionNumbers(aAstronomicalImpact.entryid, { 1 }, aAstronomicalImpact.rank)

        aDreamSurge = wan.traitData.DreamSurge
        nDreamSurgeSoftCap = wan.GetTraitDescriptionNumbers(aDreamSurge.entryid, { 3 }, aDreamSurge.rank)

        aUmbralEmbrace = wan.traitData.UmbralEmbrace
        nUmbralEmbraceDmg = wan.GetTraitDescriptionNumbers(aUmbralEmbrace.entryid, { 2 }, aUmbralEmbrace.rank) * 0.01

        bLunarCalling = wan.traitData.LunarCalling.known
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameStarfire, CheckAbilityValue, abilityActive)
    end
end)