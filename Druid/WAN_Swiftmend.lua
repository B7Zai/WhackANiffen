local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nSwifmendInstantHeal, nSwiftmendHotHeal = 0, 0
local nMasteryHarmony = 0

-- Init trait data
local nHarmoniousBlooming = 0
local nGroveTending = 0
local nStrategicInfusion = 0
local nSymbioticBlooms = 0
local sSymbioticBloomsKey = "SymbioticBlooms"
local nDreamSurge = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
        or wan.auraData.player.buff_BearForm or wan.auraData.player.buff_MoonkinForm
        or not wan.IsSpellUsable(wan.spellData.Swiftmend.id)
    then
        wan.UpdateMechanicData(wan.spellData.Swiftmend.basename)
        wan.UpdateHealingData(nil, wan.spellData.Swiftmend.basename)
        return
    end

    local critChanceModHot = 0
    local critChanceModInstant = 0

    -- check stategic infusion trait layer
    if wan.traitData.StrategicInfusion.known and wan.auraData.player.buff_StrategicInfusion then
        local cStrategicInfusion = nStrategicInfusion
        critChanceModHot = critChanceModHot + cStrategicInfusion
    end

    local cDreamSurge = 0
    if wan.traitData.DreamSurge.known and wan.auraData.player.buff_DreamSurge then
        cDreamSurge = nDreamSurge
    end

    -- add crit layer
    local critHotValue = wan.ValueFromCritical(wan.CritChance, critChanceModHot)
    local critInstantValue = wan.ValueFromCritical(wan.CritChance, critChanceModInstant)

    local currentTime = GetTime()

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] and
             (wan.auraData[groupUnitToken].buff_WildGrowth and wan.auraData[groupUnitToken].buff_WildGrowth.spellId == wan.spellData.WildGrowth.id
                    or wan.auraData[groupUnitToken].buff_Regrowth and wan.auraData[groupUnitToken].buff_Regrowth == wan.spellData.Regrowth.id
                    or wan.auraData[groupUnitToken].buff_Rejuvenation and wan.auraData[groupUnitToken].buff_Rejuvenation == wan.spellData.Rejuvenation.id) then

                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local cSwifmendInstantHeal = nSwifmendInstantHeal + cDreamSurge

                cSwifmendInstantHeal = nSwifmendInstantHeal * critInstantValue * wan.UnitState.LevelScale[groupUnitToken]

                local cSwiftmendHotHeal = wan.traitData.GroveTending.known and nGroveTending or 0
                local cSymbioticBlooms = wan.traitData.ThrivingGrowth.known and nSymbioticBlooms or 0
                local hotPotency = wan.HotPotency(groupUnitToken, currentPercentHealth, cSwifmendInstantHeal)

                cSwiftmendHotHeal = cSwiftmendHotHeal * critHotValue * hotPotency * wan.UnitState.LevelScale[groupUnitToken]
                cSymbioticBlooms = cSymbioticBlooms * critHotValue * hotPotency * wan.UnitState.LevelScale[groupUnitToken]

                wan.HotValue[groupUnitToken] = wan.HotValue[groupUnitToken] or {}
                wan.HotValue[groupUnitToken][wan.traitData.GroveTending.traitkey] = cSwiftmendHotHeal
                wan.HotValue[groupUnitToken][sSymbioticBloomsKey] = cSymbioticBlooms

                if wan.spellData.MasteryHarmony.known then
                    local _, countHots = wan.GetUnitHotValues(groupUnitToken)

                    if countHots == 0 then countHots = 1 end

                    if wan.traitData.HarmoniousBlooming.known and wan.auraData[groupUnitToken].buff_Lifebloom then
                        countHots = countHots + nHarmoniousBlooming
                    end

                    local cMasteryHarmonyOverflow = wan.SoftCapOverflow(1, countHots)
                    local cMasteryHarmony = cMasteryHarmonyOverflow > 0 and 1 + (nMasteryHarmony * cMasteryHarmonyOverflow) or 1
                    cSymbioticBlooms = cSymbioticBlooms * cMasteryHarmony
                    wan.HotValue[groupUnitToken][wan.traitData.GroveTending.traitkey] = cSwiftmendHotHeal
                    wan.HotValue[groupUnitToken][sSymbioticBloomsKey] = cSymbioticBlooms
                end

                local cSwiftmendHeal = cSwifmendInstantHeal + cSwiftmendHotHeal

                local aura = wan.auraData[groupUnitToken]["buff_" .. wan.traitData.GroveTending.traitkey]
                if aura then
                    local remainingDuration = aura.expirationTime - currentTime
                    if remainingDuration < 0 then
                        wan.auraData[groupUnitToken]["buff_" .. wan.traitData.GroveTending.traitkey] = nil
                    else
                        local hotValue = wan.HotValue[groupUnitToken][wan.traitData.GroveTending.traitkey]
                        cSwiftmendHeal = cSwiftmendHeal - hotValue
                    end
                end

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cSwiftmendHeal, currentPercentHealth)
                wan.UpdateHealingData(groupUnitToken, wan.spellData.Swiftmend.basename, abilityValue, wan.spellData.Swiftmend.icon, wan.spellData.Swiftmend.name)
            else
                wan.UpdateHealingData(groupUnitToken, wan.spellData.Swiftmend.basename)
            end
        end
    else
        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
        local cSwifmendInstantHeal = nSwifmendInstantHeal + cDreamSurge

        cSwifmendInstantHeal = nSwifmendInstantHeal * critInstantValue

        local cSwiftmendHotHeal = wan.traitData.GroveTending.known and nGroveTending or 0
        local cSymbioticBlooms = wan.traitData.ThrivingGrowth.known and nSymbioticBlooms or 0
        local hotPotency = wan.HotPotency(playerUnitToken, currentPercentHealth, cSwifmendInstantHeal)

        cSwiftmendHotHeal = cSwiftmendHotHeal * critHotValue * hotPotency
        cSymbioticBlooms = cSymbioticBlooms * critHotValue * hotPotency

        wan.HotValue[playerUnitToken] = wan.HotValue[playerUnitToken] or {}
        wan.HotValue[playerUnitToken][wan.traitData.GroveTending.traitkey] = cSwiftmendHotHeal
        wan.HotValue[playerUnitToken][sSymbioticBloomsKey] = cSymbioticBlooms

        if wan.spellData.MasteryHarmony.known then
            local _, countHots = wan.GetUnitHotValues(playerUnitToken)

            if countHots == 0 then countHots = 1 end

            if wan.traitData.HarmoniousBlooming.known and wan.auraData.player.buff_Lifebloom then
                countHots = countHots + nHarmoniousBlooming
            end

            local cMasteryHarmonyOverflow = wan.SoftCapOverflow(1, countHots)
            local cMasteryHarmony = cMasteryHarmonyOverflow > 0 and 1 + (nMasteryHarmony * cMasteryHarmonyOverflow) or 1
            cSwiftmendHotHeal = cSwiftmendHotHeal * cMasteryHarmony
            cSymbioticBlooms = cSymbioticBlooms * cMasteryHarmony
            wan.HotValue[playerUnitToken][wan.traitData.GroveTending.traitkey] = cSwiftmendHotHeal
            wan.HotValue[playerUnitToken][sSymbioticBloomsKey] = cSymbioticBlooms
        end

        local cSwiftmendHeal = cSwifmendInstantHeal + cSwiftmendHotHeal

        local aura = wan.auraData.player["buff_" .. wan.traitData.GroveTending.traitkey]
        if aura then
            local remainingDuration = aura.expirationTime - currentTime
            if remainingDuration < 0 then
                wan.auraData.player["buff_" .. wan.traitData.GroveTending.traitkey] = nil
            else
                local hotValue = wan.HotValue[playerUnitToken][wan.traitData.GroveTending.traitkey]
                cSwiftmendHeal = cSwiftmendHeal - hotValue
            end
        end

        local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cSwiftmendHeal, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.Swiftmend.basename, abilityValue, wan.spellData.Swiftmend.icon, wan.spellData.Swiftmend.name)
    end
end

-- Init frame 
local frameSwiftmend = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nSwifmendInstantHeal = wan.GetSpellDescriptionNumbers(wan.spellData.Swiftmend.id, { 1 })

            nGroveTending = wan.GetTraitDescriptionNumbers(wan.traitData.GroveTending.entryid, { 1 })

            nMasteryHarmony = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryHarmony.id, { 1 }) * 0.01

            nSymbioticBlooms = wan.GetTraitDescriptionNumbers(wan.traitData.ThrivingGrowth.entryid, { 3 })

            nDreamSurge = wan.GetTraitDescriptionNumbers(wan.traitData.DreamSurge.entryid, { 3 })
        end
    end)
end
frameSwiftmend:RegisterEvent("ADDON_LOADED")
frameSwiftmend:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Swiftmend.known and wan.spellData.Swiftmend.id
        wan.BlizzardEventHandler(frameSwiftmend, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameSwiftmend, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nStrategicInfusion = wan.GetTraitDescriptionNumbers(wan.traitData.StrategicInfusion.entryid, { 3 })
    end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.Swiftmend.basename)
        else
            wan.UpdateHealingData(nil, wan.spellData.Swiftmend.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSwiftmend, CheckAbilityValue, abilityActive)
    end
end)