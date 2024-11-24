local _, wan = ...

local frameStarfire = CreateFrame("Frame")
local function OnEvent(self, event, addonName)
    -- Early Exits
    if addonName ~= "WhackANiffen" or wan.PlayerState.Class ~= "DRUID" then return end

    -- Init spell data
    local abilityActive = false
    local nStarfireDmg, nStarfireAoEDmg, nStarfireAoECap = 0, 0, 0

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
        local cStarfireAoEDmg = 0
        local cStarfireDmg = nStarfireDmg

        -- AoE values
        if countValidUnit > 1 then
            local starfireUnitAoE = countValidUnit - 1
            local softCappedValidUnit = wan.AdjustSoftCapUnitOverflow(nStarfireAoECap, starfireUnitAoE)
            cStarfireAoEDmg = nStarfireAoEDmg * softCappedValidUnit
            cStarfireDmg = cStarfireDmg + cStarfireAoEDmg
        end

        -- Wild Surges
        if wan.traitData.WildSurges.known then 
            critChanceMod = critChanceMod + nWildSurges
        end

        -- Astral Smolder
        if wan.traitData.AstralSmolder.known then
            local countDebuffed = wan.CheckForDebuffAoE(wan.auraData, idValidUnit, "Astral Smolder")
            local cAstralSmolder = nStarfireDmg * nAstralSmolderDmg * nAstralSmolderProcChance * (countValidUnit - countDebuffed)
            cStarfireDmg = cStarfireDmg + cAstralSmolder
        end

        -- Umbral Embrace
        if wan.traitData.UmbralEmbrace.known and wan.auraData.player.buff_UmbralEclipse
            and (wan.auraData.player.buff_EclipseSolar or wan.auraData.player.buff_EclipseLunar) then
            local cUmbralEmbrace = (nStarfireDmg + cStarfireAoEDmg) * nUmbralEmbraceDmg
            cStarfireDmg = cStarfireDmg + cUmbralEmbrace

            -- Astronomical Impact
            if wan.traitData.AstronomicalImpact.known then
                critDamageMod = critDamageMod + nAstronomicalImpact
            end
        end

        -- Dream Surge
        if wan.traitData.DreamSurge.known and wan.auraData.player.buff_DreamBurst then
            local softCappenValidUnit = wan.AdjustSoftCapUnitOverflow(nDreamSurgeAoECap, countValidUnit)
            local cDreamSurgeDmg = nDreamSurgeDmg * softCappenValidUnit
            cStarfireDmg = cStarfireDmg + cDreamSurgeDmg
        end

        -- Cast time layer
        local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Starfire.id, wan.spellData.Starfire.castTime)
        cStarfireDmg = cStarfireDmg * castEfficiency

        -- Crit layer
        cStarfireDmg = cStarfireDmg * wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

        -- Handle eclipse
        if wan.traitData.Eclipse.known and wan.traitData.LunarCalling.known and not wan.auraData.player.buff_EclipseLunar then
            cStarfireDmg = 0
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
            nStarfireAoECap = starfireValues[3]

            nDreamSurgeDmg = wan.GetTraitDescriptionNumbers(wan.traitData.DreamSurge.entryid, { 2 })
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

            nDreamSurgeAoECap = wan.GetTraitDescriptionNumbers(wan.traitData.DreamSurge.entryid, { 3 })

            nUmbralEmbraceDmg = wan.GetTraitDescriptionNumbers(wan.traitData.UmbralEmbrace.entryid, { 1 }) * 0.01
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameStarfire, CheckAbilityValue, abilityActive)
        end
    end)
end

frameStarfire:RegisterEvent("ADDON_LOADED")
frameStarfire:SetScript("OnEvent", OnEvent)