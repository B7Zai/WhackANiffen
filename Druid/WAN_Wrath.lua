local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local aWrathData, nWrathDmg = {}, 0
local aMasteryAstralInvocation, nMasteryAstralInvocationArcane, nMasteryAstralInvocationNature = {}, 0, 0
local sMoonfire, sSunfire = "Moonfire", "Sunfire"
local sCatForm, sBearForm = "CatForm", "BearForm"

-- Init trait data
local aAstronomicalImpact, nAstronomicalImpact = {}, 0
local aWildSurges, nWildSurges = {}, 0
local aAstralSmolder, nAstralSmolderProcChance, nAstralSmolderDmg = {}, 0, 0
local aUmbralEmbrace, sEclipseSolar, sEclipseLunar, nUmbralEmbraceDmg = {}, "EclipseSolar", "EclipseLunar", 0

local bLunarCalling = false

local aDreamSurge, sDreamBurst, nDreamSurgeDmg, nDreamSurgeSoftCap = {}, "DreamBurst", 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or wan.CheckUnitBuff(nil, sCatForm)
        or wan.CheckUnitBuff(nil, sBearForm)
        or not wan.IsSpellUsable(aWrathData.id)
    then
        wan.UpdateAbilityData(aWrathData.basename)
        return
    end

    local castEfficiency = wan.CheckCastEfficiency(aWrathData.id, aWrathData.castTime)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(aWrathData.basename)
        return
    end

    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(aWrathData.id)
    if not isValidUnit then
        wan.UpdateAbilityData(aWrathData.basename)
        return
    end

    local checkSolarEclipseBuff = nil
    local checkLunarEclipseBuff = nil
    if aMasteryAstralInvocation.known then
        checkSolarEclipseBuff = wan.CheckUnitBuff(nil, sEclipseSolar)
        checkLunarEclipseBuff = wan.CheckUnitBuff(nil, sEclipseLunar)
        local castCount = wan.CheckSpellCount(aWrathData.id)

        if castCount == 1 and wan.UnitIsCasting("player", aWrathData.id) then
            wan.UpdateAbilityData(aWrathData.basename)
            return
        end

        if not bLunarCalling and countValidUnit < 2 and not checkSolarEclipseBuff and not checkLunarEclipseBuff then
            wan.UpdateAbilityData(aWrathData.basename)
            return
        end
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cWrathInstantDmg = 0
    local cWrathDotDmg = 0
    local cWrathInstantDmgAoE = 0
    local cWrathDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- BALANCE TRAITS ----
    
    local cMasteryAstralInvocation = 1
    if aMasteryAstralInvocation.known then
        local checkSunfireDebuff = wan.CheckUnitDebuff(nil, sSunfire)
        local cMasteryAstralInvocationNatureValue = checkSunfireDebuff and nMasteryAstralInvocationNature or 0

        cMasteryAstralInvocation = cMasteryAstralInvocation + cMasteryAstralInvocationNatureValue

        if aUmbralEmbrace.known then
            local checkUmbralEmbraceBuff = wan.CheckUnitBuff(nil, aUmbralEmbrace.formattedName)

            if checkUmbralEmbraceBuff and (checkSolarEclipseBuff or checkLunarEclipseBuff) then
                local checkMoonfireDebuff = wan.CheckUnitDebuff(nil, sMoonfire)
                local cMasteryAstralInvocationArcaneValue = checkMoonfireDebuff and nMasteryAstralInvocationArcane or 0

                cMasteryAstralInvocation = cMasteryAstralInvocation + cMasteryAstralInvocationArcaneValue
            end
        end
    end

    if aWildSurges.known then
        critChanceMod = critChanceMod + nWildSurges
    end

    local cAstralSmolderDotDmg = 0
    if aAstralSmolder.known then
        local checkDotPotency = wan.CheckDotPotency(nWrathDmg)

        cAstralSmolderDotDmg = cAstralSmolderDotDmg + (nWrathDmg * nAstralSmolderDmg * nAstralSmolderProcChance * checkDotPotency)
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

    local cWrathCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cWrathCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cWrathInstantDmg = cWrathInstantDmg
        + (nWrathDmg * cWrathCritValue * cMasteryAstralInvocation * cUmbralEmbrace)

    cWrathDotDmg = cWrathDotDmg
        + (cAstralSmolderDotDmg * cWrathCritValueBase * cUmbralEmbrace)

    cWrathInstantDmgAoE = cWrathInstantDmgAoE
        + (cDreamSurgeInstantDmgAoE * cWrathCritValueBase)

    cWrathDotDmgAoE = cWrathDotDmgAoE

    local cWrathDmg = (cWrathInstantDmg + cWrathDotDmg + cWrathInstantDmgAoE + cWrathDotDmgAoE) * castEfficiency

    -- Update ability data
    local abilityDmg = math.floor(cWrathDmg)
    wan.UpdateAbilityData(aWrathData.basename, abilityDmg, aWrathData.icon, aWrathData.name)
end

local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nWrathDmg = wan.GetSpellDescriptionNumbers(aWrathData.id, { 1 })

            nDreamSurgeDmg = wan.GetTraitDescriptionNumbers(aDreamSurge.entryid, { 2 }, aDreamSurge.rank)

            local nMasteryAstralInvocationValues = wan.GetSpellDescriptionNumbers(aMasteryAstralInvocation.id, { 2, 4 })
            nMasteryAstralInvocationArcane = nMasteryAstralInvocationValues[1] * 0.01
            nMasteryAstralInvocationNature = nMasteryAstralInvocationValues[2] * 0.01
        end
    end)
end

local frameWrath = CreateFrame("Frame")
frameWrath:RegisterEvent("ADDON_LOADED")
frameWrath:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        aWrathData = wan.spellData.Wrath

        abilityActive = aWrathData.known and aWrathData.id
        wan.BlizzardEventHandler(frameWrath, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameWrath, CheckAbilityValue, abilityActive)

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
        nAstralSmolderDmg = astralSmolderValues[2] * 0.01

        aAstronomicalImpact = wan.traitData.AstronomicalImpact
        nAstronomicalImpact = wan.GetTraitDescriptionNumbers(aAstronomicalImpact.entryid, { 1 }, aAstronomicalImpact.rank)

        aDreamSurge = wan.traitData.DreamSurge
        nDreamSurgeSoftCap = wan.GetTraitDescriptionNumbers(aDreamSurge.entryid, { 3 }, aDreamSurge.rank)

        aUmbralEmbrace = wan.traitData.UmbralEmbrace
        nUmbralEmbraceDmg = wan.GetTraitDescriptionNumbers(aUmbralEmbrace.entryid, { 2 }, aUmbralEmbrace.rank) * 0.01

        bLunarCalling = wan.traitData.LunarCalling.known
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameWrath, CheckAbilityValue, abilityActive)
    end
end)