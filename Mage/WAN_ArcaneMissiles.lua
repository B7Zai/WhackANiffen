local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nArcaneMissilesDmg, nArcaneMissilesCastTime, nArcaneMissilesDmgPerMissile = 0, 0, 0

-- Init trait data
local nTraitWithRanks = 0
local nTraitWithUnitCap, nTrait


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ArcaneMissiles.id)
    then
        wan.UpdateAbilityData(wan.spellData.ArcaneMissiles.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.ArcaneMissiles.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ArcaneMissiles.basename)
        return
    end

    local canMovecast = wan.auraData.player.buff_IceFloes and true or false
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.ArcaneMissiles.id, nArcaneMissilesCastTime, canMovecast)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(wan.spellData.ArcaneMissiles.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cArcaneMissilesInstantDmg = nArcaneMissilesDmg
    local cArcaneMissilesDotDmg = 0
    local cArcaneMissilesInstantDmgAoE = 0
    local cArcaneMissilesDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- TRAITS ----

    local cArcaneMissilesCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cArcaneMissilesInstantDmg = cArcaneMissilesInstantDmg

    cArcaneMissilesDotDmg = cArcaneMissilesDotDmg

    cArcaneMissilesInstantDmgAoE = cArcaneMissilesInstantDmgAoE
        + (nArcaneMissilesDmg * cArcaneMissilesCritValue)

    cArcaneMissilesDotDmgAoE = cArcaneMissilesDotDmgAoE
    
    local cArcaneMissilesDmg = (cArcaneMissilesInstantDmg + cArcaneMissilesDotDmg + cArcaneMissilesInstantDmgAoE + cArcaneMissilesDotDmgAoE) * castEfficiency

    -- Update ability data
    local abilityValue = math.floor(cArcaneMissilesDmg)
    wan.UpdateAbilityData(wan.spellData.ArcaneMissiles.basename, abilityValue, wan.spellData.ArcaneMissiles.icon, wan.spellData.ArcaneMissiles.name)
end

-- Init frame 
local frameArcaneMissiles = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nArcaneMissilesValues = wan.GetSpellDescriptionNumbers(wan.spellData.ArcaneMissiles.id, { 1, 2 })
            nArcaneMissilesCastTime = nArcaneMissilesValues[1] * 1000
            nArcaneMissilesDmgPerMissile = nArcaneMissilesValues[2] * 0.2
            nArcaneMissilesDmg = nArcaneMissilesValues[2]
        end
    end)
end
frameArcaneMissiles:RegisterEvent("ADDON_LOADED")
frameArcaneMissiles:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ArcaneMissiles.known and wan.spellData.ArcaneMissiles.id
        wan.BlizzardEventHandler(frameArcaneMissiles, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameArcaneMissiles, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nTraitWithRanks = wan.GetTraitDescriptionNumbers(wan.traitData.TraitName.entryid, { 1 }, wan.traitData.TraitName.rank)

        local nTraitValues = wan.GetTraitDescriptionNumbers(wan.traitData.TraitName.entryid, { 1, 2 })
        nTraitWithUnitCap = nTraitValues[1]
        nTrait = nTraitValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameArcaneMissiles, CheckAbilityValue, abilityActive)
    end
end)