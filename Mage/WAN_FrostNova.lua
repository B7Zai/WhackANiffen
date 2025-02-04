local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nFrostNovaDmg, nFrostNovaMaxRange = 0, 0

-- Init trait data
local nTraitWithRanks = 0
local nTraitWithUnitCap, nTrait


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

    local cFrostNovaInstantDmg = nFrostNovaDmg
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

    ---- TRAITS ----

    local cFrostNovaCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cFrostNovaInstantDmg = cFrostNovaInstantDmg

    cFrostNovaDotDmg = cFrostNovaDotDmg

    cFrostNovaInstantDmgAoE = cFrostNovaInstantDmgAoE
        + (nFrostNovaBaseDmgAoE * cFrostNovaCritValue)

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
        nTraitWithRanks = wan.GetTraitDescriptionNumbers(wan.traitData.TraitName.entryid, { 1 }, wan.traitData.TraitName.rank)

        local nTraitValues = wan.GetTraitDescriptionNumbers(wan.traitData.TraitName.entryid, { 1, 2 })
        nTraitWithUnitCap = nTraitValues[1]
        nTrait = nTraitValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFrostNova, CheckAbilityValue, abilityActive)
    end
end)