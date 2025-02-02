local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nHolyShockDmg, nHolyShockHeal, nHolyShockMaxRange = 0, 0, 0

-- Init trait data
local nMasteryLightbringer = 0
local nAwestruck = 0
local nDivineGlimpse = 0
local nTyrsDeliverance = 0
local nReclamation = 0
local nRisingSunlight = 0
local nLuminosity = 0
local nSunSearHotHeal, nSunSearProcChance = 0, 0
local nSecondSunriseProcChance, nSecondSunrise = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.HolyShock.id)
    then
        wan.UpdateAbilityData(wan.spellData.HolyShock.basename)
        wan.UpdateMechanicData(wan.spellData.HolyShock.basename)
        wan.UpdateHealingData(nil, wan.spellData.HolyShock.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- HOLY TRAITS ----

    local bMasteryLightbringer = wan.spellData.MasteryLightbringer.known
    local bTyrsDeliverance = wan.traitData.TyrsDeliverance.known

    if wan.traitData.Awestruck.known then
        critDamageMod = critDamageMod + nAwestruck
    end

    if wan.traitData.DivineGlimpse.known then
        critChanceMod = critChanceMod + nDivineGlimpse
    end

    local cPoweroftheSilverHand = 0
    if wan.traitData.PoweroftheSilverHand.known then
        local checkPoweroftheSilverHandBuff = wan.auraData.player["buff_" .. wan.traitData.PoweroftheSilverHand.traitkey]
        if checkPoweroftheSilverHandBuff then
            for _, nPoweroftheSilverHand in pairs(checkPoweroftheSilverHandBuff.points) do 
                cPoweroftheSilverHand = cPoweroftheSilverHand + nPoweroftheSilverHand
            end
        end
    end

    local cReclamationHeal = 1
    local cReclamationDmg = 1
    if wan.traitData.Reclamation.known then
        cReclamationHeal = cReclamationHeal + nReclamation

        local currentPercentHealth = targetGUID and UnitPercentHealthFromGUID(targetGUID) or 0
        local cReclamationRatio = (1 - currentPercentHealth) * nReclamation
        cReclamationDmg = cReclamationDmg + cReclamationRatio
    end

    local cRisingSunlight = 1
    if wan.traitData.RisingSunlight.known then
        local checkRisingSunlightBuff = wan.CheckUnitBuff(nil, wan.traitData.RisingSunlight.traitkey)
        if checkRisingSunlightBuff then
            cRisingSunlight = cRisingSunlight + nRisingSunlight
        end
    end

    ---- HERALD OF THE SUN TRAITS ----

    if wan.traitData.Luminosity.known then
        critChanceMod = critChanceMod + nLuminosity
    end

    local cSunSearHotHeal = 0
    if wan.traitData.SunSear.known then
        cSunSearHotHeal = cSunSearHotHeal + (nSunSearHotHeal * nSunSearProcChance)
    end

    local cSecondSunriseInstantDmg = 0
    local cSecondSunriseInstantHeal = 0
    if wan.traitData.SecondSunrise.known then
        cSecondSunriseInstantDmg = cSecondSunriseInstantDmg + (nHolyShockDmg * nSecondSunriseProcChance * nSecondSunrise)
        cSecondSunriseInstantHeal = cSecondSunriseInstantHeal + (nHolyShockHeal * nSecondSunriseProcChance * nSecondSunrise)
    end

    local cHolyShockCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cHolyShockCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    -- Update ability data
    if wan.PlayerState.InGroup and wan.PlayerState.InHealerMode then
        local _, _, idValidGroupUnit = wan.ValidGroupMembers()

        for groupUnitToken, groupUnitGUID in pairs(wan.GroupUnitID) do

            if idValidGroupUnit[groupUnitToken] then

                local cHolyShockInstantHeal = 0
                local cHolyShockHotHeal = 0

                local currentPercentHealth = UnitPercentHealthFromGUID(groupUnitGUID) or 1
                local levelScale = wan.UnitState.LevelScale[groupUnitToken] or 1

                local cMasteryLightbringer = 1
                if bMasteryLightbringer then
                    local _, maxRange = wan.GetRangeBracket(groupUnitToken)
                    local cMasteryLightbringerRangeCap = math.min(nHolyShockMaxRange, maxRange)
                    local cMasteryLightbringerRatio = 1 - (cMasteryLightbringerRangeCap / nHolyShockMaxRange)

                    cMasteryLightbringer = cMasteryLightbringer + (nMasteryLightbringer * cMasteryLightbringerRatio)
                end

                local cTyrsDeliverance = 1
                if bTyrsDeliverance then
                    local checkTyrsDeliveranceBuff = wan.CheckUnitBuff(nil, wan.traitData.TyrsDeliverance.traitkey)
                    if checkTyrsDeliveranceBuff then
                        cTyrsDeliverance = cTyrsDeliverance + nTyrsDeliverance
                    end
                end

                cHolyShockInstantHeal = cHolyShockInstantHeal
                    + (nHolyShockHeal * cMasteryLightbringer * cTyrsDeliverance * cReclamationHeal * cRisingSunlight * cHolyShockCritValue * levelScale)
                    + (cPoweroftheSilverHand * cMasteryLightbringer * cTyrsDeliverance * cReclamationHeal * cRisingSunlight * cHolyShockCritValue * levelScale)
                    + (cSecondSunriseInstantHeal * cMasteryLightbringer * cTyrsDeliverance * cReclamationHeal * cRisingSunlight * cHolyShockCritValue * levelScale)

                cHolyShockHotHeal = cHolyShockHotHeal
                    + (cSunSearHotHeal * cHolyShockCritValueBase * levelScale)

                local cHolyShockHeal = cHolyShockInstantHeal + cHolyShockHotHeal

                local abilityValue = wan.UnitAbilityHealValue(groupUnitToken, cHolyShockHeal, currentPercentHealth)
                wan.UpdateHealingData(groupUnitToken, wan.spellData.HolyShock.basename, abilityValue, wan.spellData.HolyShock.icon, wan.spellData.HolyShock.name)
            else
                wan.UpdateHealingData(groupUnitToken, wan.spellData.HolyShock.basename)
            end
        end
    else

        local cHolyShockInstantHeal = 0
        local cHolyShockHotHeal = 0

        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1

        local cMasteryLightbringer = 1
        if bMasteryLightbringer then
            cMasteryLightbringer = cMasteryLightbringer + nMasteryLightbringer
        end

        local cTyrsDeliverance = 1
        if bTyrsDeliverance then
            local checkTyrsDeliveranceBuff = wan.CheckUnitBuff(nil, wan.traitData.TyrsDeliverance.traitkey)
            if checkTyrsDeliveranceBuff then
                cTyrsDeliverance = cTyrsDeliverance + nTyrsDeliverance
            end
        end

        cHolyShockInstantHeal = cHolyShockInstantHeal
            + (nHolyShockHeal * cMasteryLightbringer * cTyrsDeliverance * cReclamationHeal * cRisingSunlight * cHolyShockCritValue)
            + (cPoweroftheSilverHand * cMasteryLightbringer * cTyrsDeliverance * cReclamationHeal * cRisingSunlight * cHolyShockCritValue)
            + (cSecondSunriseInstantHeal * cMasteryLightbringer * cTyrsDeliverance * cReclamationHeal * cRisingSunlight * cHolyShockCritValue)

        cHolyShockHotHeal = cHolyShockHotHeal
            + (cSunSearHotHeal * cHolyShockCritValueBase)

        local cHolyShockHeal = cHolyShockInstantHeal + cHolyShockHotHeal

        local abilityValue = wan.UnitAbilityHealValue(playerUnitToken, cHolyShockHeal, currentPercentHealth)
        wan.UpdateMechanicData(wan.spellData.HolyShock.basename, abilityValue, wan.spellData.HolyShock.icon, wan.spellData.HolyShock.name)
    end

    -- Check for valid unit
    local isValidUnit = wan.ValidUnitBoolCounter(wan.spellData.HolyShock.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.HolyShock.basename)
        return
    end

    local cHolyShockInstantDmg = 0
    local cHolyShockDotDmg = 0
    local cHolyShockInstantDmgAoE = 0
    local cHolyShockDotDmgAoE = 0

    cHolyShockInstantDmg = cHolyShockInstantDmg
        + (nHolyShockDmg * cReclamationDmg * cRisingSunlight)

    cHolyShockDotDmg = cHolyShockDotDmg

    cHolyShockInstantDmgAoE = cHolyShockInstantDmgAoE

    cHolyShockDotDmgAoE = cHolyShockDotDmgAoE

    local cHolyShockDmg = cHolyShockInstantDmg + cHolyShockDotDmg + cHolyShockInstantDmgAoE + cHolyShockDotDmgAoE

    local abilityValue = math.floor(cHolyShockDmg)
    wan.UpdateAbilityData(wan.spellData.HolyShock.basename, abilityValue, wan.spellData.HolyShock.icon, wan.spellData.HolyShock.name)
end

-- Init frame 
local frameHolyShock = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nHolyShockValues = wan.GetSpellDescriptionNumbers(wan.spellData.HolyShock.id, { 1, 2 })
            nHolyShockDmg = nHolyShockValues[1]
            nHolyShockHeal = nHolyShockValues[2]
            nHolyShockMaxRange = wan.spellData.HolyShock.maxRange

            nMasteryLightbringer = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryLightbringer.id, { 1 }) * 0.01

            nSunSearHotHeal = wan.GetTraitDescriptionNumbers(wan.traitData.SunSear.entryid, { 1 })
            nSunSearProcChance = wan.CritChance * 0.01
        end
    end)
