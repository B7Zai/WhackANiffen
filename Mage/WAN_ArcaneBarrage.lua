local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nArcaneBarrageDmg = 0
local currentArcaneCharges = 0
local maxArcaneCharges = 0

-- Init trait data
local nOverflowingEnergy = 0
local nArcingCleave, nArcingCleaveUnit, nArcingCleaveUnitCap = 0, 0, 0
local nResonance = 0
local nDematerialize = 0
local nArcaneDebilitation = 0
local nArcaneBombardment, nArcaneBombardmentThreshold = 0, 0
local nArcaneOrbDmg, nOrbBarrageProcChance, nOrbBarrage = 0, 0, 0
local nArcaneSplinterCount, nArcaneSplinterDmg, nArcaneSplinterDotDmg = 0, 0, 0
local nControlledInstincts, nControlledInstinctsSoftCap = 0, 0
local nFrostboltDmg, nGloriousIncandescenceMeteoriteCount = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.ArcaneBarrage.id)
        or currentArcaneCharges < maxArcaneCharges
    then
        wan.UpdateAbilityData(wan.spellData.ArcaneBarrage.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.ArcaneBarrage.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.ArcaneBarrage.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cArcaneBarrageInstantDmg = 0
    local cArcaneBarrageDotDmg = 0
    local cArcaneBarrageInstantDmgAoE = 0
    local cArcaneBarrageDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- CLASS TRAITS ----

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
    end

    ---- ARCANE TRAITS ----

    local cArcingCleaveInstantDmgAoE = 0
    local countArcingCleaveUnit = 0
    if wan.traitData.ArcingCleave.known then
        if currentArcaneCharges > 0 then
            local cArcingCleaveUnitCap = nArcingCleaveUnitCap * currentArcaneCharges

            for _, nameplateGUID in pairs(idValidUnit) do
                if nameplateGUID ~= targetGUID then
                    cArcingCleaveInstantDmgAoE = cArcingCleaveInstantDmgAoE + (nArcaneBarrageDmg * nArcingCleave)
                    countArcingCleaveUnit = countArcingCleaveUnit + 1

                    if countArcingCleaveUnit >= cArcingCleaveUnitCap then break end
                end
            end
        end
    end

    local cResonance = 1
    if wan.traitData.Resonance.known then
        cResonance = cResonance + (targetGUID and nResonance or 0)
        cResonance = cResonance + (nResonance * countArcingCleaveUnit)
    end

    local cDematerialize = 0
    if wan.traitData.Dematerialize.known then
        local checkNetherPrecisionBuff = wan.CheckUnitBuff(nil, wan.traitData.NetherPrecision.traitkey)
        if checkNetherPrecisionBuff then
            cDematerialize = cDematerialize + nDematerialize
        end
    end

    local cArcaneDebilitation = 1
    local cArcaneDebilitationAoE = 1
    if wan.traitData.ArcaneDebilitation.known then
        local formattedDebuffName = wan.traitData.ArcaneDebilitation.traitkey
        local checkArcaneDebilitationDebuff = wan.CheckUnitDebuff(targetUnitToken, formattedDebuffName)
        if checkArcaneDebilitationDebuff then
            local checkArcaneDebilitationStacks = checkArcaneDebilitationDebuff.applications
            cArcaneDebilitation = cArcaneDebilitation + (nArcaneDebilitation * checkArcaneDebilitationStacks)
        end

        if wan.traitData.AetherAttunement.known and wan.traitData.ArcingCleave.known then
            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitArcaneDebilitationDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)
                    if checkUnitArcaneDebilitationDebuff then
                        local checkUnitArcaneDebilitationStacks = checkUnitArcaneDebilitationDebuff.applications
                        cArcaneDebilitationAoE = cArcaneDebilitationAoE + (nArcaneDebilitation * checkUnitArcaneDebilitationStacks)
                    end
                end
            end
        end
    end

    local cArcaneBombardment = 1
    if wan.traitData.ArcaneBombardment.known then
        local targetPercentHealth = targetGUID and UnitPercentHealthFromGUID(targetGUID) or 1

        if targetPercentHealth < nArcaneBombardmentThreshold then
            cArcaneBombardment = cArcaneBombardment + nArcaneBombardment
        end
    end

    local cOrbBarrageInstantDmgAoE = 0
    if wan.traitData.OrbBarrage.known then
        local cOrbBarrageProcChance = nOrbBarrageProcChance * currentArcaneCharges
        cOrbBarrageInstantDmgAoE = cOrbBarrageInstantDmgAoE + (nArcaneOrbDmg * countValidUnit * cOrbBarrageProcChance * nOrbBarrage)
    end

    ---- SPELLSLINGER TRAITS ----

    local cArcaneSplinterInstantDmg = 0
    local cArcaneSplinterDotDmg = 0
    local cControlledInstinctsInstantDmgAoE = 0
    if wan.traitData.SplinteringSorcery.known then
        local checkNetherPrecisionBuff = wan.CheckUnitBuff(nil, wan.traitData.NetherPrecision.traitkey)
        if checkNetherPrecisionBuff then
            cArcaneSplinterInstantDmg = cArcaneSplinterInstantDmg + (nArcaneSplinterDmg * nArcaneSplinterCount)

            local dotPotency = wan.CheckDotPotency(nArcaneBarrageDmg, targetUnitToken)
            cArcaneSplinterDotDmg = cArcaneSplinterDotDmg + (nArcaneSplinterDotDmg * nArcaneSplinterCount * dotPotency)
        end

        if wan.traitData.ControlledInstincts.known then
            local checkControlledInstinctsDebuff = wan.CheckUnitDebuff(nil, wan.traitData.ControlledInstincts.traitkey)
            if checkControlledInstinctsDebuff then
                local countControlledInstinctsUnit = math.max(countValidUnit - 1, 0)
                local cControlledInstinctsUnit = wan.AdjustSoftCapUnitOverflow(nControlledInstinctsSoftCap, countControlledInstinctsUnit)
                cControlledInstinctsInstantDmgAoE = cControlledInstinctsInstantDmgAoE + (nArcaneSplinterDmg * nArcaneSplinterCount * nControlledInstincts * cControlledInstinctsUnit)
            end
        end
    end

    ---- SUNFURY TRAITS ----

    local cGloriousIncandescenceInstantDmg = 0
    if wan.traitData.GloriousIncandescence.known then
        local checkGloriousIncandescenceBuff = wan.CheckUnitBuff(nil, wan.traitData.GloriousIncandescence.traitkey)
        if checkGloriousIncandescenceBuff then
            cGloriousIncandescenceInstantDmg = cGloriousIncandescenceInstantDmg + (nFrostboltDmg * nGloriousIncandescenceMeteoriteCount)
        end
    end

    local cArcaneBarrageCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cArcaneBarrageInstantDmg = cArcaneBarrageInstantDmg
        + (nArcaneBarrageDmg * cArcaneDebilitation * cResonance * cArcaneBombardment * cArcaneBarrageCritValue)
        + (cArcaneSplinterInstantDmg * cArcaneBarrageCritValue)
        + (cGloriousIncandescenceInstantDmg * cArcaneBarrageCritValue)

    cArcaneBarrageDotDmg = cArcaneBarrageDotDmg 
        + (nArcaneBarrageDmg * cArcaneDebilitation * cResonance * cArcaneBombardment * cArcaneBarrageCritValue * cDematerialize)
        + (cArcaneSplinterDotDmg * cArcaneBarrageCritValue)

    cArcaneBarrageInstantDmgAoE = cArcaneBarrageInstantDmgAoE
        + (cArcingCleaveInstantDmgAoE * cArcaneDebilitationAoE * cResonance * cArcaneBarrageCritValue)
        + (cOrbBarrageInstantDmgAoE * cArcaneBarrageCritValue)
        + (cControlledInstinctsInstantDmgAoE * cArcaneBarrageCritValue)

    cArcaneBarrageDotDmgAoE = cArcaneBarrageDotDmgAoE
        + (cArcingCleaveInstantDmgAoE * cArcaneDebilitationAoE * cResonance * cArcaneBarrageCritValue * cDematerialize)

    local cArcaneBarrageDmg = cArcaneBarrageInstantDmg + cArcaneBarrageDotDmg + cArcaneBarrageInstantDmgAoE + cArcaneBarrageDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cArcaneBarrageDmg)
    wan.UpdateAbilityData(wan.spellData.ArcaneBarrage.basename, abilityValue, wan.spellData.ArcaneBarrage.icon, wan.spellData.ArcaneBarrage.name)
