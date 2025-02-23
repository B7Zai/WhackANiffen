local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nSupernovaDmg, nSupernova = 0, 0

-- Init trait data
local nOverflowingEnergy = 0
local nMoltenFuryThreshold, nMoltenFury = 0, 0
local nGravityLapseDmg, nGravityLapseUnitCap = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Supernova.id)
    then
        wan.UpdateAbilityData(wan.spellData.Supernova.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Supernova.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Supernova.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cSupernovaInstantDmg = 0
    local cSupernovaDotDmg = 0
    local cSupernovaInstantDmgAoE = 0
    local cSupernovaDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cSupernovaBaseDmgAoE = 0
    for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
        if nameplateGUID ~= targetGUID then
            local unitAoEPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

            cSupernovaBaseDmgAoE = cSupernovaBaseDmgAoE + (nSupernovaDmg * unitAoEPotency)
        end
    end

    ---- CLASS TRAITS ----

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
    end

    ---- FIRE TRAITS ----

    if wan.traitData.Combustion.known then
        local checkCombustionBuff = wan.CheckUnitBuff(nil, wan.spellData.Combustion.formattedName)
        if checkCombustionBuff then
            critChanceMod = critChanceMod + 100
        end
    end

    local cMoltenFury = 1
    local cMoltenFuryAoE = 1
    if wan.traitData.MoltenFury.known then
        local checkPercentageHealth = targetGUID and UnitPercentHealthFromGUID(targetGUID) or 1
        if checkPercentageHealth < nMoltenFuryThreshold then
            cMoltenFury = cMoltenFury + nMoltenFury
        end

        local countMoltenFury = 0
        local countMoltenFuryUnit = math.max(countValidUnit - 1, 0)
        for _, nameplateGUID in pairs(idValidUnit) do
            if nameplateGUID ~= targetGUID then
                local checkPercentageHealth = targetGUID and UnitPercentHealthFromGUID(nameplateGUID) or 1
                if checkPercentageHealth < nMoltenFuryThreshold then
                    countMoltenFury = countMoltenFury + 1
                end
            end
        end

        if countMoltenFuryUnit > 0 then
            cMoltenFuryAoE = cMoltenFuryAoE + ((nMoltenFury * countMoltenFury) / countMoltenFuryUnit)
        end
    end

    ---- SUNFURY TRAITS ----

    local cGravityLapseBaseDmgAoE = 0
    local cGravityLapse = 1
    if wan.traitData.GravityLapse.known then
        cGravityLapse = 0
        local countGravityLapseUnit = 0

        for _, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                cGravityLapseBaseDmgAoE = cGravityLapseBaseDmgAoE + (nGravityLapseDmg)
                countGravityLapseUnit = countGravityLapseUnit + 1

                if countGravityLapseUnit >= nGravityLapseUnitCap then break end
            end
        end
    end

    local cSupernovaCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cSupernovaInstantDmg = cSupernovaInstantDmg
        + (nSupernovaDmg * nSupernova * cMoltenFury * cGravityLapse * cSupernovaCritValue)
        + (nGravityLapseDmg * cMoltenFury * cGravityLapse * cSupernovaCritValue)

    cSupernovaDotDmg = cSupernovaDotDmg

    cSupernovaInstantDmgAoE = cSupernovaInstantDmgAoE
        + (cSupernovaBaseDmgAoE * cMoltenFuryAoE * cGravityLapse * cSupernovaCritValue)
        + (cGravityLapseBaseDmgAoE * cMoltenFuryAoE * cSupernovaCritValue)

    cSupernovaDotDmgAoE = cSupernovaDotDmgAoE

    local cSupernovaDmg = cSupernovaInstantDmg + cSupernovaDotDmg + cSupernovaInstantDmgAoE + cSupernovaDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cSupernovaDmg)
    wan.UpdateAbilityData(wan.spellData.Supernova.basename, abilityValue, wan.spellData.Supernova.icon, wan.spellData.Supernova.name)
end

-- Init frame 
local frameSupernova = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nSupernovaValues = wan.GetSpellDescriptionNumbers(wan.spellData.Supernova.id, { 1, 3 })
            nSupernovaDmg = nSupernovaValues[1]
            nSupernova = nSupernovaValues[2] * 0.01 + 1

            local nGravityLapseValues = wan.GetSpellDescriptionNumbers(wan.spellData.Supernova.id, { 1, 3 })
            nGravityLapseUnitCap = nGravityLapseValues[1]
            nGravityLapseDmg = nGravityLapseValues[2]
        end
    end)
end
frameSupernova:RegisterEvent("ADDON_LOADED")
frameSupernova:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = (wan.spellData.Supernova.know or wan.traitData.GravityLapse.known) and wan.spellData.Supernova.id
        wan.BlizzardEventHandler(frameSupernova, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameSupernova, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        local nMoltenFuryValues = wan.GetTraitDescriptionNumbers(wan.traitData.MoltenFury.entryid, { 1, 2 })
        nMoltenFuryThreshold = nMoltenFuryValues[1] * 0.01
        nMoltenFury = nMoltenFuryValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSupernova, CheckAbilityValue, abilityActive)
    end
end)