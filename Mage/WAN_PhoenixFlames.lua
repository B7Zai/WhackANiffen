local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nPhoenixFlamesDmg = 0
local nMasteryIgnite = 0

-- Init trait data
local nOverflowingEnergy = 0
local nImprovedScorch = 0
local nAshenFeatherUnitCap, nAshenFeather, nAshenFeatherIgnite = 0, 0, 0
local nMasterofFlame = 0
local nWildfireCritDmg, nWildfireCombustionCritDmg = 0, 0
local nFiresIre = 0
local nMoltenFuryThreshold, nMoltenFury = 0, 0
local nIceNova, nExcessFrost = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.PhoenixFlames.id)
    then
        wan.UpdateAbilityData(wan.spellData.PhoenixFlames.basename)
        return
    end

    if wan.spellData.HotStreak.known and wan.CheckUnitBuff("player", "HotStreak")  then
        wan.UpdateAbilityData(wan.spellData.PhoenixFlames.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.PhoenixFlames.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.PhoenixFlames.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cPhoenixFlamesInstantDmg = 0
    local cPhoenixFlamesDotDmg = 0
    local cPhoenixFlamesInstantDmgAoE = 0
    local cPhoenixFlamesDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cPhoenixFlamesBaseInstantDmgAoE = 0
    local cPhoenixFlamesUnitOverflow = wan.SoftCapOverflow(1, countValidUnit)
    for _, nameplateGUID in pairs(idValidUnit) do
        if nameplateGUID ~= targetGUID then
            cPhoenixFlamesBaseInstantDmgAoE = cPhoenixFlamesBaseInstantDmgAoE + (nPhoenixFlamesDmg * cPhoenixFlamesUnitOverflow)
        end
    end

    ---- CLASS TRAITS ----

    local cMasteryIgnite = 0
    local cMasteryIgniteAoE = 0
    if wan.spellData.MasteryIgnite.known then
        local dotPotency = wan.CheckDotPotency(nPhoenixFlamesDmg, targetUnitToken)
        cMasteryIgnite = cMasteryIgnite + (nMasteryIgnite * dotPotency)

        local dotPotencyAoE = 0
        local countMasteryIgniteSecondaryTargets = 0
        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID~= targetGUID then

                local unitDotPotency = wan.CheckDotPotency((nPhoenixFlamesDmg * cPhoenixFlamesUnitOverflow), nameplateUnitToken)
                dotPotencyAoE = dotPotencyAoE + unitDotPotency
                countMasteryIgniteSecondaryTargets = countMasteryIgniteSecondaryTargets + 1
            end
        end

        if countMasteryIgniteSecondaryTargets > 0 then
            dotPotencyAoE = dotPotencyAoE / countMasteryIgniteSecondaryTargets
        end
        
        cMasteryIgniteAoE = cMasteryIgniteAoE + (nMasteryIgnite * dotPotencyAoE)
    end

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
        critDamageModBase = critDamageModBase + nOverflowingEnergy
    end

    ---- FIRE TRAITS ----

    if wan.traitData.CalloftheSunKing.known then
        critChanceMod = critChanceMod + 100
    end

    local cImprovedScorch = 1
    local cImprovedScorchAoE = 1
    if wan.traitData.ImprovedScorch.known then
        local formattedDebuffName = wan.traitData.ImprovedScorch.traitkey
        local checkImprovedScorchDebuff = wan.CheckUnitDebuff(nil, formattedDebuffName)
        local checkImprovedScorchStacks = checkImprovedScorchDebuff and checkImprovedScorchDebuff.applications

        if checkImprovedScorchStacks == 0 then checkImprovedScorchStacks = 1 end

        if checkImprovedScorchDebuff then
            cImprovedScorch = cImprovedScorch + (nImprovedScorch * checkImprovedScorchStacks)
        end

        local countImprovedScorchDebuff = 0
        local countImprovedScorchUnit = math.max(countValidUnit - 1, 0)
        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                local checkUnitImprovedScorchDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)
                local checkUnitImprovedScorchStacks = checkUnitImprovedScorchDebuff and checkUnitImprovedScorchDebuff.applications

                if checkUnitImprovedScorchStacks == 0 then
                    checkUnitImprovedScorchStacks = 1
                end

                if checkUnitImprovedScorchDebuff then
                    countImprovedScorchDebuff = countImprovedScorchDebuff + (1 * checkUnitImprovedScorchStacks)
                end
            end
        end

        if countImprovedScorchDebuff > 0 then
            cImprovedScorchAoE = cImprovedScorchAoE + (nImprovedScorch * (countImprovedScorchDebuff / countImprovedScorchUnit))
        end
    end

    local cAshenFeather = 1
    local cAshenFeatherIgnite = 1
    if wan.traitData.AshenFeather.known then
        if countValidUnit == nAshenFeatherUnitCap then
            cAshenFeather = cAshenFeather + nAshenFeather
            cAshenFeatherIgnite = cAshenFeatherIgnite + nAshenFeatherIgnite
        end
    end

    if wan.traitData.Combustion.known then
        local checkCombustionBuff = wan.CheckUnitBuff(nil, wan.spellData.Combustion.formattedName)
        if checkCombustionBuff then
            critChanceMod = critChanceMod + 100
            critChanceModBase = critChanceModBase + 100

            if wan.traitData.FiresIre.known then
                critDamageMod = critDamageMod + nFiresIre
                critDamageModBase = critDamageModBase + nFiresIre
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
            critDamageModBase = critDamageModBase + nWildfireCombustionCritDmg
        end
    end

    local cMoltenFury = 1
    local cMoltenFuryAoE = 1
    if wan.traitData.MoltenFury.known then
        local checkPercentageHealth = targetGUID and UnitPercentHealthFromGUID(targetGUID) or 1
        if checkPercentageHealth < nMoltenFuryThreshold then
            cMoltenFury = cMoltenFury + nMoltenFury
        end

        local countMoltenFury = 0
        local countMoltenFuryUnit = math.max(countValidUnit - 1, 0)
        for _, nameplateGUID in pairs(idValidUnit) do
            if nameplateGUID ~= targetGUID then
                local checkPercentageHealth = targetGUID and UnitPercentHealthFromGUID(nameplateGUID) or 1
                if checkPercentageHealth < nMoltenFuryThreshold then
                    countMoltenFury = countMoltenFury + 1
                end
            end
        end

        if countMoltenFuryUnit > 0 then
            cMoltenFuryAoE = cMoltenFuryAoE + ((nMoltenFury * countMoltenFury) / countMoltenFuryUnit)
        end
    end

    ---- FROSTFIRE TRAITS ----

    local cExcessFrostInstantDmgAoE = 0
    if wan.traitData.ExcessFrost.known then
        local checkExcessFrostBuff = wan.CheckUnitBuff(nil, wan.traitData.ExcessFrost.traitkey)
        if checkExcessFrostBuff then
            cExcessFrostInstantDmgAoE = cExcessFrostInstantDmgAoE + (nIceNova * countValidUnit * nExcessFrost)
        end
    end

    local cPhoenixFlamesCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cPhoenixFlamesCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cPhoenixFlamesInstantDmg = cPhoenixFlamesInstantDmg
        + (nPhoenixFlamesDmg * cAshenFeather * cImprovedScorch * cMoltenFury * cPhoenixFlamesCritValue)

    cPhoenixFlamesDotDmg = cPhoenixFlamesDotDmg
        + (nPhoenixFlamesDmg * cAshenFeather * cAshenFeatherIgnite * cImprovedScorch * cMasteryIgnite * cMasterofFlame * cMoltenFury * cPhoenixFlamesCritValue)

    cPhoenixFlamesInstantDmgAoE = cPhoenixFlamesInstantDmgAoE
        + (cPhoenixFlamesBaseInstantDmgAoE * cAshenFeather * cImprovedScorchAoE * cMoltenFuryAoE * cPhoenixFlamesCritValue)
        + (cExcessFrostInstantDmgAoE * cImprovedScorch * cImprovedScorchAoE * cMoltenFury * cMoltenFuryAoE * cPhoenixFlamesCritValueBase)

    cPhoenixFlamesDotDmgAoE = cPhoenixFlamesDotDmgAoE
        + (cPhoenixFlamesBaseInstantDmgAoE * cAshenFeather * cAshenFeatherIgnite * cImprovedScorchAoE * cMasteryIgniteAoE * cMasterofFlame * cMoltenFuryAoE * cPhoenixFlamesCritValue)

    local cPhoenixFlamesDmg = cPhoenixFlamesInstantDmg + cPhoenixFlamesDotDmg + cPhoenixFlamesInstantDmgAoE + cPhoenixFlamesDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cPhoenixFlamesDmg)
    wan.UpdateAbilityData(wan.spellData.PhoenixFlames.basename, abilityValue, wan.spellData.PhoenixFlames.icon, wan.spellData.PhoenixFlames.name)
