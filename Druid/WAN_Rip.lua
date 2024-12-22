local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init frame 
local frameRip = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Init spell data
    local abilityActive = false
    local nRipDotDmg, nRipDotDuration, nRipDotDps = 0, 0, 0
    local currentCombo, comboPercentage, comboCorrection, comboMax = 0, 0, 0, 0

    --Init trait data
    local nRipAndTear = 0
    local nMasterShapeshifter, nMasterShapeshifterCombo = 0, 0

    -- Ability value calculation
    local function CheckAbilityValue()
        -- Early exits
        if not wan.PlayerState.Status or not wan.auraData.player.buff_CatForm 
            or wan.auraData.player.buff_Prowl or not wan.IsSpellUsable(wan.spellData.Rip.id)
        then
            wan.UpdateAbilityData(wan.spellData.Rip.basename)
            return
        end

        local maxRange = wan.spellData.PrimalWrath.maxRange or 5

        -- Check for valid unit
        local isValidUnit = wan.ValidUnitBoolCounter(nil, maxRange)
        if not isValidUnit then
            wan.UpdateAbilityData(wan.spellData.Rip.basename)
            return
        end

        if wan.traitData.MasterShapeshifter.known and currentCombo ~= nMasterShapeshifterCombo or comboPercentage < 80 then
            wan.UpdateAbilityData(wan.spellData.Rip.basename)
            return
        end

        -- Dot values
        local dotPotency = wan.CheckDotPotency()
        local cRipDotDmg = (not wan.auraData[wan.TargetUnitID].debuff_Rip and (nRipDotDmg * comboCorrection * dotPotency)) or 0

        local cRipDmg = cRipDotDmg

        -- Master Shapeshifter
        if wan.traitData.MasterShapeshifter.known and currentCombo == nMasterShapeshifterCombo then
            local cMasterShapeshifter = cRipDmg * nMasterShapeshifter
            cRipDmg = cRipDmg + cMasterShapeshifter
        end

        -- Rip and Tear
        if wan.traitData.RipandTear.known then
            local checkTearDebuff = wan.auraData[wan.TargetUnitID].debuff_Tear
            local cTearDotDmg = cRipDmg * currentCombo * nRipAndTear * dotPotency
            local cTearDmg = (not checkTearDebuff and (cTearDotDmg)) or 0
            cRipDmg = cRipDmg + cTearDmg
        end

        -- Crit layer
        cRipDmg = cRipDmg * wan.ValueFromCritical(wan.CritChance)

        -- Update ability data
        local abilityValue = math.floor(cRipDmg)
        wan.UpdateAbilityData(wan.spellData.Rip.basename, abilityValue, wan.spellData.Rip.icon, wan.spellData.Rip.name)
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

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"then
            local ripValues = wan.GetSpellDescriptionNumbers(wan.spellData.Rip.id, { 2 })
            nRipDotDmg = ripValues / 2
        end
    end)

    -- Set update rate based on settings
    wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
        if event == "SPELL_DATA_READY" then
            abilityActive = wan.spellData.Rip.known and wan.spellData.Rip.id
            wan.BlizzardEventHandler(frameRip, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "UNIT_POWER_UPDATE", "PLAYER_EQUIPMENT_CHANGED")
            wan.SetUpdateRate(frameRip, CheckAbilityValue, abilityActive)
        end

        if event == "TRAIT_DATA_READY" then
            nRipAndTear = wan.GetTraitDescriptionNumbers(wan.traitData.RipandTear.entryid, { 1 }) / 100
            
            local nMasterShapeshifterValues = wan.GetTraitDescriptionNumbers(wan.traitData.MasterShapeshifter.entryid, { 9, 11 })
            nMasterShapeshifter = nMasterShapeshifterValues[1] * 0.01
            nMasterShapeshifterCombo = nMasterShapeshifterValues[2]
        end

        if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
            wan.SetUpdateRate(frameRip, CheckAbilityValue, abilityActive)
        end
    end)
end

frameRip:RegisterEvent("ADDON_LOADED")
frameRip:SetScript("OnEvent", AddonLoad)