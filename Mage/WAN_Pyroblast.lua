local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nPyroblastDmg = 0

-- Init trait data
local nMasteryIgnite = 0
local nOverflowingEnergy = 0
local nFirestarterThreshold = 0
local nImprovedScorch = 0
local nInflame = 0
local nMasterofFlame = 0
local nWildfireCritDmg, nWildfireCombustionCritDmg = 0, 0
local nFiresIre = 0
local nPyromaniacProcChance, nPyromaniac = 0, 0
local nMoltenFuryThreshold, nMoltenFury = 0, 0
local nMeteorDmg, nMeteorDotDmg = 0, 0 -- this for firefall talent
local nSunKingsBlessing = 0
local nIsothermicCoreMeteor, nIsothermicCoreCometStorm, nCometStormDmg = 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or (not wan.CheckUnitBuff("player", "HotStreak") and not wan.auraData.player.buff_FuryoftheSunKing)
        or not wan.IsSpellUsable(wan.spellData.Pyroblast.id)
    then
        wan.UpdateAbilityData(wan.spellData.Pyroblast.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Pyroblast.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Pyroblast.basename)
        return
    end

    local canMovecast = wan.auraData.player.buff_IceFloes and true or false
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Pyroblast.id, wan.spellData.Pyroblast.castTime, canMovecast)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(wan.spellData.Pyroblast.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critChanceModBase = 0
    local critDamageMod = 0
    local critDamageModBase = 0

    local cPyroblastInstantDmg = 0
    local cPyroblastDotDmg = 0
    local cPyroblastInstantDmgAoE = 0
    local cPyroblastDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    if wan.traitData.Combustion.known then
        local checkCombustionBuff = wan.CheckUnitBuff(nil, wan.spellData.Combustion.formattedName)
        if checkCombustionBuff then
            critChanceMod = critChanceMod + 100
        end
    end

    ---- CLASS TRAITS ----

    local cMasteryIgnite = 0
    if wan.spellData.MasteryIgnite.known then
        local dotPotency = wan.CheckDotPotency(nPyroblastDmg, targetUnitToken)

        cMasteryIgnite = cMasteryIgnite + (nMasteryIgnite * dotPotency)
    end

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
    end

    ---- FIRE TRAITS ----

    if wan.traitData.Firestarter.known then
        local checkPercentageHealth = targetGUID and UnitPercentHealthFromGUID(targetGUID) or 1
        if checkPercentageHealth > nFirestarterThreshold then
            critChanceMod = critChanceMod + 100
        end
    end

    local cImprovedScorch = 1
    if wan.traitData.ImprovedScorch.known then
        local checkImprovedScorchDebuff = wan.CheckUnitDebuff(nil, wan.traitData.ImprovedScorch.traitkey)
        local checkImprovedScorchStacks = checkImprovedScorchDebuff and checkImprovedScorchDebuff.applications

        if checkImprovedScorchStacks == 0 then
            checkImprovedScorchStacks = 1
        end

        if checkImprovedScorchDebuff then
            cImprovedScorch = cImprovedScorch + (nImprovedScorch * checkImprovedScorchStacks)
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
            critChanceModBase = critChanceModBase + 100

            if wan.traitData.FiresIre.known then
                critChanceMod = critChanceMod + nFiresIre
                critChanceModBase = critChanceModBase + nFiresIre
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
            critChanceModBase = critChanceModBase + nWildfireCombustionCritDmg
        end
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
        local checkPercentageHealth = targetGUID and UnitPercentHealthFromGUID(targetGUID) or 1
        if checkPercentageHealth < nMoltenFuryThreshold then
            cMoltenFury = cMoltenFury + nMoltenFury
        end
    end

    local cFirefallInstantDmgAoE = 0
    local cFirefallDotDmgAoE = 0
    local cIsothermicCoreInstantDmgAoE = 0
    if wan.traitData.Firefall.known then
        local checkFirefallBuff = wan.CheckUnitBuff(nil, wan.traitData.Firefall.traitkey)
        if checkFirefallBuff and checkFirefallBuff.spellId == 384038 then
            cFirefallInstantDmgAoE = cFirefallInstantDmgAoE + (nMeteorDmg * countValidUnit)

            for nameplateUnitToken, _ in pairs(idValidUnit) do
                local dotPotency = wan.CheckDotPotency(nMeteorDmg, nameplateUnitToken)
        
                cFirefallDotDmgAoE = cFirefallDotDmgAoE + (nMeteorDotDmg * dotPotency)
            end

            if wan.traitData.IsothermicCore.known then
                cIsothermicCoreInstantDmgAoE = cIsothermicCoreInstantDmgAoE + (nCometStormDmg * nIsothermicCoreCometStorm * countValidUnit)
            end
        end
    end

    if wan.traitData.Hyperthermia.known then
        local checkHyperthermiaBuff = wan.CheckUnitBuff(nil, wan.traitData.Hyperthermia.traitkey)
        if checkHyperthermiaBuff then
            critChanceMod = critChanceMod + 100
        end
    end

    local cSunKingsBlessing = 1
    if wan.traitData.SunKingsBlessing.known then
        local formattedBuffName = "FuryoftheSunKing"
        local checkSunKingsBlessing = wan.CheckUnitBuff(nil, formattedBuffName)
        if checkSunKingsBlessing then
            cSunKingsBlessing = cSunKingsBlessing * nSunKingsBlessing
            critChanceMod = critChanceMod + 100
        end
    end

    local cPyroblastCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cPyroblastCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cPyroblastInstantDmg = cPyroblastInstantDmg
        + (nPyroblastDmg * cImprovedScorch * cMoltenFury * cSunKingsBlessing * cPyroblastCritValue)
        + (nPyroblastDmg * cImprovedScorch * cPyromaniac * cMoltenFury * cPyroblastCritValue)

    cPyroblastDotDmg = cPyroblastDotDmg 
        + (nPyroblastDmg * cImprovedScorch * cMasteryIgnite * cInflame * cMasterofFlame * cMoltenFury * cSunKingsBlessing * cPyroblastCritValue)
        + (nPyroblastDmg * cImprovedScorch * cMasteryIgnite * cInflame * cMasterofFlame * cPyromaniac * cMoltenFury * cPyroblastCritValue)

    cPyroblastInstantDmgAoE = cPyroblastInstantDmgAoE
        + (cFirefallInstantDmgAoE * cPyroblastCritValueBase)
        + (cIsothermicCoreInstantDmgAoE * cPyroblastCritValueBase)

    cPyroblastDotDmgAoE = cPyroblastDotDmgAoE
        + (cFirefallDotDmgAoE * cPyroblastCritValueBase)

    local cPyroblastDmg = (cPyroblastInstantDmg + cPyroblastDotDmg + cPyroblastInstantDmgAoE + cPyroblastDotDmgAoE) * castEfficiency

    -- Update ability data
    local abilityValue = math.floor(cPyroblastDmg)
    wan.UpdateAbilityData(wan.spellData.Pyroblast.basename, abilityValue, wan.spellData.Pyroblast.icon, wan.spellData.Pyroblast.name)
end

-- Init frame 
local framePyroblast = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nPyroblastDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Pyroblast.id, { 1 })

            nMasteryIgnite = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryIgnite.id, { 1 }) * 0.01

            local nMeteorValues = wan.GetSpellDescriptionNumbers(wan.spellData.Meteor.id, { 2, 4 })
            nMeteorDmg = nMeteorValues[1]
            nMeteorDotDmg = nMeteorValues[2]

            nCometStormDmg = wan.GetSpellDescriptionNumbers(wan.spellData.CometStorm.id, { 2 })
        end
    end)
