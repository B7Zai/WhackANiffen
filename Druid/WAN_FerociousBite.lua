local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "DRUID" then return end

-- Init spell data
local abilityActive = false
local nFerociousBiteDmg, nFerociousBiteDmgAoE, nFerociousBiteMaxRange = 0, 0, 0
local nFerociousBiteCost, nFerociousBiteFullCost = 0, 0
local currentCombo, comboMax, comboThreshold = 0, 0, 0.8
local checkEnergy, currentEnergy = 0, 0
local sCatForm = "CatForm"
local sProwl = "Prowl"

-- Init trait data
local bCoiledtoSpring = false
local bRampantFerocity, nRampantFerocityDmg, nRampantFerocity, nRampantFerocitySoftCap, sRipDebuff = false, 0, 0, 0, "Rip"
local bSaberJaws, nSaberJaws = false, 0
local bBloodtalons, sBloodtalons = false, "Bloodtalons"
local bApexPredatorsCarving, sApexPredatorsCarving = false, "ApexPredatorsCraving"
local bRavage, sRavage = false, "Ravage"
local bDreadfulWound, nDreadfulWoundDmg = false, 0
local bBurstingGrowth, nBurstingGrowthDmg, nBurstingGrowthSoftCap, sBloodseekerVines = false, 0, 0, "BloodseekerVines"
local bMasterShapeshifter, nMasterShapeshifter, nMasterShapeshifterCombo = false, 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status 
        or not wan.CheckUnitBuff(nil, sCatForm)
        or wan.CheckUnitBuff(nil, sProwl)
        or not wan.IsSpellUsable(wan.spellData.FerociousBite.id)
    then
        wan.UpdateAbilityData(wan.spellData.FerociousBite.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(nil, nFerociousBiteMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.FerociousBite.basename)
        return
    end

    -- Combo checkers and early exit
    local checkApexPredatorsCarvingBuff = wan.CheckUnitBuff(nil, sApexPredatorsCarving)
    local comboCorrection = math.max(currentCombo, ((checkApexPredatorsCarvingBuff and comboMax) or 0)) -- check for apex predator max combo nature
    local comboPercentage = comboCorrection / comboMax
    if bMasterShapeshifter and comboCorrection ~= nMasterShapeshifterCombo or comboPercentage < comboThreshold then
        wan.UpdateAbilityData(wan.spellData.FerociousBite.basename)
        return
    end

    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cFerociousBiteInstantDmg = 0
    local cFerociousBiteDotDmg = 0
    local cFerociousBiteInstantDmgAoE = 0
    local cFerociousBiteDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    -- Energy and damage value scaling with energy
    checkEnergy =  wan.CheckUnitPower("player", 3) or 0
    currentEnergy = math.max(checkEnergy, ((checkApexPredatorsCarvingBuff and nFerociousBiteFullCost) or 0))
    local energyMod = math.min(currentEnergy, nFerociousBiteFullCost)
    local bonusDmgPerEnergy = ((nFerociousBiteFullCost / nFerociousBiteCost) * energyMod) / (nFerociousBiteFullCost * 2)

    local cRampartFerocityInstantDmgAoE = 0
    if bRampantFerocity then
        local nRampantFerocityUnitOverflow = wan.SoftCapOverflow(nRampantFerocitySoftCap, countValidUnit)
        local cRampantFecocityBonusDmg = nRampantFerocityDmg * bonusDmgPerEnergy * nRampantFerocity

        for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then
                local checkRipDebuff = wan.CheckUnitDebuff(nameplateUnitToken, sRipDebuff)

                if checkRipDebuff then
                    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                    cRampartFerocityInstantDmgAoE = cRampartFerocityInstantDmgAoE
                        + (nRampantFerocityDmg * comboCorrection * checkUnitPhysicalDR * nRampantFerocityUnitOverflow)
                        + (cRampantFecocityBonusDmg * comboCorrection * checkUnitPhysicalDR * nRampantFerocityUnitOverflow)
                end
            end
        end
    end

    local cSaberJaws = 1
    if bSaberJaws then
        cSaberJaws = cSaberJaws + nSaberJaws
    end

    if bBloodtalons then
        local checkBloodtalonsBuff = wan.CheckUnitBuff(nil, sBloodtalons)
        if not checkBloodtalonsBuff then
            wan.UpdateAbilityData(wan.spellData.FerociousBite.basename)
            return
        end
    end

    local cRavageInstantDmgAoE = 0
    local cDreadfulWoundDotDmgAoE = 0
    if bRavage then
        local checkRavageBuff = wan.CheckUnitBuff(nil, sRavage)

        if checkRavageBuff then
            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                    cRavageInstantDmgAoE = cRavageInstantDmgAoE + (nFerociousBiteDmgAoE * comboCorrection * checkUnitPhysicalDR)

                    -- Ravage aoe dmg doesnt benefit from energy bonus
                end

                if bDreadfulWound then
                    local checkUnitDotPotency = wan.CheckDotPotency(cFerociousBiteInstantDmg, nameplateUnitToken)

                    cDreadfulWoundDotDmgAoE = cDreadfulWoundDotDmgAoE + (nDreadfulWoundDmg * checkUnitDotPotency)
                end
            end
        end
    end

    local cBurstingGrowthInstantDmgAoE = 0
    if bBurstingGrowth then
        local cBurstingGrowthUnitOverflow = wan.SoftCapOverflow(nBurstingGrowthSoftCap, countValidUnit)
        local checkBloodseekerVinesDebuff = wan.CheckUnitDebuff(nil, sBloodseekerVines)

        if checkBloodseekerVinesDebuff then
            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do
                if nameplateGUID ~= targetGUID then
                    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                    cBurstingGrowthInstantDmgAoE = cBurstingGrowthInstantDmgAoE + (nBurstingGrowthDmg * checkUnitPhysicalDR * cBurstingGrowthUnitOverflow)
                end
            end
        end
    end

    -- Master Shapeshifter
    local cMasterShapeshifter = 1
    if bMasterShapeshifter and comboCorrection == nMasterShapeshifterCombo then
        cMasterShapeshifter = cMasterShapeshifter + nMasterShapeshifter
    end

    -- add physical layer
    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cFerociousBiteCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cFerociousBiteInstantDmg = cFerociousBiteInstantDmg
        + (nFerociousBiteDmg * comboCorrection * checkPhysicalDR * cFerociousBiteCritValue * cMasterShapeshifter)
        + (nFerociousBiteDmg * comboCorrection * bonusDmgPerEnergy * cSaberJaws * checkPhysicalDR * cFerociousBiteCritValue * cMasterShapeshifter)

    cFerociousBiteDotDmg = cFerociousBiteDotDmg

    cFerociousBiteInstantDmgAoE = cFerociousBiteInstantDmgAoE
        + (cRampartFerocityInstantDmgAoE * cFerociousBiteCritValue)
        + (cRavageInstantDmgAoE * cFerociousBiteCritValue)
        + (cBurstingGrowthInstantDmgAoE * cFerociousBiteCritValue)

    cFerociousBiteDotDmgAoE = cFerociousBiteDotDmgAoE
        + (cDreadfulWoundDotDmgAoE * cFerociousBiteCritValue)


    local cFerociousBiteDmg = cFerociousBiteInstantDmg + cFerociousBiteDotDmg + cFerociousBiteInstantDmgAoE + cFerociousBiteDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cFerociousBiteDmg)

    -- Set icon desaturation below full cost
    local bFerociousBiteDesat = currentEnergy < nFerociousBiteFullCost and true or false
    wan.UpdateAbilityData(wan.spellData.FerociousBite.basename, abilityValue, wan.spellData.FerociousBite.icon, wan.spellData.FerociousBite.name, bFerociousBiteDesat)
