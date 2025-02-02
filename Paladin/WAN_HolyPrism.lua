local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nHolyPrismInstantHeal, nHolyPrismMaxRange = 0, 0

-- Init trait data
local nMasteryLightbringer = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.HolyPrism.id)
    then
        wan.UpdateMechanicData(wan.spellData.HolyPrism.basename)
        wan.UpdateHealingData(nil, wan.spellData.HolyPrism.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cFlashofLightCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    ---- HOLY TRAITS ----

    local bMasteryLightbringer = wan.spellData.MasteryLightbringer.known

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then

                local cHolyPrismInstantHeal = 0
                local cHolyPrismHotHeal = 0

                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local levelScale = wan.UnitState.LevelScale[groupUnitToken] or 1

                local cMasteryLightbringer = 1
                if bMasteryLightbringer then
                    local _, maxRange = wan.GetRangeBracket(groupUnitToken)
                    local cMasteryLightbringerRangeCap = math.min(nHolyPrismMaxRange, maxRange)
                    local cMasteryLightbringerRatio = 1 - (cMasteryLightbringerRangeCap / nHolyPrismMaxRange)

                    cMasteryLightbringer = cMasteryLightbringer + (nMasteryLightbringer * cMasteryLightbringerRatio)
                end

                cHolyPrismInstantHeal = cHolyPrismInstantHeal
                    + (nHolyPrismInstantHeal * cMasteryLightbringer * cFlashofLightCritValue * levelScale)

                cHolyPrismHotHeal = cHolyPrismHotHeal

                local cHolyPrismHeal = cHolyPrismInstantHeal + cHolyPrismHotHeal

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cHolyPrismHeal, currentPercentHealth)
                wan.UpdateHealingData(groupUnitToken, wan.spellData.HolyPrism.basename, abilityValue, wan.spellData.HolyPrism.icon, wan.spellData.HolyPrism.name)
            else
                wan.UpdateHealingData(groupUnitToken, wan.spellData.HolyPrism.basename)
            end
        end
    else

        local cHolyPrismInstantHeal = 0
        local cHolyPrismHotHeal = 0

        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1

        local cMasteryLightbringer = 1
        if bMasteryLightbringer then
            cMasteryLightbringer = cMasteryLightbringer + nMasteryLightbringer
        end

        cHolyPrismInstantHeal = cHolyPrismInstantHeal
            + (nHolyPrismInstantHeal * cMasteryLightbringer * cFlashofLightCritValue)

        cHolyPrismHotHeal = cHolyPrismHotHeal

        local cHolyPrismHeal = cHolyPrismInstantHeal + cHolyPrismHotHeal

        local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cHolyPrismHeal, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.HolyPrism.basename, abilityValue, wan.spellData.HolyPrism.icon, wan.spellData.HolyPrism.name)
    end
end

-- Init frame 
local frameHolyPrism = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nHolyPrismInstantHeal = wan.GetSpellDescriptionNumbers(wan.spellData.HolyPrism.id, { 5 })
            nHolyPrismMaxRange = wan.spellData.HolyPrism.maxRange

            nMasteryLightbringer = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryLightbringer.id, { 1 }) * 0.01
        end
    end)
end
frameHolyPrism:RegisterEvent("ADDON_LOADED")
frameHolyPrism:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.HolyPrism.known and wan.spellData.HolyPrism.id
        wan.BlizzardEventHandler(frameHolyPrism, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameHolyPrism, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.HolyPrism.basename)
        else
            wan.UpdateHealingData(nil, wan.spellData.HolyPrism.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameHolyPrism, CheckAbilityValue, abilityActive)
    end
end)
