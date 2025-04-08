local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nRejuvenationHotHeal = 0
local nMasteryHarmony = 0

-- Init trait data
local nThrivingVegetation = 0
local nCultivation = 0
local nHarmoniousBlooming = 2
local sGerminationKey = "RejuvenationGermination"
local nStrategicInfusion = 0
local nDreamSurge = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or wan.CheckUnitBuff(nil, wan.spellData.CatForm.formattedName)
        or wan.CheckUnitBuff(nil, wan.spellData.BearForm.formattedName)
        or wan.CheckUnitBuff(nil, wan.spellData.MoonkinForm.formattedName)
        or not wan.IsSpellUsable(wan.spellData.Rejuvenation.id)
    then
        wan.UpdateMechanicData(wan.spellData.Rejuvenation.basename)
        wan.UpdateHealingData(nil, wan.spellData.Rejuvenation.basename)
        return
    end

    -- array of hots applied by this ability as key value
    local hotKeys = { wan.spellData.Rejuvenation.basename, sGerminationKey, wan.traitData.Cultivation.traitkey }

    -- init crit layer
    local critChanceModHot = 0
    local critChanceModInstant = 0

    -- check stategic infusion trait layer
    if wan.traitData.StrategicInfusion.known and wan.auraData.player.buff_StrategicInfusion then
        local cStrategicInfusion = nStrategicInfusion
        critChanceModHot = critChanceModHot + cStrategicInfusion
    end

    --check Thriving Vegetation trait layer
    local cThrivingVegetation = 0
    if wan.traitData.ThrivingVegetation.known then
        cThrivingVegetation = nRejuvenationHotHeal * nThrivingVegetation
    end

    -- check Germination trait layer
    local cGerminationHotHeal = 0
    if wan.traitData.Germination.known then
        cGerminationHotHeal = nRejuvenationHotHeal
    end

    -- add Dream Surge trait layer
    local cDreamSurge = 0
    if wan.traitData.DreamSurge.known and wan.auraData.player.buff_DreamSurge then
        cDreamSurge = nDreamSurge
    end

    -- add crit layer
    local critHotValue = wan.ValueFromCritical(wan.CritChance, critChanceModHot)
    local critInstantValue = wan.ValueFromCritical(wan.CritChance)

    local currentTime = GetTime()

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        -- run check over all group units in range
        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then

                -- check unit health
                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1

                -- init spell value
                local cRejuvenationInstantHeal = cThrivingVegetation + cDreamSurge

                -- calculate estimated instant value
                cRejuvenationInstantHeal = cRejuvenationInstantHeal * critInstantValue * wan.UnitState.LevelScale[groupUnitToken]

                -- init spell hot value
                local cRejuvenationHotHeal = nRejuvenationHotHeal
                local hotPotency = wan.HotPotency(groupUnitToken, currentPercentHealth, cRejuvenationInstantHeal)

                -- check cultivation trait layer
                local cCultivation = 0
                if wan.traitData.Cultivation.known and currentPercentHealth >= 0.6 then
                    cCultivation = nCultivation
                end

                -- calculate estimated hot value
                cRejuvenationHotHeal = cRejuvenationHotHeal * critHotValue * hotPotency * wan.UnitState.LevelScale[groupUnitToken]
                cCultivation = cCultivation * critHotValue * hotPotency * wan.UnitState.LevelScale[groupUnitToken]
                cGerminationHotHeal = cGerminationHotHeal * critHotValue * hotPotency * wan.UnitState.LevelScale[groupUnitToken]

                -- cache hot value on unit
                wan.HotValue[groupUnitToken] = wan.HotValue[groupUnitToken] or {}
                wan.HotValue[groupUnitToken][wan.spellData.Rejuvenation.basename] = cRejuvenationHotHeal
                wan.HotValue[groupUnitToken][wan.traitData.Cultivation.traitkey] = cCultivation
                wan.HotValue[groupUnitToken][sGerminationKey] = cGerminationHotHeal

                -- add mastery layer
                if wan.spellData.MasteryHarmony.known then
                    local _, countHots = wan.GetUnitHotValues(groupUnitToken)

                    -- add base mastery mod for ability's hot
                    if countHots == 0 then countHots = 1 end

                    -- Harmonious Blooming trait layer
                    if wan.traitData.HarmoniousBlooming.known and wan.auraData[groupUnitToken].buff_Lifebloom then
                        countHots = countHots + nHarmoniousBlooming
                    end

                    -- add mastery layer to hot values and update array with max hot values
                    local cMasteryHarmony = countHots > 0 and 1 + (nMasteryHarmony * countHots) or 1
                    cRejuvenationHotHeal = cRejuvenationHotHeal * cMasteryHarmony
                    cCultivation = cCultivation * cMasteryHarmony
                    cGerminationHotHeal = cGerminationHotHeal * cMasteryHarmony
                    wan.HotValue[groupUnitToken][wan.spellData.Rejuvenation.basename] = cRejuvenationHotHeal
                    wan.HotValue[groupUnitToken][wan.traitData.Cultivation.traitkey] = cCultivation
                    wan.HotValue[groupUnitToken][sGerminationKey] = cGerminationHotHeal
                end

                -- max healing value if the ability
                local maxRejuvenationHeal = cRejuvenationInstantHeal + cRejuvenationHotHeal + cCultivation
                -- max healing value under 1 cast
                local cRejuvenationHeal = cRejuvenationInstantHeal + cRejuvenationHotHeal + cGerminationHotHeal + cCultivation

                -- subtract healing value of ability's hot from ability's max healing value
                for _, auraKey in pairs(hotKeys) do
                    local aura = wan.auraData[groupUnitToken]["buff_" .. auraKey]
                    if aura then
                        local reminingDuration = aura.expirationTime - currentTime
                        if reminingDuration < 0 then
                            wan.auraData[groupUnitToken]["buff_" .. auraKey] = nil
                        else
                            local hotValue = wan.HotValue[groupUnitToken][auraKey]
                            cRejuvenationHeal = cRejuvenationHeal - hotValue
                        end
                    end
                end

                -- cap heal values to 1 gcd
                cRejuvenationHeal = math.min(cRejuvenationHeal, maxRejuvenationHeal)

                -- update healing data
                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cRejuvenationHeal, currentPercentHealth)
                wan.UpdateHealingData(groupUnitToken, wan.spellData.Rejuvenation.basename, abilityValue, wan.spellData.Rejuvenation.icon, wan.spellData.Rejuvenation.name)
            else
                wan.UpdateHealingData(groupUnitToken, wan.spellData.Rejuvenation.basename)
            end
        end
    else
        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1

        -- init spell value
        local cRejuvenationInstantHeal = cThrivingVegetation + cDreamSurge

        -- calculate estimated instant value
        cRejuvenationInstantHeal = cRejuvenationInstantHeal * critInstantValue

        local cRejuvenationHotHeal = nRejuvenationHotHeal
        local hotPotency = wan.HotPotency(playerUnitToken, currentPercentHealth, cRejuvenationInstantHeal)

        -- check cultivation trait layer
        local cCultivation = 0
        if wan.traitData.Cultivation.known and currentPercentHealth >= 0.6 then
            cCultivation = nCultivation
        end

        -- calculate estimated hot value
        cRejuvenationHotHeal = cRejuvenationHotHeal * critHotValue * hotPotency
        cCultivation = cCultivation * critHotValue * hotPotency
        cGerminationHotHeal = cGerminationHotHeal * critHotValue * hotPotency

        -- cache hot value on unit
        wan.HotValue[playerUnitToken] = wan.HotValue[playerUnitToken] or {}
        wan.HotValue[playerUnitToken][wan.spellData.Rejuvenation.basename] = cRejuvenationHotHeal
        wan.HotValue[playerUnitToken][wan.traitData.Cultivation.traitkey] = cCultivation
        wan.HotValue[playerUnitToken][sGerminationKey] = cGerminationHotHeal

        -- add mastery layer
        if wan.spellData.MasteryHarmony.known then
            local _, countHots = wan.GetUnitHotValues(playerUnitToken)

            -- add base mastery mod for ability's hot
            if countHots == 0 then countHots = 1 end

            -- Harmonious Blooming trait layer
            if wan.traitData.HarmoniousBlooming.known and wan.auraData.player.buff_Lifebloom then
                countHots = countHots + nHarmoniousBlooming
            end

            -- add mastery layer to hot values and update array with max hot values
            local cMasteryHarmony = countHots > 0 and 1 + (nMasteryHarmony * countHots) or 1
            cRejuvenationHotHeal = cRejuvenationHotHeal * cMasteryHarmony
            cCultivation = cCultivation * cMasteryHarmony
            cGerminationHotHeal = cGerminationHotHeal * cMasteryHarmony
            wan.HotValue[playerUnitToken][wan.spellData.Rejuvenation.basename] = cRejuvenationHotHeal
            wan.HotValue[playerUnitToken][wan.traitData.Cultivation.traitkey] = cCultivation
            wan.HotValue[playerUnitToken][playerUnitToken] = cGerminationHotHeal
        end

        -- max healing value
        local maxRejuvenationHeal = cRejuvenationInstantHeal + cRejuvenationHotHeal + cCultivation
        local cRejuvenationHeal = cRejuvenationInstantHeal + cRejuvenationHotHeal + cGerminationHotHeal + cCultivation

        -- subtract healing value of ability's hot from ability's max healing value
        for _, auraKey in pairs(hotKeys) do
            local aura = wan.auraData.player["buff_" .. auraKey]
            if aura then
                local reminingDuration = aura.expirationTime - currentTime
                if reminingDuration < 0 then
                    wan.auraData.player["buff_" .. auraKey] = nil
                else
                    local hotValue = wan.HotValue[playerUnitToken][auraKey]
                    cRejuvenationHeal = cRejuvenationHeal - hotValue
                end
            end
        end

        -- cap heal values to 1 gcd
        cRejuvenationHeal = math.min(cRejuvenationHeal, maxRejuvenationHeal)

        -- update mechanics data
        local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cRejuvenationHeal, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.Rejuvenation.basename, abilityValue, wan.spellData.Rejuvenation.icon, wan.spellData.Rejuvenation.name)
    end
