local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local aStarfall, nStarfallDmg, nStarfallMaxRange = {}, 0, 0
local aMasteryAstralInvocation, nMasteryAstralInvocationArcane, nMasteryAstralInvocationNature = {}, 0, 0
local sMoonfire, sSunfire = "Moonfire", "Sunfire"
local sCatForm, sBearForm = "CatForm", "BearForm"

-- Init trait data
local aAstronomicalImpact, nAstronomicalImpact = {}, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or wan.CheckUnitBuff(nil, sCatForm)
        or wan.CheckUnitBuff(nil, sBearForm)
        or not wan.IsSpellUsable(aStarfall.id)
    then
        wan.UpdateAbilityData(aStarfall.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit  = wan.ValidUnitBoolCounter(nil, nStarfallMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(aStarfall.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cStarfallInstantDmg = 0
    local cStarfallDotDmg = 0
    local cStarfallInstantDmgAoE = 0
    local cStarfallDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cStarfallDotDmgBaseAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkUnitHealthPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

        cStarfallDotDmgBaseAoE = cStarfallDotDmgBaseAoE + (nStarfallDmg * checkUnitHealthPotency)
    end

    ---- BALANCE TRAITS ----

    local cMasteryAstralInvocationAoE = 1
    if aMasteryAstralInvocation.known then

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkMoonfireDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sMoonfire)
            local checkSunfireDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sSunfire)

            local cMasteryAstralInvocationArcaneValue = checkMoonfireDebuff and nMasteryAstralInvocationArcane or 0
            local cMasteryAstralInvocationNatureValue = checkSunfireDebuff and nMasteryAstralInvocationNature or 0

            cMasteryAstralInvocationAoE = cMasteryAstralInvocationAoE + (cMasteryAstralInvocationArcaneValue / countValidUnit)
            cMasteryAstralInvocationAoE = cMasteryAstralInvocationAoE + (cMasteryAstralInvocationNatureValue / countValidUnit)
        end
    end

    if wan.traitData.AstronomicalImpact.known then
        critDamageMod = critDamageMod + nAstronomicalImpact
    end

    local cStarfallCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cStarfallInstantDmg = cStarfallInstantDmg

    cStarfallDotDmg = cStarfallDotDmg

    cStarfallInstantDmgAoE = cStarfallInstantDmgAoE

    cStarfallDotDmgAoE = cStarfallDotDmgAoE
        + (cStarfallDotDmgBaseAoE * cStarfallCritValue * cMasteryAstralInvocationAoE)

    local cStarfallDmg = cStarfallInstantDmg + cStarfallDotDmg + cStarfallInstantDmgAoE + cStarfallDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cStarfallDmg)
    wan.UpdateAbilityData(aStarfall.basename, abilityValue, aStarfall.icon, aStarfall.name)
end

-- Init frame 
local frameStarfall = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"then
            local starfallValues = wan.GetSpellDescriptionNumbers(aStarfall.id, { 1, 2 })
            nStarfallMaxRange = starfallValues[1]
            nStarfallDmg = starfallValues[2]

            local nMasteryAstralInvocationValues = wan.GetSpellDescriptionNumbers(aMasteryAstralInvocation.id, { 2, 4 })
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
        aStarfall = wan.spellData.Starfall

        abilityActive = aStarfall.known and aStarfall.id
        wan.BlizzardEventHandler(frameStarfall, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameStarfall, CheckAbilityValue, abilityActive)

        sCatForm = wan.spellData.CatForm.formattedName
        sBearForm = wan.spellData.BearForm.formattedName

        aMasteryAstralInvocation = wan.spellData.MasteryAstralInvocation
        sMoonfire = wan.spellData.Moonfire.formattedName
        sSunfire = wan.spellData.Sunfire.formattedName
    end

    if event == "TRAIT_DATA_READY" then 
        aAstronomicalImpact = wan.traitData.AstronomicalImpact
        nAstronomicalImpact = wan.GetTraitDescriptionNumbers(aAstronomicalImpact.entryid, { 1 }, aAstronomicalImpact.rank)
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameStarfall, CheckAbilityValue, abilityActive)
    end
end)