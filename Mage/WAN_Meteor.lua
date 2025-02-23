local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nMeteorDmg, nMeteorDotDmg = 0, 0

-- Init trait data
local nMasteryIgnite = 0
local nOverflowingEnergy = 0
local nImprovedScorch = 0
local nMasterofFlame = 0
local nWildfireCritDmg, nWildfireCombustionCritDmg = 0, 0
local nFiresIre = 0
local nMoltenFuryThreshold, nMoltenFury = 0, 0
local nLitFuseDmg, nLitFuseUnitCap = 0, 0
local nMarkoftheFirelord = 0
local nConvection = 0
local nIsothermicCoreMeteor, nIsothermicCoreCometStorm, nCometStormDmg = 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Meteor.id)
    then
        wan.UpdateAbilityData(wan.spellData.Meteor.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.Meteor.maxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Meteor.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cMeteorInstantDmg = 0
    local cMeteorDotDmg = 0
    local cMeteorInstantDmgAoE = 0
    local cMeteorDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cMeteorBaseDotDmgAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local dotPotency = wan.CheckDotPotency(nMeteorDmg, nameplateUnitToken)

        cMeteorBaseDotDmgAoE = cMeteorBaseDotDmgAoE + (nMeteorDotDmg * dotPotency)
    end

    ---- CLASS TRAITS ----

    local cMasteryIgniteAoE = 0
    if wan.spellData.MasteryIgnite.known then
        local dotPotencyAoE = 0
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local dotPotency = wan.CheckDotPotency(nMeteorDmg, nameplateUnitToken)
            dotPotencyAoE = dotPotencyAoE + dotPotency
        end

        dotPotencyAoE = dotPotencyAoE / countValidUnit
        cMasteryIgniteAoE = cMasteryIgniteAoE + (nMasteryIgnite * dotPotencyAoE)
    end

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
    end

    ---- FIRE TRAITS ----

    local cImprovedScorchAoE = 1
    if wan.traitData.ImprovedScorch.known then
        local formattedDebuffName = wan.traitData.ImprovedScorch.traitkey
        local countImprovedScorchDebuff = 0

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitImprovedScorchDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)
            local checkImprovedScorchStacks = checkUnitImprovedScorchDebuff and checkUnitImprovedScorchDebuff.applications

            if checkImprovedScorchStacks == 0 then
                checkImprovedScorchStacks = 1
            end

            if checkUnitImprovedScorchDebuff then
                countImprovedScorchDebuff = countImprovedScorchDebuff + (1 *  checkImprovedScorchStacks)
            end
        end

        if countImprovedScorchDebuff > 0 then
            cImprovedScorchAoE = cImprovedScorchAoE + (nImprovedScorch * (countImprovedScorchDebuff / countValidUnit))
        end
    end

    if wan.traitData.Combustion.known then
        local checkCombustionBuff = wan.CheckUnitBuff(nil, wan.spellData.Combustion.formattedName)
        if checkCombustionBuff then
            critChanceMod = critChanceMod + 100

            if wan.traitData.FiresIre.known then
                critDamageMod = critDamageMod + nFiresIre
            end
        end
    end

    local cMasterofFlame = 1
    if wan.traitData.MasterofFlame.known then
        local checkCombustionBuff = wan.CheckUnitBuff(nil, wan.spellData.Combustion.formattedName)
        if not checkCombustionBuff then
            cMasterofFlame = cMasterofFlame + nMasterofFlame
        end
    end

    if wan.traitData.Wildfire.known then
        critDamageMod = critDamageMod + nWildfireCritDmg
        local checkCombustionBuff = wan.CheckUnitBuff(nil, wan.spellData.Combustion.formattedName)
        if checkCombustionBuff then
            critDamageMod = critDamageMod + nWildfireCombustionCritDmg
        end
    end

    local cMoltenFury = 1
    if wan.traitData.MoltenFury.known then
        local countMoltenFury = 0
        for _, nameplateGUID in pairs(idValidUnit) do
            local checkPercentageHealth = targetGUID and UnitPercentHealthFromGUID(nameplateGUID) or 1
            if checkPercentageHealth < nMoltenFuryThreshold then
                countMoltenFury = countMoltenFury + 1
            end
        end

        if countMoltenFury > 0 then
            cMoltenFury = cMoltenFury + ((nMoltenFury * countMoltenFury) / countValidUnit)
        end
    end

    local cLitFuseInstantDmg = 0
    local cLitFuseInstantDmgAoE = 0
    local cMarkoftheFirelord = 1
    if wan.traitData.DeepImpact.known then
        cLitFuseInstantDmg = cLitFuseInstantDmg + nLitFuseDmg

        local cLitFuseUnitOverflow = wan.SoftCapOverflow(1, countValidUnit)
        local countLitFuseUnit = 0
        for _, nameplateGUID in pairs(idValidUnit) do
            if nameplateGUID ~= targetGUID then
                cLitFuseInstantDmgAoE = cLitFuseInstantDmgAoE + (nLitFuseDmg * cLitFuseUnitOverflow)

                countLitFuseUnit = countLitFuseUnit + 1

                if countLitFuseUnit >= nLitFuseUnitCap then break end
            end
        end

        local cConvection = 1
        if wan.traitData.Convection.known then
            if countValidUnit == 1 then
                cConvection = cConvection + nConvection
            end
        end

        if wan.traitData.MarkoftheFirelord.known then
            cMarkoftheFirelord = cMarkoftheFirelord + nMarkoftheFirelord
        end

        cLitFuseInstantDmg = cLitFuseInstantDmg + ((nLitFuseDmg * cConvection) + (nLitFuseDmg * countLitFuseUnit))
        cLitFuseInstantDmgAoE = cLitFuseInstantDmgAoE * countLitFuseUnit
    end

    ---- FROSTFIRE TRAITS ----

    local cIsothermicCore = 0
    if wan.traitData.IsothermicCore.known then
        cIsothermicCore = cIsothermicCore + (nCometStormDmg * nIsothermicCoreCometStorm * countValidUnit)
    end

    local cMeteorCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cMeteorInstantDmg = cMeteorInstantDmg

    cMeteorDotDmg = cMeteorDotDmg

    cMeteorInstantDmgAoE = cMeteorInstantDmgAoE
        + (nMeteorDmg * cImprovedScorchAoE * countValidUnit * cMoltenFury * cMeteorCritValue)
        + ((cLitFuseInstantDmg + cLitFuseInstantDmgAoE) * cImprovedScorchAoE * cMoltenFury * cMeteorCritValue)
        + (cIsothermicCore * cImprovedScorchAoE * cMoltenFury * cMeteorCritValue)

    cMeteorDotDmgAoE = cMeteorDotDmgAoE
        + (nMeteorDmg * cImprovedScorchAoE * countValidUnit * cMasteryIgniteAoE * cMasterofFlame * cMoltenFury * cMeteorCritValue)
        + (cMeteorBaseDotDmgAoE * cImprovedScorchAoE * cMoltenFury * cMeteorCritValue)
        + ((cLitFuseInstantDmg + cLitFuseInstantDmgAoE) * cMasteryIgniteAoE * cMarkoftheFirelord * cImprovedScorchAoE * cMoltenFury * cMeteorCritValue)

    local cMeteorDmg = cMeteorInstantDmg + cMeteorDotDmg + cMeteorInstantDmgAoE + cMeteorDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cMeteorDmg)
    wan.UpdateAbilityData(wan.spellData.Meteor.basename, abilityValue, wan.spellData.Meteor.icon, wan.spellData.Meteor.name)
