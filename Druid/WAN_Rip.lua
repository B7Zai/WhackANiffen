local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

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
    if not wan.PlayerState.Status 
        or not wan.CheckUnitBuff(nil, wan.spellData.CatForm.formattedName) 
        or wan.auraData.player.buff_Prowl or not wan.IsSpellUsable(wan.spellData.Rip.id)
    then
        wan.UpdateAbilityData(wan.spellData.Rip.basename)
        return
    end

    local maxRangeRip = wan.spellData.PrimalWrath.known and wan.spellData.PrimalWrath.maxRange or 5

    -- Check for valid unit
    local isValidUnit = wan.ValidUnitBoolCounter(nil, maxRangeRip)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Rip.basename)
        return
    end

    if wan.traitData.MasterShapeshifter.known and currentCombo ~= nMasterShapeshifterCombo or comboPercentage < 80 then
        wan.UpdateAbilityData(wan.spellData.Rip.basename)
        return
    end

    -- Dot values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cRipInstantDmg = 0
    local cRipDotDmg = 0
    local cRipInstantDmgAoE = 0
    local cRipDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cRipDotDmgBase = 0
    local checkRipDebuff = wan.CheckUnitDebuff(nil, wan.spellData.Rip.formattedName)
    if not checkRipDebuff then
        local dotPotency = wan.CheckDotPotency()
        cRipDotDmgBase = cRipDotDmgBase + (nRipDotDmg * comboCorrection * dotPotency)
    end

    ---- FERAL TRAITS ----

    local cTearDotDmg = 0
    if wan.traitData.RipandTear.known then
        local checkTearDebuff = wan.CheckUnitDebuff(nil, "Tear")
        if not checkTearDebuff then
            local dotPotency = wan.CheckDotPotency()
             cTearDotDmg = cTearDotDmg + (nRipDotDmg * currentCombo * nRipAndTear * dotPotency)
        end
    end

    ---- RESTORATION TRAITS ----

    local cMasterShapeshifter = 1
    if wan.traitData.MasterShapeshifter.known and currentCombo == nMasterShapeshifterCombo then
        cMasterShapeshifter = cMasterShapeshifter + nMasterShapeshifter
    end


    -- Crit layer
    local cRipCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cRipInstantDmg = cRipInstantDmg

    cRipDotDmg = cRipDotDmg
        + (cRipDotDmgBase * cRipCritValue * cMasterShapeshifter)
        + (cTearDotDmg * cRipCritValue)

    cRipInstantDmgAoE = cRipInstantDmgAoE

    cRipDotDmgAoE = cRipDotDmgAoE

    local cRipDmg = cRipInstantDmg + cRipDotDmg + cRipInstantDmgAoE + cRipDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cRipDmg)
    wan.UpdateAbilityData(wan.spellData.Rip.basename, abilityValue, wan.spellData.Rip.icon, wan.spellData.Rip.name)
end

-- Init frame 
local frameRip = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

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
end
frameRip:RegisterEvent("ADDON_LOADED")
frameRip:SetScript("OnEvent", AddonLoad)

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