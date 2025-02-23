local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "MAGE" then return end

-- Init spell data
local abilityActive = false
local nScorchDmg, nScorchThreshold = 0, 0

-- Init trait data
local nMasteryIgnite = 0
local nOverflowingEnergy = 0
local nImprovedScorch = 0
local nScald, nScaldThreshold = 0, 0
local nMasterofFlame = 0
local nWildfireCritDmg, nWildfireCombustionCritDmg = 0, 0
local nFiresIre = 0
local nMoltenFuryThreshold, nMoltenFury = 0, 0
local nSunfuryExecutionThreshold = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or not wan.IsSpellUsable(wan.spellData.Scorch.id)
    then
        wan.UpdateAbilityData(wan.spellData.Scorch.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Scorch.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Scorch.basename)
        return
    end

    local canMovecast = true
    local castEfficiency = wan.CheckCastEfficiency(wan.spellData.Scorch.id, wan.spellData.Scorch.castTime, canMovecast)
    if castEfficiency == 0 then
        wan.UpdateAbilityData(wan.spellData.Scorch.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0

    local cScorchInstantDmg = 0
    local cScorchDotDmg = 0
    local cScorchInstantDmgAoE = 0
    local cScorchDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local checkPercentageHealth = targetGUID and UnitPercentHealthFromGUID(targetGUID) or 1
    if checkPercentageHealth < nScorchThreshold then
        critChanceMod = critChanceMod + 100
    end

    if wan.traitData.Combustion.known then
        local checkCombustionBuff = wan.CheckUnitBuff(nil, wan.spellData.Combustion.formattedName)
        if checkCombustionBuff then
            critChanceMod = critChanceMod + 100
        end
    end

    ---- CLASS TRAITS ----

    local cMasteryIgnite = 0
    if wan.spellData.MasteryIgnite.known then
        local dotPotency = wan.CheckDotPotency(nScorchDmg, targetUnitToken)

        cMasteryIgnite = cMasteryIgnite + (nMasteryIgnite * dotPotency)
    end

    if wan.traitData.OverflowingEnergy.known then
        critDamageMod = critDamageMod + nOverflowingEnergy
    end

    ---- FIRE TRAITS ----

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

    local cScald = 1
    if wan.traitData.Scald.known then
        local checkHeatShimmerBuff = wan.traitData.HeatShimmer.known and wan.CheckUnitBuff(nil, wan.traitData.HeatShimmer.traitkey)

        if checkPercentageHealth < nScaldThreshold or checkHeatShimmerBuff then
            cScald = cScald + nScald
        end
    end

    if wan.traitData.HeatShimmer.known then
        local checkHeatShimmerBuff = wan.CheckUnitBuff(nil, wan.traitData.HeatShimmer.traitkey)
        if checkHeatShimmerBuff then
            critChanceMod = critChanceMod + 100
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
        local checkPercentageHealth = targetGUID and UnitPercentHealthFromGUID(targetGUID) or 1
        if checkPercentageHealth < nMoltenFuryThreshold then
            cMoltenFury = cMoltenFury + nMoltenFury
        end
    end
    
    local cScorchCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cScorchInstantDmg = cScorchInstantDmg
        + (nScorchDmg * cScald * cImprovedScorch * cMoltenFury * cScorchCritValue)

    cScorchDotDmg = cScorchDotDmg
        + (nScorchDmg * cScald * cImprovedScorch * cMasteryIgnite * cMasterofFlame * cMoltenFury * cScorchCritValue)

    cScorchInstantDmgAoE = cScorchInstantDmgAoE

    cScorchDotDmgAoE = cScorchDotDmgAoE

    local cScorchDmg = (cScorchInstantDmg + cScorchDotDmg + cScorchInstantDmgAoE + cScorchDotDmgAoE) * castEfficiency

    -- Update ability data
    local abilityValue = math.floor(cScorchDmg)
    wan.UpdateAbilityData(wan.spellData.Scorch.basename, abilityValue, wan.spellData.Scorch.icon, wan.spellData.Scorch.name)
end

-- Init frame 
local frameScorch = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nScorchValues = wan.GetSpellDescriptionNumbers(wan.spellData.Scorch.id, { 1, 4 })
            nScorchDmg = nScorchValues[1]
            nScorchThreshold = (wan.traitData.SunfuryExecution.known and nSunfuryExecutionThreshold)
                or (wan.traitData.Scald.known and nScaldThreshold)
                or (nScorchValues[2] * 0.01)

            nMasteryIgnite = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryIgnite.id, { 1 }) * 0.01
        end
    end)
end
frameScorch:RegisterEvent("ADDON_LOADED")
frameScorch:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Scorch.known and wan.spellData.Scorch.id
        wan.BlizzardEventHandler(frameScorch, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameScorch, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then 
        nOverflowingEnergy = wan.GetTraitDescriptionNumbers(wan.traitData.OverflowingEnergy.entryid, { 1 })

        nImprovedScorch = wan.GetTraitDescriptionNumbers(wan.traitData.ImprovedScorch.entryid, { 2 }) * 0.01

        local nScaldValues = wan.GetTraitDescriptionNumbers(wan.traitData.Scald.entryid, { 1, 2 })
        nScald = nScaldValues[1] * 0.01
        nScaldThreshold = nScaldValues[2] * 0.01

        nMasterofFlame = wan.GetTraitDescriptionNumbers(wan.traitData.MasterofFlame.entryid, { 1 }) * 0.01

        local nWildfireValues = wan.GetTraitDescriptionNumbers(wan.traitData.Wildfire.entryid, { 1, 2 })
        nWildfireCritDmg = nWildfireValues[1]
        nWildfireCombustionCritDmg = nWildfireValues[2]

        nFiresIre = wan.GetTraitDescriptionNumbers(wan.traitData.FiresIre.entryid, { 2 }, wan.traitData.FiresIre.rank)

        local nMoltenFuryValues = wan.GetTraitDescriptionNumbers(wan.traitData.MoltenFury.entryid, { 1, 2 })
        nMoltenFuryThreshold = nMoltenFuryValues[1] * 0.01
        nMoltenFury = nMoltenFuryValues[2] * 0.01

        nSunfuryExecutionThreshold = wan.GetTraitDescriptionNumbers(wan.traitData.SunfuryExecution.entryid, { 1 }) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameScorch, CheckAbilityValue, abilityActive)
    end
end)