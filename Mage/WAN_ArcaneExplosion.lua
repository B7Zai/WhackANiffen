local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nArcaneExplosionDmg, nArcaneExplosionMaxRange = 0, 0

-- Init trait data
local nOverflowingEnergy = 0
local nConcentratedPower = 0
local nEureka = 0
local nImprovedScorch = 0
local nFiresIre = 0
local nMoltenFuryThreshold, nMoltenFury = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ArcaneExplosion.id)
    then
        wan.UpdateAbilityData(wan.spellData.ArcaneExplosion.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nArcaneExplosionMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ArcaneExplosion.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cArcaneExplosionInstantDmg = 0
    local cArcaneExplosionDotDmg = 0
    local cArcaneExplosionInstantDmgAoE = 0
    local cArcaneExplosionDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- CLASS TRAITS ----

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
    end

    ---- ARCANE TRAITS ----

    local cConcentratedPower = 1
    if wan.traitData.ConcentratedPower.known then
        local formattedBuffName = wan.spellData.Clearcasting.formattedName
        local checkClearcastingBuff = wan.CheckUnitBuff(nil, formattedBuffName)
        if checkClearcastingBuff then
            cConcentratedPower = cConcentratedPower + nConcentratedPower
        end
    end

    local cEureka = 1
    if wan.traitData.Eureka.known then
        local formattedBuffName = wan.spellData.Clearcasting.formattedName
        local checkClearcastingBuff = wan.CheckUnitBuff(nil, formattedBuffName)
        if checkClearcastingBuff then
            cEureka = cEureka + nEureka
        end
    end

    ---- FIRE TRAITS ----

    local cImprovedScorchAoE = 1
    if wan.traitData.ImprovedScorch.known then
        local formattedDebuffName = wan.traitData.ImprovedScorch.traitkey
        local countImprovedScorchDebuff = 0

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitImprovedScorchDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)
            local checkImprovedScorchStacks = checkUnitImprovedScorchDebuff and checkUnitImprovedScorchDebuff.applications

            if checkImprovedScorchStacks == 0 then
                checkImprovedScorchStacks = 1
            end

            if checkUnitImprovedScorchDebuff then
                countImprovedScorchDebuff = countImprovedScorchDebuff + (1 *  checkImprovedScorchStacks)
            end
        end

        if countImprovedScorchDebuff > 0 then
            cImprovedScorchAoE = cImprovedScorchAoE + (nImprovedScorch * (countImprovedScorchDebuff / countValidUnit))
        end
    end

    if wan.traitData.Combustion.known then
        local checkCombustionBuff = wan.CheckUnitBuff(nil, wan.spellData.Combustion.formattedName)
        if checkCombustionBuff then
            critChanceMod = critChanceMod + 100

            if wan.traitData.FiresIre.known then
                critDamageMod = critDamageMod + nFiresIre
            end
        end
    end

    local cMoltenFury = 1
    if wan.traitData.MoltenFury.known then
        local countMoltenFury = 0
        for _, nameplateGUID in pairs(idValidUnit) do
            local checkPercentageHealth = targetGUID and UnitPercentHealthFromGUID(nameplateGUID) or 1
            if checkPercentageHealth < nMoltenFuryThreshold then
                countMoltenFury = countMoltenFury + 1
            end
        end

        if countMoltenFury > 0 then
            cMoltenFury = cMoltenFury + ((nMoltenFury * countMoltenFury) / countValidUnit)
        end
    end

    local cArcaneExplosionCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cArcaneExplosionInstantDmg = cArcaneExplosionInstantDmg

    cArcaneExplosionDotDmg = cArcaneExplosionDotDmg

    cArcaneExplosionInstantDmgAoE = cArcaneExplosionInstantDmgAoE
        + (nArcaneExplosionDmg * countValidUnit * cEureka * cConcentratedPower * cImprovedScorchAoE * cMoltenFury * cArcaneExplosionCritValue)

    cArcaneExplosionDotDmgAoE = cArcaneExplosionDotDmgAoE

    local cArcaneExplosionDmg = cArcaneExplosionInstantDmg + cArcaneExplosionDotDmg + cArcaneExplosionInstantDmgAoE + cArcaneExplosionDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cArcaneExplosionDmg)
    wan.UpdateAbilityData(wan.spellData.ArcaneExplosion.basename, abilityValue, wan.spellData.ArcaneExplosion.icon, wan.spellData.ArcaneExplosion.name)
end

-- Init frame 
local frameArcaneExplosion = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nArcaneExplosionValues = wan.GetSpellDescriptionNumbers(wan.spellData.ArcaneExplosion.id, { 1, 2 })
            nArcaneExplosionDmg = nArcaneExplosionValues[1]
            nArcaneExplosionMaxRange = nArcaneExplosionValues[2]
        end
    end)
end
frameArcaneExplosion:RegisterEvent("ADDON_LOADED")
frameArcaneExplosion:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ArcaneExplosion.known and wan.spellData.ArcaneExplosion.id
        wan.BlizzardEventHandler(frameArcaneExplosion, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameArcaneExplosion, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        nConcentratedPower = wan.GetTraitDescriptionNumbers(wan.traitData.ConcentratedPower.entryid, { 2 }) * 0.01

        nEureka = wan.GetTraitDescriptionNumbers(wan.traitData.Eureka.entryid, { 1 }) * 0.01

        nImprovedScorch = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedScorch.entryid, { 2 }) * 0.01

        nFiresIre = wan.GetTraitDescriptionNumbers(wan.traitData.FiresIre.entryid, { 2 }, wan.traitData.FiresIre.rank)

        local nMoltenFuryValues = wan.GetTraitDescriptionNumbers(wan.traitData.MoltenFury.entryid, { 1, 2 })
        nMoltenFuryThreshold = nMoltenFuryValues[1] * 0.01
        nMoltenFury = nMoltenFuryValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameArcaneExplosion, CheckAbilityValue, abilityActive)
    end
end)