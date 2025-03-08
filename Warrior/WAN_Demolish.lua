local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nDemolishDmg, nDemolishDmgAoE, nDemolishSoftCap = 0, 0, 0

-- Init trait data
local nMasteryDeepWounds = 0
local nSweepingStrikesUnitCap, nSweepingStrikesMaxRange, nSweepingStrikes = 0, 0, 0
local nColossusSmash = 0
local nImpale = 0
local nMartialExpertCritDamage = 0
local nRecklessnessCritChance = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Demolish.id) then
        wan.UpdateAbilityData(wan.spellData.Demolish.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Demolish.id, nSweepingStrikesMaxRange)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Demolish.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    --local critChanceModBase = 0
    --local critDamageModBase = 0

    local cDemolishInstantDmg = 0
    local cDemolishDotDmg = 0
    local cDemolishInstantDmgAoE = 0
    local cDemolishDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local cDemolishInstantDmgBaseAoE = 0
    local cDemolishUnitOverflow = wan.SoftCapOverflow(nDemolishSoftCap, countValidUnit)
    for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

        if nameplateGUID ~= targetGUID then
            local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)
            local checkPotency = wan.CheckDotPotency()

            cDemolishInstantDmgBaseAoE = cDemolishInstantDmgBaseAoE + (nDemolishDmgAoE * checkUnitPhysicalDR * checkPotency * cDemolishUnitOverflow)
        end
    end

    ---- WARRIOR TRAITS ----

    if wan.traitData.BerserkersTorment.known or wan.traitData.WarlordsTorment.known or wan.traitData.Recklessness.known then
        local checkRecklessnessBuff = wan.CheckUnitBuff(nil, wan.spellData.Recklessness.formattedName)
        if checkRecklessnessBuff then
            critChanceMod = critChanceMod + nRecklessnessCritChance
        end
    end

    ---- ARMS TRAITS ----

    local cSweepingStrikesInstantDmgAoE = 0
    local checkSweepingStrikesBuff = nil
    if wan.spellData.SweepingStrikes.known then
        checkSweepingStrikesBuff = wan.CheckUnitBuff(nil, wan.spellData.SweepingStrikes.formattedName)
        local countSweepingStrikesUnit = 0

        if checkSweepingStrikesBuff then
            for nameplateUnitToken, nameplateGUID in pairs(idValidUnit) do

                if nameplateGUID ~= targetGUID then
                    local checkUnitPhysicalDR = wan.CheckUnitPhysicalDamageReduction(nameplateUnitToken)

                    cSweepingStrikesInstantDmgAoE = cSweepingStrikesInstantDmgAoE + ((nDemolishDmg - nDemolishDmgAoE) * nSweepingStrikes * checkUnitPhysicalDR)
                    countSweepingStrikesUnit = countSweepingStrikesUnit + 1

                    if countSweepingStrikesUnit >= nSweepingStrikesUnitCap then break end
                end
            end
        end
    end

    local cMasteryDeepWounds = 1
    if wan.spellData.MasteryDeepWounds.known then

        for nameplateUnitToken, _ in pairs(idValidUnit) do

            local checkUnitMasteryDeepWoundsDebuff = wan.CheckUnitDebuff(nameplateUnitToken, "DeepWounds")

            if checkUnitMasteryDeepWoundsDebuff then
                cMasteryDeepWounds = cMasteryDeepWounds + (nMasteryDeepWounds / countValidUnit)
            end
        end
    end

    local cColossusSmash = 1
    if wan.traitData.ColossusSmash.known then
        local formattedDebuffName = wan.traitData.ColossusSmash.traitkey

        for nameplateUnitToken, _ in pairs(idValidUnit) do
            local checkUnitColossusSmashDebuff = wan.CheckUnitDebuff(nameplateUnitToken, formattedDebuffName)

            if checkUnitColossusSmashDebuff then
                cColossusSmash = cColossusSmash + (nColossusSmash / countValidUnit)
            end
        end
    end

    if wan.traitData.Impale.known then
        critDamageMod = critDamageMod + nImpale
    end

    ---- COLOSSUS TRAITS ----

    if wan.traitData.MartialExpert.known then
        critDamageMod = critDamageMod + nMartialExpertCritDamage
    end

    local checkPhysicalDR = wan.CheckUnitPhysicalDamageReduction()
    local cDemolishCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    --local cDemolishCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cDemolishInstantDmg = cDemolishInstantDmg
        + (nDemolishDmg * checkPhysicalDR * cDemolishCritValue * cMasteryDeepWounds * cColossusSmash)

    cDemolishDotDmg = cDemolishDotDmg

    cDemolishInstantDmgAoE = cDemolishInstantDmgAoE
        + (cDemolishInstantDmgBaseAoE * cDemolishCritValue * cMasteryDeepWounds * cColossusSmash)
        + (cSweepingStrikesInstantDmgAoE * cDemolishCritValue * cMasteryDeepWounds * cColossusSmash)

    cDemolishDotDmgAoE = cDemolishDotDmgAoE

    local cDemolishDmg = cDemolishInstantDmg + cDemolishDotDmg + cDemolishInstantDmgAoE + cDemolishDotDmgAoE

    local cdPotency = wan.CheckOffensiveCooldownPotency(cDemolishDmg, isValidUnit, idValidUnit)

    -- Update ability data
    local abilityValue = cdPotency and math.floor(cDemolishDmg) or 0
    wan.UpdateAbilityData(wan.spellData.Demolish.basename, abilityValue, wan.spellData.Demolish.icon, wan.spellData.Demolish.name)
end

-- Init frame 
local frameDemolish = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nDemolishValues = wan.GetSpellDescriptionNumbers(wan.spellData.Demolish.id, { 1, 2, 4 })
            nDemolishDmg = nDemolishValues[1]
            nDemolishDmgAoE = nDemolishValues[2]
            nDemolishSoftCap = nDemolishValues[3]

            nMasteryDeepWounds = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryDeepWounds.id, { 3 }) * 0.01
        end
    end)
end
frameDemolish:RegisterEvent("ADDON_LOADED")
frameDemolish:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Demolish.known and wan.spellData.Demolish.id
        wan.BlizzardEventHandler(frameDemolish, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameDemolish, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        local nSweepingStrikesValues = wan.GetSpellDescriptionNumbers(wan.spellData.SweepingStrikes.id, { 2, 3, 4 })
        nSweepingStrikesUnitCap = nSweepingStrikesValues[1]
        nSweepingStrikesMaxRange = nSweepingStrikesValues[2]
        nSweepingStrikes = nSweepingStrikesValues[3] * 0.01

        nColossusSmash = wan.GetTraitDescriptionNumbers(wan.traitData.ColossusSmash.entryid, { 2 }) * 0.01

        nImpale = wan.GetTraitDescriptionNumbers(wan.traitData.Impale.entryid, { 1 })

        nMartialExpertCritDamage = wan.GetTraitDescriptionNumbers(wan.traitData.MartialExpert.entryid, { 1 })

        nRecklessnessCritChance = wan.GetSpellDescriptionNumbers(wan.spellData.Recklessness.id, { 2 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameDemolish, CheckAbilityValue, abilityActive)
    end
end)