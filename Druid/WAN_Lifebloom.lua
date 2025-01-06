local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nLifebloomInstantHeal, nLifeBloomHotHealFraction, nLifebloomHotHeal, nLifebloomHotDuration, nLifebloomHotTickRate = 0, 0, 0, 0, 1
local nMasteryHarmony = 0

-- Init triat data
local nHarmoniousBlooming = 0
local nStrategicInfusion = 0
local nBuddingLeaves = 0
local nPhotosynthesisProcChance = 0
local nDreamSurge = 0

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
    local critChanceModInstant = 0

    -- setting the cap for max number of targets lifebloom can apply to
    local nLifebloomCap = wan.traitData.Undergrowth.known and 2 or 1

    -- check stategic infusion trait layer
    if wan.traitData.StrategicInfusion.known and wan.auraData.player.buff_StrategicInfusion then
        local cStrategicInfusion = nStrategicInfusion
        critChanceModHot = critChanceModHot + cStrategicInfusion
    end

    -- check crit layer
    local critHotValue = wan.ValueFromCritical(wan.CritChance, critChanceModHot)
    local critInstantValue = wan.ValueFromCritical(wan.CritChance, critChanceModInstant)

    -- photosynthesis trait layer
    local cPhotosynthesisHeal = 0
    if wan.traitData.Photosynthesis.known then
        local nLifebloomHotTickModifier = wan.Haste * 0.01
        local nLifebloomHotTickRateMod = nLifebloomHotTickRate / (1 + nLifebloomHotTickModifier)
        local nLifebloomTickNumber = nLifebloomHotDuration / nLifebloomHotTickRateMod
        cPhotosynthesisHeal = nLifebloomTickNumber * nPhotosynthesisProcChance * nLifebloomInstantHeal
    end

    -- budding leaves trait layer
    local cBuddingLeaves = 0
    if wan.traitData.BuddingLeaves.known then
        cBuddingLeaves = nLifeBloomHotHealFraction * nBuddingLeaves
    end

    -- dream surge trait layer
    local cDreamSurge = 0
    if wan.traitData.DreamSurge.known and wan.auraData.player.buff_DreamSurge then
        cDreamSurge = nDreamSurge
    end

    local currentTime = GetTime()

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        -- exit early when a lifebloom is at the target cap
        local nLifebloomCount = 0
        for groupUnitToken, _ in pairs(wan.GroupUnitID) do
            local aura = wan.auraData[groupUnitToken] and wan.auraData[groupUnitToken].buff_Lifebloom
            if aura then
                local remainingDuration = aura.expirationTime - currentTime
                if remainingDuration < 0 then
                    wan.auraData[groupUnitToken]["buff_" .. hotKey] = nil
                else
                    if aura.sourceUnit == "player" then
                        nLifebloomCount = nLifebloomCount + 1
                    end

                    if nLifebloomCount >= nLifebloomCap then
                        wan.UpdateHealingData(nil, wan.spellData.Lifebloom.basename)
                        return
                    end
                end
            end
        end

        -- run check over all group units in range
        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do
            
            if idValidGroupUnit[groupUnitToken] then
                -- check unit health
                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cLifebloomInstantHeal = cDreamSurge

                -- calculate estimated hot value
                cLifebloomInstantHeal = cLifebloomInstantHeal * critInstantValue *
                wan.UnitState.LevelScale[groupUnitToken]

                local cLifebloomHotHeal = nLifebloomHotHeal
                local hotPotency = wan.HotPotency(groupUnitToken, currentPercentHealth)

                -- trait layers
                cLifebloomHotHeal = cLifebloomHotHeal + cPhotosynthesisHeal + cBuddingLeaves

                -- calculate estimated hot value
                cLifebloomHotHeal = cLifebloomHotHeal * critHotValue * hotPotency * wan.UnitState.LevelScale[groupUnitToken]

                -- cache hot value on unit
                wan.HotValue[groupUnitToken] = wan.HotValue[groupUnitToken] or {}
                wan.HotValue[groupUnitToken][hotKey] = cLifebloomHotHeal

                -- add mastery layer
                if wan.spellData.MasteryHarmony.known then
                    local _, countHots = wan.GetUnitHotValues(groupUnitToken)

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

                -- subtract healing value of ability's hot from ability's max healing value
                local aura = wan.auraData[groupUnitToken]["buff_" .. hotKey]
                if aura then
                    local remainingDuration = aura.expirationTime - currentTime
                    if remainingDuration < 0 then
                        wan.auraData[groupUnitToken]["buff_" .. hotKey] = nil
                    else
                        local hotValue = wan.HotValue[groupUnitToken][hotKey]
                        cLifebloomHeal = cLifebloomHeal - hotValue
                    end
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
        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
        local hotPotency = wan.HotPotency(playerUnitToken, currentPercentHealth)
        local cLifebloomInstantHeal = cDreamSurge
        local cLifebloomHotHeal = nLifebloomHotHeal

        -- calculate estimated hot value
        cLifebloomHotHeal = cLifebloomHotHeal * critHotValue * hotPotency

        -- cache hot value on unit
        wan.HotValue[playerUnitToken] = wan.HotValue[playerUnitToken] or {}
        wan.HotValue[playerUnitToken][wan.spellData.Lifebloom.basename] = cLifebloomHotHeal

        -- add mastery layer
        if wan.spellData.MasteryHarmony.known then
            local _, countHots = wan.GetUnitHotValues(playerUnitToken)

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
            if wan.traitData.HarmoniousBlooming.known and wan.auraData.player.buff_Lifebloom then
                countHots = countHots + nHarmoniousBlooming
            end

            -- add mastery layer to hot value and cache hot value on unit
            local cMasteryHarmony = countHots > 0 and 1 + (nMasteryHarmony * countHots) or 1
            cLifebloomHotHeal = cLifebloomHotHeal * cMasteryHarmony
            wan.HotValue[playerUnitToken][wan.spellData.Lifebloom.basename] = cLifebloomHotHeal
        end

        local cLifebloomHeal = cLifebloomInstantHeal + cLifebloomHotHeal

        local aura = wan.auraData.player["buff_" .. hotKey]
        if aura then
            local remainingDuration = aura.expirationTime - currentTime
            if remainingDuration < 0 then
                wan.auraData.player["buff_" .. hotKey] = nil
            else
                local hotValue = wan.HotValue[playerUnitToken][hotKey]
                cLifebloomHeal = cLifebloomHeal - hotValue
            end
        end

        -- update healing data
        local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cLifebloomHeal, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.Lifebloom.basename, abilityValue, wan.spellData.Lifebloom.icon, wan.spellData.Lifebloom.name)
    end
