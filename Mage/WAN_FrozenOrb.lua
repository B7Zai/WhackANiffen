local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nFrozenOrbDmg = 0

-- Init trait data
local nOverflowingEnergy = 0
local nShatterMultiplier, nShatter, sFrozenDebuffs = 0, 0, {}
local nArcaneSplinterDmg, nArcaneSplinterDotDmg = 0, 0
local nSplinteringOrbSplinterCount = 0
local nFreezingWinds = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.FrozenOrb.id)
    then
        wan.UpdateAbilityData(wan.spellData.FrozenOrb.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.FrozenOrb.maxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.FrozenOrb.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cFrozenOrbInstantDmg = 0
    local cFrozenOrbDotDmg = 0
    local cFrozenOrbInstantDmgAoE = 0
    local cFrozenOrbDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cFrozenOrbBaseDmgAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local unitAoEPotency = wan.CheckDotPotency(nil, nameplateUnitToken)

        cFrozenOrbBaseDmgAoE = cFrozenOrbBaseDmgAoE + (nFrozenOrbDmg * unitAoEPotency)
    end

    ---- CLASS TRAITS ----

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
    end

    ---- FROST TRAITS ----

    if wan.traitData.Shatter.known then
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            for _, debuff in pairs(sFrozenDebuffs) do
                local checkID = debuff == wan.traitData.FreezingCold.traitkey and 386770 or nil
                local checkFrozenDebuff = wan.CheckUnitDebuff(nameplateUnitToken, debuff, checkID)
                if checkFrozenDebuff then
                    critChanceMod = critChanceMod + ((wan.CritChance * nShatterMultiplier) + nShatter)
                    break
                end
            end
        end
        critChanceMod = critChanceMod / countValidUnit
    end

    local cFreezingWinds = 1
    if wan.traitData.FreezingWinds.entryid then
        local countBlizzardDebuff = 0

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkBlizzardDebuff = wan.CheckUnitDebuff(nameplateUnitToken, wan.spellData.Blizzard.formattedName)

            if checkBlizzardDebuff then
                countBlizzardDebuff = countBlizzardDebuff + 1
            end
        end

        if countBlizzardDebuff then
            cFreezingWinds = cFreezingWinds + ((nFreezingWinds * countBlizzardDebuff) / countValidUnit)
        end
    end

    ---- SPELLSLINGER TRAITS ----

    local cSplinteringOrbsInstantDmgAoE = 0
    local cSplinteringOrbsDotDmgAoE = 0
    if wan.traitData.SplinteringOrbs.known then
        cSplinteringOrbsInstantDmgAoE = cSplinteringOrbsInstantDmgAoE + (nArcaneSplinterDmg * nSplinteringOrbSplinterCount)

        local dotPotency = wan.CheckDotPotency(nFrozenOrbDmg, targetUnitToken)
        cSplinteringOrbsDotDmgAoE = cSplinteringOrbsDotDmgAoE + (nArcaneSplinterDotDmg * nSplinteringOrbSplinterCount * dotPotency)
    end

    local cFrozenOrbCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cFrozenOrbCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cFrozenOrbInstantDmg = cFrozenOrbInstantDmg

    cFrozenOrbDotDmg = cFrozenOrbDotDmg

    cFrozenOrbInstantDmgAoE = cFrozenOrbInstantDmgAoE
        + (cFrozenOrbBaseDmgAoE * cFrozenOrbCritValue * cFreezingWinds)
        + (cSplinteringOrbsInstantDmgAoE * cFrozenOrbCritValueBase)

    cFrozenOrbDotDmgAoE = cFrozenOrbDotDmgAoE
        + (cSplinteringOrbsDotDmgAoE * cFrozenOrbCritValueBase)
    
    local cFrozenOrbDmg = cFrozenOrbInstantDmg + cFrozenOrbDotDmg + cFrozenOrbInstantDmgAoE + cFrozenOrbDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cFrozenOrbDmg)
    wan.UpdateAbilityData(wan.spellData.FrozenOrb.basename, abilityValue, wan.spellData.FrozenOrb.icon, wan.spellData.FrozenOrb.name)
end

-- Init frame 
local frameFrozenOrb = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nFrozenOrbDmg = wan.GetSpellDescriptionNumbers(wan.spellData.FrozenOrb.id, { 2 })

            local nSplinteringSorceryValues = wan.GetTraitDescriptionNumbers(wan.traitData.SplinteringSorcery.entryid, { 3, 4 })
            nArcaneSplinterDmg = nSplinteringSorceryValues[1]
            nArcaneSplinterDotDmg = nSplinteringSorceryValues[2]
        end
    end)
end
frameFrozenOrb:RegisterEvent("ADDON_LOADED")
frameFrozenOrb:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.FrozenOrb.known and wan.spellData.FrozenOrb.id
        wan.BlizzardEventHandler(frameFrozenOrb, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFrozenOrb, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        sFrozenDebuffs = {
            "WintersChill",
            wan.traitData.Frostbite.traitkey,
            wan.traitData.IceLance.traitkey,
            wan.spellData.FrostNova.formattedName,
            wan.traitData.FreezingCold.traitkey,
            wan.traitData.IceNova.traitkey,
            "Freeze"
        }

        local nShatterValues = wan.GetTraitDescriptionNumbers(wan.traitData.Shatter.entryid, { 1, 2 })
        nShatterMultiplier = nShatterValues[1]
        nShatter = nShatterValues[2]

        nSplinteringOrbSplinterCount = wan.GetTraitDescriptionNumbers(wan.traitData.SplinteringOrbs.entryid, { 2 })

        nFreezingWinds = wan.GetTraitDescriptionNumbers(wan.traitData.FreezingWinds.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFrozenOrb, CheckAbilityValue, abilityActive)
    end
end)