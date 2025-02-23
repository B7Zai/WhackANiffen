local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nIceNovaDmg = 0

-- Init trait data
local nOverflowingEnergy = 0
local nFiresIre = 0
local nMoltenFuryThreshold, nMoltenFury = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.IceNova.id)
    then
        wan.UpdateAbilityData(wan.spellData.IceNova.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.IceNova.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.IceNova.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cIceNovaInstantDmg = 0
    local cIceNovaDotDmg = 0
    local cIceNovaInstantDmgAoE = 0
    local cIceNovaDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local nIceNovaBaseDmgAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local unitAoEPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

        nIceNovaBaseDmgAoE = nIceNovaBaseDmgAoE + (nIceNovaDmg * unitAoEPotency)
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

    local cIceNovaCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cIceNovaInstantDmg = cIceNovaInstantDmg

    cIceNovaDotDmg = cIceNovaDotDmg

    cIceNovaInstantDmgAoE = cIceNovaInstantDmgAoE
        + (nIceNovaBaseDmgAoE * cMoltenFury * cIceNovaCritValue)

    cIceNovaDotDmgAoE = cIceNovaDotDmgAoE

    local cIceNovaDmg = cIceNovaInstantDmg + cIceNovaDotDmg + cIceNovaInstantDmgAoE + cIceNovaDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cIceNovaDmg)
    wan.UpdateAbilityData(wan.spellData.IceNova.basename, abilityValue, wan.spellData.IceNova.icon, wan.spellData.IceNova.name)
end

-- Init frame 
local frameIceNova = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nIceNovaDmg = wan.GetSpellDescriptionNumbers(wan.spellData.IceNova.id, { 1 })
        end
    end)
end
frameIceNova:RegisterEvent("ADDON_LOADED")
frameIceNova:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.IceNova.known and wan.spellData.IceNova.id
        wan.BlizzardEventHandler(frameIceNova, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameIceNova, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        nFiresIre = wan.GetTraitDescriptionNumbers(wan.traitData.FiresIre.entryid, { 2 }, wan.traitData.FiresIre.rank)

        local nMoltenFuryValues = wan.GetTraitDescriptionNumbers(wan.traitData.MoltenFury.entryid, { 1, 2 })
        nMoltenFuryThreshold = nMoltenFuryValues[1] * 0.01
        nMoltenFury = nMoltenFuryValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameIceNova, CheckAbilityValue, abilityActive)
    end
end)