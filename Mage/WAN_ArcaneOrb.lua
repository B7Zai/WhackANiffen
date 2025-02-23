local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nArcaneOrbDmg = 0

-- Init trait data
local nOverflowingEnergy = 0
local nArcaneSplinterDmg, nArcaneSplinterDotDmg = 0, 0
local nSplinteringOrbSplinterCount, nSplinteringOrbSplinterCap = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ArcaneOrb.id)
    then
        wan.UpdateAbilityData(wan.spellData.ArcaneOrb.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.ArcaneOrb.maxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ArcaneOrb.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cArcaneOrbInstantDmg = 0
    local cArcaneOrbDotDmg = 0
    local cArcaneOrbInstantDmgAoE = 0
    local cArcaneOrbDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- CLASS TRAITS ----

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
    end

    ---- SPELLSLINGER TRAITS ----

    local cSplinteringOrbsInstantDmgAoE = 0
    local cSplinteringOrbsDotDmgAoE = 0
    if wan.traitData.SplinteringOrbs.known then
        local countSplinteringOrbSplinters = 0
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            cSplinteringOrbsInstantDmgAoE = cSplinteringOrbsInstantDmgAoE + (nArcaneSplinterDmg * nSplinteringOrbSplinterCount)

            local dotPotency = wan.CheckDotPotency(nArcaneOrbDmg, nameplateUnitToken)
            cSplinteringOrbsDotDmgAoE = cSplinteringOrbsDotDmgAoE + (nArcaneSplinterDotDmg * nSplinteringOrbSplinterCount * dotPotency)
            
            countSplinteringOrbSplinters = countSplinteringOrbSplinters + nSplinteringOrbSplinterCount
            if countSplinteringOrbSplinters >= nSplinteringOrbSplinterCap then break end
        end
    end

    local cArcaneOrbCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cArcaneOrbInstantDmg = cArcaneOrbInstantDmg

    cArcaneOrbDotDmg = cArcaneOrbDotDmg

    cArcaneOrbInstantDmgAoE = cArcaneOrbInstantDmgAoE
        + (nArcaneOrbDmg * countValidUnit * cArcaneOrbCritValue)
        + (cSplinteringOrbsInstantDmgAoE * cArcaneOrbCritValue)

    cArcaneOrbDotDmgAoE = cArcaneOrbDotDmgAoE
        + (cSplinteringOrbsDotDmgAoE * cArcaneOrbCritValue)

    local cArcaneOrbDmg = cArcaneOrbInstantDmg + cArcaneOrbDotDmg + cArcaneOrbInstantDmgAoE + cArcaneOrbDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cArcaneOrbDmg)
    wan.UpdateAbilityData(wan.spellData.ArcaneOrb.basename, abilityValue, wan.spellData.ArcaneOrb.icon, wan.spellData.ArcaneOrb.name)
end

-- Init frame 
local frameArcaneOrb = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nArcaneOrbDmg = wan.GetSpellDescriptionNumbers(wan.spellData.ArcaneOrb.id, { 2 })

            local nSplinteringSorceryValues = wan.GetTraitDescriptionNumbers(wan.traitData.SplinteringSorcery.entryid, { 4, 5 })
            nArcaneSplinterDmg = nSplinteringSorceryValues[1]
            nArcaneSplinterDotDmg = nSplinteringSorceryValues[2]
        end
    end)
end
frameArcaneOrb:RegisterEvent("ADDON_LOADED")
frameArcaneOrb:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ArcaneOrb.known and wan.spellData.ArcaneOrb.id
        wan.BlizzardEventHandler(frameArcaneOrb, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameArcaneOrb, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        local nSplinteringOrbValues = wan.GetTraitDescriptionNumbers(wan.traitData.SplinteringOrbs.entryid, { 1, 2 })
        nSplinteringOrbSplinterCount = nSplinteringOrbValues[1]
        nSplinteringOrbSplinterCap = nSplinteringOrbValues[2]
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameArcaneOrb, CheckAbilityValue, abilityActive)
    end
end)