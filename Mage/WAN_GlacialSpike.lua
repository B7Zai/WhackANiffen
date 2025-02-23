local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nGlacialSpikeDmg = 0
local sFrozenDebuffs = {}

-- Init trait data
local nOverflowingEnergy = 0
local nShatterMultiplier, nShatter = 0, 0
local nSplittingIce, nSplittingIceUnitCap = 0, 1
local nPiercingCold = 0
local nArcaneSplinterDmg, nArcaneSplinterDotDmg = 0, 0
local nSignatureSpellShardCount = 0
local nControlledInstincts, nControlledInstinctsSoftCap = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or (wan.spellData.ArcaneBlast.known and wan.IsSpellUsable(wan.spellData.ArcaneBlast.id))
        or wan.UnitIsCasting("player", wan.spellData.GlacialSpike.name)
        or not wan.IsSpellUsable(wan.spellData.GlacialSpike.id)
    then
        wan.UpdateAbilityData(wan.spellData.GlacialSpike.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.GlacialSpike.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.GlacialSpike.basename)
        return
    end

    local canMovecast = (wan.auraData.player.buff_IceFloes and true) or false
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.GlacialSpike.id, wan.spellData.GlacialSpike.castTime, canMovecast)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(wan.spellData.GlacialSpike.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critChanceModBase = 0
    local critDamageMod = 0
    local critDamageModBase = 0

    local cGlacialSpikeInstantDmg = 0
    local cGlacialSpikeDotDmg = 0
    local cGlacialSpikeInstantDmgAoE = 0
    local cGlacialSpikeDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- CLASS TRAITS ----

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
    end

    ---- FROST TRAITS ----

    if wan.traitData.Shatter.known then
        for _, debuff in ipairs(sFrozenDebuffs) do
            local checkID = debuff == wan.traitData.FreezingCold.traitkey and 386770 or nil
            local checkFrozenDebuff = wan.CheckUnitDebuff(nil, debuff, checkID)
            if checkFrozenDebuff then
                critChanceMod = critChanceMod + ((wan.CritChance * nShatterMultiplier) + nShatter)
                break
            end
        end

        if wan.traitData.SplittingIce.known then
            local frozenUnitCap = 1 + nSplittingIceUnitCap
            local countSplittingIceUnit = 0

            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
                
                if nameplateGUID ~= targetGUID then

                    for _, debuff in pairs(sFrozenDebuffs) do
                        local checkID = debuff == wan.traitData.FreezingCold.traitkey and 386770 or nil
                        local checkFrozenDebuff = wan.CheckUnitDebuff(nameplateUnitToken, debuff, checkID)
                        if checkFrozenDebuff then
                            critChanceMod = critChanceMod + ((wan.CritChance * nShatterMultiplier) + nShatter)
                        end
                    end

                    countSplittingIceUnit = countSplittingIceUnit + 1
                            
                    if countSplittingIceUnit >= nSplittingIceUnitCap then break end
                end
            end

            critChanceMod = critChanceMod / frozenUnitCap
        end
    end

    if wan.traitData.PiercingCold.known then
        critDamageMod = critDamageMod + nPiercingCold
    end

    local cSplittingIceInstantDmgAoE = 0
    if wan.traitData.SplittingIce.known then
        local countSplittingIceUnit = 0

        for _, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                cSplittingIceInstantDmgAoE = cSplittingIceInstantDmgAoE + (nGlacialSpikeDmg * nSplittingIce)

                countSplittingIceUnit = countSplittingIceUnit + 1

                if countSplittingIceUnit >= nSplittingIceUnitCap then break end
            end
        end
    end

    ---- SPELLSLINGER TRAITS ----

    local cArcaneSplinterInstantDmg = 0
    local cArcaneSplinterDotDmg = 0
    local cControlledInstinctsInstantDmgAoE = 0
    if wan.traitData.SignatureSpell.known then

        local cSignatureSpellShardCount = 1
        if wan.traitData.SignatureSpell.known then
            cSignatureSpellShardCount = cSignatureSpellShardCount + nSignatureSpellShardCount 
        end

        local checkWintersChill = wan.CheckUnitDebuff(nil, "WintersChill")
        if checkWintersChill then
            cArcaneSplinterInstantDmg = cArcaneSplinterInstantDmg + (nArcaneSplinterDmg * cSignatureSpellShardCount)

            local dotPotency = wan.CheckDotPotency(nGlacialSpikeDmg, targetUnitToken)
            cArcaneSplinterDotDmg = cArcaneSplinterDotDmg + (nArcaneSplinterDotDmg * cSignatureSpellShardCount * dotPotency)
        end

        if wan.traitData.ControlledInstincts.known then
            local checkBlizzardDebuff = wan.CheckUnitDebuff(nil, wan.spellData.Blizzard.formattedName)
            if checkBlizzardDebuff then
                local countControlledInstinctsUnit = math.max(countValidUnit - 1, 0)
                local cControlledInstinctsUnit = wan.AdjustSoftCapUnitOverflow(nControlledInstinctsSoftCap, countControlledInstinctsUnit)
                cControlledInstinctsInstantDmgAoE = cControlledInstinctsInstantDmgAoE + (nArcaneSplinterDmg * cSignatureSpellShardCount * nControlledInstincts * cControlledInstinctsUnit)
            end
        end
    end

    local cGlacialSpikeCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cGlacialSpikeCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cGlacialSpikeInstantDmg = cGlacialSpikeInstantDmg
        + (nGlacialSpikeDmg * cGlacialSpikeCritValue)
        + (cArcaneSplinterInstantDmg * cGlacialSpikeCritValueBase)

    cGlacialSpikeDotDmg = cGlacialSpikeDotDmg
        + (nArcaneSplinterDotDmg * cGlacialSpikeCritValueBase)

    cGlacialSpikeInstantDmgAoE = cGlacialSpikeInstantDmgAoE
        + (cSplittingIceInstantDmgAoE * cGlacialSpikeCritValue)
        + (cControlledInstinctsInstantDmgAoE * cGlacialSpikeCritValueBase)

    cGlacialSpikeDotDmgAoE = cGlacialSpikeDotDmgAoE

    local cGlacialSpikeDmg = (cGlacialSpikeInstantDmg + cGlacialSpikeDotDmg + cGlacialSpikeInstantDmgAoE + cGlacialSpikeDotDmgAoE) * castEfficiency

    -- Update ability data
    local abilityValue = math.floor(cGlacialSpikeDmg)
    wan.UpdateAbilityData(wan.spellData.GlacialSpike.basename, abilityValue, wan.spellData.GlacialSpike.icon, wan.spellData.GlacialSpike.name)
end

-- Init frame 
local frameGlacialSpike = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nGlacialSpikeDmg = wan.GetSpellDescriptionNumbers(wan.spellData.GlacialSpike.id, { 1 })

            local nSplinteringSorceryValues = wan.GetTraitDescriptionNumbers(wan.traitData.SplinteringSorcery.entryid, { 3, 4 })
            nArcaneSplinterDmg = nSplinteringSorceryValues[1]
            nArcaneSplinterDotDmg = nSplinteringSorceryValues[2]
        end
    end)
end
frameGlacialSpike:RegisterEvent("ADDON_LOADED")
frameGlacialSpike:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.GlacialSpike.known and wan.spellData.GlacialSpike.id
        wan.BlizzardEventHandler(frameGlacialSpike, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameGlacialSpike, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        sFrozenDebuffs = {
            "WintersChill",
            wan.traitData.Frostbite.traitkey,
            wan.traitData.GlacialSpike.traitkey,
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

        nSplittingIce = wan.GetTraitDescriptionNumbers(wan.traitData.SplittingIce.entryid, { 3 }) * 0.01

        nSignatureSpellShardCount = wan.GetTraitDescriptionNumbers(wan.traitData.SignatureSpell.entryid, { 1 })

        local nControlledInstinctsValues = wan.GetTraitDescriptionNumbers(wan.traitData.ControlledInstincts.entryid, { 2, 3 })
        nControlledInstincts = nControlledInstinctsValues[1] * 0.01
        nControlledInstinctsSoftCap = nControlledInstinctsValues[2]
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameGlacialSpike, CheckAbilityValue, abilityActive)
    end
end)