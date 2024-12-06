local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameRejuvenation = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nRejuvenationHotHeal = 0
    local nMasteryHarmony = 0

    -- Init trait data
    local nThrivingVegetation = 0
    local nCultivation = 0
    local nHarmoniousBlooming = 2
    local sGerminationKey = "RejuvenationGermination"

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm or wan.auraData.player.buff_MoonkinForm
            or not wan.IsSpellUsable(wan.spellData.Rejuvenation.id)
        then
            wan.UpdateMechanicData(wan.spellData.Rejuvenation.basename)
            wan.UpdateHealingData(nil, wan.spellData.Rejuvenation.basename)
            return
        end

        -- base value
        local cRejuvenationInstantHeal = 0
        local cRejuvenationHotHeal = nRejuvenationHotHeal

        -- array of hots applied by this ability as key value
        local hotKeys = { wan.spellData.Rejuvenation.basename, sGerminationKey, wan.traitData.Cultivation.traitkey }

        --check Thriving Vegetation trait layer
        if wan.traitData.ThrivingVegetation.known then
            local cThrivingVegetation = nRejuvenationHotHeal * nThrivingVegetation
            cRejuvenationInstantHeal = cRejuvenationInstantHeal + cThrivingVegetation
        end

        -- check Germination trait layer
        local cGerminationHotHeal = 0
        if wan.traitData.Germination.known then
            cGerminationHotHeal = nRejuvenationHotHeal
        end

        -- check cultivation trait layer
        local cCultivation = 0
        if wan.traitData.Cultivation.known then
            cCultivation = nCultivation
        end

        local critMod = wan.ValueFromCritical(wan.CritChance)

        -- Update ability data
        if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
            local _, _, idValidGroupUnit = wan.ValidGroupMembers()

            cRejuvenationHotHeal = cRejuvenationHotHeal * critMod
            cCultivation = cCultivation * critMod
            cGerminationHotHeal = cGerminationHotHeal * critMod
            cRejuvenationInstantHeal = cRejuvenationInstantHeal * critMod

            -- run check over all group units in range
            for groupUnitToken, groupUnitGUID in pairs(idValidGroupUnit) do

                wan.HotValue[groupUnitToken] = wan.HotValue[groupUnitToken] or {}
                wan.HotValue[groupUnitToken][wan.spellData.Rejuvenation.basename] = cRejuvenationHotHeal
                wan.HotValue[groupUnitToken][wan.traitData.Cultivation.traitkey] = cCultivation
                wan.HotValue[groupUnitToken][sGerminationKey] = cGerminationHotHeal

                -- add mastery layer
                if wan.spellData.MasteryHarmony.known then
                    local _, countHots = wan.GetUnitHotValues(groupUnitToken, wan.HotValue[groupUnitToken])

                    if wan.traitData.HarmoniousBlooming.known and wan.auraData[groupUnitToken].buff_Lifebloom then
                        countHots = countHots + nHarmoniousBlooming
                    end

                    local cMasteryHarmony = countHots > 0 and 1 + (nMasteryHarmony * countHots) or 1
                    cRejuvenationHotHeal = cRejuvenationHotHeal * cMasteryHarmony
                    cCultivation = cCultivation * cMasteryHarmony
                    cGerminationHotHeal = cGerminationHotHeal * cMasteryHarmony
                    wan.HotValue[groupUnitToken][wan.spellData.Rejuvenation.basename] = cRejuvenationHotHeal
                    wan.HotValue[groupUnitToken][wan.traitData.Cultivation.traitkey] = cCultivation
                    wan.HotValue[groupUnitToken][sGerminationKey] = cGerminationHotHeal
                end

                local currentPercentHealth = (UnitPercentHealthFromGUID(groupUnitGUID) or 0)

                -- add Cultivation layer
                if currentPercentHealth >= 0.6 then
                    cCultivation = 0
                end

                -- max healing value
                local maxRejuvenationHeal = cRejuvenationInstantHeal + cRejuvenationHotHeal + cGerminationHotHeal + cCultivation 
                local cRejuvenationHeal = cRejuvenationInstantHeal + cRejuvenationHotHeal + cGerminationHotHeal + cCultivation 

                -- subtract healing value of ability's hot from ability's max healing value
                for _, auraKey in pairs(hotKeys) do
                    if wan.auraData[groupUnitToken]["buff_" .. auraKey] then
                        local hotValue = wan.HotValue[groupUnitToken][auraKey]
                        cRejuvenationHeal = cRejuvenationHeal - hotValue
                    end
                end

                -- exit early when ability doesn't contribute toward healing
                if cRejuvenationHeal / maxRejuvenationHeal < 0.5 then
                    wan.UpdateHealingData(groupUnitToken, wan.spellData.Rejuvenation.basename)
                else
                    local unitHotValues = wan.GetUnitHotValues(groupUnitToken, wan.HotValue[groupUnitToken])
                    local maxHealth = wan.UnitMaxHealth[groupUnitToken]
                    local abilityPercentageValue = (cRejuvenationHeal / maxHealth) or 0
                    local hotPercentageValue = (unitHotValues / maxHealth) or 0
                    local abilityValue = math.floor(cRejuvenationHeal) or 0

                    -- check if the value of the healing ability exceeds the unit's missing health
                    if (currentPercentHealth + abilityPercentageValue + hotPercentageValue) < 1 then
                        wan.UpdateHealingData(groupUnitToken, wan.spellData.Rejuvenation.basename, abilityValue,
                            wan.spellData.Rejuvenation.icon, wan.spellData.Rejuvenation.name)
                        -- check on units that are too lvl compared to the player
                    elseif cRejuvenationHeal > maxHealth then
                        -- convert heal scaling on player when group member is low lvl
                        local playerMaxHealth = wan.UnitMaxHealth["player"]
                        local abilityPercentageValueLowLvl = (cRejuvenationHeal / playerMaxHealth) or 0
                        local hotPercentageValueLowLvl = (unitHotValues / playerMaxHealth) or 0
                        if (currentPercentHealth + abilityPercentageValueLowLvl + hotPercentageValueLowLvl) < 1 then
                            wan.UpdateHealingData(groupUnitToken, wan.spellData.Rejuvenation.basename, abilityValue, wan.spellData.Rejuvenation.icon, wan.spellData.Rejuvenation.name)
                        end
                    else
                        wan.UpdateHealingData(groupUnitToken, wan.spellData.Rejuvenation.basename)
                    end
                end
            end
        else
            local unitToken = "player"
            local playerGUID =  wan.PlayerState.GUID

            cRejuvenationHotHeal = cRejuvenationHotHeal * critMod
            cRejuvenationInstantHeal = cRejuvenationInstantHeal * critMod
            cCultivation = cCultivation * critMod
            cGerminationHotHeal = cGerminationHotHeal * critMod

            wan.HotValue[unitToken] = wan.HotValue[unitToken] or {}
            wan.HotValue[unitToken][wan.spellData.Rejuvenation.basename] = math.floor(cRejuvenationHotHeal)
            wan.HotValue[unitToken][wan.traitData.Cultivation.traitkey] = math.floor(cCultivation)
            wan.HotValue[unitToken][sGerminationKey] = math.floor(cGerminationHotHeal)

            -- add mastery layer
            if wan.spellData.MasteryHarmony.known then
                local _, countHots = wan.GetUnitHotValues(unitToken, wan.HotValue[unitToken])

                if wan.traitData.HarmoniousBlooming.known and wan.auraData[unitToken].buff_Lifebloom then
                    countHots = countHots + nHarmoniousBlooming
                end

                local cMasteryHarmony = countHots > 0 and 1 + (nMasteryHarmony * countHots) or 1
                cRejuvenationHotHeal = cRejuvenationHotHeal + (cRejuvenationHotHeal * cMasteryHarmony)
                cCultivation = cCultivation * cMasteryHarmony
                cGerminationHotHeal = cGerminationHotHeal * cMasteryHarmony
                wan.HotValue[unitToken][wan.spellData.Rejuvenation.basename] = math.floor(cRejuvenationHotHeal)
                wan.HotValue[unitToken][wan.traitData.Cultivation.traitkey] = math.floor(cCultivation)
                wan.HotValue[unitToken][sGerminationKey] = math.floor(cGerminationHotHeal)
            end

            -- add Cultivation layer
            local currentPercentHealth = playerGUID and UnitPercentHealthFromGUID(playerGUID) or 0
            if currentPercentHealth >= 0.6 then
                cCultivation = 0
            end

            -- max healing value
            local maxRejuvenationHeal = cRejuvenationInstantHeal + cRejuvenationHotHeal + cGerminationHotHeal + cCultivation
            local cRejuvenationHeal = cRejuvenationInstantHeal + cRejuvenationHotHeal + cGerminationHotHeal + cCultivation

            -- subtract healing value of ability's hot from ability's max healing value
            for _, auraKey in pairs(hotKeys) do
                if wan.auraData[unitToken]["buff_" .. auraKey] then
                    local hotValue = wan.HotValue[unitToken][auraKey]
                    cRejuvenationHeal = cRejuvenationHeal - hotValue
                end
            end

            -- exit early when ability doesn't contribute toward healing
            if cRejuvenationHeal / maxRejuvenationHeal < 0.5 then
                wan.UpdateMechanicData(wan.spellData.Rejuvenation.basename)
            else
                local unitHotValues = wan.GetUnitHotValues(unitToken, wan.HotValue[unitToken])
                local maxHealth = wan.UnitMaxHealth[unitToken]
                local abilityPercentageValue = (cRejuvenationHeal / maxHealth) or 0
                local hotPercentageValue = (unitHotValues / maxHealth) or 0
                local abilityValue = math.floor(cRejuvenationHeal) or 0

                if (currentPercentHealth + abilityPercentageValue + hotPercentageValue) < 1 then
                    wan.UpdateMechanicData(wan.spellData.Rejuvenation.basename, abilityValue, wan.spellData.Rejuvenation.icon, wan.spellData.Rejuvenation.name)
                else
                    wan.UpdateMechanicData(wan.spellData.Rejuvenation.basename)
                end
            end
        end
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nRejuvenationHotHeal = wan.GetSpellDescriptionNumbers(wan.spellData.Rejuvenation.id, { 1 })

            local nMasteryHarmonyValue = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryHarmony.id, { 1 })
            nMasteryHarmony = nMasteryHarmonyValue * 0.01

            nCultivation = wan.GetTraitDescriptionNumbers(wan.traitData.Cultivation.entryid, { 1 })
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Rejuvenation.known and wan.spellData.Rejuvenation.id
            wan.BlizzardEventHandler(frameRejuvenation, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameRejuvenation, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then 
            nThrivingVegetation = wan.GetTraitDescriptionNumbers(wan.traitData.ThrivingVegetation.entryid, { 1 }) * 0.01
            nHarmoniousBlooming = wan.GetTraitDescriptionNumbers(wan.traitData.HarmoniousBlooming.entryid, { 1 }) - 1
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameRejuvenation, CheckAbilityValue, abilityActive)
        end
    end)
end

frameRejuvenation:RegisterEvent("ADDON_LOADED")
frameRejuvenation:SetScript("OnEvent", AddonLoad)