local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nWordofGloryHeal, nWordofGloryMaxRange = 0, 0

-- Init trait data
local nMasteryLightbringer = 0
local nExtrication = 0
local nLightoftheTitans = 0
local nEternalFlameHotHeal, nEternalFlame = 0, 0
local nDawnlightHotHeal = 0
local nHandoftheProtector = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.WordofGlory.id)
    then
        wan.UpdateMechanicData(wan.spellData.WordofGlory.basename)
        wan.UpdateHealingData(nil, wan.spellData.WordofGlory.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    ---- CLASS TRAITS ----

    local cRecompense = 0
    if wan.traitData.Recompense.known then
        local checkRecompenseBuff = wan.auraData.player["buff_" .. wan.traitData.Recompense.traitkey]
        if checkRecompenseBuff then
            for _, nRecompense in pairs(checkRecompenseBuff.points) do 
                cRecompense = cRecompense + nRecompense
            end
        end
    end

    ---- HOLY TRAITS ----

    local bMasteryLightbringer = wan.spellData.MasteryLightbringer.known

    if wan.traitData.Extrication.known then
        critChanceMod = critChanceMod + nExtrication
    end

    ---- PROTECTION TRAITS ----

    local bLightoftheTitans = wan.traitData.LightoftheTitans.known
    local sLightoftheTitansFormattedBuffName = wan.traitData.LightoftheTitans.traitkey

    local bHandoftheProtector = wan.traitData.HandoftheProtector.known

    ---- HERALD OF THE SUN TRAITS ----

    local bDawnlight = wan.traitData.Dawnlight.known
    local sDawnlightFormattedBuffName = wan.traitData.Dawnlight.traitkey

    local bEternalFlame = wan.traitData.EternalFlame.known
    local sEternalFlameFormattedBuffName = wan.traitData.EternalFlame.traitkey

    local hotKeys = { sDawnlightFormattedBuffName, sEternalFlameFormattedBuffName, sLightoftheTitansFormattedBuffName }
    local cWordofGloryCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cWordofGloryCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)
    local currentTime = GetTime()

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then

                local cWordofGloryInstantHeal = 0
                local cWordofGloryHotHeal = 0

                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local hotPotency = wan.HotPotency(groupUnitToken, currentPercentHealth, nWordofGloryHeal)
                wan.HotValue[groupUnitToken] = wan.HotValue[groupUnitToken] or {}

                ---- HOLY TRAITS ----

                local cMasteryLightbringer = 1
                if bMasteryLightbringer then
                    local _, maxRange = wan.GetRangeBracket(groupUnitToken)
                    local cMasteryLightbringerRangeCap = math.min(nWordofGloryMaxRange, maxRange)
                    local cMasteryLightbringerRatio = 1 - (cMasteryLightbringerRangeCap / nWordofGloryMaxRange)

                    cMasteryLightbringer = cMasteryLightbringer + (nMasteryLightbringer * cMasteryLightbringerRatio)
                end

                ---- PROTECTION TRAITS ----

                local cLightoftheTitans = 0
                if bLightoftheTitans then
                    cLightoftheTitans = cLightoftheTitans + (nWordofGloryHeal * nLightoftheTitans)

                    wan.HotValue[groupUnitToken][sLightoftheTitansFormattedBuffName] = cLightoftheTitans * cWordofGloryCritValue * hotPotency
                end

                local cHandoftheProtector = 1
                if bHandoftheProtector and  groupUnitGUID ~= playerGUID then
                    cHandoftheProtector = cHandoftheProtector + nHandoftheProtector
                end

                ---- HERALD OF THE SUN TRAITS ----

                local cDawnlightHotHeal = 0
                if bDawnlight then
                    cDawnlightHotHeal = cDawnlightHotHeal + nDawnlightHotHeal

                    wan.HotValue[groupUnitToken][sDawnlightFormattedBuffName] = cDawnlightHotHeal * cWordofGloryCritValueBase * hotPotency
                end

                local cEternalFlame = 1
                local cEternalFlameHotHeal = 0
                if bEternalFlame then
                    cEternalFlameHotHeal = cEternalFlameHotHeal + nEternalFlameHotHeal

                    if groupUnitGUID == playerGUID then
                        cEternalFlame = cEternalFlame + nEternalFlame
                    end

                    wan.HotValue[groupUnitToken][sEternalFlameFormattedBuffName] = cEternalFlameHotHeal * cEternalFlame * cWordofGloryCritValue * hotPotency
                end

                cWordofGloryInstantHeal = cWordofGloryInstantHeal
                    + (nWordofGloryHeal * cHandoftheProtector * cMasteryLightbringer * cEternalFlame * cWordofGloryCritValue)
                    + (cRecompense * cMasteryLightbringer * cEternalFlame * cWordofGloryCritValue)

                cWordofGloryHotHeal = cWordofGloryHotHeal
                    + (cLightoftheTitans * cHandoftheProtector * hotPotency * cWordofGloryCritValue)
                    + (cDawnlightHotHeal * hotPotency * cWordofGloryCritValueBase)
                    + (cEternalFlameHotHeal * hotPotency * cEternalFlame * cWordofGloryCritValue)

                local cWordofGloryHeal = cWordofGloryInstantHeal + cWordofGloryHotHeal

                for _, formattedAuraName in pairs(hotKeys) do
                    local aura = wan.auraData[groupUnitToken]["buff_" .. formattedAuraName]
                    if aura then
                        local reminingDuration = aura.expirationTime - currentTime
                        if reminingDuration < 0 then
                            wan.auraData[groupUnitToken]["buff_" .. formattedAuraName] = nil
                        else
                            local hotValue = wan.HotValue[groupUnitToken][formattedAuraName]
                            cWordofGloryHeal = cWordofGloryHeal - hotValue
                        end
                    end
                end

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cWordofGloryHeal, currentPercentHealth)
                wan.UpdateHealingData(groupUnitToken, wan.spellData.WordofGlory.basename, abilityValue, wan.spellData.WordofGlory.icon, wan.spellData.WordofGlory.name)
            else
                wan.UpdateHealingData(groupUnitToken, wan.spellData.WordofGlory.basename)
            end
        end
    else

        local cWordofGloryInstantHeal = 0
        local cWordofGloryHotHeal = 0

        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
        local hotPotency = wan.HotPotency(playerUnitToken, currentPercentHealth, nWordofGloryHeal)
        wan.HotValue[playerUnitToken] = wan.HotValue[playerUnitToken] or {}

        ---- HOLY TRAITS ----

        local cMasteryLightbringer = 1
        if bMasteryLightbringer then
            cMasteryLightbringer = cMasteryLightbringer + nMasteryLightbringer
        end

        ---- PROTECTION TRAITS ----

        local cLightoftheTitans = 0
        if bLightoftheTitans then
            cLightoftheTitans = cLightoftheTitans + (nWordofGloryHeal * nLightoftheTitans)

            wan.HotValue[playerUnitToken][sLightoftheTitansFormattedBuffName] = cLightoftheTitans * cWordofGloryCritValue * hotPotency
        end

        ---- HERALD OF THE SUN TRAITS ----

        local cDawnlightHotHeal = 0
        if bDawnlight then
            cDawnlightHotHeal = cDawnlightHotHeal + nDawnlightHotHeal

            wan.HotValue[playerUnitToken][sDawnlightFormattedBuffName] = cDawnlightHotHeal * cWordofGloryCritValueBase * hotPotency
        end

        local cEternalFlame = 1
        local cEternalFlameHotHeal = 0
        if bEternalFlame then
            cEternalFlameHotHeal = cEternalFlameHotHeal + nEternalFlameHotHeal
            cEternalFlame = cEternalFlame + nEternalFlame

            wan.HotValue[playerUnitToken][sEternalFlameFormattedBuffName] = cEternalFlameHotHeal * cEternalFlame * cWordofGloryCritValue * hotPotency
        end

        cWordofGloryInstantHeal = cWordofGloryInstantHeal
            + (nWordofGloryHeal * cMasteryLightbringer * cEternalFlame * cWordofGloryCritValue)
            + (cRecompense * cMasteryLightbringer * cEternalFlame * cWordofGloryCritValue)

        cWordofGloryHotHeal = cWordofGloryHotHeal
            + (cLightoftheTitans * hotPotency * cWordofGloryCritValue)
            + (cDawnlightHotHeal * cWordofGloryCritValueBase)
            + (cEternalFlameHotHeal * cEternalFlame * cWordofGloryCritValue)

        local cWordofGloryHeal = cWordofGloryInstantHeal + cWordofGloryHotHeal

        for _, formattedAuraName in pairs(hotKeys) do
            local aura = wan.auraData[playerUnitToken]["buff_" .. formattedAuraName]
            if aura then
                local reminingDuration = aura.expirationTime - currentTime
                if reminingDuration < 0 then
                    wan.auraData[playerUnitToken]["buff_" .. formattedAuraName] = nil
                else
                    local hotValue = wan.HotValue[playerUnitToken][formattedAuraName]
                    cWordofGloryHeal = cWordofGloryHeal - hotValue
                end
            end
        end

        local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cWordofGloryHeal, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.WordofGlory.basename, abilityValue, wan.spellData.WordofGlory.icon, wan.spellData.WordofGlory.name)
    end
