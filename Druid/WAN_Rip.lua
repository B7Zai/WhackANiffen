local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local abilityActive = false
local sRipDebuff, nRipDotDmg, nRipMaxRange = "Rip", 0, 0
local currentCombo, comboPercentage, comboCorrection, comboMax, comboThreshold = 0, 0, 0, 0, 0
local sCatForm = "CatForm"
local sProwl = "Prowl"

--Init trait data
local bCoiledtoSpring = false
local bRipandTear, nRipandTear = false, 0
local bBloodtalons, sBloodtalons = false, "Bloodtalons"
local bMasterShapeshifter, nMasterShapeshifter, nMasterShapeshifterCombo = false, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or not wan.CheckUnitBuff(nil, sCatForm)
        or wan.CheckUnitBuff(nil, sProwl)
        or not wan.IsSpellUsable(wan.spellData.Rip.id)
    then
        wan.UpdateAbilityData(wan.spellData.Rip.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit = wan.ValidUnitBoolCounter(nil, nRipMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Rip.basename)
        return
    end

    if bMasterShapeshifter and currentCombo ~= nMasterShapeshifterCombo or comboPercentage < comboThreshold then
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
    local checkRipDebuff = wan.CheckUnitDebuff(nil, sRipDebuff)
    if not checkRipDebuff then
        local dotPotency = wan.CheckDotPotency()
        cRipDotDmgBase = cRipDotDmgBase + (nRipDotDmg * comboCorrection * dotPotency)
    end

    ---- FERAL TRAITS ----

    local cTearDotDmg = 0
    if bRipandTear then
        local checkTearDebuff = wan.CheckUnitDebuff(nil, "Tear")

        if not checkTearDebuff then
            local checkDotPotency = wan.CheckDotPotency()

            cTearDotDmg = cTearDotDmg + (nRipDotDmg * currentCombo * nRipandTear * checkDotPotency)
        end
    end

    if bBloodtalons then
        local checkBloodtalonsBuff = wan.CheckUnitBuff(nil, sBloodtalons)
        if not checkBloodtalonsBuff then
            wan.UpdateAbilityData(wan.spellData.Rip.basename)
            return
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

local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)

        if event == "SPELLS_CHANGED" then
            comboMax = wan.CheckUnitMaxPower("player", 4) or 5
            currentCombo = wan.CheckUnitPower("player", 4) or 0
            comboPercentage = currentCombo / comboMax
            comboCorrection = currentCombo + 1
        end

        if event == "UNIT_POWER_UPDATE" then
            local unitID, powerType = ...
            if unitID == "player" and powerType == "COMBO_POINTS" then
                currentCombo = wan.CheckUnitPower("player", 4) or 0
                comboPercentage = currentCombo / comboMax
                comboCorrection = currentCombo + 1
            end
        end

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED"then
            local ripValues = wan.GetSpellDescriptionNumbers(wan.spellData.Rip.id, { 2 })
            nRipDotDmg = ripValues / 2
        end
    end)
end

local frameRip = CreateFrame("Frame")
frameRip:RegisterEvent("ADDON_LOADED")
frameRip:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Rip.known and wan.spellData.Rip.id
        wan.BlizzardEventHandler(frameRip, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "UNIT_POWER_UPDATE", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameRip, CheckAbilityValue, abilityActive)

        sRipDebuff = wan.spellData.Rip.formattedName
        nRipMaxRange = wan.spellData.PrimalWrath.known and wan.spellData.PrimalWrath.maxRange or 6
        sCatForm = wan.spellData.CatForm.formattedName
        sProwl = wan.spellData.Prowl.formattedName
    end

    if event == "TRAIT_DATA_READY" then

        bCoiledtoSpring = wan.traitData.CoiledtoSpring.known
        comboThreshold = bCoiledtoSpring and 1 or 0.8

        bRipandTear = wan.traitData.RipandTear.known
        nRipandTear = wan.GetTraitDescriptionNumbers(wan.traitData.RipandTear.entryid, { 1 }) * 0.01

        bBloodtalons = wan.traitData.Bloodtalons.known
        sBloodtalons = wan.traitData.Bloodtalons.traitkey

        bMasterShapeshifter = wan.traitData.MasterShapeshifter.known
        local nMasterShapeshifterValues = wan.GetTraitDescriptionNumbers(wan.traitData.MasterShapeshifter.entryid, { 9, 11 })
        nMasterShapeshifter = nMasterShapeshifterValues[1] * 0.01
        nMasterShapeshifterCombo = nMasterShapeshifterValues[2]
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameRip, CheckAbilityValue, abilityActive)
    end
end)