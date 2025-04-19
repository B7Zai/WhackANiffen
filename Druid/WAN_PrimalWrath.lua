local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init data
local playerGUID = wan.PlayerState.GUID
local playerUnitToken = "player"
local abilityActive = false
local nPrimalWrathInstantDmg, nRipDotDmg, sRipDebuff = 0, 0, "Rip"
local currentCombo, comboPercentage, comboCorrection, comboMax, comboThreshold = 0, 0, 0, 0, 0.8
local sCatForm = "CatForm"
local sProwl = "Prowl"

-- Init trait data
local bCoiledtoSpring = false
local bBloodtalons, sBloodtalons = false, "Bloodtalons"
local bRipandTear, nRipandTear, sTearDebuff = false, 0, "Tear"

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status
        or comboPercentage < comboThreshold
        or not wan.CheckUnitBuff(nil, sCatForm)
        or wan.CheckUnitBuff(nil, sProwl)
        or not wan.IsSpellUsable(wan.spellData.PrimalWrath.id)
    then
        wan.UpdateAbilityData(wan.spellData.PrimalWrath.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, wan.spellData.PrimalWrath.maxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.PrimalWrath.basename)
        return
    end

    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cPrimalWrathInstantDmg = 0
    local cPrimalWrathDotDmg = 0
    local cPrimalWrathInstantDmgAoE = 0
    local cPrimalWrathDotDmgAoE = 0

    local cPrimalWrathInstantDmgBaseAoE = 0
    local cPrimalWrathDotDmgBaseAoE = 0
    for nameplateUnitToken, _ in pairs(idValidUnit) do
        local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)
        cPrimalWrathInstantDmgBaseAoE = cPrimalWrathInstantDmgBaseAoE + (nPrimalWrathInstantDmg * comboCorrection * checkPhysicalDR)

        local checkRipDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sRipDebuff)
        if not checkRipDebuff then
            local checkUnitDotPotency = wan.CheckDotPotency(nPrimalWrathInstantDmg, nameplateUnitToken)
            local cRipDotDmg = nRipDotDmg * comboCorrection

            cPrimalWrathDotDmgBaseAoE =  cPrimalWrathDotDmgBaseAoE + (cRipDotDmg * checkUnitDotPotency)
        end
    end

    ---- FERAL TRAITS ----

    local cTearDotDmgAoE = 0
    if bRipandTear then
        local cTearDotDmg = nRipDotDmg * comboCorrection * nRipandTear
        for nameplateUnitToken, _ in pairs(idValidUnit) do

            local checkTearDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sTearDebuff)
            if not checkTearDebuff then
                local checkUnitDotPotency = wan.CheckDotPotency(nPrimalWrathInstantDmg, nameplateUnitToken)

                cTearDotDmgAoE =  cTearDotDmgAoE + (cTearDotDmg * checkUnitDotPotency)
            end
        end
    end

    if bBloodtalons then
        local checkBloodtalonsBuff = wan.CheckUnitBuff(nil, sBloodtalons)
        if not checkBloodtalonsBuff then
            wan.UpdateAbilityData(wan.spellData.PrimalWrath.basename)
            return
        end
    end

    local cPrimalWrathCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cPrimalWrathInstantDmg = cPrimalWrathInstantDmg

    cPrimalWrathDotDmg = cPrimalWrathDotDmg

    cPrimalWrathInstantDmgAoE = cPrimalWrathInstantDmgAoE
        + (cPrimalWrathInstantDmgBaseAoE * cPrimalWrathCritValue)

    cPrimalWrathDotDmgAoE = cPrimalWrathDotDmgAoE
        + (cPrimalWrathDotDmgBaseAoE * cPrimalWrathCritValue)
        + (cTearDotDmgAoE * cPrimalWrathCritValue)

    local cPrimalWrathDmg = cPrimalWrathInstantDmg + cPrimalWrathDotDmg + cPrimalWrathInstantDmgAoE + cPrimalWrathDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cPrimalWrathDmg)
    wan.UpdateAbilityData(wan.spellData.PrimalWrath.basename, abilityValue, wan.spellData.PrimalWrath.icon, wan.spellData.PrimalWrath.name)
end

-- Init frame
local framePrimalWrath = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early exit
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

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nPrimalWrathInstantDmg = wan.GetSpellDescriptionNumbers(wan.spellData.PrimalWrath.id, { 3 }) * 0.5
            
            nRipDotDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Rip.id, { 2 }) * 0.25
        end
    end)
end
framePrimalWrath:RegisterEvent("ADDON_LOADED")
framePrimalWrath:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.PrimalWrath.known and wan.spellData.PrimalWrath.id
        wan.BlizzardEventHandler(framePrimalWrath, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "UNIT_POWER_UPDATE", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(framePrimalWrath, CheckAbilityValue, abilityActive)

        sRipDebuff = wan.spellData.Rip.formattedName
        sCatForm = wan.spellData.CatForm.formattedName
        sProwl = wan.spellData.Prowl.formattedName
    end

    if event == "TRAIT_DATA_READY" then

        bCoiledtoSpring = wan.traitData.CoiledtoSpring.known
        comboThreshold = bCoiledtoSpring and 1 or 0.8

        bBloodtalons = wan.traitData.Bloodtalons.known
        sBloodtalons = wan.traitData.Bloodtalons.traitkey

        bRipandTear = wan.traitData.RipandTear.known
        nRipandTear = wan.GetTraitDescriptionNumbers(wan.traitData.RipandTear.entryid, { 1 }, wan.traitData.RipandTear.rank) * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(framePrimalWrath, CheckAbilityValue, abilityActive)
    end
end)
