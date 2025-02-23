local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nFlurryDmg, nFlurryAttacks = 0, 0

-- Init trait data
local nOverflowingEnergy = 0
local nMasteryIciclesDmg, nMasteryIciclesCap = 0, 0
local nShatterMultiplier, nShatter, sFrozenDebuffs = 0, 0, {}
local nPiercingCold, nPiercingColdIcicleCritDamage = 0, 0
local nSplinteringColdProcChance = 0
local nGlacialAssaultProcChance, nGlacialAssaultDmg = 0, 0
local nSplittingIce, nSplittingIceUnitCap = 0, 1
local nIceNova, nExcessFrost = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Flurry.id)
    then
        wan.UpdateAbilityData(wan.spellData.Flurry.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Flurry.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Flurry.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critChanceModBase = 0
    local critDamageMod = 0
    local critDamageModBase = 0

    local cFlurryInstantDmg = 0
    local cFlurryDotDmg = 0
    local cFlurryInstantDmgAoE = 0
    local cFlurryDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- CLASS TRAITS ----

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
    end

    local cMasteryIciclesInstantDmg = 0
    local cMasteryIciclesInstantDmgAoE = 0
    local cPiercingCold = 1
    if wan.spellData.MasteryIcicles.known then
        local checkIciclesBuff = wan.CheckUnitBuff(nil, "Icicles")
        if checkIciclesBuff and checkIciclesBuff.applications == nMasteryIciclesCap then
            cMasteryIciclesInstantDmg = cMasteryIciclesInstantDmg + nMasteryIciclesDmg

            if wan.traitData.SplinteringCold.known then
                cMasteryIciclesInstantDmg = cMasteryIciclesInstantDmg + (nMasteryIciclesDmg * nSplinteringColdProcChance)
            end

            if wan.traitData.SplittingIce.known then
                local countSplittingIceUnit = 0

                for _, nameplateGUID in pairs(idValidUnit) do

                    if nameplateGUID ~= targetGUID then

                        cMasteryIciclesInstantDmgAoE = cMasteryIciclesInstantDmgAoE + (nMasteryIciclesDmg * nSplittingIce)
        
                        countSplittingIceUnit = countSplittingIceUnit + 1
        
                        if countSplittingIceUnit >= nSplittingIceUnitCap then break end
                    end
                end
            end
        end

        if wan.traitData.PiercingCold.known then
            cPiercingCold = cPiercingCold + nPiercingColdIcicleCritDamage
        end
    end

    ---- FROST TRAITS ----

    if wan.traitData.Shatter.known then
        local nWinterChillAttacks = (nFlurryAttacks > 0 and 1 - (1 / nFlurryAttacks)) or 0
        local checkShatter = false

        for _, debuff in ipairs(sFrozenDebuffs) do
            local checkID = debuff == wan.traitData.FreezingCold.traitkey and 386770 or nil
            local checkFrozenDebuff = wan.CheckUnitDebuff(nil, debuff, checkID)
            if checkFrozenDebuff then
                critChanceMod = critChanceMod + ((wan.CritChance * nShatterMultiplier) + nShatter)
                checkShatter = true
                break
            end
        end

        if not checkShatter then
            critChanceMod = critChanceMod + (((wan.CritChance * nShatterMultiplier) + nShatter * nWinterChillAttacks))
        end
    end

    local cGlacialAssaultInstantDmgAoE = 0
    if wan.traitData.GlacialAssault.entryid then
        cGlacialAssaultInstantDmgAoE = cGlacialAssaultInstantDmgAoE + (nGlacialAssaultDmg * nGlacialAssaultProcChance * nFlurryAttacks * countValidUnit)
    end

    ---- FROSTFIRE TRAITS ----

    local cExcessFrostInstantDmgAoE = 0
    if wan.traitData.ExcessFrost.known then
        local checkExcessFrostBuff = wan.CheckUnitBuff(nil, wan.traitData.ExcessFrost.traitkey)
        if checkExcessFrostBuff then
            cExcessFrostInstantDmgAoE = cExcessFrostInstantDmgAoE + (nIceNova * countValidUnit * nExcessFrost)
        end
    end

    local cFlurryCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cFlurryCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cFlurryInstantDmg = cFlurryInstantDmg
        + (nFlurryDmg * cFlurryCritValue)
        + (cMasteryIciclesInstantDmg * cFlurryCritValue * cPiercingCold)

    cFlurryDotDmg = cFlurryDotDmg

    cFlurryInstantDmgAoE = cFlurryInstantDmgAoE
        + (cGlacialAssaultInstantDmgAoE * cFlurryCritValue)
        + (cMasteryIciclesInstantDmgAoE * cFlurryCritValueBase * cPiercingCold)
        + (cExcessFrostInstantDmgAoE * cFlurryCritValueBase)

    cFlurryDotDmgAoE = cFlurryDotDmgAoE

    local cFlurryDmg = cFlurryInstantDmg + cFlurryDotDmg + cFlurryInstantDmgAoE + cFlurryDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cFlurryDmg)
    wan.UpdateAbilityData(wan.spellData.Flurry.basename, abilityValue, wan.spellData.Flurry.icon, wan.spellData.Flurry.name)
end

-- Init frame 
local frameFlurry = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nFlurryValues = wan.GetSpellDescriptionNumbers(wan.spellData.Flurry.id, { 1, 2 })
            nFlurryAttacks = nFlurryValues[1]
            nFlurryDmg = nFlurryValues[2]

            local nMasteryIciclesValues = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryIcicles.id, { 1, 2 })
            nMasteryIciclesDmg = nMasteryIciclesValues[1]
            nMasteryIciclesCap= nMasteryIciclesValues[2]

            local nGlacialAssaultValues = wan.GetTraitDescriptionNumbers(wan.traitData.GlacialAssault.entryid, { 3, 4 })
            nGlacialAssaultProcChance = nGlacialAssaultValues[1] * 0.01
            nGlacialAssaultDmg = nGlacialAssaultValues[2]

            nIceNova = wan.GetTraitDescriptionNumbers(wan.traitData.IceNova.entryid, { 1 })
        end
    end)
end
frameFlurry:RegisterEvent("ADDON_LOADED")
frameFlurry:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Flurry.known and wan.spellData.Flurry.id
        wan.BlizzardEventHandler(frameFlurry, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFlurry, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        sFrozenDebuffs = {
            "WintersChill",
            wan.traitData.Frostbite.traitkey,
            wan.traitData.Flurry.traitkey,
            wan.spellData.FrostNova.formattedName,
            wan.traitData.FreezingCold.traitkey,
            wan.traitData.IceNova.traitkey,
            "Freeze"
        }

        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        local nShatterValues = wan.GetTraitDescriptionNumbers(wan.traitData.Shatter.entryid, { 1, 2 })
        nShatterMultiplier = nShatterValues[1]
        nShatter = nShatterValues[2]

        nPiercingCold = wan.GetTraitDescriptionNumbers(wan.traitData.PiercingCold.entryid, { 1 })
        nPiercingColdIcicleCritDamage = nPiercingCold * 0.01

        nSplinteringColdProcChance = wan.GetTraitDescriptionNumbers(wan.traitData.SplinteringCold.entryid, { 1 }, wan.traitData.SplinteringCold.rank) * 0.01

        nSplittingIce = wan.GetTraitDescriptionNumbers(wan.traitData.SplittingIce.entryid, { 2 }) * 0.01

        nExcessFrost = wan.GetTraitDescriptionNumbers(wan.traitData.ExcessFrost.entryid, { 1 }) * 0.01 + 1
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFlurry, CheckAbilityValue, abilityActive)
    end
end)