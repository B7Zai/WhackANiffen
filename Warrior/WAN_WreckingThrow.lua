local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "WARRIOR" then return end

-- Init spell data
local playerUnitToken = "player"
local playerGUID = wan.PlayerState.GUID
local abilityActive = false
local nWreckingThrowDmg, nWreckingThrowAbsorbDmg = 0, 0

-- Init trait data
local nMasteryDeepWounds = 0
local nColossusSmash = 0
local nImpale = 0
local nMartialExpertCritDamage = 0
local nOverwhelmingBlades = 0
local nDominanceoftheColossus = 0
local nRecklessnessCritChance = 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.WreckingThrow.id)
    then
        wan.UpdateAbilityData(wan.spellData.WreckingThrow.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.WreckingThrow.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.WreckingThrow.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    --local critChanceModBase = 0
    --local critDamageModBase = 0

    local cWreckingThrowInstantDmg = 0
    local cWreckingThrowDotDmg = 0
    local cWreckingThrowInstantDmgAoE = 0
    local cWreckingThrowDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    local checkUnitAbsorb = wan.CheckUnitAbsorb(targetUnitToken)
    if checkUnitAbsorb == 0 then
        wan.UpdateAbilityData(wan.spellData.WreckingThrow.basename)
        return
    end

    local cWreckingThrowAbsorbDmg = math.min(nWreckingThrowAbsorbDmg, checkUnitAbsorb)

    ---- WARRIOR TRAITS ----

    if wan.traitData.BerserkersTorment.known or wan.traitData.WarlordsTorment.known or wan.traitData.Recklessness.known then
        local checkRecklessnessBuff = wan.CheckUnitBuff(nil, wan.spellData.Recklessness.formattedName)
        if checkRecklessnessBuff then
            critChanceMod = critChanceMod + nRecklessnessCritChance
        end
    end

    ---- ARMS TRAITS ----

    local cMasteryDeepWounds = 1
    if wan.spellData.MasteryDeepWounds.known then
        local checkMasteryDeepWoundsDebuff = wan.CheckUnitDebuff(nil, "DeepWounds")
        if checkMasteryDeepWoundsDebuff then
            cMasteryDeepWounds = cMasteryDeepWounds + nMasteryDeepWounds
        end
    end

    local cColossusSmash = 1
    if wan.traitData.ColossusSmash.known then
        local checkColossusSmashDebuff = wan.CheckUnitDebuff(nil, wan.traitData.ColossusSmash.traitkey)
        if checkColossusSmashDebuff then
            cColossusSmash = cColossusSmash + nColossusSmash
        end
    end

    if wan.traitData.Impale.known then
        critDamageMod = critDamageMod + nImpale
    end

    ---- COLOSSUS TRAITS ----

    if wan.traitData.MartialExpert.known then
        critDamageMod = critDamageMod + nMartialExpertCritDamage
    end

    local cDominanceoftheColossus = 1
    if wan.traitData.DominanceoftheColossus.known then
        local checkWreckedDebuff = wan.CheckUnitDebuff(nil, "Wrecked")

        if checkWreckedDebuff then
            local cWreckedStacks = checkWreckedDebuff.applications
            cDominanceoftheColossus = cDominanceoftheColossus + (nDominanceoftheColossus * cWreckedStacks)
        end
    end

    ---- SLAYER TRAITS ----

    local cOverwhelmingBlades = 1
    if wan.traitData.OverwhelmingBlades.known or wan.traitData.UnrelentingOnslaught.known then
        local checkOverwhelmingBladesDebuff = wan.CheckUnitDebuff(nil, "Overwhelmed")

        if checkOverwhelmingBladesDebuff then
            local cOverwhelmingBladesStacks = checkOverwhelmingBladesDebuff.applications
            cOverwhelmingBlades = cOverwhelmingBlades + (nOverwhelmingBlades * cOverwhelmingBladesStacks)
        end
    end

    local cWreckingThrowCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)
    --local cWreckingThrowCritValueBase = wan.ValueFromCritical(wan.CritChance, critChanceModBase, critDamageModBase)

    cWreckingThrowInstantDmg = cWreckingThrowInstantDmg
        + (nWreckingThrowDmg * cWreckingThrowCritValue * cMasteryDeepWounds * cColossusSmash * cDominanceoftheColossus * cOverwhelmingBlades)
        + (cWreckingThrowAbsorbDmg * cWreckingThrowCritValue * cMasteryDeepWounds * cColossusSmash * cDominanceoftheColossus * cOverwhelmingBlades)

    cWreckingThrowDotDmg = cWreckingThrowDotDmg

    cWreckingThrowInstantDmgAoE = cWreckingThrowInstantDmgAoE

    cWreckingThrowDotDmgAoE = cWreckingThrowDotDmgAoE

    local cWreckingThrowDmg = cWreckingThrowInstantDmg + cWreckingThrowDotDmg + cWreckingThrowInstantDmgAoE + cWreckingThrowDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cWreckingThrowDmg)
    wan.UpdateAbilityData(wan.spellData.WreckingThrow.basename, abilityValue, wan.spellData.WreckingThrow.icon, wan.spellData.WreckingThrow.name)
end

-- Init frame 
local frameWreckingThrow = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            local nWreckingThrowValues = wan.GetSpellDescriptionNumbers(wan.spellData.WreckingThrow.id, { 1, 2 })
            nWreckingThrowDmg = nWreckingThrowValues[1]
            nWreckingThrowAbsorbDmg = (nWreckingThrowDmg * nWreckingThrowValues[2] * 0.01) - nWreckingThrowDmg

            nMasteryDeepWounds = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryDeepWounds.id, { 3 }) * 0.01
        end
    end)
end
frameWreckingThrow:RegisterEvent("ADDON_LOADED")
frameWreckingThrow:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.WreckingThrow.known and wan.spellData.WreckingThrow.id
        wan.BlizzardEventHandler(frameWreckingThrow, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameWreckingThrow, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nColossusSmash = wan.GetTraitDescriptionNumbers(wan.traitData.ColossusSmash.entryid, { 2 }) * 0.01

        nImpale = wan.GetTraitDescriptionNumbers(wan.traitData.Impale.entryid, { 1 })

        nMartialExpertCritDamage = wan.GetTraitDescriptionNumbers(wan.traitData.MartialExpert.entryid, { 1 })

        nOverwhelmingBlades = wan.GetTraitDescriptionNumbers(wan.traitData.OverwhelmingBlades.entryid, { 1 }) * 0.01

        nDominanceoftheColossus = wan.GetTraitDescriptionNumbers(wan.traitData.DominanceoftheColossus.entryid, { 3 }) * 0.001
        
        nRecklessnessCritChance = wan.GetSpellDescriptionNumbers(wan.spellData.Recklessness.id, { 2 })
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameWreckingThrow, CheckAbilityValue, abilityActive)
    end
end)