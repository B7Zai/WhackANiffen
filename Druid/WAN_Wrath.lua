local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameWrath = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init spell data
    local abilityActive = false
    local nWrathDmg = 0

    -- Init trait data
    local nAstronomicalImpact = 0
    local nWildSurges = 0
    local nAstralSmolderProcChance, nAstralSmolderDmg = 0, 0
    local nDreamSurgeDmg, nDreamSurgeAoECap = 0, 0
    local nUmbralEmbraceDmg = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm
            or not wan.IsSpellUsable(wan.spellData.Wrath.id)
        then
            wan.UpdateAbilityData(wan.spellData.Wrath.basename)
            return
        end

        -- Check for valid unit
        local isValidUnit, countValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Wrath.id)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.Wrath.basename)
            return
        end

        -- Base values
        local critChanceMod = 0
        local critDamageMod = 0
        local cWrathDmg = nWrathDmg

        -- Wild Surges
        if wan.traitData.WildSurges.known then 
            critChanceMod = critChanceMod + nWildSurges
        end

        -- Astral Smolder
        if wan.traitData.AstralSmolder.known and not wan.auraData[wan.TargetUnitID].debuff_AstralSmolder then
            local cAstralSmolder = nWrathDmg * nAstralSmolderDmg * nAstralSmolderProcChance
            cWrathDmg = cWrathDmg + cAstralSmolder
        end

        -- Umbral Embrace
        if wan.traitData.UmbralEmbrace.known and wan.auraData.player.buff_UmbralEclipse
            and (wan.auraData.player.buff_EclipseSolar or wan.auraData.player.buff_EclipseLunar) then
            local cUmbralEmbrace = nWrathDmg * nUmbralEmbraceDmg
            cWrathDmg = cWrathDmg + cUmbralEmbrace
            
            -- Astronomical Impact
            if wan.traitData.AstronomicalImpact.known then
                critDamageMod = critDamageMod + nAstronomicalImpact
            end
        end

        -- Dream Surge
        if wan.traitData.DreamSurge.known and wan.auraData.player.buff_DreamBurst then
            local softCappenValidUnit = wan.AdjustSoftCapUnitOverflow(nDreamSurgeAoECap, countValidUnit)
            local cDreamSurgeDmg = nDreamSurgeDmg * softCappenValidUnit
            cWrathDmg = cWrathDmg + cDreamSurgeDmg
        end

        -- Cast time layer
        local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Wrath.id, wan.spellData.Wrath.castTime)
        cWrathDmg = cWrathDmg * castEfficiency

        -- Crit layer
        cWrathDmg = cWrathDmg * wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

        -- Handle eclipse
        if wan.traitData.Eclipse.known and not wan.auraData.player.butt_EclipseLunar then
            cWrathDmg = cWrathDmg * countValidUnit
        end

        -- Update ability data
        local abilityDmg = math.floor(cWrathDmg)

        wan.UpdateAbilityData(wan.spellData.Wrath.basename, abilityDmg, wan.spellData.Wrath.icon, wan.spellData.Wrath.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nWrathDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Wrath.id, { 1 })
            nDreamSurgeDmg = wan.GetTraitDescriptionNumbers(wan.traitData.DreamSurge.entryid, { 2 })
        end
    end)

    -- Set update rate based on settings & data update on traits
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

            nDreamSurgeAoECap = wan.GetTraitDescriptionNumbers(wan.traitData.DreamSurge.entryid, { 3 })

            nUmbralEmbraceDmg = wan.GetTraitDescriptionNumbers(wan.traitData.UmbralEmbrace.entryid, { 1 }) * 0.01
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameWrath, CheckAbilityValue, abilityActive)
        end
    end)
end

frameWrath:RegisterEvent("ADDON_LOADED")
frameWrath:SetScript("OnEvent", AddonLoad)