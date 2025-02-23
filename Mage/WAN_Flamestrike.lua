local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nFlamestrikeDmg, nFlamestrikeSoftCap = 0, 0

-- Init trait data
local nMasteryIgnite = 0
local nOverflowingEnergy = 0
local nMajestyofthePhoenixCritChance, nMajestyofthePhoenixCritDmg = 0, 0
local nImprovedScorch = 0
local nInflame = 0
local nFlamePatchDmg = 0
local nMasterofFlame = 0
local nWildfireCritDmg, nWildfireCombustionCritDmg = 0, 0
local nMarkoftheFirelord = 0
local nFiresIre = 0
local nPyromaniacProcChance, nPyromaniac = 0, 0
local nMoltenFuryThreshold, nMoltenFury = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Flamestrike.id)
    then
        wan.UpdateAbilityData(wan.spellData.Flamestrike.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.Flamestrike.maxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Flamestrike.basename)
        return
    end

    local canMovecast = wan.auraData.player.buff_IceFloes and true or false
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Flamestrike.id, wan.spellData.Flamestrike.castTime, canMovecast)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(wan.spellData.Flamestrike.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cFlamestrikeInstantDmg = 0
    local cFlamestrikeDotDmg = 0
    local cFlamestrikeInstantDmgAoE = 0
    local cFlamestrikeDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- CLASS TRAITS ----

    local cMasteryIgniteAoE = 0
    if wan.spellData.MasteryIgnite.known then
        local dotPotencyAoE = 0
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local dotPotency = wan.CheckDotPotency(nFlamestrikeDmg, nameplateUnitToken)
            dotPotencyAoE = dotPotencyAoE + dotPotency
        end

        dotPotencyAoE = dotPotencyAoE / countValidUnit
        cMasteryIgniteAoE = cMasteryIgniteAoE + (nMasteryIgnite * dotPotencyAoE)

    end

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
    end

    ---- FIRE TRAITS ----

    if wan.traitData.MajestyofthePhoenix.known then
        local checkMajestyofthePhoenixBuff = wan.CheckUnitBuff(nil, wan.traitData.MajestyofthePhoenix.traitkey)
        local checkMajestyofthePhoenixStacks = checkMajestyofthePhoenixBuff and checkMajestyofthePhoenixBuff.applications

        if checkMajestyofthePhoenixStacks == 0 then
            checkMajestyofthePhoenixStacks = 1
        end

        if checkMajestyofthePhoenixBuff then
            critChanceMod = critChanceMod + (nMajestyofthePhoenixCritChance * checkMajestyofthePhoenixStacks)
            critDamageMod = critDamageMod + (nMajestyofthePhoenixCritDmg * checkMajestyofthePhoenixStacks)
        end
    end

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

    local cInflame = 1
    if wan.traitData.Inflame.known then
        local checkHotStreakBuff = wan.CheckUnitBuff("player", "HotStreak")
        if checkHotStreakBuff then
            cInflame = cInflame + nInflame
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

    local cFlamePatchDotDmgAoE = 0
    if wan.traitData.FlamePatch.known then
        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local dotPotency = wan.CheckDotPotency(nFlamestrikeDmg, nameplateUnitToken)

            cFlamePatchDotDmgAoE = cFlamePatchDotDmgAoE + (nFlamePatchDmg * dotPotency)
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

    local cMarkoftheFirelord = 1
    if wan.traitData.MarkoftheFirelord.known then
        cMarkoftheFirelord = cMarkoftheFirelord + nMarkoftheFirelord
    end

    local cPyromaniac = 0
    if wan.traitData.Pyromaniac.known then
        local checkHotStreakBuff = wan.CheckUnitBuff("player", "HotStreak")
        if checkHotStreakBuff then
            cPyromaniac = cPyromaniac + (nPyromaniac * nPyromaniacProcChance)
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

    if wan.traitData.Hyperthermia.known then
        local checkHyperthermiaBuff = wan.CheckUnitBuff(nil, wan.traitData.Hyperthermia.traitkey)
        if checkHyperthermiaBuff then
            critChanceMod = critChanceMod + 100
        end
    end

    local cFlamestrikeUnitOverflow = wan.AdjustSoftCapUnitOverflow(nFlamestrikeSoftCap, countValidUnit)
    local cFlamestrikeCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cFlamestrikeInstantDmg = cFlamestrikeInstantDmg

    cFlamestrikeDotDmg = cFlamestrikeDotDmg

    cFlamestrikeInstantDmgAoE = cFlamestrikeInstantDmgAoE
        + (nFlamestrikeDmg * cImprovedScorchAoE * cFlamestrikeUnitOverflow * cMoltenFury * cFlamestrikeCritValue)
        + (nFlamestrikeDmg * cImprovedScorchAoE * cPyromaniac * cFlamestrikeUnitOverflow * cMoltenFury * cFlamestrikeCritValue)

    cFlamestrikeDotDmgAoE = cFlamestrikeDotDmgAoE
        + (nFlamestrikeDmg * cImprovedScorchAoE * cFlamestrikeUnitOverflow * cMasteryIgniteAoE * cMarkoftheFirelord * cMasterofFlame * cInflame * cMoltenFury * cFlamestrikeCritValue)
        + (cFlamePatchDotDmgAoE * cImprovedScorchAoE * cMoltenFury * cFlamestrikeCritValue)
        + (nFlamestrikeDmg * cImprovedScorchAoE * cFlamestrikeUnitOverflow * cMasteryIgniteAoE * cPyromaniac * cMarkoftheFirelord * cMasterofFlame * cInflame * cMoltenFury * cFlamestrikeCritValue)

    local cFlamestrikeDmg = (cFlamestrikeInstantDmg + cFlamestrikeDotDmg + cFlamestrikeInstantDmgAoE + cFlamestrikeDotDmgAoE) * castEfficiency

    -- Update ability data
    local abilityValue = math.floor(cFlamestrikeDmg)
    wan.UpdateAbilityData(wan.spellData.Flamestrike.basename, abilityValue, wan.spellData.Flamestrike.icon, wan.spellData.Flamestrike.name)
end

-- Init frame 
local frameFlamestrike = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nFlamestrikeValues = wan.GetSpellDescriptionNumbers(wan.spellData.Flamestrike.id, { 1, 4 })
            nFlamestrikeDmg = nFlamestrikeValues[1]
            nFlamestrikeSoftCap = nFlamestrikeValues[2]

            nMasteryIgnite = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryIgnite.id, { 1 }) * 0.01

            local nMajestyofthePhoenixValues = wan.GetTraitDescriptionNumbers(wan.traitData.MajestyofthePhoenix.entryid, { 1, 2 })
            nMajestyofthePhoenixCritChance = nMajestyofthePhoenixValues[1]
            nMajestyofthePhoenixCritDmg = nMajestyofthePhoenixValues[2]

            nFlamePatchDmg = wan.GetTraitDescriptionNumbers(wan.traitData.FlamePatch.entryid, { 1 })
        end
    end)
