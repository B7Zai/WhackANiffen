local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nEyeofTyrDmg, nEyeofTyrMaxRange, nEyeofTyr = 0, 8, 0

-- Init trait data
local checkHammerofLight, nHammerofLightDmg, nHammerofLightDmgAoE, nHammerofLightUnitCap = false, 0, 0, 0
local nEmpyreanHammer, nEmpyreanHammerTicks = 0, 0
local nShaketheHeavensProcRate, nShaketheHeavensDuration, nShaketheHeavensTicks = 0, 0, 0
local nWrathfulDescent = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.EyeofTyr.id)
    then
        wan.UpdateAbilityData(wan.spellData.EyeofTyr.basename)
        return
    end

    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nEyeofTyrMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.EyeofTyr.basename)
        return
    end

    local cEyeofTyr = 0
    if wan.traitData.LightsGuidance.known and checkHammerofLight then

        -- Base values
        local critChanceMod = 0
        local critDamageMod = 0
        local critChanceModBase = 0
        local critDamageModBase = 0

        local cEyeofTyrInstantDmg = 0
        local cEyeofTyrDotDmg = 0
        local cEyeofTyrInstantDmgAoE = 0
        local cEyeofTyrDotDmgAoE = 0

        local targetUnitToken = wan.TargetUnitID
        local targetGUID = wan.UnitState.GUID[targetUnitToken]

        ---- TEMPLAR TRAITS ----

        local cHammerofLightInstantDmg = 0
        local cHammerofLightInstantDmgAoE = 0
        if wan.traitData.LightsGuidance.known and checkHammerofLight then
            cHammerofLightInstantDmg = cHammerofLightInstantDmg + nHammerofLightDmg

            local countHammerofLightUnit = 0
            for _, nameplateGUID in pairs(idValidUnit) do
                if nameplateGUID ~= targetGUID then
                    cHammerofLightInstantDmgAoE = cHammerofLightInstantDmgAoE + nHammerofLightDmgAoE
                    countHammerofLightUnit = countHammerofLightUnit + 1

                    if countHammerofLightUnit >= nHammerofLightUnitCap then break end
                end
            end
        end

        local cEmpyreanHammerInstantDmg = 0
        if wan.traitData.LightsGuidance.known and checkHammerofLight then
            local cWrathfulDescent = 1
            if wan.traitData.WrathfulDescent.known then
                local nWrathfulDescentUnits = math.max(countValidUnit - 1, 0)
                local nWrathfulDescentProcChance = wan.CritChance * 0.01
                cWrathfulDescent = cWrathfulDescent + (nWrathfulDescent * nWrathfulDescentUnits * nWrathfulDescentProcChance)
            end

            cEmpyreanHammerInstantDmg = cEmpyreanHammerInstantDmg +
            (nEmpyreanHammer * nEmpyreanHammerTicks * cWrathfulDescent)

            if wan.traitData.ShaketheHeavens.known then
                local formattedBuffName = wan.traitData.ShaketheHeavens.traitkey
                local checkShaketheHeavensBuff = wan.CheckUnitBuff(nil, formattedBuffName)

                if not checkShaketheHeavensBuff then
                    cEmpyreanHammerInstantDmg = cEmpyreanHammerInstantDmg +
                    (nEmpyreanHammer * nShaketheHeavensTicks * cWrathfulDescent)
                end
            end
        end

        local cWakeofAshesCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

        cEyeofTyrInstantDmg = cEyeofTyrInstantDmg
            + (cHammerofLightInstantDmg * cWakeofAshesCritValue)
            + (cEmpyreanHammerInstantDmg * cWakeofAshesCritValue)

        cEyeofTyrDotDmg = cEyeofTyrDotDmg

        cEyeofTyrInstantDmgAoE = cEyeofTyrInstantDmgAoE
            + (nEyeofTyrDmg * countValidUnit * cWakeofAshesCritValue)
            + (cHammerofLightInstantDmgAoE * cWakeofAshesCritValue)

        cEyeofTyrDotDmgAoE = cEyeofTyrDotDmgAoE * cWakeofAshesCritValue

        cEyeofTyr = cEyeofTyrInstantDmg + cEyeofTyrDotDmg + cEyeofTyrInstantDmgAoE + cEyeofTyrDotDmgAoE
    else

        local currentPercentHealth = UnitPercentHealthFromGUID(playerGUID) or 1
        cEyeofTyr = wan.UnitAbilityHealValue(playerUnitToken, nEyeofTyr, currentPercentHealth)
    end

    local abilityValue = math.floor(cEyeofTyr)
    wan.UpdateAbilityData(wan.spellData.EyeofTyr.basename, abilityValue, wan.spellData.EyeofTyr.icon, wan.spellData.EyeofTyr.name)
end

-- Init frame 
local frameEyeofTyr = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nEyeofTyr = wan.DefensiveCooldownToValue(wan.spellData.EyeofTyr.id)

            checkHammerofLight = wan.spellData.EyeofTyr.name == "Hammer of Light"

            local nEyeofTyrValues = wan.GetSpellDescriptionNumbers(wan.spellData.EyeofTyr.id, { 1, 2 })
            nEyeofTyrDmg = not checkHammerofLight and nEyeofTyrValues[1] or 0
            nEyeofTyrMaxRange = nEyeofTyrValues[2]

            local nHammerofLightValues = wan.GetTraitDescriptionNumbers(wan.traitData.LightsGuidance.entryid, { 4, 5, 6, 7, 8 })
            nHammerofLightDmg = nHammerofLightValues[1]
            nHammerofLightDmgAoE = nHammerofLightValues[2]
            nHammerofLightUnitCap = nHammerofLightValues[3]
            nEmpyreanHammerTicks = nHammerofLightValues[4]
            nEmpyreanHammer = nHammerofLightValues[5]
        end
    end)
end
frameEyeofTyr:RegisterEvent("ADDON_LOADED")
frameEyeofTyr:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.EyeofTyr.known and wan.spellData.EyeofTyr.id
        wan.BlizzardEventHandler(frameEyeofTyr, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameEyeofTyr, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        local nShaketheHeavensValues = wan.GetTraitDescriptionNumbers(wan.traitData.ShaketheHeavens.entryid, { 1, 2 })
        nShaketheHeavensProcRate = nShaketheHeavensValues[1]
        nShaketheHeavensDuration = nShaketheHeavensValues[2]
        nShaketheHeavensTicks = nShaketheHeavensDuration / nShaketheHeavensProcRate

        nWrathfulDescent = wan.GetTraitDescriptionNumbers(wan.traitData.WrathfulDescent.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameEyeofTyr, CheckAbilityValue, abilityActive)
    end
end)