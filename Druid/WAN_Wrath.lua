local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nWrathDmg = 0
local nMasteryAstralInvocationArcane = 0
local nMasteryAstralInvocationNature = 0
local nMasteryAstralInvocationAstral = 0

-- Init trait data
local nAstronomicalImpact = 0
local nWildSurges = 0
local nAstralSmolderProcChance, nAstralSmolderDmg = 0, 0
local nDreamSurgeDmg, nDreamSurgeSoftCap = 0, 0
local nUmbralEmbraceDmg = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
    or wan.auraData.player.buff_BearForm or not wan.IsSpellUsable(wan.spellData.Wrath.id)
    then
        wan.UpdateAbilityData(wan.spellData.Wrath.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Wrath.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Wrath.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    -- add mastery layer
    local cMasteryAstralInvocationNature = 1
    local cMasteryAstralInvocationArcane = 1
    local cMasteryAstralInvocationAstral = 1
    if wan.spellData.MasteryAstralInvocation.known then
        local cMasteryAstralInvocationNatureValue = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.spellData.Sunfire.basename] and nMasteryAstralInvocationNature or 0
        local cMasteryAstralInvocationArcaneValue = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.spellData.Moonfire.basename] and nMasteryAstralInvocationArcane or 0
        local cMasteryAstralInvocationAstralValue = cMasteryAstralInvocationNatureValue + cMasteryAstralInvocationArcaneValue
        cMasteryAstralInvocationNature = 1 + cMasteryAstralInvocationNatureValue
        cMasteryAstralInvocationArcane = 1 + cMasteryAstralInvocationArcaneValue
        cMasteryAstralInvocationAstral = 1 + cMasteryAstralInvocationAstralValue
    end

    local cWrathInstantDmg = nWrathDmg * cMasteryAstralInvocationNature
    local cWrathDotDmg = 0

    -- Wild Surges
    if wan.traitData.WildSurges.known then 
        critChanceMod = critChanceMod + nWildSurges
    end

    -- Astral Smolder
    local cAstralSmolder = 0
    if wan.traitData.AstralSmolder.known then
        local checkAstralSmolderDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.traitData.AstralSmolder.traitkey]

        if not checkAstralSmolderDebuff then
            cAstralSmolder = nWrathDmg * nAstralSmolderDmg * nAstralSmolderProcChance * cMasteryAstralInvocationAstral
        end
    end

    -- Umbral Embrace
    local cUmbralEmbrace = 1
    if wan.traitData.UmbralEmbrace.known and wan.auraData.player.buff_UmbralEclipse
        and (wan.auraData.player.buff_EclipseSolar or wan.auraData.player.buff_EclipseLunar) then
        cUmbralEmbrace = cUmbralEmbrace + nUmbralEmbraceDmg + cMasteryAstralInvocationArcane

        -- Astronomical Impact
        if wan.traitData.AstronomicalImpact.known then
            critDamageMod = critDamageMod + nAstronomicalImpact
        end
    end

    -- Dream Surge
    local cDreamSurgeDmg = 0
    local cDreamSurgeCritValue = 1
    if wan.traitData.DreamSurge.known and wan.auraData.player.buff_DreamBurst then

        local cDreamSurgeUnitOverflow = wan.SoftCapOverflow(nDreamSurgeSoftCap, countValidUnit)
        cDreamSurgeCritValue = wan.ValueFromCritical(wan.CritChance)
        cDreamSurgeDmg = nDreamSurgeDmg * cDreamSurgeUnitOverflow * cMasteryAstralInvocationNature

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                local cUnitMasteryAstralInvocationNature = 1
                if wan.spellData.MasteryAstralInvocation.known then
                    local cUnitMasteryAstralInvocationNatureValue = wan.auraData[nameplateUnitToken]["debuff_" .. wan.spellData.Sunfire.basename] and nMasteryAstralInvocationNature or 0
                    cUnitMasteryAstralInvocationNature = 1 + cUnitMasteryAstralInvocationNatureValue
                end

                cDreamSurgeDmg = cDreamSurgeDmg + (nDreamSurgeDmg * cUnitMasteryAstralInvocationNature * cDreamSurgeCritValue * cDreamSurgeUnitOverflow)
            end
        end
    end

    -- Cast time layer
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Wrath.id, wan.spellData.Wrath.castTime)

    -- Crit layer
    local cWrathCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cWrathInstantDmg = ((cWrathInstantDmg * cUmbralEmbrace * cWrathCritValue) + cDreamSurgeDmg) * castEfficiency
    cWrathDotDmg = cWrathDotDmg + (cAstralSmolder * cWrathCritValue * castEfficiency)

    local cWrathDmg = cWrathInstantDmg + cWrathDotDmg


    -- Update ability data
    local abilityDmg = math.floor(cWrathDmg)
    wan.UpdateAbilityData(wan.spellData.Wrath.basename, abilityDmg, wan.spellData.Wrath.icon, wan.spellData.Wrath.name)
end

-- Init frame 
local frameWrath = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nWrathDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Wrath.id, { 1 })

            nDreamSurgeDmg = wan.GetTraitDescriptionNumbers(wan.traitData.DreamSurge.entryid, { 2 })

            local nMasteryAstralInvocationValues = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryAstralInvocation.id, { 2, 4 })
            nMasteryAstralInvocationArcane = nMasteryAstralInvocationValues[1] * 0.01
            nMasteryAstralInvocationNature = nMasteryAstralInvocationValues[2] * 0.01
        end
    end)
end
frameWrath:RegisterEvent("ADDON_LOADED")
frameWrath:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Wrath.known and wan.spellData.Wrath.id
        wan.BlizzardEventHandler(frameWrath, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameWrath, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nWildSurges = wan.GetTraitDescriptionNumbers(wan.traitData.WildSurges.entryid, { 1 })

        local astralSmolderValues = wan.GetTraitDescriptionNumbers(wan.traitData.AstralSmolder.entryid, { 1, 2 })
        nAstralSmolderProcChance = astralSmolderValues[1] * 0.01
        nAstralSmolderDmg = astralSmolderValues[2] * 0.01

        nAstronomicalImpact = wan.GetTraitDescriptionNumbers(wan.traitData.AstronomicalImpact.entryid, { 1 })

        nDreamSurgeSoftCap = wan.GetTraitDescriptionNumbers(wan.traitData.DreamSurge.entryid, { 3 })

        nUmbralEmbraceDmg = wan.GetTraitDescriptionNumbers(wan.traitData.UmbralEmbrace.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameWrath, CheckAbilityValue, abilityActive)
    end
end)