end

local framePhoenixFlames = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nPhoenixFlamesDmg = wan.GetSpellDescriptionNumbers(wan.spellData.PhoenixFlames.id, { 1 })

            nMasteryIgnite = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryIgnite.id, { 1 }) * 0.01

            nIceNova = wan.GetTraitDescriptionNumbers(wan.traitData.IceNova.entryid, { 1 })
        end
    end)
end
framePhoenixFlames:RegisterEvent("ADDON_LOADED")
framePhoenixFlames:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings & data update on traits
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.PhoenixFlames.known and wan.spellData.PhoenixFlames.id
        wan.BlizzardEventHandler(framePhoenixFlames, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(framePhoenixFlames, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        nImprovedScorch = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedScorch.entryid, { 2 }) * 0.01

        local nAshenFeatherValues = wan.GetTraitDescriptionNumbers(wan.traitData.AshenFeather.entryid, { 1, 2, 3 })
        nAshenFeatherUnitCap = nAshenFeatherValues[1]
        nAshenFeather = nAshenFeatherValues[2] * 0.01
        nAshenFeatherIgnite = nAshenFeatherValues[3] * 0.01

        nMasterofFlame = wan.GetTraitDescriptionNumbers(wan.traitData.MasterofFlame.entryid, { 1 }) * 0.01

        local nWildfireValues = wan.GetTraitDescriptionNumbers(wan.traitData.Wildfire.entryid, { 1, 2 })
        nWildfireCritDmg = nWildfireValues[1]
        nWildfireCombustionCritDmg = nWildfireValues[2]

        nFiresIre = wan.GetTraitDescriptionNumbers(wan.traitData.FiresIre.entryid, { 2 }, wan.traitData.FiresIre.rank)

        local nMoltenFuryValues = wan.GetTraitDescriptionNumbers(wan.traitData.MoltenFury.entryid, { 1, 2 })
        nMoltenFuryThreshold = nMoltenFuryValues[1] * 0.01
        nMoltenFury = nMoltenFuryValues[2] * 0.01

        nExcessFrost = wan.GetTraitDescriptionNumbers(wan.traitData.ExcessFrost.entryid, { 1 }) * 0.01 + 1
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(framePhoenixFlames, CheckAbilityValue, abilityActive)
    end
end)
