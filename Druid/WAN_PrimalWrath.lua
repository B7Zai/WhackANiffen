local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local framePrimalWrath = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early exit
    if addonName ~= "WhackANiffen" then return end

    -- Init data
    local abilityActive = false
    local nPrimalWrathInstantDmg, nRipDotDmg, nRipDotDuration, nRipDotDps = 0, 0, 0, 0
    local currentCombo, comboPercentage, comboCorrection, comboMax = 0, 0, 0, 0

    -- Init trait data
    local nRipAndTear = 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or not wan.auraData.player.buff_CatForm
            or comboPercentage < 80 or wan.auraData.player.buff_Prowl
            or not wan.IsSpellUsable(wan.spellData.PrimalWrath.id)
        then
            wan.UpdateAbilityData(wan.spellData.PrimalWrath.basename)
            return
        end

        -- Check for valid unit
        local _, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.PrimalWrath.maxRange)
        if countValidUnit == 0 then
            wan.UpdateAbilityData(wan.spellData.PrimalWrath.basename)
            return
        end

        -- Base values
        local checkPhysicalDRAoE = wan.CheckUnitPhysicalDamageReductionAoE(idValidUnit)
        local cPrimalWrathInstantDmg = nPrimalWrathInstantDmg * countValidUnit * comboCorrection * checkPhysicalDRAoE

        -- Dot value
        local dotPotencyAoE = wan.CheckDotPotencyAoE(wan.auraData, idValidUnit, wan.spellData.Rip.name, nil, cPrimalWrathInstantDmg)
        local ripDebuffedUnitAoE = wan.CheckForDebuffAoE(wan.auraData, idValidUnit, wan.spellData.Rip.name)
        local missingRipDebuffAoE = countValidUnit - ripDebuffedUnitAoE
        local cRipDotValue = nRipDotDmg * currentCombo * dotPotencyAoE * missingRipDebuffAoE
        local cRipDmg = (ripDebuffedUnitAoE < countValidUnit and cRipDotValue) or 0

        -- Base value
        local cPrimalWrathDmg = cPrimalWrathInstantDmg + cRipDmg

        -- Rip and Tear
        if wan.traitData.RipandTear.known then
            local tearDebuffedUnitAoE = wan.CheckForDebuffAoE(wan.auraData, idValidUnit, "Tear")
            local missingTearDebuffAoE = countValidUnit - tearDebuffedUnitAoE
            local cTearDotValue = nRipDotDmg * currentCombo * nRipAndTear * missingTearDebuffAoE * dotPotencyAoE
            local cTearDmg = (tearDebuffedUnitAoE < countValidUnit and cTearDotValue) or 0
            cPrimalWrathDmg = cPrimalWrathDmg + cTearDmg
        end

        -- Crit layer
        cPrimalWrathDmg = cPrimalWrathDmg * wan.ValueFromCritical(wan.CritChance)

        -- Update ability data
        local abilityValue = math.floor(cPrimalWrathDmg)
        wan.UpdateAbilityData(wan.spellData.PrimalWrath.basename, abilityValue, wan.spellData.PrimalWrath.icon, wan.spellData.PrimalWrath.name)
    end


    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)

        if event == "SPELLS_CHANGED" then
            comboMax = UnitPowerMax("player", 4) or 5
            currentCombo = UnitPower("player", 4) or 0
            comboPercentage = (currentCombo / comboMax) * 100
            comboCorrection = currentCombo + 1
        end

        if event == "UNIT_POWER_UPDATE" then
            local unitID, powerType = ...
            if unitID == "player" and powerType == "COMBO_POINTS" then
                currentCombo = UnitPower("player", 4) or 0
                comboPercentage = (currentCombo / comboMax) * 100
                comboCorrection = currentCombo + 1
            end
        end

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nPrimalWrathInstantDmg = wan.GetSpellDescriptionNumbers(wan.spellData.PrimalWrath.id, {3}) / 2
            nRipDotDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Rip.id, {2}) / 2
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.PrimalWrath.known and wan.spellData.PrimalWrath.id
            wan.BlizzardEventHandler(framePrimalWrath, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "UNIT_POWER_UPDATE", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(framePrimalWrath, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then
            nRipAndTear = wan.GetTraitDescriptionNumbers(wan.traitData.RipandTear.entryid, { 1 }) / 100
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(framePrimalWrath, CheckAbilityValue, abilityActive)
        end
    end)
end

framePrimalWrath:RegisterEvent("ADDON_LOADED")
framePrimalWrath:SetScript("OnEvent", AddonLoad)