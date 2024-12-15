local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameRegrowth = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nRegrowthInstantHeal, nRegrowthHotHeal = 0, 0
    local nMasteryHarmony = 0

    -- Init trait data
    local nAbundance, nAbundanceCapValue = 0, 0
    local nImprovedRegrowth = 0
    local nNourish, nNourishMastery = 0, 0
    local nForestsFlow = 0
    local nHarmoniousBlooming = 0
    local nStrategicInfusion = 0
    local nDreamSurge = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_Prowl
            or (wan.auraData.player.buff_CatForm and not wan.auraData.player.buff_PredatorySwiftness)
            or (wan.auraData.player.buff_BearForm and not wan.auraData.player.buff_DreamofCenarius)
            or not wan.IsSpellUsable(wan.spellData.Regrowth.id)
        then
            wan.UpdateMechanicData(wan.spellData.Regrowth.basename)
            wan.UpdateHealingData(nil, wan.spellData.Regrowth.basename)
            return
        end

        -- Cast time layer
        local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Regrowth.id, wan.spellData.Regrowth.castTime)
        if castEfficiency == 0 then
            wan.UpdateMechanicData(wan.spellData.Regrowth.basename)
            wan.UpdateHealingData(nil, wan.spellData.Regrowth.basename)
            return
        end

        local critChanceModHot = 0

        local hotKey = wan.spellData.Regrowth.basename

         -- check abundance trait layer
        if wan.traitData.Abundance.known and wan.auraData.player.buff_Abundance then
            local nAbundanceStacks = wan.auraData.player.buff_Abundance.applications
            local cAbundanceCrit = nAbundance * nAbundanceStacks
            critChanceModHot  = cAbundanceCrit >= nAbundanceCapValue and nAbundanceCapValue or cAbundanceCrit
        end

        -- check stategic infusion trait layer
        if wan.traitData.StrategicInfusion.known and wan.auraData.player.buff_StrategicInfusion then
            local cAtrategicInfusion = nStrategicInfusion
            critChanceModHot = critChanceModHot + cAtrategicInfusion
        end

        local cDreamSurge = 0
        if wan.traitData.DreamSurge.known and wan.auraData.player.buff_DreamSurge then
            cDreamSurge = nDreamSurge
        end

        -- Update ability data
        if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
            local _, _, idValidGroupUnit = wan.ValidGroupMembers()

            local critHotValue = wan.ValueFromCritical(wan.CritChance, critChanceModHot)

            for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

                if idValidGroupUnit[groupUnitToken] then
                    local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                    local critChanceModInstant = 0
                    local cRegrowthInstantHeal = nRegrowthInstantHeal + cDreamSurge

                    local countHots = 0
                    if wan.spellData.MasteryHarmony.known then
                        _, countHots = wan.GetUnitHotValues(groupUnitToken, wan.HotValue[groupUnitToken])
                    end
                    
                    -- add Improved Regrowth layer
                    if wan.traitData.ImprovedRegrowth.known and wan.auraData[groupUnitToken]["buff_" .. hotKey] then
                        local cImprovedRegrowth = nImprovedRegrowth
                        critChanceModInstant = critChanceModInstant + cImprovedRegrowth
                    end

                    if wan.traitData.ForestsFlow.known and wan.auraData.player.buff_Clearcasting then
                        if wan.traitData.HarmoniousBlooming.known and wan.auraData[groupUnitToken].buff_Lifebloom then
                            countHots = countHots + nHarmoniousBlooming
                        end

                        local cMasteryHarmony = (nMasteryHarmony * countHots) or 0
                        local cForestFlow = (nNourish + (nNourish * cMasteryHarmony * nNourishMastery)) * nForestsFlow
                        cRegrowthInstantHeal = cRegrowthInstantHeal + cForestFlow
                    end

                    local critInstantValue = wan.ValueFromCritical(wan.CritChance, critChanceModInstant)
                    cRegrowthInstantHeal = nRegrowthInstantHeal * critInstantValue * wan.UnitState.LevelScale[groupUnitToken]

                    local cRegrowthHotHeal = nRegrowthHotHeal
                    local hotPotency = wan.HotPotency(groupUnitToken, currentPercentHealth, cRegrowthInstantHeal)

                    cRegrowthHotHeal = cRegrowthHotHeal * critHotValue * hotPotency * wan.UnitState.LevelScale[groupUnitToken]

                    wan.HotValue[groupUnitToken] = wan.HotValue[groupUnitToken] or {}
                    wan.HotValue[groupUnitToken][hotKey] = cRegrowthHotHeal

                    if wan.spellData.MasteryHarmony.known then
                        if countHots == 0 then countHots = 1 end

                        if wan.traitData.HarmoniousBlooming.known and wan.auraData[groupUnitToken].buff_Lifebloom then
                            countHots = countHots + nHarmoniousBlooming
                        end

                        local cMasteryHarmony = countHots > 0 and 1 + (nMasteryHarmony * countHots) or 1
                        cRegrowthHotHeal = cRegrowthHotHeal * cMasteryHarmony
                        wan.HotValue[groupUnitToken][hotKey] = cRegrowthHotHeal
                    end
                    
                    local cRegrowthHeal = cRegrowthInstantHeal + cRegrowthHotHeal

                    -- subtract healing value of ability's hot from ability's max healing value
                    if wan.auraData[groupUnitToken]["buff_" .. hotKey] then
                        local hotValue = wan.HotValue[groupUnitToken][hotKey]
                        cRegrowthHeal = cRegrowthHeal - hotValue
                    end

                    -- add cast efficiency layer
                    cRegrowthHeal = cRegrowthHeal * castEfficiency

                    local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cRegrowthHeal, currentPercentHealth)
                    wan.UpdateHealingData(groupUnitToken, wan.spellData.Regrowth.basename, abilityValue, wan.spellData.Regrowth.icon, wan.spellData.Regrowth.name)
                else
                    wan.UpdateHealingData(groupUnitToken, wan.spellData.Regrowth.basename)
                end
            end
        else
            local unitToken = "player"
            local playerGUID = wan.PlayerState.GUID
            local currentPercentHealth = playerGUID and (UnitPercentHealthFromGUID(playerGUID) or 0)

            local countHots = 0
            if wan.spellData.MasteryHarmony.known then
                _, countHots = wan.GetUnitHotValues(unitToken, wan.HotValue[unitToken])
            end

            local critChanceModInstant = 0
            local cRegrowthInstantHeal = nRegrowthInstantHeal + cDreamSurge 

            -- add Improved Regrowth layer
            if wan.traitData.ImprovedRegrowth.known and wan.auraData[unitToken]["buff_" .. hotKey] then
                local cImprovedRegrowth = nImprovedRegrowth
                critChanceModInstant = critChanceModInstant + cImprovedRegrowth
            end

            if wan.traitData.ForestsFlow.known and wan.auraData.player.buff_Clearcasting then
                if wan.traitData.HarmoniousBlooming.known and wan.auraData[unitToken].buff_Lifebloom then
                    countHots = countHots + nHarmoniousBlooming
                end

                local cMasteryHarmony = (nMasteryHarmony * countHots) or 0
                local cForestFlow = (nNourish + (nNourish * cMasteryHarmony * nNourishMastery)) * nForestsFlow
                cRegrowthInstantHeal = cRegrowthInstantHeal + cForestFlow
            end

            local critInstantValue = wan.ValueFromCritical(wan.CritChance, critChanceModInstant)
            cRegrowthInstantHeal = nRegrowthInstantHeal * critInstantValue

            local cRegrowthHotHeal = nRegrowthHotHeal
            local hotPotency = wan.HotPotency(unitToken, currentPercentHealth, cRegrowthInstantHeal)

            local critHotValue = wan.ValueFromCritical(wan.CritChance, critChanceModHot)
            cRegrowthHotHeal = cRegrowthHotHeal * critHotValue * hotPotency

            wan.HotValue[unitToken] = wan.HotValue[unitToken] or {}
            wan.HotValue[unitToken][hotKey] = cRegrowthHotHeal

            if wan.spellData.MasteryHarmony.known then
                if countHots == 0 then countHots = 1 end

                if wan.traitData.HarmoniousBlooming.known and wan.auraData[unitToken].buff_Lifebloom then
                    countHots = countHots + nHarmoniousBlooming
                end

                local cMasteryHarmony = countHots > 0 and 1 + (nMasteryHarmony * countHots) or 1
                cRegrowthHotHeal = cRegrowthHotHeal * cMasteryHarmony
                wan.HotValue[unitToken][hotKey] = cRegrowthHotHeal
            end

            local cRegrowthHeal = cRegrowthInstantHeal + cRegrowthHotHeal

            -- subtract healing value of ability's hot from ability's max healing value
            if wan.auraData[unitToken]["buff_" .. hotKey] then
                local hotValue = wan.HotValue[unitToken][hotKey]
                cRegrowthHeal = cRegrowthHeal - hotValue
            end

            -- add cast efficiency layer
            cRegrowthHeal = cRegrowthHeal * castEfficiency

            local abilityValue = wan.UnitAbilityHealValue(unitToken, cRegrowthHeal, currentPercentHealth)
            wan.UpdateMechanicData(wan.spellData.Regrowth.basename, abilityValue, wan.spellData.Regrowth.icon, wan.spellData.Regrowth.name)
        end
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local regrowthValues = wan.GetSpellDescriptionNumbers(wan.spellData.Regrowth.id, { 1, 2 })
            nRegrowthInstantHeal = regrowthValues[1]
            nRegrowthHotHeal = regrowthValues[2]

            nMasteryHarmony = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryHarmony.id, { 1 }) * 0.01

            local nNourishValues = wan.GetTraitDescriptionNumbers(wan.traitData.Nourish.entryid, { 1, 2 })
            nNourish = nNourishValues[1]
            nNourishMastery = nNourishValues[2] * 0.01

            nDreamSurge = wan.GetTraitDescriptionNumbers(wan.traitData.DreamSurge.entryid, { 3 })
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Regrowth.known and wan.spellData.Regrowth.id
            wan.BlizzardEventHandler(frameRegrowth, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameRegrowth, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then 
            local nAbundanceValues = wan.GetTraitDescriptionNumbers(wan.traitData.Abundance.entryid, { 2, 3 })
            nAbundance = nAbundanceValues[1]
            nAbundanceCapValue = nAbundanceValues[2]

            nImprovedRegrowth = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedRegrowth.entryid, { 1 })

            nForestsFlow = wan.GetTraitDescriptionNumbers(wan.traitData.ForestsFlow.entryid, { 1 }) * 0.01

            nHarmoniousBlooming = wan.GetTraitDescriptionNumbers(wan.traitData.HarmoniousBlooming.entryid, { 1 }) - 1

            nStrategicInfusion = wan.GetTraitDescriptionNumbers(wan.traitData.StrategicInfusion.entryid, { 3 })
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameRegrowth, CheckAbilityValue, abilityActive)
        end
    end)
end

frameRegrowth:RegisterEvent("ADDON_LOADED")
frameRegrowth:SetScript("OnEvent", AddonLoad)