end
frameFlamestrike:RegisterEvent("ADDON_LOADED")
frameFlamestrike:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Flamestrike.known and wan.spellData.Flamestrike.id
        wan.BlizzardEventHandler(frameFlamestrike, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFlamestrike, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        nImprovedScorch = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedScorch.entryid, { 2 }) * 0.01

        nInflame = wan.GetTraitDescriptionNumbers(wan.traitData.Inflame.entryid, { 1 }) * 0.01

        nMasterofFlame = wan.GetTraitDescriptionNumbers(wan.traitData.MasterofFlame.entryid, { 1 }) * 0.01

        local nWildfireValues = wan.GetTraitDescriptionNumbers(wan.traitData.Wildfire.entryid, { 1, 2 })
        nWildfireCritDmg = nWildfireValues[1]
        nWildfireCombustionCritDmg = nWildfireValues[2]

        nMarkoftheFirelord = wan.GetTraitDescriptionNumbers(wan.traitData.MarkoftheFirelord.entryid, { 1 }) * 0.01

        nFiresIre = wan.GetTraitDescriptionNumbers(wan.traitData.FiresIre.entryid, { 2 }, wan.traitData.FiresIre.rank)

        local nPyromaniacValues = wan.GetTraitDescriptionNumbers(wan.traitData.Pyromaniac.entryid, { 1, 2 })
        nPyromaniacProcChance = nPyromaniacValues[1] * 0.01
        nPyromaniac = nPyromaniacValues[2] * 0.01

        local nMoltenFuryValues = wan.GetTraitDescriptionNumbers(wan.traitData.MoltenFury.entryid, { 1, 2 })
        nMoltenFuryThreshold = nMoltenFuryValues[1] * 0.01
        nMoltenFury = nMoltenFuryValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFlamestrike, CheckAbilityValue, abilityActive)
    end
end)