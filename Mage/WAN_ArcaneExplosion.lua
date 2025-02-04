local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nArcaneExplosionDmg, nArcaneExplosionMaxRange = 0, 0

-- Init trait data
local nTraitWithRanks = 0
local nTraitWithUnitCap, nTrait


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

    local cArcaneExplosionInstantDmg = nArcaneExplosionDmg
    local cArcaneExplosionDotDmg = 0
    local cArcaneExplosionInstantDmgAoE = 0
    local cArcaneExplosionDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local nArcaneExplosionBaseDmgAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local unitAoEPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

        nArcaneExplosionBaseDmgAoE = nArcaneExplosionBaseDmgAoE + (nArcaneExplosionDmg * unitAoEPotency)
    end

    ---- TRAITS ----

    local cArcaneExplosionCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cArcaneExplosionInstantDmg = cArcaneExplosionInstantDmg

    cArcaneExplosionDotDmg = cArcaneExplosionDotDmg

    cArcaneExplosionInstantDmgAoE = cArcaneExplosionInstantDmgAoE
        + (nArcaneExplosionBaseDmgAoE * cArcaneExplosionCritValue)

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
        nTraitWithRanks = wan.GetTraitDescriptionNumbers(wan.traitData.TraitName.entryid, { 1 }, wan.traitData.TraitName.rank)

        local nTraitValues = wan.GetTraitDescriptionNumbers(wan.traitData.TraitName.entryid, { 1, 2 })
        nTraitWithUnitCap = nTraitValues[1]
        nTrait = nTraitValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameArcaneExplosion, CheckAbilityValue, abilityActive)
    end
end)