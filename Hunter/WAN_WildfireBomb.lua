local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "HUNTER" then return end

-- Init spell data
local abilityActive = false
local nWildfireBombInstantDmg, nWildfireBombDotDmg, nWildfireBombSoftCap, nWildfireBomb = 0, 0, 0, 0

-- Init trait data
local nLunarStormDuration, nLunarStormDmg, nLunarStormTickRate, nLunarStorm = 0, 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.WildfireBomb.id)
    then
        wan.UpdateAbilityData(wan.spellData.WildfireBomb.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit ,idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.WildfireBomb.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.WildfireBomb.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cWildfireBombInstantDmg = 0
    local cWildfireBombDotDmg = 0
    local cWildfireBombInstantDmgAoE = 0
    local cWildfireBombDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cWildfireBombDotDmgBase = 0
    local formattedDebuffName = wan.spellData.WildfireBomb.formattedName
    local checkWildfireBombDebuff = wan.CheckUnitDebuff(nil, formattedDebuffName)
    if not checkWildfireBombDebuff then
        local dotPotency = wan.CheckDotPotency(nWildfireBombInstantDmg, targetUnitToken)
        cWildfireBombDotDmgBase = cWildfireBombDotDmgBase + (nWildfireBombDotDmg * dotPotency)
    end

    local cWildfireBombInstantDmgBaseAoE = 0
    local cWildfireBombDotDmgBaseAoE = 0
    local cWildfireBombUnitOverflow = wan.SoftCapOverflow(nWildfireBombSoftCap, countValidUnit)
    for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

        if nameplateGUID ~= targetGUID then
            cWildfireBombInstantDmgBaseAoE = cWildfireBombInstantDmgBaseAoE + (nWildfireBombInstantDmg * cWildfireBombUnitOverflow)
            local checkUnitWildfireBombDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)

            if not checkUnitWildfireBombDebuff then
                local dotPotency = wan.CheckDotPotency(nWildfireBombInstantDmg, nameplateUnitToken)
                cWildfireBombDotDmgBaseAoE = cWildfireBombDotDmgBaseAoE + (nWildfireBombDotDmg * dotPotency)
            end
        end
    end

    ---- SENTINEL TRAITS ----

    local cLunarStormInstantDmgAoE = 0
    if wan.traitData.LunarStorm.known then
        local checkLunarStormDebuff = wan.CheckUnitDebuff("player", wan.traitData.LunarStorm.traitkey)
        if not checkLunarStormDebuff then
            cLunarStormInstantDmgAoE = cLunarStormInstantDmgAoE + nLunarStorm
        end
    end

    local cWildfireBombCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cWildfireBombInstantDmg = cWildfireBombInstantDmg
        + (nWildfireBombInstantDmg * nWildfireBomb * cWildfireBombUnitOverflow * cWildfireBombCritValue)

    cWildfireBombDotDmg = cWildfireBombDotDmg
        + (cWildfireBombDotDmgBase * cWildfireBombCritValue)

    cWildfireBombInstantDmgAoE = cWildfireBombInstantDmgAoE
        + (cWildfireBombInstantDmgBaseAoE * nWildfireBomb * cWildfireBombCritValue)
        + (cLunarStormInstantDmgAoE * cWildfireBombCritValue)

    cWildfireBombDotDmgAoE = cWildfireBombDotDmgAoE
        + (cWildfireBombDotDmgBaseAoE * cWildfireBombCritValue)

    local cWildfireBombDmg = cWildfireBombInstantDmg + cWildfireBombDotDmg + cWildfireBombInstantDmgAoE + cWildfireBombDotDmgAoE

    local abilityValue = math.floor(cWildfireBombDmg)
    wan.UpdateAbilityData(wan.spellData.WildfireBomb.basename, abilityValue, wan.spellData.WildfireBomb.icon, wan.spellData.WildfireBomb.name)
end

-- Init frame 
local frameWildfireBomb = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nWildfireBombValues = wan.GetSpellDescriptionNumbers(wan.spellData.WildfireBomb.id, { 1, 2, 4, 5 })
            nWildfireBombInstantDmg = nWildfireBombValues[1]
            nWildfireBombDotDmg = nWildfireBombValues[2]
            nWildfireBombSoftCap = nWildfireBombValues[3]
            nWildfireBomb = 1 + (nWildfireBombValues[4] * 0.01)

            local nLunarStormValues = wan.GetTraitDescriptionNumbers(wan.traitData.LunarStorm.entryid, { 3, 4, 6 })
            nLunarStormDmg = nLunarStormValues[1]
            nLunarStormDuration = nLunarStormValues[2]
            nLunarStormTickRate = nLunarStormValues[3]
            nLunarStorm = nLunarStormDmg * (nLunarStormDuration / nLunarStormTickRate)
        end
    end)
end
frameWildfireBomb:RegisterEvent("ADDON_LOADED")
frameWildfireBomb:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.WildfireBomb.known and wan.spellData.WildfireBomb.id
        wan.BlizzardEventHandler(frameWildfireBomb, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameWildfireBomb, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameWildfireBomb, CheckAbilityValue, abilityActive)
    end
end)