end

-- Init frame 
local frameWordofGlory = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nWordofGloryHeal = wan.GetSpellDescriptionNumbers(wan.spellData.WordofGlory.id, { 1 })
            nWordofGloryMaxRange = wan.spellData.WordofGlory.maxRange

            nMasteryLightbringer = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryLightbringer.id, { 1 }) * 0.01

            nDawnlightHotHeal = wan.GetTraitDescriptionNumbers(wan.traitData.Dawnlight.entryid, { 2 })
        end
    end)
end
frameWordofGlory:RegisterEvent("ADDON_LOADED")
frameWordofGlory:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.WordofGlory.known and wan.spellData.WordofGlory.id
        wan.BlizzardEventHandler(frameWordofGlory, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameWordofGlory, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nExtrication = wan.GetTraitDescriptionNumbers(wan.traitData.Extrication.entryid, { 1 })

        nLightoftheTitans = wan.GetTraitDescriptionNumbers(wan.traitData.LightoftheTitans.entryid, { 1 }) * 0.01

        local nEternalFlameValues = wan.GetTraitDescriptionNumbers(wan.traitData.EternalFlame.entryid, { 2, 3 })
        nEternalFlameHotHeal = nEternalFlameValues[1]
        nEternalFlame = nEternalFlameValues[2] * 0.01

        nHandoftheProtector = wan.GetTraitDescriptionNumbers(wan.traitData.HandoftheProtector.entryid, { 1 }) * 0.01
    end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.WordofGlory.basename)
        else
            wan.UpdateHealingData(nil, wan.spellData.WordofGlory.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameWordofGlory, CheckAbilityValue, abilityActive)
    end
end)
