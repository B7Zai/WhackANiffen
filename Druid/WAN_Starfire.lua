local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameStarfire = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init spell data
    local abilityActive = false
    local nStarfireDmg, nStarfireAoEDmg, nStarfireAoECap = 0, 0, 0
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
        or wan.auraData.player.buff_BearForm
            or not wan.IsSpellUsable(wan.spellData.Starfire.id)
        then
            wan.UpdateAbilityData(wan.spellData.Starfire.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Starfire.id)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.Starfire.basename)
            return
        end

        -- Base values
        local critChanceMod = 0
        local critDamageMod = 0

        -- add mastery layer
        local cMasteryAstralInvocationNature = 1
        local cMasteryAstralInvocationArcane = 1
        local cMasteryAstralInvocationAstral = 1
        if wan.spellData.MasteryAstralInvocation.known then
            local cMasteryAstralInvocationNatureValue = wan.auraData[wan.TargetUnitID]["debuff_" .. wan.spellData.Sunfire.basename] and nMasteryAstralInvocationNature or 0
            local cMasteryAstralInvocationArcaneValue = wan.auraData[wan.TargetUnitID]["debuff_" .. wan.spellData.Moonfire.basename] and nMasteryAstralInvocationArcane or 0
            local cMasteryAstralInvocationAstralValue = cMasteryAstralInvocationNatureValue + cMasteryAstralInvocationArcaneValue
            cMasteryAstralInvocationNature = 1 + cMasteryAstralInvocationNatureValue
            cMasteryAstralInvocationArcane = 1 + cMasteryAstralInvocationArcaneValue
            cMasteryAstralInvocationAstral = 1 + cMasteryAstralInvocationAstralValue
        end

        local cStarfireInstantDmg = nStarfireDmg * cMasteryAstralInvocationArcane
        local cStarfireDotDmg = 0

        -- Wild Surges
        if wan.traitData.WildSurges.known then
            critChanceMod = critChanceMod + nWildSurges
        end

        -- Astral Smolder
        local cAstralSmolder = 0
        if wan.traitData.AstralSmolder.known and not wan.auraData[wan.TargetUnitID]["debuff_" .. wan.traitData.AstralSmolder.traitkey] then
            cAstralSmolder = nStarfireDmg * nAstralSmolderDmg * nAstralSmolderProcChance * cMasteryAstralInvocationAstral
        end

        -- Umbral Embrace
        local cUmbralEmbrace = 1
        if wan.traitData.UmbralEmbrace.known and wan.auraData.player.buff_UmbralEclipse
            and (wan.auraData.player.buff_EclipseSolar or wan.auraData.player.buff_EclipseLunar) then
            cUmbralEmbrace = cUmbralEmbrace + nUmbralEmbraceDmg + cMasteryAstralInvocationNature

            -- Astronomical Impact
            if wan.traitData.AstronomicalImpact.known then
                critDamageMod = critDamageMod + nAstronomicalImpact
            end
        end

        -- Dream Surge
        local cDreamSurgeDmg = 0
        local cDreamSurgeCritValue = 1
        local cDreamSurgeUnitOverflow = 1
        if wan.traitData.DreamSurge.known and wan.auraData.player.buff_DreamBurst then
            cDreamSurgeCritValue = wan.ValueFromCritical(wan.CritChance)
            cDreamSurgeUnitOverflow = wan.SoftCapOverflow(nDreamSurgeSoftCap, countValidUnit)
            cDreamSurgeDmg = nDreamSurgeDmg * cDreamSurgeUnitOverflow * cMasteryAstralInvocationNature
        end

        -- Crit layer
        local cStarfireCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

        -- AoE values
        local cStarfireInstantDmgAoE = 0
        local cStarfireDotDmgAoE = 0
        if countValidUnit > 1 then

            local cStarfireUnitOverflow = wan.SoftCapOverflow(nStarfireAoECap, countValidUnit)

            for unitToken, unitGUID in pairs(idValidUnit) do

                if unitGUID ~= wan.UnitState.GUID[wan.TargetUnitID] then

                    local cMasteryAstralInvocationUnitNature = 1
                    local cMasteryAstralInvocationUnitArcane = 1
                    local cMasteryAstralInvocationUnitAstral = 1
                    if wan.spellData.MasteryAstralInvocation.known then
                        local cMasteryAstralInvocationUnitNatureValue = wan.auraData[unitToken]["debuff_" .. wan.spellData.Sunfire.basename] and nMasteryAstralInvocationNature or 0
                        local cMasteryAstralInvocationUnitArcaneValue = wan.auraData[unitToken]["debuff_" .. wan.spellData.Moonfire.basename] and nMasteryAstralInvocationArcane or 0
                        local cMasteryAstralInvocationUnitAstralValue = cMasteryAstralInvocationUnitNatureValue + cMasteryAstralInvocationUnitArcaneValue
                        cMasteryAstralInvocationUnitNature = 1 + cMasteryAstralInvocationUnitNatureValue
                        cMasteryAstralInvocationUnitArcane = 1 + cMasteryAstralInvocationUnitArcaneValue
                        cMasteryAstralInvocationUnitAstral = 1 + cMasteryAstralInvocationUnitAstralValue
                    end

                    cStarfireInstantDmgAoE = cStarfireInstantDmgAoE + (nStarfireAoEDmg * cStarfireUnitOverflow * cUmbralEmbrace * cMasteryAstralInvocationUnitArcane * cStarfireCritValue)

                    -- Astral Smolder
                    local cUnitAstralSmolder = 0
                    if wan.traitData.AstralSmolder.known and not wan.auraData[unitToken]["debuff_" .. wan.traitData.AstralSmolder.traitkey] then
                        cUnitAstralSmolder = nStarfireDmg * nAstralSmolderDmg * nAstralSmolderProcChance * cMasteryAstralInvocationUnitAstral * cStarfireCritValue 
                    end

                    local cUnitDreamSurgeDmg = 0
                    if wan.traitData.DreamSurge.known and wan.auraData.player.buff_DreamBurst then
                        cUnitDreamSurgeDmg = nDreamSurgeDmg * cDreamSurgeUnitOverflow * cMasteryAstralInvocationUnitNature * cDreamSurgeCritValue
                    end

                    cStarfireInstantDmgAoE = cStarfireInstantDmgAoE + cUnitDreamSurgeDmg
                    cStarfireDotDmgAoE = cStarfireDotDmgAoE + cUnitAstralSmolder
                end
            end
        end

        -- Cast time layer
        local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Starfire.id, wan.spellData.Starfire.castTime)

        cStarfireInstantDmg = ((cStarfireInstantDmg * cUmbralEmbrace * cStarfireCritValue) + cDreamSurgeDmg)
        cStarfireDotDmg = (cStarfireDotDmg + cAstralSmolder) * cStarfireCritValue

        local cStarfireDmg = (cStarfireInstantDmg + cStarfireDotDmg + cStarfireInstantDmgAoE + cStarfireDotDmgAoE) * castEfficiency

        -- Handle eclipse
        if wan.traitData.Eclipse.known  and not wan.auraData.player.buff_EclipseLunar then
            if wan.traitData.LunarCalling.known then
                cStarfireDmg = 0
            else
                cStarfireDmg = cStarfireDmg / countValidUnit
            end
        end

        -- Update ability data
        local abilityValue = math.floor(cStarfireDmg)  

        wan.UpdateAbilityData(wan.spellData.Starfire.basename, abilityValue, wan.spellData.Starfire.icon, wan.spellData.Starfire.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local starfireValues = wan.GetSpellDescriptionNumbers(wan.spellData.Starfire.id, { 1, 2, 3 })
            nStarfireDmg = starfireValues[1]
            nStarfireAoEDmg = starfireValues[2]
            nStarfireAoECap = 1 + starfireValues[3]

            nDreamSurgeDmg = wan.GetTraitDescriptionNumbers(wan.traitData.DreamSurge.entryid, { 2 })

            local nMasteryAstralInvocationValues = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryAstralInvocation.id, { 2, 4 })
            nMasteryAstralInvocationArcane = nMasteryAstralInvocationValues[1] * 0.01
            nMasteryAstralInvocationNature = nMasteryAstralInvocationValues[2] * 0.01

        end
    end)

    -- Set update rate based on settings & data update on traits
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Starfire.known and wan.spellData.Starfire.id
            wan.BlizzardEventHandler(frameStarfire, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameStarfire, CheckAbilityValue, abilityActive)
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
            wan.SetUpdateRate(frameStarfire, CheckAbilityValue, abilityActive)
        end
    end)
end

frameStarfire:RegisterEvent("ADDON_LOADED")
frameStarfire:SetScript("OnEvent", AddonLoad)