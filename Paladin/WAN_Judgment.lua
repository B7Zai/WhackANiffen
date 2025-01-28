local _, wan = ...

-- Exit early if player class doesn't match
if wan.PlayerState.Class ~= "PALADIN" then return end

-- Init spell data
local abilityActive = false
local nJudgmentDmg = 0
local nMasteryHighlordsJudgmentProcChance, nMasteryHighlordsJudgmentDmg = 0, 0

-- Init trait data
local nDivineGlimpse = 0
local nBoundlessJudgment = 0
local nHighlordsWrath = 0
local nBlessedChampionUnitCap, nBlessedChampion = 0, 0
local nForWhomtheBellTolls, nForWhomtheBellTollsMin = 0, 0

-- Ability value calculation
local function CheckAbilityValue()
    -- Early exits
    if not wan.PlayerState.Status or not wan.IsSpellUsable(wan.spellData.Judgment.id)
    then
        wan.UpdateAbilityData(wan.spellData.Judgment.basename)
        return
    end

    -- Check for valid unit
    local isValidUnit, countValidUnit, idValidUnit = wan.ValidUnitBoolCounter(wan.spellData.Judgment.id)
    if not isValidUnit then
        wan.UpdateAbilityData(wan.spellData.Judgment.basename)
        return
    end

    -- Base values
    local critChanceMod = 0
    local critDamageMod = 0
    local critChanceModBase = 0
    local critDamageModBase = 0

    local cJudgmentInstantDmg = 0
    local cJudgmentDotDmg = 0
    local cJudgmentInstantDmgAoE = 0
    local cJudgmentDotDmgAoE = 0

    local targetUnitToken = wan.TargetUnitID
    local targetGUID = wan.UnitState.GUID[targetUnitToken]

    ---- CLASS TRAITS ----

    local cRecompense = 0
    if wan.traitData.Recompense.known then
        local checkRecompenseBuff = wan.auraData.player["buff_" .. wan.traitData.Recompense.traitkey]
        if checkRecompenseBuff then
            for _, nRecompense  in pairs(checkRecompenseBuff.points) do
                cRecompense = cRecompense + nRecompense 
            end
        end
    end

    ---- HOLY TRAITS ----

    if wan.traitData.DivineGlimpse.known then
        critChanceMod = critChanceMod + nDivineGlimpse
    end

    ---- RETRIBUTION TRAITS ----

    local cHighlordsJudgmentInstantDmg = 0
    if wan.spellData.MasteryHighlordsJudgment.known then
        cHighlordsJudgmentInstantDmg = cHighlordsJudgmentInstantDmg + (nMasteryHighlordsJudgmentDmg * (nMasteryHighlordsJudgmentProcChance * nBoundlessJudgment * nHighlordsWrath))
    end

    local cBlessedChampionInstantDmgAoE = 0
    local countBlessedChampionUnits = 0
    if wan.traitData.BlessedChampion.known then

        for _, nameplateGUID in pairs(idValidUnit) do

            if nameplateGUID ~= targetGUID then

                cBlessedChampionInstantDmgAoE = cBlessedChampionInstantDmgAoE + ((nJudgmentDmg + cRecompense) * nBlessedChampion)
                countBlessedChampionUnits = countBlessedChampionUnits + 1

                if countBlessedChampionUnits >= nBlessedChampionUnitCap then break end
            end
        end
    end

    --- TEMPLAR TRAITS ----

    local cForWhomtheBellTolls = 1
    if wan.traitData.ForWhomtheBellTolls.known then
        local checkForWhomtheBellTollsBuff = wan.CheckUnitBuff("player", wan.traitData.ForWhomtheBellTolls.traitkey)
        if checkForWhomtheBellTollsBuff then
            local nForWhomtheBellTollsUnits = math.max(countValidUnit - 1, 0)
            cForWhomtheBellTolls = cForWhomtheBellTolls + (math.max((nForWhomtheBellTolls - (nForWhomtheBellTollsMin *  nForWhomtheBellTollsUnits)), nForWhomtheBellTollsMin))
        end
    end

    local cJudgmentCritValue = wan.ValueFromCritical(wan.CritChance, critChanceMod, critDamageMod)

    cJudgmentInstantDmg = cJudgmentInstantDmg 
        + (nJudgmentDmg * cForWhomtheBellTolls * cJudgmentCritValue)
        + (cHighlordsJudgmentInstantDmg * cJudgmentCritValue)
        + (cRecompense * cForWhomtheBellTolls * cJudgmentCritValue)

    cJudgmentDotDmg = cJudgmentDotDmg

    cJudgmentInstantDmgAoE = cJudgmentInstantDmgAoE
        + (cBlessedChampionInstantDmgAoE * cForWhomtheBellTolls * cJudgmentCritValue)
        + (cHighlordsJudgmentInstantDmg * countBlessedChampionUnits * cJudgmentCritValue)

    cJudgmentDotDmgAoE = cJudgmentDotDmgAoE

    local cJudgmentDmg = cJudgmentInstantDmg + cJudgmentDotDmg + cJudgmentInstantDmgAoE + cJudgmentDotDmgAoE

    -- Update ability data
    local abilityValue = math.floor(cJudgmentDmg)
    wan.UpdateAbilityData(wan.spellData.Judgment.basename, abilityValue, wan.spellData.Judgment.icon, wan.spellData.Judgment.name)
