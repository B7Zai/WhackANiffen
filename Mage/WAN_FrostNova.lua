local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nFrostNovaDmg, nFrostNovaMaxRange = 0, 0

-- Init trait data
local nOverflowingEnergy = 0
local nFiresIre = 0
local nMoltenFuryThreshold, nMoltenFury = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.FrostNova.id)
    then
        wan.UpdateAbilityData(wan.spellData.FrostNova.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nFrostNovaMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.FrostNova.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cFrostNovaInstantDmg = 0
    local cFrostNovaDotDmg = 0
    local cFrostNovaInstantDmgAoE = 0
    local cFrostNovaDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local nFrostNovaBaseDmgAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local unitAoEPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

        nFrostNovaBaseDmgAoE = nFrostNovaBaseDmgAoE + (nFrostNovaDmg * unitAoEPotency)
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

    local cFrostNovaCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cFrostNovaInstantDmg = cFrostNovaInstantDmg

    cFrostNovaDotDmg = cFrostNovaDotDmg

    cFrostNovaInstantDmgAoE = cFrostNovaInstantDmgAoE
        + (nFrostNovaBaseDmgAoE * cMoltenFury * cFrostNovaCritValue)

    cFrostNovaDotDmgAoE = cFrostNovaDotDmgAoE

    local cFrostNovaDmg = cFrostNovaInstantDmg + cFrostNovaDotDmg + cFrostNovaInstantDmgAoE + cFrostNovaDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cFrostNovaDmg)
    wan.UpdateAbilityData(wan.spellData.FrostNova.basename, abilityValue, wan.spellData.FrostNova.icon, wan.spellData.FrostNova.name)
end

-- Init frame 
local frameFrostNova = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nFrostNovaValues = wan.GetSpellDescriptionNumbers(wan.spellData.FrostNova.id, { 1, 2 })
            nFrostNovaMaxRange = nFrostNovaValues[1]
            nFrostNovaDmg = nFrostNovaValues[2]
        end
    end)
end
frameFrostNova:RegisterEvent("ADDON_LOADED")
frameFrostNova:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.FrostNova.known and wan.spellData.FrostNova.id
        wan.BlizzardEventHandler(frameFrostNova, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFrostNova, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        nFiresIre = wan.GetTraitDescriptionNumbers(wan.traitData.FiresIre.entryid, { 2 }, wan.traitData.FiresIre.rank)

        local nMoltenFuryValues = wan.GetTraitDescriptionNumbers(wan.traitData.MoltenFury.entryid, { 1, 2 })
        nMoltenFuryThreshold = nMoltenFuryValues[1] * 0.01
        nMoltenFury = nMoltenFuryValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFrostNova, CheckAbilityValue, abilityActive)
    end
end)