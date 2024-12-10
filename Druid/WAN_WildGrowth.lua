local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameWildGrowth = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nWildGrowthInstantHeal, nWildGrowthHotHeal, nWildGrowthUnitCap = 0, 0, 5
    local nMasteryHarmony = 0

    -- Init triat data
    local nHarmoniousBlooming = 0
    local nStrategicInfusion = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm or wan.auraData.player.buff_MoonkinForm
        or not wan.PlayerState.InGroup or not wan.PlayerState.InHealerMode
            or not wan.IsSpellUsable(wan.spellData.WildGrowth.id)
        then
            wan.UpdateMechanicData(wan.spellData.WildGrowth.basename)
            wan.UpdateHealingData(nil, wan.spellData.WildGrowth.basename)
            return
        end

        local critChanceModHot = 0

        local cWildGrowthUnitCap = nWildGrowthUnitCap
        if wan.traitData.ImprovedWildGrowth.known then
            cWildGrowthUnitCap = cWildGrowthUnitCap + 1
        end

        if wan.auraData.player.buff_IncarnationTreeofLife then
            cWildGrowthUnitCap = cWildGrowthUnitCap + 2
        end

        -- check stategic infusion trait layer
        if wan.traitData.StrategicInfusion.known and wan.auraData.player.buff_StrategicInfusion then
            local cStrategicInfusion = nStrategicInfusion
            critChanceModHot = critChanceModHot + cStrategicInfusion
        end

        -- cast time layer
        local castEfficiency = wan.CheckCastEfficiency(wan.spellData.WildGrowth.id, wan.spellData.WildGrowth.castTime)

        -- array of hots applied by this ability as key value
        local hotKey = wan.spellData.WildGrowth.basename

        -- check crit layer
        local critHotValue = wan.ValueFromCritical(wan.CritChance, critChanceModHot)

        -- init data for calculation
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()
        local unitsNeedHeal = 0
        wan.HealUnitCountAoE[hotKey] = wan.HealUnitCountAoE[hotKey] or unitsNeedHeal

        -- run check over all group units in range
        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then
                -- check unit health
                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1

                -- base values
                local cWildGrowthInstantHeal = 0
                local critChanceModInstant = 0
                local cWildGrowthHotHeal = nWildGrowthHotHeal
                local hotPotency = wan.HotPotency(groupUnitToken, currentPercentHealth)

                -- calculate estimated hot value
                cWildGrowthHotHeal = cWildGrowthHotHeal * critHotValue * hotPotency

                -- cache hot value on unit
                wan.HotValue[groupUnitToken] = wan.HotValue[groupUnitToken] or {}
                wan.HotValue[groupUnitToken][hotKey] = cWildGrowthHotHeal

                -- add mastery layer
                if wan.spellData.MasteryHarmony.known then
                    local _, countHots = wan.GetUnitHotValues(groupUnitToken, wan.HotValue[groupUnitToken])

                    -- add base mastery mod for ability's hot
                    if countHots == 0 then countHots = 1 end

                    -- Harmonious Blooming trait layer
                    if wan.traitData.HarmoniousBlooming.known and wan.auraData[groupUnitToken].buff_Lifebloom then
                        countHots = countHots + nHarmoniousBlooming
                    end

                    -- add mastery layer to hot value and update array with max hot value
                    local cMasteryHarmony = countHots > 0 and 1 + (nMasteryHarmony * countHots) or 1
                    cWildGrowthHotHeal = cWildGrowthHotHeal * cMasteryHarmony
                    wan.HotValue[groupUnitToken][hotKey] = cWildGrowthHotHeal
                end

                -- max healing values
                local maxWildGrowthHeal = cWildGrowthInstantHeal + cWildGrowthHotHeal
                local cWildGrowthHeal = cWildGrowthInstantHeal + cWildGrowthHotHeal

                -- subtract healing value of ability's hot from ability's max healing value
                if wan.auraData[groupUnitToken]["buff_" .. hotKey] then
                    local hotValue = wan.HotValue[groupUnitToken][hotKey]
                    cWildGrowthHeal = cWildGrowthHeal - hotValue
                end

                cWildGrowthHeal = cWildGrowthHeal * castEfficiency

                -- exit early when ability doesn't contribute toward healing
                if cWildGrowthHeal / maxWildGrowthHeal < 0.5 then
                    wan.UpdateHealingData(groupUnitToken, wan.spellData.WildGrowth.basename)
                else
                    local unitHotValues = wan.GetUnitHotValues(groupUnitToken, wan.HotValue[groupUnitToken])
                    local maxHealth = wan.UnitMaxHealth[groupUnitToken]
                    local abilityPercentageValue = (cWildGrowthHeal / maxHealth) or 0
                    local hotPercentageValue = (unitHotValues / maxHealth) or 0
                    local abilityValue = (math.floor(cWildGrowthHeal) or 0) * wan.HealUnitCountAoE[hotKey]

                    -- check if the value of the healing ability exceeds the unit's missing health
                    if (currentPercentHealth + abilityPercentageValue + hotPercentageValue) < 1 then
                        unitsNeedHeal = unitsNeedHeal + 1
                        wan.UpdateHealingData(groupUnitToken, wan.spellData.WildGrowth.basename, abilityValue,
                            wan.spellData.WildGrowth.icon, wan.spellData.WildGrowth.name)

                        -- check on units that are too lvl compared to the player
                    elseif cWildGrowthHeal > maxHealth then
                        unitsNeedHeal = unitsNeedHeal + 1

                        -- convert heal scaling on player when group member is low lvl
                        local playerMaxHealth = wan.UnitMaxHealth["player"]
                        local abilityPercentageValueLowLvl = (cWildGrowthHeal / playerMaxHealth) or 0
                        local hotPercentageValueLowLvl = (unitHotValues / playerMaxHealth) or 0
                        if (currentPercentHealth + abilityPercentageValueLowLvl + hotPercentageValueLowLvl) < 1 then
                            wan.UpdateHealingData(groupUnitToken, wan.spellData.WildGrowth.basename, abilityValue,
                                wan.spellData.WildGrowth.icon, wan.spellData.WildGrowth.name)
                        end
                    else
                        wan.UpdateHealingData(groupUnitToken, wan.spellData.WildGrowth.basename)
                    end
                end
            else
                wan.UpdateHealingData(groupUnitToken, wan.spellData.WildGrowth.basename)
            end
        end

        if unitsNeedHeal > cWildGrowthUnitCap then
            unitsNeedHeal = cWildGrowthUnitCap
        end
        wan.HealUnitCountAoE[hotKey] = unitsNeedHeal
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nWildGrowthHotHeal = wan.GetSpellDescriptionNumbers(wan.spellData.WildGrowth.id, { 3 })

            nMasteryHarmony = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryHarmony.id, { 1 }) * 0.01
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.WildGrowth.known and wan.spellData.WildGrowth.id
            wan.BlizzardEventHandler(frameWildGrowth, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameWildGrowth, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then 
            nHarmoniousBlooming = wan.GetTraitDescriptionNumbers(wan.traitData.HarmoniousBlooming.entryid, { 1 }) - 1

            nStrategicInfusion = wan.GetTraitDescriptionNumbers(wan.traitData.StrategicInfusion.entryid, { 3 })
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameWildGrowth, CheckAbilityValue, abilityActive)
        end
    end)
end

frameWildGrowth:RegisterEvent("ADDON_LOADED")
frameWildGrowth:SetScript("OnEvent", AddonLoad)