end

-- Init frame 
local frameJudgment = CreateFrame("Frame")
local function AddonLoad(self, event, addonName)
    -- Early Exit
    if addonName ~= "WhackANiffen" then return end

    -- Data update on events
    self:SetScript("OnEvent", function(self, event, ...)
        if (event == "UNIT_AURA" and ... == "player") or event == "SPELLS_CHANGED" or event == "PLAYER_EQUIPMENT_CHANGED" then
            nJudgmentDmg = wan.GetSpellDescriptionNumbers(wan.spellData.Judgment.id, { 1 })

            local nMasteryHighlordsJudgmentValues = wan.GetSpellDescriptionNumbers(wan.spellData.MasteryHighlordsJudgment.id, { 2, 3 })
            nMasteryHighlordsJudgmentProcChance = nMasteryHighlordsJudgmentValues[1] * 0.01
            nMasteryHighlordsJudgmentDmg = nMasteryHighlordsJudgmentValues[2]
        end
    end)
end
frameJudgment:RegisterEvent("ADDON_LOADED")
frameJudgment:SetScript("OnEvent", AddonLoad)

-- Set update rate based on settings
wan.EventFrame:HookScript("OnEvent", function(self, event, ...)

    if event == "SPELL_DATA_READY" then
        abilityActive = wan.spellData.Judgment.known and wan.spellData.Judgment.id
        wan.BlizzardEventHandler(frameJudgment, abilityActive, "SPELLS_CHANGED", "UNIT_AURA", "PLAYER_EQUIPMENT_CHANGED")
        wan.SetUpdateRate(frameJudgment, CheckAbilityValue, abilityActive)
    end

    if event == "TRAIT_DATA_READY" then
        nDivineGlimpse = wan.GetTraitDescriptionNumbers(wan.traitData.DivineGlimpse.entryid, { 1 })

        nBoundlessJudgment = 1 + wan.GetTraitDescriptionNumbers(wan.traitData.BoundlessJudgment.entryid, { 1 }) * 0.01

        nHighlordsWrath = 1 + wan.GetTraitDescriptionNumbers(wan.traitData.HighlordsWrath.entryid, { 1 }) * 0.01

        local nBlessedChampionValues = wan.GetTraitDescriptionNumbers(wan.traitData.BlessedChampion.entryid, { 1, 2 })
        nBlessedChampionUnitCap = nBlessedChampionValues[1]
        nBlessedChampion = 1 - (nBlessedChampionValues[2] * 0.01)

        local nForWhomtheBellTollsValues = wan.GetTraitDescriptionNumbers(wan.traitData.ForWhomtheBellTolls.entryid, { 1, 4 })
        nForWhomtheBellTolls = nForWhomtheBellTollsValues[1] * 0.01
        nForWhomtheBellTollsMin = nForWhomtheBellTollsValues[2] * 0.01
    end

    if event == "CUSTOM_UPDATE_RATE_TOGGLE" or event == "CUSTOM_UPDATE_RATE_SLIDER" then
        wan.SetUpdateRate(frameJudgment, CheckAbilityValue, abilityActive)
    end
end)