end

-- Init frame 
local frameArcaneBarrage = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)

        if event == "SPELLS_CHANGED" then
            maxArcaneCharges = UnitPowerMax("player", 16) or 0
            currentArcaneCharges = UnitPower("player", 16) or 0
        end

        if event == "UNIT_POWER_UPDATE" then
            local unitID, powerType = ...
            if unitID == "player" and powerType == "ARCANE_CHARGES" then
                currentArcaneCharges = UnitPower("player", 16) or 0
            end
        end

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nArcaneBarrageDmg = wan.GetSpellDescriptionNumbers(wan.spellData.ArcaneBarrage.id, { 1 })

            nArcaneOrbDmg = wan.GetSpellDescriptionNumbers(wan.spellData.ArcaneOrb.id, { 2 })

            local nSplinteringSorceryValues = wan.GetTraitDescriptionNumbers(wan.traitData.SplinteringSorcery.entryid, { 1, 4, 5 })
            nArcaneSplinterCount = nSplinteringSorceryValues[1]
            nArcaneSplinterDmg = nSplinteringSorceryValues[2]
            nArcaneSplinterDotDmg = nSplinteringSorceryValues[3]

            nFrostboltDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Frostbolt.id, { 1 })
        end
    end)
end
frameArcaneBarrage:RegisterEvent("ADDON_LOADED")
frameArcaneBarrage:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.ArcaneBarrage.known and wan.spellData.ArcaneBarrage.id
        wan.BlizzardEventHandler(frameArcaneBarrage, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED", "UNIT_POWER_UPDATE")
        wan.SetUpdateRate(frameArcaneBarrage, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        local nArcingCleaveValues = wan.GetTraitDescriptionNumbers(wan.traitData.ArcingCleave.entryid, { 1, 2 })
        nArcingCleaveUnit = nArcingCleaveValues[1]
        nArcingCleaveUnitCap = 1 * nArcingCleaveUnit
        nArcingCleave = nArcingCleaveValues[2] * 0.01

        nResonance = wan.GetTraitDescriptionNumbers(wan.traitData.Resonance.entryid, { 1 }) * 0.01

        nDematerialize = wan.GetTraitDescriptionNumbers(wan.traitData.Dematerialize.entryid, { 1 }) * 0.01

        nArcaneDebilitation = wan.GetTraitDescriptionNumbers(wan.traitData.ArcaneDebilitation.entryid, { 1 }, wan.traitData.ArcaneDebilitation.rank) * 0.01

        local nArcaneBombardmentValues = wan.GetTraitDescriptionNumbers(wan.traitData.ArcaneBombardment.entryid, { 1, 2 })
        nArcaneBombardment = nArcaneBombardmentValues[1] * 0.01
        nArcaneBombardmentThreshold = nArcaneBombardmentValues[2] * 0.01

        local nOrbBarrageValues = wan.GetTraitDescriptionNumbers(wan.traitData.OrbBarrage.entryid, { 1, 2 })
        nOrbBarrageProcChance = nOrbBarrageValues[1] * 0.01
        nOrbBarrage = nOrbBarrageValues[2] * 0.01

        local nControlledInstinctsValues = wan.GetTraitDescriptionNumbers(wan.traitData.ControlledInstincts.entryid, { 2, 3 })
        nControlledInstincts = nControlledInstinctsValues[1] * 0.01
        nControlledInstinctsSoftCap = nControlledInstinctsValues[2]

        nGloriousIncandescenceMeteoriteCount = wan.GetTraitDescriptionNumbers(wan.traitData.GloriousIncandescence.entryid, { 2 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameArcaneBarrage, CheckAbilityValue, abilityActive)
    end
end)