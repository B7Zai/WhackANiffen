local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nFireBlastDmg = 0

-- Init trait data
local nMasteryIgnite = 0
local nOverflowingEnergy = 0
local nLitFuseDmg, nLitFuseUnitCap = 0, 0
local nImprovedScorch = 0
local nConvection = 0
local nMasterofFlame = 0
local nWildfireCritDmg, nWildfireCombustionCritDmg = 0, 0
local nMarkoftheFirelord = 0
local nFiresIre = 0
local nMoltenFuryThreshold, nMoltenFury = 0, 0
local nBlastZoneUnit, nBlastZoneUnitCap = 0, 0
local nExcessFireDmg, nExcessFireSoftCap = 0, 0
local nGloriousIncandescenceUnitCap, nGloriousIncandescenceMeteoriteCount, nFrostboltDmg = 0, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.FireBlast.id)
    then
        wan.UpdateAbilityData(wan.spellData.FireBlast.basename)
        return
    end

    if wan.spellData.HotStreak.known and 
        (not wan.CheckUnitBuff("player", "HeatingUp") and not wan.CheckUnitBuff(nil, wan.traitData.LitFuse.traitkey)) then
        wan.UpdateAbilityData(wan.spellData.FireBlast.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.FireBlast.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.FireBlast.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critChanceModBase = 0
    local critDamageMod = 0
    local critDamageModBase = 0

    local cFireBlastInstantDmg = 0
    local cFireBlastDotDmg = 0
    local cFireBlastInstantDmgAoE = 0
    local cFireBlastDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- CLASS TRAITS ----

    local cMasteryIgnite = 0
    if wan.spellData.MasteryIgnite.known then
        local dotPotency = wan.CheckDotPotency(nFireBlastDmg, targetUnitToken)

        cMasteryIgnite = cMasteryIgnite + (nMasteryIgnite * dotPotency)
    end

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
        critDamageModBase = critDamageModBase + nOverflowingEnergy
    end

    ---- FIRE TRAITS ----

    if wan.traitData.FireBlast.known then
        critChanceMod = critChanceMod + 100
    end

    local cLitFuseInstantDmg = 0
    local cLitFuseInstantDmgAoE = 0
    local cMarkoftheFirelord = 1
    if wan.traitData.LitFuse.known then
        local checkLitFuseBuff = wan.CheckUnitBuff(nil, wan.traitData.LitFuse.traitkey)

        if checkLitFuseBuff then
            local cLitFuseUnitCap = wan.traitData.BlastZone.known and nBlastZoneUnitCap or nLitFuseUnitCap
            local cLitFuseUnit = math.max(countValidUnit - 1, 0)
            local countLitFuseUnit = math.min(cLitFuseUnit, cLitFuseUnitCap)
            local cLitFuseUnitOverflow = wan.AdjustSoftCapUnitOverflow(1, countValidUnit)

            local cConvection = 1
            if wan.traitData.Convection.known then
                if countValidUnit == 1 then
                    cConvection = cConvection + nConvection
                end
            end

            if wan.traitData.MarkoftheFirelord.known then
                cMarkoftheFirelord = cMarkoftheFirelord + nMarkoftheFirelord
            end

            local cBlastZone = 1
            local cBlastZoneAoE = 0
            if wan.traitData.BlastZone.known then
                cBlastZone = math.min(countValidUnit, nBlastZoneUnit)
                cBlastZoneAoE = cBlastZone
            end

            cLitFuseInstantDmg = cLitFuseInstantDmg + ((nLitFuseDmg * cConvection * cBlastZone) + (nLitFuseDmg * countLitFuseUnit))
            cLitFuseInstantDmgAoE = cLitFuseInstantDmgAoE + (nLitFuseDmg * countLitFuseUnit * (cLitFuseUnitOverflow + cBlastZoneAoE))
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
    if wan.traitData.MoltenFury.known then
        local checkPercentageHealth = targetGUID and UnitPercentHealthFromGUID(targetGUID) or 1
        if checkPercentageHealth < nMoltenFuryThreshold then
            cMoltenFury = cMoltenFury + nMoltenFury
        end
    end

    ---- FROSTFIRE TRAITS ----

    local cExcessFireInstantDmgAoE = 0
    if wan.traitData.ExcessFire.known then
        local checkExcessFireBuff = wan.CheckUnitBuff(nil, wan.traitData.ExcessFire.traitkey)
        if checkExcessFireBuff then
            local cExcessFireUnitOverflow = wan.AdjustSoftCapUnitOverflow(nExcessFireSoftCap, countValidUnit)
            cExcessFireInstantDmgAoE = cExcessFireInstantDmgAoE + (nExcessFireDmg * cExcessFireUnitOverflow)
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

    local cFireBlastCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    local cFireBlastCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cFireBlastInstantDmg = cFireBlastInstantDmg
        + (nFireBlastDmg * cImprovedScorch * cMoltenFury * cFireBlastCritValue)
        + (cLitFuseInstantDmg * cImprovedScorch * cMoltenFury * cFireBlastCritValueBase)
        + (cGloriousIncandescenceInstantDmg * cImprovedScorch * cMoltenFury * cFireBlastCritValueBase)

    cFireBlastDotDmg = cFireBlastDotDmg 
        + (nFireBlastDmg * cMasteryIgnite * cImprovedScorch * cMasterofFlame * cMoltenFury * cFireBlastCritValueBase) -- Ignite
        + (cLitFuseInstantDmg * cImprovedScorch * cMoltenFury * cMasteryIgnite * cFireBlastCritValueBase) -- Ignite
        + (cGloriousIncandescenceInstantDmg * cMasteryIgnite * cImprovedScorch * cMoltenFury * cFireBlastCritValueBase) -- Ignite

    cFireBlastInstantDmgAoE = cFireBlastInstantDmgAoE
        + (cLitFuseInstantDmgAoE * cFireBlastCritValueBase)
        + (cExcessFireInstantDmgAoE * cFireBlastCritValueBase)

    cFireBlastDotDmgAoE = cFireBlastDotDmgAoE
        + (cLitFuseInstantDmgAoE * cMasteryIgnite * cMarkoftheFirelord  * cMasterofFlame * cFireBlastCritValueBase)

    local cFireBlastDmg = cFireBlastInstantDmg + cFireBlastDotDmg + cFireBlastInstantDmgAoE + cFireBlastDotDmgAoE

    if wan.spellData.HotStreak.known and wan.CheckUnitBuff("player", "HeatingUp") then
        cFireBlastDmg = cFireBlastDmg * countValidUnit
    end

    -- Update ability data
    local abilityValue = math.floor(cFireBlastDmg)
    wan.UpdateAbilityData(wan.spellData.FireBlast.basename, abilityValue, wan.spellData.FireBlast.icon, wan.spellData.FireBlast.name)
end

-- Init frame 
local frameFireBlast = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nFireBlastDmg = wan.GetSpellDescriptionNumbers(wan.spellData.FireBlast.id, { 1 })

            nMasteryIgnite = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryIgnite.id, { 1 }) * 0.01

            local nLitFuseValues = wan.GetTraitDescriptionNumbers(wan.traitData.LitFuse.entryid, { 6, 8 })
            nLitFuseDmg = nLitFuseValues[1]
            nLitFuseUnitCap = nLitFuseValues[2]

            local nExcessFireValues = wan.GetTraitDescriptionNumbers(wan.traitData.ExcessFire.entryid, { 1, 2 })
            nExcessFireDmg = nExcessFireValues[1]
            nExcessFireSoftCap = nExcessFireValues[2]

            nFrostboltDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Frostbolt.id, { 1 })
        end
    end)
