local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local aStellarflare, nStellarFlareInstantDmg, nStellarFlareDotDmg = {}, 0, 0
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
        or wan.UnitIsCasting("player", aStellarflare.id)
        or not wan.IsSpellUsable(aStellarflare.id)
    then
        wan.UpdateAbilityData(aStellarflare.basename)
        return
    end

    local castEfficiency = wan.CheckCastEfficiency(aStellarflare.id, aStellarflare.castTime)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(aStellarflare.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit = wan.ValidUnitBoolCounter(aStellarflare.id)
    if not isValidUnit then
        wan.UpdateAbilityData(aStellarflare.basename)
        return
    end

    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cStellarflareInstantDmg = 0
    local cStellarflareDotDmg = 0
    local cStellarflareInstantDmgAoE = 0
    local cStellarflareDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cStellarFlareDotDmgBase = 0
    local checkStellarFlareDebuff = wan.CheckUnitDebuff(nil, aStellarflare.formattedName)
    if not checkStellarFlareDebuff then
        local checkDotPotency = wan.CheckDotPotency(nStellarFlareInstantDmg)

        cStellarFlareDotDmgBase = cStellarFlareDotDmgBase + (nStellarFlareDotDmg * checkDotPotency)
    end

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

    local cStellarFlareCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cStellarflareInstantDmg = cStellarflareInstantDmg

    cStellarflareDotDmg = cStellarflareDotDmg
        + (cStellarFlareDotDmgBase * cStellarFlareCritValue * cMasteryAstralInvocation)

    cStellarflareInstantDmgAoE = cStellarflareInstantDmgAoE

    cStellarflareDotDmgAoE = cStellarflareDotDmgAoE

    local cStellarflareDmg = (cStellarflareInstantDmg + cStellarflareDotDmg + cStellarflareInstantDmgAoE + cStellarflareDotDmgAoE) * castEfficiency
    
    -- Update ability data
    local abilityDmg = math.floor(cStellarflareDmg)
    wan.UpdateAbilityData(aStellarflare.basename, abilityDmg, aStellarflare.icon, aStellarflare.name)
end

-- Init frame 
local frameStellarFlare = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local stellarFlareValues = wan.GetSpellDescriptionNumbers(aStellarflare.id, { 1, 2, 3 })
            nStellarFlareInstantDmg = stellarFlareValues[1]
            nStellarFlareDotDmg = stellarFlareValues[2]

            local nMasteryAstralInvocationValues = wan.GetSpellDescriptionNumbers(aMasteryAstralInvocation.id, { 2, 4 })
            nMasteryAstralInvocationArcane = nMasteryAstralInvocationValues[1] * 0.01
            nMasteryAstralInvocationNature = nMasteryAstralInvocationValues[2] * 0.01
        end
    end)
end
frameStellarFlare:RegisterEvent("ADDON_LOADED")
frameStellarFlare:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings & data update on traits
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        aStellarflare = wan.spellData.StellarFlare

        abilityActive = aStellarflare.known and aStellarflare.id
        wan.BlizzardEventHandler(frameStellarFlare, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameStellarFlare, CheckAbilityValue, abilityActive)

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
        wan.SetUpdateRate(frameStellarFlare, CheckAbilityValue, abilityActive)
    end
end)