end
framePyroblast:RegisterEvent("ADDON_LOADED")
framePyroblast:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Pyroblast.known and wan.spellData.Pyroblast.id
        wan.BlizzardEventHandler(framePyroblast, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(framePyroblast, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        nFirestarterThreshold = wan.GetTraitDescriptionNumbers(wan.traitData.Firestarter.entryid, { 1 }) * 0.01

        nImprovedScorch = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedScorch.entryid, { 2 }) * 0.01

        nInflame = wan.GetTraitDescriptionNumbers(wan.traitData.Inflame.entryid, { 1 }) * 0.01

        nMasterofFlame = wan.GetTraitDescriptionNumbers(wan.traitData.MasterofFlame.entryid, { 1 }) * 0.01

        local nWildfireValues = wan.GetTraitDescriptionNumbers(wan.traitData.Wildfire.entryid, { 1, 2 })
        nWildfireCritDmg = nWildfireValues[1]
        nWildfireCombustionCritDmg = nWildfireValues[2]

        nFiresIre = wan.GetTraitDescriptionNumbers(wan.traitData.FiresIre.entryid, { 2 }, wan.traitData.FiresIre.rank)

        local nPyromaniacValues = wan.GetTraitDescriptionNumbers(wan.traitData.Pyromaniac.entryid, { 1, 2 })
        nPyromaniacProcChance = nPyromaniacValues[1] * 0.01
        nPyromaniac = nPyromaniacValues[2] * 0.01

        local nMoltenFuryValues = wan.GetTraitDescriptionNumbers(wan.traitData.MoltenFury.entryid, { 1, 2 })
        nMoltenFuryThreshold = nMoltenFuryValues[1] * 0.01
        nMoltenFury = nMoltenFuryValues[2] * 0.01

        nSunKingsBlessing = wan.GetTraitDescriptionNumbers(wan.traitData.SunKingsBlessing.entryid, { 4 }) * 0.01

        local nIsothermicCoreValues = wan.GetTraitDescriptionNumbers(wan.traitData.IsothermicCore.entryid, { 1, 2 })
        nIsothermicCoreMeteor = nIsothermicCoreValues[1] * 0.01
        nIsothermicCoreCometStorm = nIsothermicCoreValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(framePyroblast, CheckAbilityValue, abilityActive)
    end
end)