end

-- Init frame 
local frameRejuvenation = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nRejuvenationHotHeal = wan.GetSpellDescriptionNumbers(wan.spellData.Rejuvenation.id, { 1 })

            local nMasteryHarmonyValue = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryHarmony.id, { 1 })
            nMasteryHarmony = nMasteryHarmonyValue * 0.01

            nCultivation = wan.GetTraitDescriptionNumbers(wan.traitData.Cultivation.entryid, { 1 })

            nDreamSurge = wan.GetTraitDescriptionNumbers(wan.traitData.DreamSurge.entryid, { 3 })
        end
    end)
end
frameRejuvenation:RegisterEvent("ADDON_LOADED")
frameRejuvenation:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Rejuvenation.known and wan.spellData.Rejuvenation.id
        wan.BlizzardEventHandler(frameRejuvenation, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameRejuvenation, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nThrivingVegetation = wan.GetTraitDescriptionNumbers(wan.traitData.ThrivingVegetation.entryid, { 1 }) * 0.01
        nHarmoniousBlooming = wan.GetTraitDescriptionNumbers(wan.traitData.HarmoniousBlooming.entryid, { 1 }) - 1
        nStrategicInfusion = wan.GetTraitDescriptionNumbers(wan.traitData.StrategicInfusion.entryid, { 3 })
    end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.Rejuvenation.basename)
        else
            wan.UpdateHealingData(nil, wan.spellData.Rejuvenation.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRejuvenation, CheckAbilityValue, abilityActive)
    end
end)