end

-- Init frame 
local frameMeteor = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nMeteorValues = wan.GetSpellDescriptionNumbers(wan.spellData.Meteor.id, { 2, 4 })
            nMeteorDmg = nMeteorValues[1]
            nMeteorDotDmg = nMeteorValues[2]

            nMasteryIgnite = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryIgnite.id, { 1 }) * 0.01

            local nLitFuseValues = wan.GetTraitDescriptionNumbers(wan.traitData.LitFuse.entryid, { 6, 8 })
            nLitFuseDmg = nLitFuseValues[1]
            nLitFuseUnitCap = nLitFuseValues[2]

            nCometStormDmg = wan.GetSpellDescriptionNumbers(wan.spellData.CometStorm.id, { 2 })
        end
    end)
end
frameMeteor:RegisterEvent("ADDON_LOADED")
frameMeteor:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Meteor.known and wan.spellData.Meteor.id
        wan.BlizzardEventHandler(frameMeteor, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameMeteor, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        nImprovedScorch = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedScorch.entryid, { 2 }) * 0.01

        nMasterofFlame = wan.GetTraitDescriptionNumbers(wan.traitData.MasterofFlame.entryid, { 1 }) * 0.01

        local nWildfireValues = wan.GetTraitDescriptionNumbers(wan.traitData.Wildfire.entryid, { 1, 2 })
        nWildfireCritDmg = nWildfireValues[1]
        nWildfireCombustionCritDmg = nWildfireValues[2]

        nFiresIre = wan.GetTraitDescriptionNumbers(wan.traitData.FiresIre.entryid, { 2 }, wan.traitData.FiresIre.rank)

        local nMoltenFuryValues = wan.GetTraitDescriptionNumbers(wan.traitData.MoltenFury.entryid, { 1, 2 })
        nMoltenFuryThreshold = nMoltenFuryValues[1] * 0.01
        nMoltenFury = nMoltenFuryValues[2] * 0.01

        nMarkoftheFirelord = wan.GetTraitDescriptionNumbers(wan.traitData.MarkoftheFirelord.entryid, { 1 }) * 0.01

        nConvection = wan.GetTraitDescriptionNumbers(wan.traitData.Convection.entryid, { 1 }) * 0.01

        local nIsothermicCoreValues = wan.GetTraitDescriptionNumbers(wan.traitData.IsothermicCore.entryid, { 1, 2 })
        nIsothermicCoreMeteor = nIsothermicCoreValues[1] * 0.01
        nIsothermicCoreCometStorm = nIsothermicCoreValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameMeteor, CheckAbilityValue, abilityActive)
    end
end)