end
frameHolyShock:RegisterEvent("ADDON_LOADED")
frameHolyShock:SetScript("OnEvent", AddonLoad)

wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.HolyShock.known and wan.spellData.HolyShock.id
        wan.BlizzardEventHandler(frameHolyShock, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameHolyShock, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nAwestruck = wan.GetTraitDescriptionNumbers(wan.traitData.Awestruck.entryid, { 1 })

        nDivineGlimpse = wan.GetTraitDescriptionNumbers(wan.traitData.DivineGlimpse.entryid, { 1 })

        nTyrsDeliverance = wan.GetTraitDescriptionNumbers(wan.traitData.TyrsDeliverance.entryid, { 6 }) * 0.01

        nReclamation = wan.GetTraitDescriptionNumbers(wan.traitData.Reclamation.entryid, { 2 }) * 0.01

        nRisingSunlight = wan.GetTraitDescriptionNumbers(wan.traitData.RisingSunlight.entryid, { 1 })

        nLuminosity = wan.GetTraitDescriptionNumbers(wan.traitData.Luminosity.entryid, { 1 })

        local nSecondSunriseValues = wan.GetTraitDescriptionNumbers(wan.traitData.SecondSunrise.entryid, { 1, 2 })
        nSecondSunriseProcChance = nSecondSunriseValues[1] * 0.01
        nSecondSunrise = nSecondSunriseValues[2] * 0.01
    end

    if event == "HEALERMODE_FRAME_TOGGLE" then
        if wan.PlayerState.InHealerMode then
            wan.UpdateMechanicData(wan.spellData.HolyShock.basename)
        else
            wan.UpdateHealingData(nil, wan.spellData.HolyShock.basename)
        end
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameHolyShock, CheckAbilityValue, abilityActive)
    end
end)
