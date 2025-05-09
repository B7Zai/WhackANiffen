local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nWildMushroomInstantDmg, nWildMushroomDotDmg = 0, 0
local sWildMushroomAuraKey = "FungalGrowth"
local nMasteryAstralInvocationArcane = 0
local nMasteryAstralInvocationNature = 0
local nMasteryAstralInvocationAstral = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or wan.CheckUnitBuff(nil, wan.spellData.CatForm.formattedName)
        or wan.CheckUnitBuff(nil, wan.spellData.BearForm.formattedName)
        or not wan.IsSpellUsable(wan.spellData.WildMushroom.id)
    then
        wan.UpdateAbilityData(wan.spellData.WildMushroom.basename)
        return
    end

    -- Check for valid unit
    local _, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.WildMushroom.id)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.WildMushroom.basename)
        return
    end

    -- Base value
    local cWildMushroomInstantDmg = 0
    local cWildMushroomDotDmg = 0
    
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        -- add mastery layer
        local cMasteryAstralInvocationNature = 1
        if wan.spellData.MasteryAstralInvocation.known then
            local cMasteryAstralInvocationNatureValue = wan.auraData[nameplateUnitToken]["debuff_" .. wan.spellData.Sunfire.basename] and nMasteryAstralInvocationNature or 0
            cMasteryAstralInvocationNature = 1 + cMasteryAstralInvocationNatureValue
        end

        local checkUnitWildMushroomDebuff = wan.auraData[nameplateUnitToken]["debuff_" .. sWildMushroomAuraKey]
        if not checkUnitWildMushroomDebuff then
            local unitDotPotency = wan.CheckDotPotency(cWildMushroomInstantDmg, nameplateUnitToken)
            cWildMushroomDotDmg = cWildMushroomDotDmg + (nWildMushroomDotDmg * unitDotPotency * cMasteryAstralInvocationNature)
            cWildMushroomInstantDmg = cWildMushroomInstantDmg + (nWildMushroomInstantDmg * cMasteryAstralInvocationNature)
        end
    end

    local cWirldMushroomDmg = cWildMushroomInstantDmg + cWildMushroomDotDmg

    -- Crit layer
    cWirldMushroomDmg = cWirldMushroomDmg * wan.ValueFromCritical(wan.CritChance)

    -- Update ability data
    local abilityValue = math.floor(cWirldMushroomDmg)
    wan.UpdateAbilityData(wan.spellData.WildMushroom.basename, abilityValue, wan.spellData.WildMushroom.icon, wan.spellData.WildMushroom.name)
end

-- Init frame 
local frameWildMushroom = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local wildMushroomValues = wan.GetSpellDescriptionNumbers(wan.spellData.WildMushroom.id, { 1, 2 })
            nWildMushroomInstantDmg = wildMushroomValues[1]
            nWildMushroomDotDmg = wildMushroomValues[2]

            local nMasteryAstralInvocationValues = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryAstralInvocation.id, { 2, 4 })
            nMasteryAstralInvocationArcane = nMasteryAstralInvocationValues[1] * 0.01
            nMasteryAstralInvocationNature = nMasteryAstralInvocationValues[2] * 0.01
        end
    end)
end
frameWildMushroom:RegisterEvent("ADDON_LOADED")
frameWildMushroom:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.WildMushroom.known and wan.spellData.WildMushroom.id
        wan.BlizzardEventHandler(frameWildMushroom, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameWildMushroom, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameWildMushroom, CheckAbilityValue, abilityActive)
    end
end)