local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nBarbedShotDmg = 0
local checkDebuffs = {}

-- Init trait data
local nFuriousAssault = 0
local nStompDmg, nStompDmgAoE = 0, 0
local nPoisonedBarbsProcChance, nPoisonedBarbsDmg, nPoisonedBarbsSoftCap, nSerpentStingInstantDmg, nSerpentStingDotDmg = 0, 0, 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or not wan.IsSpellUsable(wan.spellData.BarbedShot.id)
    then
        wan.UpdateAbilityData(wan.spellData.BarbedShot.basename)
        wan.UpdateMechanicData(wan.spellData.BarbedShot.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.BarbedShot.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.BarbedShot.basename)
        wan.UpdateMechanicData(wan.spellData.BarbedShot.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cBarbedShotInstantDmg = 0
    local cBarbedShotDotDmg = 0
    local cBarbedShotInstantDmgAoE = 0
    local cBarbedShotDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cBarbedShotDotDmgBase = 0
    local checkBarbedShotDebuff = wan.CheckUnitDebuff(nil, wan.spellData.BarbedShot.formattedName)
    if not checkBarbedShotDebuff then
        local dotPotency = wan.CheckDotPotency()
        cBarbedShotDotDmgBase = cBarbedShotDotDmgBase + (nBarbedShotDmg * dotPotency)
    end

    local cPoisonedBarbsInstantDmgAoE = 0
    local cPoisonedBarbsDotDmgAoE = 0
    if wan.traitData.PoisonedBarbs.known then
        local cPoisonedBarbsUnitOverflow = wan.AdjustSoftCapUnitOverflow(nPoisonedBarbsSoftCap, countValidUnit)
        cPoisonedBarbsInstantDmgAoE = cPoisonedBarbsInstantDmgAoE + ((nPoisonedBarbsDmg + nSerpentStingInstantDmg) * cPoisonedBarbsUnitOverflow * nPoisonedBarbsProcChance)

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkSerpentStingDebuff = wan.CheckUnitDebuff(nil, "SerpentSting")

            if not checkSerpentStingDebuff then
                local dotPotency = wan.CheckDotPotency((nPoisonedBarbsDmg + nSerpentStingInstantDmg), nameplateUnitToken)

                cPoisonedBarbsDotDmgAoE = cPoisonedBarbsDotDmgAoE + (nSerpentStingDotDmg * dotPotency * nPoisonedBarbsProcChance)
            end
        end
    end

    local cStompInstantDmg = 0
    local cStompInstantDmgAoE = 0
    if wan.traitData.Stomp.known then
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

    local cFuriousAssault = 1
    if wan.traitData.FuriousAssault.known and wan.auraData.player.buff_FuriousAssault then
        cFuriousAssault = cFuriousAssault + nFuriousAssault
    end

    -- Crit layer
    local cBarbedShotCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cBarbedShotInstantDmg = cBarbedShotInstantDmg
        + (cStompInstantDmg * cBarbedShotCritValue)

    cBarbedShotDotDmg = cBarbedShotDotDmg
        + (cBarbedShotDotDmgBase * cBarbedShotCritValue)

    cBarbedShotInstantDmgAoE = cBarbedShotInstantDmgAoE
        + (cPoisonedBarbsInstantDmgAoE * cBarbedShotCritValue)
        + (cStompInstantDmgAoE * cBarbedShotCritValue)

    cBarbedShotDotDmgAoE = cBarbedShotDotDmgAoE
        + (cPoisonedBarbsDotDmgAoE * cBarbedShotCritValue) 

    local cBarbedShotDmg = cBarbedShotInstantDmg + cBarbedShotDotDmg + cBarbedShotInstantDmgAoE + cBarbedShotDotDmgAoE

    local mechanicPrio = false
    if wan.traitData.ThrilloftheHunt.known then
        local checkThrillOfTheHuntBuff = wan.CheckUnitBuff(nil, wan.traitData.ThrilloftheHunt.traitkey)
        if not checkThrillOfTheHuntBuff then
            mechanicPrio = true
        else
            local expirationTime = checkThrillOfTheHuntBuff.expirationTime - GetTime()

            if expirationTime < 2.5 then
                mechanicPrio = true
            end
        end
    end

    local abilityValue = not mechanicPrio and math.floor(cBarbedShotDmg) or 0
    local mechanicValue = mechanicPrio and math.floor(cBarbedShotDmg) or 0
    wan.UpdateAbilityData(wan.spellData.BarbedShot.basename, abilityValue, wan.spellData.BarbedShot.icon, wan.spellData.BarbedShot.name)
    wan.UpdateMechanicData(wan.spellData.BarbedShot.basename, mechanicValue, wan.spellData.BarbedShot.icon, wan.spellData.BarbedShot.name)
end

-- Init frame 
local frameBarbedShot = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nBarbedShotDmg = wan.GetSpellDescriptionNumbers(wan.spellData.BarbedShot.id, { 1 })

            local nStompValues = wan.GetTraitDescriptionNumbers(wan.traitData.Stomp.entryid, { 1, 2 })
            nStompDmg = nStompValues[1]
            nStompDmgAoE = nStompValues[2]

            local nPoisonedBarbsValues = wan.GetTraitDescriptionNumbers(wan.traitData.PoisonedBarbs.entryid, { 1, 2, 3, 6, 7 })
            nPoisonedBarbsProcChance = nPoisonedBarbsValues[1] * 0.01
            nPoisonedBarbsDmg = nPoisonedBarbsValues[2]
            nPoisonedBarbsSoftCap = nPoisonedBarbsValues[3]
            nSerpentStingInstantDmg = nPoisonedBarbsValues[4]
            nSerpentStingDotDmg = nPoisonedBarbsValues[5]
        end
    end)
end
frameBarbedShot:RegisterEvent("ADDON_LOADED")
frameBarbedShot:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BarbedShot.known and wan.spellData.BarbedShot.id
        wan.BlizzardEventHandler(frameBarbedShot, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBarbedShot, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nFuriousAssault = wan.GetTraitDescriptionNumbers(wan.traitData.FuriousAssault.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBarbedShot, CheckAbilityValue, abilityActive)
    end
end)