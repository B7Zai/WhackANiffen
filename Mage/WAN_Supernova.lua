local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nSupernovaDmg, nSupernova = 0, 0

-- Init trait data
local nTraitWithRanks = 0
local nTraitWithUnitCap, nTrait


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

    local cSupernovaInstantDmg = nSupernovaDmg
    local cSupernovaDotDmg = 0
    local cSupernovaInstantDmgAoE = 0
    local cSupernovaDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cSupernovaBaseDmg = 0
    local cSupernovaBaseDmgAoE = 0
    for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
        cSupernovaBaseDmg = cSupernovaBaseDmg + (nSupernovaDmg * nSupernova)

        if nameplateGUID ~= targetGUID then
            local unitAoEPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

            cSupernovaBaseDmgAoE = cSupernovaBaseDmgAoE + (nSupernovaDmg * unitAoEPotency)
        end
    end

    ---- TRAITS ----

    local cSupernovaCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cSupernovaInstantDmg = cSupernovaInstantDmg

    cSupernovaDotDmg = cSupernovaDotDmg

    cSupernovaInstantDmgAoE = cSupernovaInstantDmgAoE
        + (cSupernovaBaseDmgAoE * cSupernovaCritValue)

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
            local nSupernovaValues = wan.GetSpellDescriptionNumbers(wan.spellData.Supernova.id, { 1, 2 })
            nSupernovaDmg = nSupernovaValues[1]
            nSupernova = nSupernovaValues[2] * 0.01 + 1
        end
    end)
end
frameSupernova:RegisterEvent("ADDON_LOADED")
frameSupernova:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Supernova.known and wan.spellData.Supernova.id
        wan.BlizzardEventHandler(frameSupernova, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameSupernova, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nTraitWithRanks = wan.GetTraitDescriptionNumbers(wan.traitData.TraitName.entryid, { 1 }, wan.traitData.TraitName.rank)

        local nTraitValues = wan.GetTraitDescriptionNumbers(wan.traitData.TraitName.entryid, { 1, 2 })
        nTraitWithUnitCap = nTraitValues[1]
        nTrait = nTraitValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameSupernova, CheckAbilityValue, abilityActive)
    end
end)