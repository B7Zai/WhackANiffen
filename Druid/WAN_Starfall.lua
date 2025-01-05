local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nStarfallDmg, nStarfallMaxRange = 0, 0
local nMasteryAstralInvocationArcane = 0
local nMasteryAstralInvocationNature = 0

-- Init trait data
local nAstronomicalImpact = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
    or wan.auraData.player.buff_BearForm
        or not wan.IsSpellUsable(wan.spellData.Starfall.id)
    then
        wan.UpdateAbilityData(wan.spellData.Starfall.basename)
        return
    end

    -- Check for valid unit
    local _, countValidUnit, idValidUnit  = wan.ValidUnitBoolCounter(nil, nStarfallMaxRange)
    if countValidUnit == 0 then
        wan.UpdateAbilityData(wan.spellData.Starfall.basename)
        return
    end

    local critChanceMod = 0
    local critDamageMod = 0

    local cStarfallDmg = 0

    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

        local cMasteryAstralInvocationUnitAstral = 1
        if wan.spellData.MasteryAstralInvocation.known then
            local cMasteryAstralInvocationUnitNatureValue = wan.auraData[nameplateUnitToken]["debuff_" .. wan.spellData.Sunfire.basename] and nMasteryAstralInvocationNature or 0
            local cMasteryAstralInvocationUnitArcaneValue = wan.auraData[nameplateUnitToken]["debuff_" .. wan.spellData.Moonfire.basename] and nMasteryAstralInvocationArcane or 0
            local cMasteryAstralInvocationUnitAstralValue = cMasteryAstralInvocationUnitNatureValue + cMasteryAstralInvocationUnitArcaneValue
            cMasteryAstralInvocationUnitAstral = 1 + cMasteryAstralInvocationUnitAstralValue
        end

        cStarfallDmg = cStarfallDmg + (nStarfallDmg * checkPotency * cMasteryAstralInvocationUnitAstral)
    end

    if wan.traitData.AstronomicalImpact.known then
        critDamageMod = critDamageMod + nAstronomicalImpact
    end

    cStarfallDmg = cStarfallDmg * wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    -- Update ability data
    local abilityValue = math.floor(cStarfallDmg)
    wan.UpdateAbilityData(wan.spellData.Starfall.basename, abilityValue, wan.spellData.Starfall.icon, wan.spellData.Starfall.name)
end

-- Init frame 
local frameStarfall = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"then
            local starfallValues = wan.GetSpellDescriptionNumbers(wan.spellData.Starfall.id, { 1, 2 })
            nStarfallMaxRange = starfallValues[1]
            nStarfallDmg = starfallValues[2]

            
            local nMasteryAstralInvocationValues = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryAstralInvocation.id, { 2, 4 })
            nMasteryAstralInvocationArcane = nMasteryAstralInvocationValues[1] * 0.01
            nMasteryAstralInvocationNature = nMasteryAstralInvocationValues[2] * 0.01
        end
    end)
end
frameStarfall:RegisterEvent("ADDON_LOADED")
frameStarfall:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings & data update on traits
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Starfall.known and wan.spellData.Starfall.id
        wan.BlizzardEventHandler(frameStarfall, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameStarfall, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nAstronomicalImpact = wan.GetTraitDescriptionNumbers(wan.traitData.AstronomicalImpact.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameStarfall, CheckAbilityValue, abilityActive)
    end
end)