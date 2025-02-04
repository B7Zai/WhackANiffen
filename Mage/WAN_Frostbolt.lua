local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nFrostboltDmg = 0

-- Init trait datat


-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Frostbolt.id)
    then
        wan.UpdateAbilityData(wan.spellData.Frostbolt.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Frostbolt.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Frostbolt.basename)
        return
    end

    local canMovecast = wan.auraData.player.buff_IceFloes and true or false
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Frostbolt.id, wan.spellData.Frostbolt.castTime, canMovecast)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(wan.spellData.Frostbolt.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cFrostboltInstantDmg = 0
    local cFrostboltDotDmg = 0
    local cFrostboltInstantDmgAoE = 0
    local cFrostboltDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cFrostboltCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cFrostboltInstantDmg = cFrostboltInstantDmg
        + (nFrostboltDmg* cFrostboltCritValue)

    cFrostboltDotDmg = cFrostboltDotDmg 

    cFrostboltInstantDmgAoE = cFrostboltInstantDmgAoE

    cFrostboltDotDmgAoE = cFrostboltDotDmgAoE

    local cFrostboltDmg = (cFrostboltInstantDmg + cFrostboltDotDmg + cFrostboltInstantDmgAoE + cFrostboltDotDmgAoE) * castEfficiency

    -- Update ability data
    local abilityValue = math.floor(cFrostboltDmg)
    wan.UpdateAbilityData(wan.spellData.Frostbolt.basename, abilityValue, wan.spellData.Frostbolt.icon, wan.spellData.Frostbolt.name)
end

-- Init frame 
local frameFrostbolt = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nFrostboltDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Frostbolt.id, { 1 })

        end
    end)
end
frameFrostbolt:RegisterEvent("ADDON_LOADED")
frameFrostbolt:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Frostbolt.known and wan.spellData.Frostbolt.id
        wan.BlizzardEventHandler(frameFrostbolt, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFrostbolt, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        --nPenetratingShots = wan.GetTraitDescriptionNumbers(wan.traitData.PenetratingShots.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFrostbolt, CheckAbilityValue, abilityActive)
    end
end)