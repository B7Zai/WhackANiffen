local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nBlastWaveDmg, nBlastWaveMaxRange = 0, 0

-- Init trait data
local nOverflowingEnergy = 0
local nFiresIre = 0
local nMoltenFuryThreshold, nMoltenFury = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.BlastWave.id)
    then
        wan.UpdateAbilityData(wan.spellData.BlastWave.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nBlastWaveMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.BlastWave.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cBlastWaveInstantDmg = 0
    local cBlastWaveDotDmg = 0
    local cBlastWaveInstantDmgAoE = 0
    local cBlastWaveDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local nBlastWaveBaseDmgAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local unitAoEPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

        nBlastWaveBaseDmgAoE = nBlastWaveBaseDmgAoE + (nBlastWaveDmg * unitAoEPotency)
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

    local cBlastWaveCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cBlastWaveInstantDmg = cBlastWaveInstantDmg

    cBlastWaveDotDmg = cBlastWaveDotDmg

    cBlastWaveInstantDmgAoE = cBlastWaveInstantDmgAoE
        + (nBlastWaveBaseDmgAoE * cMoltenFury * cBlastWaveCritValue)

    cBlastWaveDotDmgAoE = cBlastWaveDotDmgAoE

    local cBlastWaveDmg = cBlastWaveInstantDmg + cBlastWaveDotDmg + cBlastWaveInstantDmgAoE + cBlastWaveDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cBlastWaveDmg)
    wan.UpdateAbilityData(wan.spellData.BlastWave.basename, abilityValue, wan.spellData.BlastWave.icon, wan.spellData.BlastWave.name)
end

-- Init frame 
local frameBlastWave = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nBlastWaveValues = wan.GetSpellDescriptionNumbers(wan.spellData.BlastWave.id, { 1, 2 })
            nBlastWaveDmg = nBlastWaveValues[1]
            nBlastWaveMaxRange = nBlastWaveValues[2]
        end
    end)
end
frameBlastWave:RegisterEvent("ADDON_LOADED")
frameBlastWave:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.BlastWave.known and wan.spellData.BlastWave.id
        wan.BlizzardEventHandler(frameBlastWave, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameBlastWave, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        nFiresIre = wan.GetTraitDescriptionNumbers(wan.traitData.FiresIre.entryid, { 2 }, wan.traitData.FiresIre.rank)

        local nMoltenFuryValues = wan.GetTraitDescriptionNumbers(wan.traitData.MoltenFury.entryid, { 1, 2 })
        nMoltenFuryThreshold = nMoltenFuryValues[1] * 0.01
        nMoltenFury = nMoltenFuryValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameBlastWave, CheckAbilityValue, abilityActive)
    end
end)