end

-- Init frame 
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)

        if event == "SPELLS_CHANGED" then
            comboMax = wan.CheckUnitMaxPower("player", 4) or 5
            currentCombo = wan.CheckUnitPower("player", 4) or 0
        end

        if event == "UNIT_POWER_UPDATE" then
            local unitID, powerType = ...
            if unitID == "player" and powerType == "COMBO_POINTS" then
                currentCombo = wan.CheckUnitPower("player", 4) or 0
            end
        end

        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local ferociousBiteValues = wan.GetSpellDescriptionNumbers(wan.spellData.FerociousBite.id, { 4, 5 })
            nFerociousBiteDmg = ferociousBiteValues[1]
            nFerociousBiteDmgAoE = ferociousBiteValues[2]

            nFerociousBiteCost = wan.GetSpellCost(wan.spellData.FerociousBite.id, 3) or 1
            if nFerociousBiteCost == 0 then nFerociousBiteCost = 1 end
            nFerociousBiteFullCost =  nFerociousBiteCost * 2

            nRampantFerocityDmg = wan.GetTraitDescriptionNumbers(wan.traitData.RampantFerocity.entryid, { 1 }, wan.traitData.RampantFerocity.rank)

            nDreadfulWoundDmg = wan.GetSpellDescriptionNumbers(wan.traitData.DreadfulWound.id, { 1 })

            local burstingGrowthValues = wan.GetTraitDescriptionNumbers(wan.traitData.BurstingGrowth.entryid, { 1, 2 })
            nBurstingGrowthDmg = burstingGrowthValues[1]
            nBurstingGrowthSoftCap = burstingGrowthValues[2]
        end
    end)
