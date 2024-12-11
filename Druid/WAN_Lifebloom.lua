local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameLifebloom = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nLifebloomInstantHeal, nLifebloomHotHeal, nLifebloomHeal = 0, 0, 0
    local nMasteryHarmony = 0

    -- Init triat data
    local nHarmoniousBlooming = 0
    local nStrategicInfusion = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm or wan.auraData.player.buff_MoonkinForm
            or not wan.IsSpellUsable(wan.spellData.Lifebloom.id)
        then
            wan.UpdateMechanicData(wan.spellData.Lifebloom.basename)
            wan.UpdateHealingData(nil, wan.spellData.Lifebloom.basename)
            return
        end

        -- key of hot applied by this ability as key value
        local hotKey = wan.spellData.Lifebloom.basename

        local critChanceModHot = 0

        -- setting the cap for max number of targets lifebloom can apply to
        local nLifebloomCap = wan.traitData.Undergrowth.known and 2 or 1

        -- check stategic infusion trait layer
        if wan.traitData.StrategicInfusion.known and wan.auraData.player.buff_StrategicInfusion then
            local cStrategicInfusion = nStrategicInfusion
            critChanceModHot = critChanceModHot + cStrategicInfusion
        end

        -- check crit layer
        local critHotValue = wan.ValueFromCritical(wan.CritChance, critChanceModHot)

        -- Update ability data
        if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
            local _, _, idValidGroupUnit = wan.ValidGroupMembers()

            -- exit early when a lifebloom is at the target cap
            local nLifebloomCount = 0
            for groupUnitToken, _ in pairs(idValidGroupUnit) do
                if wan.auraData[groupUnitToken].buff_Lifebloom then
                    nLifebloomCount = nLifebloomCount + 1
                end
            end

            if nLifebloomCount >= nLifebloomCap then
                wan.UpdateHealingData(nil, wan.spellData.Lifebloom.basename)
                return
            end

            -- run check over all group units in range
            for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

                if idValidGroupUnit[groupUnitToken] then
                    -- check unit health
                    local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                    local cLifebloomInstantHeal = 0
                    local cLifebloomHotHeal = nLifebloomHotHeal
                    local hotPotency = wan.HotPotency(groupUnitToken, currentPercentHealth)

                    -- calculate estimated hot value
                    cLifebloomHotHeal = cLifebloomHotHeal * critHotValue * hotPotency

                    -- cache hot value on unit
                    wan.HotValue[groupUnitToken] = wan.HotValue[groupUnitToken] or {}
                    wan.HotValue[groupUnitToken][hotKey] = cLifebloomHotHeal

                    -- add mastery layer
                    if wan.spellData.MasteryHarmony.known then
                        local _, countHots = wan.GetUnitHotValues(groupUnitToken, wan.HotValue[groupUnitToken])

                        -- add base mastery mod for ability's hot
                        if wan.traitData.HarmoniousBlooming.known then
                            if countHots == 0 then
                                countHots = 1 + nHarmoniousBlooming
                            end
                        else
                            if countHots == 0 then
                                countHots = 1
                            end
                        end

                        -- Harmonious Blooming trait layer
                        if wan.traitData.HarmoniousBlooming.known and wan.auraData[groupUnitToken].buff_Lifebloom then
                            countHots = countHots + nHarmoniousBlooming
                        end

                        -- add mastery layer to hot value and update array with max hot value
                        local cMasteryHarmony = countHots > 0 and 1 + (nMasteryHarmony * countHots) or 1
                        cLifebloomHotHeal = cLifebloomHotHeal * cMasteryHarmony
                        wan.HotValue[groupUnitToken][hotKey] = cLifebloomHotHeal
                    end

                    local cLifebloomHeal = cLifebloomInstantHeal + cLifebloomHotHeal

                    if wan.auraData[groupUnitToken]["buff_" .. hotKey] then
                        local hotValue = wan.HotValue[groupUnitToken][hotKey]
                        cLifebloomHeal = cLifebloomHeal - hotValue
                    end

                    -- update healing data
                    local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cLifebloomHeal, currentPercentHealth)
                    wan.UpdateHealingData(groupUnitToken, wan.spellData.Lifebloom.basename, abilityValue, wan.spellData.Lifebloom.icon, wan.spellData.Lifebloom.name)
                else
                    wan.UpdateHealingData(groupUnitToken, wan.spellData.Lifebloom.basename)
                end
            end
        else
            -- init data for player
            local unitToken = "player"
            local playerGUID =  wan.PlayerState.GUID
            local currentPercentHealth = playerGUID and UnitPercentHealthFromGUID(playerGUID) or 0
            local hotPotency = wan.HotPotency(unitToken, currentPercentHealth)
            local cLifebloomInstantHeal = 0
            local cLifebloomHotHeal = nLifebloomHotHeal

            -- calculate estimated hot value
            cLifebloomHotHeal = cLifebloomHotHeal * critHotValue * hotPotency

            -- cache hot value on unit 
            wan.HotValue[unitToken] = wan.HotValue[unitToken] or {}
            wan.HotValue[unitToken][wan.spellData.Lifebloom.basename] = cLifebloomHotHeal

            -- add mastery layer
            if wan.spellData.MasteryHarmony.known then
                local _, countHots = wan.GetUnitHotValues(unitToken, wan.HotValue[unitToken])

                -- add base mastery mod for ability's hot
                if wan.traitData.HarmoniousBlooming.known then
                    if countHots == 0 then
                        countHots = 1 + nHarmoniousBlooming
                    end
                else
                    if countHots == 0 then
                        countHots = 1
                    end
                end

                -- Harmonious Blooming trait layer
                if wan.traitData.HarmoniousBlooming.known and wan.auraData[unitToken].buff_Lifebloom then
                    countHots = countHots + nHarmoniousBlooming
                end

                -- add mastery layer to hot value and cache hot value on unit 
                local cMasteryHarmony = countHots > 0 and 1 + (nMasteryHarmony * countHots) or 1
                cLifebloomHotHeal = cLifebloomHotHeal * cMasteryHarmony
                wan.HotValue[unitToken][wan.spellData.Lifebloom.basename] = cLifebloomHotHeal
            end

            local cLifebloomHeal = cLifebloomInstantHeal + cLifebloomHotHeal

            if wan.auraData[unitToken]["buff_" .. hotKey] then
                local hotValue = wan.HotValue[unitToken][hotKey]
                cLifebloomHeal = cLifebloomHeal - hotValue
            end

            -- update healing data
            local abilityValue = wan.UnitAbilityHealValue(unitToken, cLifebloomHeal, currentPercentHealth)
            wan.UpdateMechanicData(wan.spellData.Lifebloom.basename, abilityValue, wan.spellData.Lifebloom.icon, wan.spellData.Lifebloom.name)
        end
    end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nLifebloomValues = wan.GetSpellDescriptionNumbers(wan.spellData.Lifebloom.id, { 1, 3 })
            nLifebloomHotHeal = nLifebloomValues[1] + nLifebloomValues[2]

            nMasteryHarmony = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryHarmony.id, { 1 }) * 0.01
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Lifebloom.known and wan.spellData.Lifebloom.id
            wan.BlizzardEventHandler(frameLifebloom, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameLifebloom, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then 
            nHarmoniousBlooming = wan.GetTraitDescriptionNumbers(wan.traitData.HarmoniousBlooming.entryid, { 1 }) - 1

            nStrategicInfusion = wan.GetTraitDescriptionNumbers(wan.traitData.StrategicInfusion.entryid, { 3 })
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameLifebloom, CheckAbilityValue, abilityActive)
        end
    end)
end

frameLifebloom:RegisterEvent("ADDON_LOADED")
frameLifebloom:SetScript("OnEvent", AddonLoad)