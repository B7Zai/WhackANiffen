local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nConeofColdDmg, nConeofColdMaxRange = 0, 12

-- Init trait data
local nTraitWithRanks = 0
local nTraitWithUnitCap, nTrait


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ConeofCold.id)
    then
        wan.UpdateAbilityData(wan.spellData.ConeofCold.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nConeofColdMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ConeofCold.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cConeofColdInstantDmg = nConeofColdDmg
    local cConeofColdDotDmg = 0
    local cConeofColdInstantDmgAoE = 0
    local cConeofColdDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local nConeofColdBaseDmgAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local unitAoEPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

        nConeofColdBaseDmgAoE = nConeofColdBaseDmgAoE + (nConeofColdDmg * unitAoEPotency)
    end

    ---- TRAITS ----

    local cConeofColdCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cConeofColdInstantDmg = cConeofColdInstantDmg

    cConeofColdDotDmg = cConeofColdDotDmg

    cConeofColdInstantDmgAoE = cConeofColdInstantDmgAoE
        + (nConeofColdBaseDmgAoE * cConeofColdCritValue)

    cConeofColdDotDmgAoE = cConeofColdDotDmgAoE

    local cConeofColdDmg = cConeofColdInstantDmg + cConeofColdDotDmg + cConeofColdInstantDmgAoE + cConeofColdDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cConeofColdDmg)
    wan.UpdateAbilityData(wan.spellData.ConeofCold.basename, abilityValue, wan.spellData.ConeofCold.icon, wan.spellData.ConeofCold.name)
end

-- Init frame 
local frameConeofCold = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nConeofColdDmg = wan.GetSpellDescriptionNumbers(wan.spellData.ConeofCold.id, { 1 })
        end
    end)
end
frameConeofCold:RegisterEvent("ADDON_LOADED")
frameConeofCold:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ConeofCold.known and wan.spellData.ConeofCold.id
        wan.BlizzardEventHandler(frameConeofCold, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameConeofCold, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nTraitWithRanks = wan.GetTraitDescriptionNumbers(wan.traitData.TraitName.entryid, { 1 }, wan.traitData.TraitName.rank)

        local nTraitValues = wan.GetTraitDescriptionNumbers(wan.traitData.TraitName.entryid, { 1, 2 })
        nTraitWithUnitCap = nTraitValues[1]
        nTrait = nTraitValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameConeofCold, CheckAbilityValue, abilityActive)
    end
end)