end

-- Init frame 
local frameLifebloom = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nLifebloomValues = wan.GetSpellDescriptionNumbers(wan.spellData.Lifebloom.id, { 1, 2, 3 })
            nLifebloomHotHeal = nLifebloomValues[1] + nLifebloomValues[3]
            nLifeBloomHotHealFraction = nLifebloomValues[1]
            nLifebloomInstantHeal = nLifebloomValues[3]
            nLifebloomHotDuration = nLifebloomValues[2]

            nMasteryHarmony = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryHarmony.id, { 1 }) * 0.01

            nDreamSurge = wan.GetTraitDescriptionNumbers(wan.traitData.DreamSurge.entryid, { 3 })
        end
    end)
end
frameLifebloom:RegisterEvent("ADDON_LOADED")
frameLifebloom:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Lifebloom.known and wan.spellData.Lifebloom.id
        wan.BlizzardEventHandler(frameLifebloom, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameLifebloom, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nPhotosynthesisProcChance = wan.GetTraitDescriptionNumbers(wan.traitData.Photosynthesis.entryid, { 2 }) * 0.01

        nBuddingLeaves = wan.GetTraitDescriptionNumbers(wan.traitData.BuddingLeaves.entryid, { 2 }, wan.traitData.BuddingLeaves.rank) * 0.01

        nHarmoniousBlooming = wan.GetTraitDescriptionNumbers(wan.traitData.HarmoniousBlooming.entryid, { 1 }) - 1

        nStrategicInfusion = wan.GetTraitDescriptionNumbers(wan.traitData.StrategicInfusion.entryid, { 3 })
    end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.Lifebloom.basename)
        else
            wan.UpdateHealingData(nil, wan.spellData.Lifebloom.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameLifebloom, CheckAbilityValue, abilityActive)
    end
end)