end

local frameFerociousBite = CreateFrame("Frame")
frameFerociousBite:RegisterEvent("ADDON_LOADED")
frameFerociousBite:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)
    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.FerociousBite.known and wan.spellData.FerociousBite.id
        wan.BlizzardEventHandler(frameFerociousBite, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "UNIT_POWER_UPDATE", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameFerociousBite, CheckAbilityValue, abilityActive)

        sCatForm = wan.spellData.CatForm.formattedName
        sProwl = wan.spellData.Prowl.formattedName
        sRipDebuff = wan.spellData.Rip.formattedName
        nFerociousBiteMaxRange = wan.spellData.PrimalWrath.known and wan.spellData.PrimalWrath.maxRange or 6
    end

    if event == "TRAIT_DATA_READY" then

        bCoiledtoSpring = wan.traitData.CoiledtoSpring.known
        comboThreshold = bCoiledtoSpring and 1 or 0.8

        bRampantFerocity = wan.traitData.RampantFerocity.known
        local nRampantFerocityValues = wan.GetTraitDescriptionNumbers(wan.traitData.RampantFerocity.entryid, { 2, 3 }, wan.traitData.RampantFerocity.rank)
        nRampantFerocity = nRampantFerocityValues[1] * 0.01
        nRampantFerocitySoftCap = nRampantFerocityValues[2]

        bSaberJaws = wan.traitData.SaberJaws.known
        nSaberJaws = wan.GetTraitDescriptionNumbers(wan.traitData.SaberJaws.entryid, { 1 }, wan.traitData.SaberJaws.rank) * 0.01

        bBloodtalons = wan.traitData.Bloodtalons.known
        sBloodtalons = wan.traitData.Bloodtalons.traitkey

        bApexPredatorsCarving = wan.traitData.ApexPredatorsCraving.known
        sApexPredatorsCarving = wan.traitData.ApexPredatorsCraving.traitkey

        bRavage = wan.traitData.Ravage.known
        sRavage = wan.traitData.Ravage.traitkey

        bDreadfulWound = wan.traitData.DreadfulWound.known

        bBurstingGrowth = wan.traitData.BurstingGrowth.known

        bMasterShapeshifter = wan.traitData.MasterShapeshifter.known
        local nMasterShapeshifterValues = wan.GetTraitDescriptionNumbers(wan.traitData.MasterShapeshifter.entryid, { 9, 11 }, wan.traitData.MasterShapeshifter.rank)
        nMasterShapeshifter = nMasterShapeshifterValues[1] * 0.01
        nMasterShapeshifterCombo = nMasterShapeshifterValues[2]
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameFerociousBite, CheckAbilityValue, abilityActive)
    end
end)
