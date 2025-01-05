local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nStellarFlareInstantDmg, nStellarFlareDotDmg, nStellarFlareDotDuration = 0, 0, 0
local nMasteryAstralInvocationArcane = 0
local nMasteryAstralInvocationNature = 0
local nMasteryAstralInvocationAstral = 0

-- Init trait data
local nAstronomicalImpact = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or wan.auraData.player.buff_CatForm
    or wan.auraData.player.buff_BearForm
        or not wan.IsSpellUsable(wan.spellData.StellarFlare.id)
    then
        wan.UpdateAbilityData(wan.spellData.StellarFlare.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit = wan.ValidUnitBoolCounter(wan.spellData.StellarFlare.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.StellarFlare.basename)
        return
    end

    -- Base value
    local critChanceMod = 0
    local critDamageMod = 0
    local cStellarFlareInstantDmg = nStellarFlareInstantDmg
    local cStellarFlareDotDmg = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    -- check mastery layer
    local cMasteryAstralInvocationAstral = 1
    if wan.spellData.MasteryAstralInvocation.known then
        local cMasteryAstralInvocationNatureValue = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.spellData.Sunfire.basename] and nMasteryAstralInvocationNature or 0
        local cMasteryAstralInvocationArcaneValue = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken]["debuff_" .. wan.spellData.Moonfire.basename] and nMasteryAstralInvocationArcane or 0
        local cMasteryAstralInvocationAstralValue = cMasteryAstralInvocationNatureValue + cMasteryAstralInvocationArcaneValue
        cMasteryAstralInvocationAstral = 1 + cMasteryAstralInvocationAstralValue
    end

    -- Dot value
    local checkStellarFlareDebuff = wan.auraData[targetUnitToken] and wan.auraData[targetUnitToken].debuff_StellarFlare
    if not checkStellarFlareDebuff then
        local dotPotency = wan.CheckDotPotency(nStellarFlareInstantDmg)
        cStellarFlareDotDmg = cStellarFlareDotDmg + (nStellarFlareDotDmg * dotPotency)
    end

    -- Astronomical Impact
    if wan.traitData.AstronomicalImpact.known then
        critDamageMod = critDamageMod + nAstronomicalImpact
    end

    -- Cast time layer
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.StellarFlare.id, wan.spellData.StellarFlare.castTime)

    -- Crit layer
    local cStellarFlareCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)


    local cStellarFlareDmg = (cStellarFlareInstantDmg + cStellarFlareDotDmg) * cMasteryAstralInvocationAstral * cStellarFlareCritValue * castEfficiency 

    -- Update ability data
    local abilityDmg = math.floor(cStellarFlareDmg)
    wan.UpdateAbilityData(wan.spellData.StellarFlare.basename, abilityDmg, wan.spellData.StellarFlare.icon, wan.spellData.StellarFlare.name)
end

-- Init frame 
local frameStellarFlare = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local stellarFlareValues = wan.GetSpellDescriptionNumbers(wan.spellData.StellarFlare.id, { 1, 2, 3 })
            nStellarFlareInstantDmg = stellarFlareValues[1]
            nStellarFlareDotDmg = stellarFlareValues[2]
            nStellarFlareDotDuration = stellarFlareValues[3]

            local nMasteryAstralInvocationValues = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryAstralInvocation.id, { 2, 4 })
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
        abilityActive = wan.spellData.StellarFlare.known and wan.spellData.StellarFlare.id
        wan.BlizzardEventHandler(frameStellarFlare, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameStellarFlare, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nAstronomicalImpact = wan.GetTraitDescriptionNumbers(wan.traitData.AstronomicalImpact.entryid, { 1 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameStellarFlare, CheckAbilityValue, abilityActive)
    end
end)