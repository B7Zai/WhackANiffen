local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local aStarsurge, nStarsurgeDmg = {}, 0
local aStarfall = {}
local aMasteryAstralInvocation, nMasteryAstralInvocationArcane, nMasteryAstralInvocationNature = {}, 0, 0
local sMoonfire, sSunfire = "Moonfire", "Sunfire"
local sCatForm, sBearForm = "CatForm", "BearForm"

-- Init trait data
local aAstronomicalImpact, nAstronomicalImpact = {}, 0
local aPowerofGoldrinn, nPowerofGoldrinn, nPowerOfGoldrinnProcChance = {}, 0, 0.33

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or wan.CheckUnitBuff(nil, sCatForm)
        or wan.CheckUnitBuff(nil, sBearForm)
        or (aStarfall.known and not wan.IsSpellUsable(aStarfall.id) or not wan.IsSpellUsable(aStarsurge.id))
    then
        wan.UpdateAbilityData(aStarsurge.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit  = wan.ValidUnitBoolCounter(aStarsurge.id)
    if not isValidUnit then
        wan.UpdateAbilityData(aStarsurge.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cStarsurgeInstantDmg = 0
    local cStarsurgeDotDmg = 0
    local cStarsurgeInstantDmgAoE = 0
    local cStarsurgeDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- BALANCE TRAITS ----

    local cMasteryAstralInvocation = 1
    if aMasteryAstralInvocation.known then
        local checkSunfireDebuff = wan.CheckUnitDebuff(nil, sSunfire)
        local checkMoonfireDebuff = wan.CheckUnitDebuff(nil, sMoonfire)

        local cMasteryAstralInvocationArcaneValue = checkMoonfireDebuff and nMasteryAstralInvocationArcane or 0
        local cMasteryAstralInvocationNatureValue = checkSunfireDebuff and nMasteryAstralInvocationNature or 0

        cMasteryAstralInvocation = cMasteryAstralInvocation + cMasteryAstralInvocationNatureValue + cMasteryAstralInvocationArcaneValue
    end

    if aAstronomicalImpact.known then
        critDamageMod = critDamageMod + nAstronomicalImpact
    end

    local cPowerofGoldrinn = 0
    if aPowerofGoldrinn.known then
        cPowerofGoldrinn = cPowerofGoldrinn + (nPowerofGoldrinn * nPowerOfGoldrinnProcChance)
    end

    local cStarsurgeCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cStarsurgeInstantDmg = cStarsurgeInstantDmg
        + (nStarsurgeDmg * cStarsurgeCritValue * cMasteryAstralInvocation)

    cStarsurgeDotDmg = cStarsurgeDotDmg

    cStarsurgeInstantDmgAoE = cStarsurgeInstantDmgAoE
        + (cPowerofGoldrinn * cStarsurgeCritValue * cMasteryAstralInvocation)

    cStarsurgeDotDmgAoE = cStarsurgeDotDmgAoE

    local cStarsurgeDmg = cStarsurgeInstantDmg + cStarsurgeDotDmg + cStarsurgeInstantDmgAoE + cStarsurgeDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cStarsurgeDmg)
    wan.UpdateAbilityData(aStarsurge.basename, abilityValue, aStarsurge.icon, aStarsurge.name)
end

-- Init frame 
local frameStarsurge = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"then
            nStarsurgeDmg = wan.GetSpellDescriptionNumbers(aStarsurge.id, { 1 })

            nPowerofGoldrinn = wan.GetTraitDescriptionNumbers(aPowerofGoldrinn.entryid, { 1 }, aPowerofGoldrinn.rank)

            local nMasteryAstralInvocationValues = wan.GetSpellDescriptionNumbers(aMasteryAstralInvocation.id, { 2, 4 })
            nMasteryAstralInvocationArcane = nMasteryAstralInvocationValues[1] * 0.01
            nMasteryAstralInvocationNature = nMasteryAstralInvocationValues[2] * 0.01
        end
    end)
end
frameStarsurge:RegisterEvent("ADDON_LOADED")
frameStarsurge:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings & data update on traits
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        aStarsurge = wan.spellData.Starsurge

        abilityActive = aStarsurge.known and aStarsurge.id
        wan.BlizzardEventHandler(frameStarsurge, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameStarsurge, CheckAbilityValue, abilityActive)

        sCatForm = wan.spellData.CatForm.formattedName
        sBearForm = wan.spellData.BearForm.formattedName

        aMasteryAstralInvocation = wan.spellData.MasteryAstralInvocation
        sMoonfire = wan.spellData.Moonfire.formattedName
        sSunfire = wan.spellData.Sunfire.formattedName

        aStarfall = wan.spellData.Starfall
    end

    if event == "TRAIT_DATA_READY" then
        aAstronomicalImpact = wan.traitData.AstronomicalImpact
        nAstronomicalImpact = wan.GetTraitDescriptionNumbers(aAstronomicalImpact.entryid, { 1 }, aAstronomicalImpact.rank)

        aPowerofGoldrinn = wan.traitData.PowerofGoldrinn
     end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameStarsurge, CheckAbilityValue, abilityActive)
    end
end)