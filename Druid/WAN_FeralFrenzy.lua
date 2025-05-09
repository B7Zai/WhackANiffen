local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local abilityActive = false
local nFeralFrenzyInstantDmg, nFeralFrenzyDotDmg = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or not wan.PlayerState.Combat
        or not wan.IsSpellUsable(wan.spellData.FeralFrenzy.id)
    then
        wan.UpdateAbilityData(wan.spellData.FeralFrenzy.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit = wan.ValidUnitBoolCounter(wan.spellData.FeralFrenzy.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.FeralFrenzy.basename)
        return
    end

    -- Remove physical layer
    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cFeralFrenzyInstantDmg = nFeralFrenzyInstantDmg * checkPhysicalDR
    local cFeralFrenzyDotDmg = 0

    -- Dot value
    local checkFeralFrenzyDebuff = wan.auraData[wan.TargetUnitID] and wan.auraData[wan.TargetUnitID].debuff_FeralFrenzy
    if not checkFeralFrenzyDebuff then
        local dotPotency = wan.CheckDotPotency(cFeralFrenzyInstantDmg)
        cFeralFrenzyDotDmg = cFeralFrenzyDotDmg + (nFeralFrenzyDotDmg * dotPotency)
    end

    -- Base value
    local cFeralFrenzy = cFeralFrenzyInstantDmg + cFeralFrenzyDotDmg
    local cdPotency = wan.CheckOffensiveCooldownPotency(cFeralFrenzy, isValidUnit)

    -- Crit layer
    cFeralFrenzy = cFeralFrenzy * wan.ValueFromCritical(wan.CritChance)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cFeralFrenzy) or 0
    wan.UpdateAbilityData(wan.spellData.FeralFrenzy.basename, abilityValue, wan.spellData.FeralFrenzy.icon, wan.spellData.FeralFrenzy.name)
end

-- Init frame 
local frameFeralFrenzy = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local feralFrenzyValues = wan.GetSpellDescriptionNumbers(wan.spellData.FeralFrenzy.id, { 2, 3 })
            nFeralFrenzyInstantDmg = feralFrenzyValues[1]
            nFeralFrenzyDotDmg = feralFrenzyValues[2]
        end
    end)
end
frameFeralFrenzy:RegisterEvent("ADDON_LOADED")
frameFeralFrenzy:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.FeralFrenzy.known and wan.spellData.FeralFrenzy.id
        wan.BlizzardEventHandler(frameFeralFrenzy, abilityActive, "SPELLS_CHANGED", "UNIT_AURA",
            "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFeralFrenzy, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFeralFrenzy, CheckAbilityValue, abilityActive)
    end
end)
