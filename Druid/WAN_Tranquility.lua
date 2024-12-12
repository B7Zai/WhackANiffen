local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameTranquility = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nTranquilityInstantHeal, nTranquilityChannelTime, nTranquilityHotHeal, nTranquilitySoftCap = 0, 0, 0, 0
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
            or not wan.IsSpellUsable(wan.spellData.Tranquility.id)
        then
            wan.UpdateMechanicData(wan.spellData.Tranquility.basename)
            wan.UpdateHealingData(nil, wan.spellData.Tranquility.basename)
            return
        end       

        -- cast time layer
        local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Tranquility.id, nTranquilityChannelTime)
        if castEfficiency == 0 then
            wan.UpdateMechanicData(wan.spellData.Tranquility.basename)
            wan.UpdateHealingData(nil, wan.spellData.Tranquility.basename)
            return
        end

        local critChanceModHot = 0
        local critChanceModInstant = 0

        -- check stategic infusion trait layer
        if wan.traitData.StrategicInfusion.known and wan.auraData.player.buff_StrategicInfusion then
            local cStrategicInfusion = nStrategicInfusion
            critChanceModHot = critChanceModHot + cStrategicInfusion
        end

        -- check crit layer
        local critHotValue = wan.ValueFromCritical(wan.CritChance, critChanceModHot)
        local critInstantValue = wan.ValueFromCritical(wan.CritChance, critChanceModInstant)

        -- init data for calculation
        local _, countValidGroupUnit, idValidGroupUnit = wan.ValidGroupMembers()
        local unitsNeedHeal = 0
        wan.HealUnitCountAoE[wan.spellData.Tranquility.basename] = wan.HealUnitCountAoE[wan.spellData.Tranquility.basename] or unitsNeedHeal

        -- run check over all group units in range
        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then
                
                -- check unit health
                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1

                -- base values
                local cTranquilityInstantHeal = 0

                cTranquilityInstantHeal = nTranquilityInstantHeal * critInstantValue

                local cTranquilityHotHeal = nTranquilityHotHeal
                local hotPotency = wan.HotPotency(groupUnitToken, currentPercentHealth, cTranquilityInstantHeal)

                -- calculate estimated hot value
                cTranquilityHotHeal = cTranquilityHotHeal * critHotValue * hotPotency

                -- cache hot value on unit
                wan.HotValue[groupUnitToken] = wan.HotValue[groupUnitToken] or {}
                wan.HotValue[groupUnitToken][wan.spellData.Tranquility.basename] = cTranquilityHotHeal

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
                    cTranquilityHotHeal = cTranquilityHotHeal * cMasteryHarmony
                    wan.HotValue[groupUnitToken][wan.spellData.Tranquility.basename] = cTranquilityHotHeal
                end

                local cTranquilityHeal = cTranquilityInstantHeal + cTranquilityHotHeal

                -- subtract healing value of ability's hot from ability's max healing value
                if wan.auraData[groupUnitToken]["buff_" .. wan.spellData.Tranquility.basename] then
                    local auraStacks = wan.auraData[groupUnitToken]["buff_" .. wan.spellData.Tranquility.basename].applications
                    local hotValue = wan.HotValue[groupUnitToken][wan.spellData.Tranquility.basename]
                    cTranquilityHeal = cTranquilityHeal - (hotValue * auraStacks)
                end

                -- add cast efficiency layer
                cTranquilityHeal = cTranquilityHeal * castEfficiency

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cTranquilityHeal, currentPercentHealth, wan.HealUnitCountAoE[wan.spellData.Tranquility.basename])
                if abilityValue > 0 then unitsNeedHeal = unitsNeedHeal + 1 end
                wan.UpdateHealingData(groupUnitToken, wan.spellData.Tranquility.basename, abilityValue, wan.spellData.Tranquility.icon, wan.spellData.Tranquility.name)
            else
                wan.UpdateHealingData(groupUnitToken, wan.spellData.Tranquility.basename)
            end
        end

        wan.HealUnitCountAoE[wan.spellData.Tranquility.basename] = unitsNeedHeal
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nTranquilityValues = wan.GetSpellDescriptionNumbers(wan.spellData.Tranquility.id, { 2, 3, 4, 6 })
            nTranquilityInstantHeal = nTranquilityValues[1]
            nTranquilityChannelTime = nTranquilityValues[2]
            nTranquilityHotHeal = nTranquilityValues[3]
            nTranquilitySoftCap = nTranquilityValues[4]

            nMasteryHarmony = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryHarmony.id, { 1 }) * 0.01
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Tranquility.known and wan.spellData.Tranquility.id
            wan.BlizzardEventHandler(frameTranquility, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameTranquility, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then 
            nHarmoniousBlooming = wan.GetTraitDescriptionNumbers(wan.traitData.HarmoniousBlooming.entryid, { 1 }) - 1

            nStrategicInfusion = wan.GetTraitDescriptionNumbers(wan.traitData.StrategicInfusion.entryid, { 3 })
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameTranquility, CheckAbilityValue, abilityActive)
        end
    end)
end

frameTranquility:RegisterEvent("ADDON_LOADED")
frameTranquility:SetScript("OnEvent", AddonLoad)