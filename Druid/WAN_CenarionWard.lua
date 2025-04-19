local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nCenarionWardHotHeal = 0
local nMasteryHarmony = 0

-- Init trait data
local nHarmoniousBlooming = 2
local bStrategicInfusion, sStrategicInfusion, nStrategicInfusion = false, "StrategicInfusion", 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or wan.CheckUnitBuff(nil, wan.spellData.CatForm.formattedName)
        or wan.CheckUnitBuff(nil, wan.spellData.BearForm.formattedName)
        or wan.CheckUnitBuff(nil, wan.spellData.MoonkinForm.formattedName)
        or not wan.IsSpellUsable(wan.spellData.CenarionWard.id)
    then
        wan.UpdateMechanicData(wan.spellData.CenarionWard.basename)
        wan.UpdateHealingData(nil, wan.spellData.CenarionWard.basename)
        return
    end

    -- init crit layer
    local critChanceModHot = 0
    local critChanceModInstant = 0

    if bStrategicInfusion then
        local checkStrategicInfusion = wan.CheckUnitBuff(nil, sStrategicInfusion)

        if checkStrategicInfusion then
            local cStrategicInfusion = nStrategicInfusion
            critChanceModHot = critChanceModHot + cStrategicInfusion
        end
    end

    local critHotValue = wan.ValueFromCritical(wan.CritChance, critChanceModHot)
    local critInstantValue = wan.ValueFromCritical(wan.CritChance)

    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] and not wan.auraData[groupUnitToken].buff_CenarionWard then
                local currentPercentHealth = wan.CheckUnitPercentHealth(groupUnitGUID)
                local cCenarionWardInstantHeal = 0

                cCenarionWardInstantHeal = cCenarionWardInstantHeal * critInstantValue

                local cCenarionWardHotHeal = nCenarionWardHotHeal
                local hotPotency = wan.HotPotency(groupUnitToken, currentPercentHealth, cCenarionWardInstantHeal)

                cCenarionWardHotHeal = cCenarionWardHotHeal * critHotValue * hotPotency * wan.UnitState.LevelScale[groupUnitToken] 

                wan.HotValue[groupUnitToken] = wan.HotValue[groupUnitToken] or {}
                wan.HotValue[groupUnitToken][wan.traitData.CenarionWard.traitkey] = cCenarionWardHotHeal

                if wan.spellData.MasteryHarmony.known then
                    local _, countHots = wan.GetUnitHotValues(groupUnitToken)

                    if countHots == 0 then countHots = 1 end

                    if wan.traitData.HarmoniousBlooming.known and wan.auraData[groupUnitToken].buff_Lifebloom then
                        countHots = countHots + nHarmoniousBlooming
                    end

                    local cMasteryHarmony = countHots > 0 and 1 + (nMasteryHarmony * countHots) or 1
                    cCenarionWardHotHeal = cCenarionWardHotHeal * cMasteryHarmony
                    wan.HotValue[groupUnitToken][wan.traitData.CenarionWard.traitkey] = cCenarionWardHotHeal
                end

                -- max healing value under 1 cast
                local cCenarionWardHeal = cCenarionWardInstantHeal + cCenarionWardHotHeal

                -- subtract healing value of ability's hot from ability's max healing value
                if wan.auraData[groupUnitToken]["buff_" .. wan.traitData.CenarionWard.traitkey] then
                    local hotValue = wan.HotValue[groupUnitToken][wan.traitData.CenarionWard.traitkey]
                    cCenarionWardHeal = cCenarionWardHeal - hotValue
                end

                -- update healing data
                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cCenarionWardHeal, currentPercentHealth)
                wan.UpdateHealingData(groupUnitToken, wan.spellData.CenarionWard.basename, abilityValue, wan.spellData.CenarionWard.icon, wan.spellData.CenarionWard.name)
            else
                wan.UpdateHealingData(groupUnitToken, wan.traitData.CenarionWard.traitkey)
            end
        end
    else
        if not wan.auraData.player.buff_CenarionWard then
            local unitToken = "player"
            local currentPercentHealth = wan.CheckUnitPercentHealth(playerGUID)

            local cCenarionWardInstantHeal = 0

            cCenarionWardInstantHeal = cCenarionWardInstantHeal * critInstantValue

            local cCenarionWardHotHeal = nCenarionWardHotHeal
            local hotPotency = wan.HotPotency(unitToken, currentPercentHealth, cCenarionWardInstantHeal)

            cCenarionWardHotHeal = cCenarionWardHotHeal * critHotValue * hotPotency

            wan.HotValue.player = wan.HotValue.player or {}
            wan.HotValue.player[wan.traitData.CenarionWard.traitkey] = cCenarionWardHotHeal

            -- add mastery layer
            if wan.spellData.MasteryHarmony.known then
                local _, countHots = wan.GetUnitHotValues(unitToken)

                if countHots == 0 then countHots = 1 end

                if wan.traitData.HarmoniousBlooming.known and wan.auraData.player.buff_Lifebloom then
                    countHots = countHots + nHarmoniousBlooming
                end

                local cMasteryHarmony = countHots > 0 and 1 + (nMasteryHarmony * countHots) or 1
                cCenarionWardHotHeal = cCenarionWardHotHeal * cMasteryHarmony
                wan.HotValue.player[wan.spellData.CenarionWard.basename] = cCenarionWardHotHeal
            end

            -- max healing value
            local cCenarionWardHeal = cCenarionWardInstantHeal + cCenarionWardHotHeal

            -- subtract healing value of ability's hot from ability's max healing value
            if wan.auraData.player["buff_" .. wan.spellData.CenarionWard.basename] then
                local hotValue = wan.HotValue.player[wan.spellData.CenarionWard.basename]
                cCenarionWardHeal = cCenarionWardHeal - hotValue
            end

            -- update healing data
            local abilityValue = wan.UnitAbilityHealValue(unitToken, cCenarionWardHeal, currentPercentHealth)
            wan.UpdateMechanicData(wan.spellData.CenarionWard.basename, abilityValue, wan.spellData.CenarionWard.icon, wan.spellData.CenarionWard.name)
        else
            wan.UpdateMechanicData(wan.spellData.CenarionWard.basename)
        end
    end
end

-- Init frame 
local frameCenarionWard = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nCenarionWardHotHeal = wan.GetSpellDescriptionNumbers(wan.spellData.CenarionWard.id, { 2 })

            local nMasteryHarmonyValue = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryHarmony.id, { 1 })
            nMasteryHarmony = nMasteryHarmonyValue * 0.01

        end
    end)
end
frameCenarionWard:RegisterEvent("ADDON_LOADED")
frameCenarionWard:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.CenarionWard.known and wan.spellData.CenarionWard.id
        wan.BlizzardEventHandler(frameCenarionWard, abilityActive, "SPELLS_CHANGED", "UNIT_AURA",
            "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameCenarionWard, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nHarmoniousBlooming = wan.GetTraitDescriptionNumbers(wan.traitData.HarmoniousBlooming.entryid, { 1 }) - 1

        bStrategicInfusion = wan.traitData.StrategicInfusion.known
        sStrategicInfusion = wan.traitData.StrategicInfusion.traitkey
        nStrategicInfusion = wan.GetTraitDescriptionNumbers(wan.traitData.StrategicInfusion.entryid, { 3 })
    end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.CenarionWard.basename)
        else
            wan.UpdateHealingData(nil, wan.spellData.CenarionWard.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameCenarionWard, CheckAbilityValue, abilityActive)
    end
end)