end
frameFireBlast:RegisterEvent("ADDON_LOADED")
frameFireBlast:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.FireBlast.known and wan.spellData.FireBlast.id
        wan.BlizzardEventHandler(frameFireBlast, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFireBlast, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        nImprovedScorch = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedScorch.entryid, { 2 }) * 0.01

        nConvection = wan.GetTraitDescriptionNumbers(wan.traitData.Convection.entryid, { 1 }) * 0.01

        nMasterofFlame = wan.GetTraitDescriptionNumbers(wan.traitData.MasterofFlame.entryid, { 1 }) * 0.01

        local nWildfireValues = wan.GetTraitDescriptionNumbers(wan.traitData.Wildfire.entryid, { 1, 2 })
        nWildfireCritDmg = nWildfireValues[1]
        nWildfireCombustionCritDmg = nWildfireValues[2]

        nMarkoftheFirelord = wan.GetTraitDescriptionNumbers(wan.traitData.MarkoftheFirelord.entryid, { 1 }) * 0.01

        nFiresIre = wan.GetTraitDescriptionNumbers(wan.traitData.FiresIre.entryid, { 2 }, wan.traitData.FiresIre.rank)

        local nMoltenFuryValues = wan.GetTraitDescriptionNumbers(wan.traitData.MoltenFury.entryid, { 1, 2 })
        nMoltenFuryThreshold = nMoltenFuryValues[1] * 0.01
        nMoltenFury = nMoltenFuryValues[2] * 0.01

        local nBlastZoneValues = wan.GetTraitDescriptionNumbers(wan.traitData.BlastZone.entryid, { 1, 2 })
        nBlastZoneUnit = nBlastZoneValues[1]
        nBlastZoneUnitCap = nBlastZoneValues[2]
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFireBlast, CheckAbilityValue, abilityActive)
    end
end)