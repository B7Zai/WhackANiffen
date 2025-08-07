local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local aSteadyShotData, nSteadyShotDmg = {}, 0

-- Init trait datat
local aBarbedShot = {}
local aThrilloftheHunt = {}
local aStomp, nStompDmg, nStompDmgAoE = {}, 0, 0
local aPoisonedBarbs, nPoisonedBarbsProcChance, nPoisonedBarbsDmg, nPoisonedBarbsSoftCap, nSerpentStingInstantDmg, nSerpentStingDotDmg = {}, 0, 0, 0, 0, 0
local nPenetratingShots = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or not wan.IsSpellUsable(aSteadyShotData.id)
    then
        wan.UpdateAbilityData(aSteadyShotData.basename)
        wan.UpdateMechanicData(aSteadyShotData.basename)
        return
    end

    local canMoveCast = true
    local castEfficiency = wan.CheckCastEfficiency(aSteadyShotData.id, aSteadyShotData.castTime, canMoveCast)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(aSteadyShotData.basename)
        wan.UpdateMechanicData(aSteadyShotData.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(aSteadyShotData.id)
    if not isValidUnit then
        wan.UpdateAbilityData(aSteadyShotData.basename)
        wan.UpdateMechanicData(aSteadyShotData.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cSteadyShotInstantDmg = 0
    local cSteadyShotDotDmg = 0
    local cSteadyShotInstantDmgAoE = 0
    local cSteadyShotDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- BEAST MASTER TRAITS ----

    local cBarbedShotEnabler = 1
    local cBarbedShotDotDmg = 0
    if aBarbedShot.known then
        cBarbedShotEnabler = 0

        local checkBarbedShotDebuff = wan.CheckUnitDebuff(nil, aSteadyShotData.formattedName)
        if not checkBarbedShotDebuff then
            local dotPotency = wan.CheckDotPotency()
            cBarbedShotDotDmg = cBarbedShotDotDmg + (nSteadyShotDmg * dotPotency)
        end
    end

    local cStompInstantDmg = 0
    local cStompInstantDmgAoE = 0
    if aStomp.known then
        local activePets = (wan.IsPetUsable() and 1 or 0) * (wan.traitData.AnimalCompanion.known and 2 or 1)
        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(targetUnitToken)
        cStompInstantDmg = cStompInstantDmg + (nStompDmg * checkPhysicalDR * activePets)

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                cStompInstantDmgAoE = cStompInstantDmgAoE + (nStompDmgAoE * checkUnitPhysicalDR * activePets)
            end
        end
    end

    local cPoisonedBarbsInstantDmgAoE = 0
    local cPoisonedBarbsDotDmgAoE = 0
    if aPoisonedBarbs.known then
        local cPoisonedBarbsUnitOverflow = wan.AdjustSoftCapUnitOverflow(nPoisonedBarbsSoftCap, countValidUnit)
        cPoisonedBarbsInstantDmgAoE = cPoisonedBarbsInstantDmgAoE + (((nPoisonedBarbsDmg * cPoisonedBarbsUnitOverflow ) + (nSerpentStingInstantDmg * countValidUnit)) * nPoisonedBarbsProcChance)

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkSerpentStingDebuff = wan.CheckUnitDebuff(nil, "SerpentSting")

            if not checkSerpentStingDebuff then
                local dotPotency = wan.CheckDotPotency((nPoisonedBarbsDmg + nSerpentStingInstantDmg), nameplateUnitToken)

                cPoisonedBarbsDotDmgAoE = cPoisonedBarbsDotDmgAoE + (nSerpentStingDotDmg * dotPotency * nPoisonedBarbsProcChance)
            end
        end
    end

    ---- MARKSMAN TRAITS ----

    local cPenetratingShots = 0
    if wan.traitData.PenetratingShots.known then
        cPenetratingShots = cPenetratingShots + (wan.CritChance * nPenetratingShots)
        critDamageMod = critDamageMod + (wan.CritChance * nPenetratingShots)
    end

    local checkPhysicalDR = not aBarbedShot.known and 1 or wan.CheckUnitPhysicalDamageReduction()
    local cSteadyShotCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cSteadyShotBaseCritValue = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cSteadyShotInstantDmg = cSteadyShotInstantDmg
        + (nSteadyShotDmg * checkPhysicalDR * cSteadyShotCritValue * cBarbedShotEnabler)
        + (cStompInstantDmg * cSteadyShotBaseCritValue)

    cSteadyShotDotDmg = cSteadyShotDotDmg
        + (cBarbedShotDotDmg * cSteadyShotCritValue)
    
    cSteadyShotInstantDmgAoE = cSteadyShotInstantDmgAoE
        + (cStompInstantDmg * cSteadyShotBaseCritValue)
        + (cPoisonedBarbsInstantDmgAoE * cSteadyShotBaseCritValue)

    cSteadyShotDotDmgAoE = cSteadyShotDotDmgAoE
        + (cPoisonedBarbsDotDmgAoE * cSteadyShotBaseCritValue)

    local cSteadyShotDmg = (cSteadyShotInstantDmg + cSteadyShotDotDmg + cSteadyShotInstantDmgAoE + cSteadyShotDotDmgAoE) * castEfficiency

    local mechanicPrio = false
    if aThrilloftheHunt.known then
        local checkThrillOfTheHuntBuff = wan.CheckUnitBuff(nil, aThrilloftheHunt.traitkey)
        if not checkThrillOfTheHuntBuff then
            mechanicPrio = true
        else
            local expirationTime = checkThrillOfTheHuntBuff.expirationTime - GetTime()
            print(expirationTime)

            if expirationTime < 2.5 then
                mechanicPrio = true
            end
        end
    end

    -- Update ability data
    local abilityValue = not mechanicPrio and math.floor(cSteadyShotDmg) or 0
    local mechanicValue = mechanicPrio and math.floor(cSteadyShotDmg) or 0
    wan.UpdateAbilityData(aSteadyShotData.basename, abilityValue, aSteadyShotData.icon, aSteadyShotData.name)
    wan.UpdateMechanicData(aSteadyShotData.basename, mechanicValue, aSteadyShotData.icon, aSteadyShotData.name)
end

-- Init frame 
local frameSteadyShot = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nSteadyShotDmg = wan.GetSpellDescriptionNumbers(aSteadyShotData.id, { 1 })

            local aStompValues = wan.GetTraitDescriptionNumbers(aStomp.entryid, { 1, 2 }, aStomp.rank)
            nStompDmg = aStompValues[1]
            nStompDmgAoE = aStompValues[2]

            local nPoisonedBarbsValues = wan.GetTraitDescriptionNumbers(aPoisonedBarbs.entryid, { 1, 2, 3, 6, 7 })
            nPoisonedBarbsProcChance = nPoisonedBarbsValues[1] * 0.01
            nPoisonedBarbsDmg = nPoisonedBarbsValues[2]
            nPoisonedBarbsSoftCap = nPoisonedBarbsValues[3]
            nSerpentStingInstantDmg = nPoisonedBarbsValues[4]
            nSerpentStingDotDmg = nPoisonedBarbsValues[5]
        end
    end)
end
frameSteadyShot:RegisterEvent("ADDON_LOADED")
frameSteadyShot:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        aSteadyShotData = wan.spellData.SteadyShot

        abilityActive = aSteadyShotData.known and aSteadyShotData.id
        wan.BlizzardEventHandler(frameSteadyShot, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameSteadyShot, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        aBarbedShot = wan.traitData.BarbedShot

        aThrilloftheHunt = wan.traitData.ThrilloftheHunt

        aStomp = wan.traitData.Stomp

        aPoisonedBarbs = wan.traitData.PoisonedBarbs

        nPenetratingShots = wan.GetTraitDescriptionNumbers(wan.traitData.PenetratingShots.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSteadyShot, CheckAbilityValue, abilityActive)
    end
end)