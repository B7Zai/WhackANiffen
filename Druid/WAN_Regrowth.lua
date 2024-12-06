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

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_Prowl
            or (wan.auraData.player.buff_CatForm and not wan.auraData.player.buff_PredatorySwiftness)
            or (wan.auraData.player.buff_BearForm and not wan.auraData.player.buff_DreamofCenarius)
            or not wan.IsSpellUsable(wan.spellData.Regrowth.id)
        then
            wan.UpdateMechanicData(wan.spellData.Regrowth.basename)
            wan.GroupUnitHealThreshold(nil, wan.spellData.Regrowth.basename)
            return
        end

        -- Cast time layer
        local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Regrowth.id, wan.spellData.Regrowth.castTime)

        local cAbundance = 0
        if wan.traitData.Abundance.known and wan.auraData.player.buff_Abundance then
            local nAbundanceStacks = wan.auraData.player.buff_Abundance.applications
            local cAbundanceCrit = nAbundance * nAbundanceStacks
            cAbundance = cAbundanceCrit >= nAbundanceCapValue and nAbundanceCapValue or cAbundanceCrit
        end

        -- Crit layer
        local critHotValue = wan.ValueFromCritical(wan.CritChance, cAbundance)
        local critInstantCheck = wan.ValueFromCritical(wan.CritChance)

        -- Update ability data
        if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then

            local _, _, idValidGroupUnit = wan.ValidGroupMembers()

            for groupUnitToken, groupUnitGUID in pairs(idValidGroupUnit) do

                local hotKey = "buff_" .. wan.spellData.Rejuvenation.basename
                local cRegrowthHotHeal = nRegrowthHotHeal * critHotValue
                
                wan.HotValue[groupUnitToken] = wan.HotValue[groupUnitToken] or {}
                wan.HotValue[groupUnitToken][hotKey] = math.floor(cRegrowthHotHeal)

                if wan.spellData.MasteryHarmony.known then
                    local _, countHots = wan.GetUnitHotValues(groupUnitToken, wan.HotValue[groupUnitToken])
                    local cMasteryHarmony = nMasteryHarmony * countHots
                    cRegrowthHotHeal = cRegrowthHotHeal * cMasteryHarmony
                    wan.HotValue[groupUnitToken][hotKey] = math.floor(cRegrowthHotHeal)
                end

                local critInstantValue = 0
                if wan.traitData.ImprovedRegrowth.known and wan.auraData[groupUnitToken][hotKey] then
                    local cImprovedRegrowth = nImprovedRegrowth
                    critInstantValue = critInstantValue + cImprovedRegrowth
                end

                local critInstant = wan.ValueFromCritical(wan.CritChance, critInstantValue)
                local cRegrowthInstantHeal = nRegrowthInstantHeal * critInstant

                local baseRegrowthHeal = cRegrowthInstantHeal + cRegrowthHotHeal
                local cRegrowthHeal = cRegrowthInstantHeal + cRegrowthHotHeal

                -- subtract healing value of ability's hot from ability's max healing value
                if wan.auraData[groupUnitToken][hotKey] then
                    local hotValue = wan.HotValue[groupUnitToken][hotKey]
                    cRegrowthHeal = cRegrowthHeal - hotValue
                end

                -- exit early when ability doesn't contribute toward healing
                if cRegrowthHeal / baseRegrowthHeal < 0.5 then
                    wan.UpdateHealingData(groupUnitToken, wan.spellData.Regrowth.basename)
                    break
                end

                local unitHotValues = wan.GetUnitHotValues(groupUnitToken, wan.HotValue[groupUnitToken])

                -- check health of the unit
                local currentPercentHealth = (UnitPercentHealthFromGUID(groupUnitGUID) or 0)
                local maxHealth = wan.UnitMaxHealth[groupUnitToken]
                local abilityPercentageValue = (cRegrowthHeal / maxHealth) or 0
                local hotPercentageValue = (unitHotValues / maxHealth) or 0
                local abilityValue = math.floor(cRegrowthHeal) or 0

                -- check if the value of the healing ability exceeds the unit's missing health
                if (currentPercentHealth + abilityPercentageValue + hotPercentageValue) < 1 then
                    wan.UpdateHealingData(groupUnitToken, wan.spellData.Regrowth.basename, abilityValue, wan.spellData.Regrowth.icon, wan.spellData.Regrowth.name)

                    -- check on units that are too lvl compared to the player
                elseif cRegrowthHeal > maxHealth then
                    -- convert heal scaling on player when group member is low lvl
                    local playerMaxHealth = wan.UnitMaxHealth["player"]
                    local abilityPercentageValueLowLvl = (cRegrowthHeal / playerMaxHealth) or 0
                    local hotPercentageValueLowLvl = (unitHotValues / playerMaxHealth) or 0
                    if (currentPercentHealth + abilityPercentageValueLowLvl + hotPercentageValueLowLvl) < 1 then
                        wan.UpdateHealingData(groupUnitToken, wan.spellData.Regrowth.basename, abilityValue, wan.spellData.Regrowth.icon, wan.spellData.Regrowth.name)
                    end
                end
            end
        else
            local cRegrowthInstantHeal = nRegrowthInstantHeal * critInstantCheck
            local cRegrowthHotHeal = nRegrowthHotHeal * critHotValue
            -- Base values
            local cRegrowtHotHeal = wan.auraData.player.buff_Regrowth and cRegrowthHotHeal or 0
            local cRegrowthHeal = (cRegrowthInstantHeal + cRegrowtHotHeal) * castEfficiency
            cRegrowthHeal = not wan.auraData.player.buff_FrenziedRegeneration and wan.HealThreshold() > cRegrowthHeal and cRegrowthHeal or 0

            local abilityValue = math.floor(cRegrowthHeal) or 0
            wan.UpdateMechanicData(wan.spellData.Regrowth.basename, abilityValue, wan.spellData.Regrowth.icon, wan.spellData.Regrowth.name)
        end
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local regrowthValues = wan.GetSpellDescriptionNumbers(wan.spellData.Regrowth.id, { 1, 2 })
            nRegrowthInstantHeal = regrowthValues[1]
            nRegrowthHotHeal = regrowthValues[2]

            local nMasteryHarmonyValue = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryHarmony.id, { 1 })
            nMasteryHarmony = 1 + (nMasteryHarmonyValue * 0.01)
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
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameRegrowth, CheckAbilityValue, abilityActive)
        end
    end)
end

frameRegrowth:RegisterEvent("ADDON_LOADED")
frameRegrowth:SetScript("OnEvent", AddonLoad)