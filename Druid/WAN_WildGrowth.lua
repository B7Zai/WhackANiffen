local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nWildGrowthInstantHeal, nWildGrowthHotHeal, nWildGrowthUnitCap = 0, 0, 5
local nMasteryHarmony = 0

-- Init triat data
local nHarmoniousBlooming = 0
local nEmbraceoftheDream = 0
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
   
    -- cast time layer
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.WildGrowth.id, wan.spellData.WildGrowth.castTime)
    if castEfficiency == 0 then
        wan.UpdateMechanicData(wan.spellData.WildGrowth.basename)
        wan.UpdateHealingData(nil, wan.spellData.WildGrowth.basename)
        return
    end

    local critChanceModHot = 0
    local critChanceModInstant = 0

    -- update unit cap 
    local cWildGrowthUnitCap = nWildGrowthUnitCap
    if wan.traitData.ImprovedWildGrowth.known then
        cWildGrowthUnitCap = cWildGrowthUnitCap + 1
    end

    -- update unit cap 
    if wan.auraData.player.buff_IncarnationTreeofLife then
        cWildGrowthUnitCap = cWildGrowthUnitCap + 2
    end

    -- check stategic infusion trait layer
    if wan.traitData.StrategicInfusion.known and wan.auraData.player.buff_StrategicInfusion then
        local cStrategicInfusion = nStrategicInfusion
        critChanceModHot = critChanceModHot + cStrategicInfusion
    end

    -- array of hots applied by this ability as key value
    local hotKey = wan.spellData.WildGrowth.basename

    -- check crit layer
    local critHotValue = wan.ValueFromCritical(wan.CritChance, critChanceModHot)
    local critInstantValue = wan.ValueFromCritical(wan.CritChance, critChanceModHot)

    -- init data for calculation
    local _, _, idValidGroupUnit = wan.ValidGroupMembers()
    local unitsNeedHeal = 0
    wan.HealUnitCountAoE[hotKey] = wan.HealUnitCountAoE[hotKey] or 1

    local currentTime = GetTime()

    -- run check over all group units in range
    for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

        if idValidGroupUnit[groupUnitToken] then

            -- check unit health
            local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1

            -- add Embrace of the Dream layer
            local cEmbraceoftheDream = 0
            if wan.traitData.EmbraceoftheDream.known and (wan.auraData[groupUnitToken].buff_Rejuvenation or wan.auraData[groupUnitToken].buff_Regrowth) then
                cEmbraceoftheDream = cEmbraceoftheDream + nEmbraceoftheDream
            end

            -- base values
            local cWildGrowthInstantHeal = cEmbraceoftheDream

            cWildGrowthInstantHeal = cWildGrowthInstantHeal * critInstantValue * wan.UnitState.LevelScale[groupUnitToken]

            local cWildGrowthHotHeal = nWildGrowthHotHeal
            local hotPotency = wan.HotPotency(groupUnitToken, currentPercentHealth)

            -- calculate estimated hot value
            cWildGrowthHotHeal = cWildGrowthHotHeal * critHotValue * hotPotency * wan.UnitState.LevelScale[groupUnitToken]

            -- cache hot value on unit
            wan.HotValue[groupUnitToken] = wan.HotValue[groupUnitToken] or {}
            wan.HotValue[groupUnitToken][hotKey] = cWildGrowthHotHeal

            -- add mastery layer
            if wan.spellData.MasteryHarmony.known then
                local _, countHots = wan.GetUnitHotValues(groupUnitToken)

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

            local cWildGrowthHeal = cWildGrowthInstantHeal + cWildGrowthHotHeal

            -- subtract healing value of ability's hot from ability's max healing value
            local aura = wan.auraData[groupUnitToken]["buff_" .. hotKey]
            if aura then
                local remainingDuration = aura.expirationTime - currentTime
                if remainingDuration < 0 then
                    wan.auraData[groupUnitToken]["buff_" .. hotKey] = nil
                else
                    local hotValue = wan.HotValue[groupUnitToken][hotKey]
                    cWildGrowthHeal = cWildGrowthHeal - hotValue
                end
            end

            -- add cast efficiency layer
            cWildGrowthHeal = cWildGrowthHeal * castEfficiency * wan.HealUnitCountAoE[hotKey]

            local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cWildGrowthHeal, currentPercentHealth, wan.HealUnitCountAoE[hotKey])
            if abilityValue > 0 then unitsNeedHeal = unitsNeedHeal + 1 end
            wan.UpdateHealingData(groupUnitToken, wan.spellData.WildGrowth.basename, abilityValue, wan.spellData.WildGrowth.icon, wan.spellData.WildGrowth.name)
        else
            wan.UpdateHealingData(groupUnitToken, wan.spellData.WildGrowth.basename)
        end
    end

    if unitsNeedHeal > 0 then

        if unitsNeedHeal > cWildGrowthUnitCap then
            unitsNeedHeal = cWildGrowthUnitCap
        end
        wan.HealUnitCountAoE[hotKey] = unitsNeedHeal
        
    else
        wan.HealUnitCountAoE[hotKey] = 1
    end
end

-- Init frame 
local frameWildGrowth = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nWildGrowthHotHeal = wan.GetSpellDescriptionNumbers(wan.spellData.WildGrowth.id, { 3 })

            nMasteryHarmony = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryHarmony.id, { 1 }) * 0.01

            nEmbraceoftheDream = wan.GetTraitDescriptionNumbers(wan.traitData.EmbraceoftheDream.entryid, { 1 })
        end
    end)
end
frameWildGrowth:RegisterEvent("ADDON_LOADED")
frameWildGrowth:SetScript("OnEvent", AddonLoad)

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

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if not wan.PlayerState.InHealerMode then
            wan.UpdateHealingData(nil, wan.spellData.WildGrowth.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameWildGrowth, CheckAbilityValue, abilityActive)
    end
end)